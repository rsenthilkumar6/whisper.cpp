// WebSocket streaming server for whisper.cpp
//
// Receives raw 16-bit PCM mono audio (16 kHz) over a WebSocket connection and
// streams back incremental transcriptions. The client is expected to:
//
//   1. (optional) send a text frame with JSON config:
//        {"config": {"language": "en", "task": "transcribe", "translate": false}}
//   2. send binary frames containing raw int16 PCM audio (16 kHz, mono)
//   3. (optional) send a text frame {"eof": true} to request a final result
//
// The server responds with text frames containing JSON:
//        {"text": "<current transcript>", "is_final": false}
//        {"text": "<final transcript>",   "is_final": true}
//        {"error": "..."}
//
// "Streaming" is implemented by re-transcribing the (capped) rolling audio
// buffer whenever enough new audio has arrived, and sending the full current
// transcript each time. The client only needs to insert the new suffix.

#include "whisper.h"
#include "json.hpp"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <atomic>
#include <ctime>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

using json = nlohmann::ordered_json;

static const int SAMPLE_RATE = WHISPER_SAMPLE_RATE;  // 16000

// ---------------------------------------------------------------------------
// Minimal RFC6455 WebSocket server (server-side framing only)
// ---------------------------------------------------------------------------

// Decode one complete frame from the buffered socket data.
// Returns true if a frame was parsed (and consumed from `buf`).
// opcode: 0x1 text, 0x2 binary, 0x8 close, 0x9 ping, 0xA pong, 0x0 continuation
struct WSFrame {
    uint8_t opcode = 0;
    bool fin = true;
    std::vector<uint8_t> payload;
};

static bool ws_try_parse_frame(std::vector<uint8_t> & buf, WSFrame & frame) {
    if (buf.size() < 2) return false;

    frame.fin    = (buf[0] & 0x80) != 0;
    frame.opcode = buf[0] & 0x0F;

    bool masked = (buf[1] & 0x80) != 0;
    uint64_t len = buf[1] & 0x7F;
    size_t idx = 2;

    if (len == 126) {
        if (buf.size() < idx + 2) return false;
        len = (uint64_t(buf[2]) << 8) | buf[3];
        idx = 4;
    } else if (len == 127) {
        if (buf.size() < idx + 8) return false;
        len = 0;
        for (int i = 0; i < 8; i++) len = (len << 8) | buf[idx + i];
        idx = 10;
    }

    uint8_t mask[4] = {0, 0, 0, 0};
    if (masked) {
        if (buf.size() < idx + 4) return false;
        memcpy(mask, &buf[idx], 4);
        idx += 4;
    }

    if (buf.size() < idx + len) return false;

    frame.payload.resize(len);
    if (len > 0) {
        memcpy(frame.payload.data(), &buf[idx], len);
        if (masked) {
            for (uint64_t i = 0; i < len; i++) frame.payload[i] ^= mask[i & 3];
        }
    }
    buf.erase(buf.begin(), buf.begin() + idx + len);
    return true;
}

static bool ws_send(int fd, uint8_t opcode, const std::vector<uint8_t> & data) {
    std::vector<uint8_t> out;
    out.push_back(0x80 | opcode);  // FIN + opcode, server frames are unmasked
    size_t len = data.size();
    if (len < 126) {
        out.push_back((uint8_t)len);
    } else if (len < 65536) {
        out.push_back(126);
        out.push_back((len >> 8) & 0xFF);
        out.push_back(len & 0xFF);
    } else {
        out.push_back(127);
        for (int i = 7; i >= 0; i--) out.push_back((len >> (8 * i)) & 0xFF);
    }
    out.insert(out.end(), data.begin(), data.end());
    size_t written = 0;
    while (written < out.size()) {
        ssize_t n = write(fd, out.data() + written, out.size() - written);
        if (n <= 0) return false;
        written += (size_t)n;
    }
    return true;
}

static bool ws_send_text(int fd, const std::string & s) {
    return ws_send(fd, 0x1, std::vector<uint8_t>(s.begin(), s.end()));
}

static bool ws_handshake(int fd) {
    std::vector<uint8_t> buf;
    char tmp[4096];
    bool got_end = false;
    while (!got_end) {
        ssize_t n = recv(fd, tmp, sizeof(tmp), 0);
        if (n <= 0) return false;
        buf.insert(buf.end(), (uint8_t *)tmp, (uint8_t *)tmp + n);
        // HTTP request ends with double CRLF
        if (buf.size() >= 4) {
            for (size_t i = 0; i + 3 < buf.size(); i++) {
                if (buf[i] == '\r' && buf[i+1] == '\n' && buf[i+2] == '\r' && buf[i+3] == '\n') {
                    got_end = true;
                    break;
                }
            }
        }
    }

    std::string req((char *)buf.data(), buf.size());
    std::string key;
    size_t pos = req.find("Sec-WebSocket-Key:");
    if (pos == std::string::npos) return false;
    pos += 18;
    while (pos < req.size() && (req[pos] == ' ' || req[pos] == '\t')) pos++;
    size_t end = req.find("\r\n", pos);
    if (end == std::string::npos) return false;
    key = req.substr(pos, end - pos);

    // accept key = base64(sha1(key + GUID))
    const std::string GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    std::string concat = key + GUID;

    // SHA-1
    uint32_t h[5] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0};
    std::vector<uint8_t> msg(concat.begin(), concat.end());
    msg.push_back(0x80);
    while (msg.size() % 64 != 56) msg.push_back(0x00);
    uint64_t bitlen = (uint64_t)concat.size() * 8;
    for (int i = 7; i >= 0; i--) msg.push_back((bitlen >> (8 * i)) & 0xFF);

    auto rol = [](uint32_t v, int s) { return (v << s) | (v >> (32 - s)); };
    for (size_t off = 0; off < msg.size(); off += 64) {
        uint32_t w[80];
        for (int i = 0; i < 16; i++) {
            w[i] = (msg[off + 4*i] << 24) | (msg[off + 4*i+1] << 16) |
                   (msg[off + 4*i+2] << 8)  | (msg[off + 4*i+3]);
        }
        for (int i = 16; i < 80; i++) {
            w[i] = rol(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
        }
        uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
        for (int i = 0; i < 80; i++) {
            uint32_t f; uint32_t k;
            if (i < 20)      { f = (b & c) | ((~b) & d); k = 0x5A827999; }
            else if (i < 40) { f = b ^ c ^ d;             k = 0x6ED9EBA1; }
            else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC; }
            else             { f = b ^ c ^ d;             k = 0xCA62C1D6; }
            uint32_t tmp2 = rol(a, 5) + f + e + k + w[i];
            e = d; d = c; c = rol(b, 30); b = a; a = tmp2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e;
    }

    std::vector<uint8_t> digest;
    for (int i = 0; i < 5; i++)
        for (int j = 3; j >= 0; j--)
            digest.push_back((h[i] >> (8 * j)) & 0xFF);

    // base64 encode
    static const char *b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string accept;
    for (size_t i = 0; i < digest.size(); i += 3) {
        uint32_t v = digest[i] << 16;
        if (i + 1 < digest.size()) v |= digest[i+1] << 8;
        if (i + 2 < digest.size()) v |= digest[i+2];
        accept.push_back(b64[(v >> 18) & 0x3F]);
        accept.push_back(b64[(v >> 12) & 0x3F]);
        accept.push_back(i + 1 < digest.size() ? b64[(v >> 6) & 0x3F] : '=');
        accept.push_back(i + 2 < digest.size() ? b64[v & 0x3F] : '=');
    }

    auto now = std::time(nullptr);
    char date_buf[64];
    std::strftime(date_buf, sizeof(date_buf), "%a, %d %b %Y %H:%M:%S GMT", std::gmtime(&now));

    std::string resp =
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Accept: " + accept + "\r\n"
        "Date: " + date_buf + "\r\n"
        "\r\n";
    size_t written = 0;
    while (written < resp.size()) {
        ssize_t n = write(fd, resp.data() + written, resp.size() - written);
        if (n <= 0) return false;
        written += (size_t)n;
    }
    return true;
}

// ---------------------------------------------------------------------------
// Server parameters
// ---------------------------------------------------------------------------

struct server_config {
    std::string model      = "models/ggml-base.en.bin";
    std::string language   = "en";
    bool        translate  = false;
    int         n_threads  = std::min(4, (int)std::thread::hardware_concurrency());
    bool        flash_attn = true;
    bool        use_gpu    = true;
    std::string host       = "0.0.0.0";
    int         port       = 9002;
    int         beam_size  = 0;
};

// ---------------------------------------------------------------------------
// Per-connection streaming session
// ---------------------------------------------------------------------------

static std::mutex g_whisper_mtx;  // serialize whisper_full across connections

struct Session {
    int fd = -1;
    struct whisper_context * ctx = nullptr;
    const server_config * cfg = nullptr;

    std::mutex mtx;
    std::vector<float> audio;       // accumulated int16->float PCM (16 kHz)
    std::atomic<bool> alive{true};
    std::atomic<bool> has_new_audio{false};
    std::atomic<int>  new_samples{0};

    std::string language;
    bool        translate = false;

    // rolling buffer cap (samples) to bound re-transcription cost
    static const int max_buffer_samples = SAMPLE_RATE * 30;  // 30 s
    // minimum new audio (samples) before re-transcribing
    static const int min_new_samples   = SAMPLE_RATE * 1;    // 1 s

    std::string run_whisper(bool is_final) {
        whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        wparams.strategy       = (cfg->beam_size > 1) ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY;
        wparams.translate      = translate;
        wparams.language       = language.c_str();
        wparams.n_threads      = cfg->n_threads;
        wparams.print_realtime = false;
        wparams.print_progress = false;
        wparams.no_timestamps  = true;
        wparams.single_segment = false;
        wparams.no_context     = true;
        wparams.beam_search.beam_size = cfg->beam_size;

        std::lock_guard<std::mutex> lock(mtx);
        if (audio.empty()) return "";
        std::lock_guard<std::mutex> glock(g_whisper_mtx);
        if (whisper_full(ctx, wparams, audio.data(), (int)audio.size()) != 0) {
            return "";
        }
        std::string text;
        int n = whisper_full_n_segments(ctx);
        for (int i = 0; i < n; i++) {
            text += whisper_full_get_segment_text(ctx, i);
        }
        return text;
    }
};

static void session_reader(Session * s) {
    std::vector<uint8_t> buf;
    char tmp[16384];
    bool got_text_msg = false;

    while (s->alive.load()) {
        ssize_t n = recv(s->fd, tmp, sizeof(tmp), 0);
        if (n <= 0) { s->alive.store(false); break; }
        buf.insert(buf.end(), (uint8_t *)tmp, (uint8_t *)tmp + n);

        WSFrame frame;
        while (ws_try_parse_frame(buf, frame)) {
            if (frame.opcode == 0x8) {            // close
                s->alive.store(false);
                ws_send(s->fd, 0x8, {});
                return;
            } else if (frame.opcode == 0x9) {     // ping -> pong
                ws_send(s->fd, 0xA, frame.payload);
            } else if (frame.opcode == 0x1) {     // text (JSON control)
                std::string msg(frame.payload.begin(), frame.payload.end());
                try {
                    auto j = json::parse(msg);
                    if (j.contains("config")) {
                        auto c = j["config"];
                        if (c.contains("language")) s->language = c["language"].get<std::string>();
                        if (c.contains("task") && c["task"].get<std::string>() == "translate") s->translate = true;
                        if (c.contains("translate")) s->translate = c["translate"].get<bool>();
                        if (s->language.empty() || s->language == "auto") s->language = "auto";
                    }
                    if (j.contains("eof") && j["eof"].get<bool>()) {
                        std::string text = s->run_whisper(true);
                        json out;
                        out["text"] = text;
                        out["is_final"] = true;
                        ws_send_text(s->fd, out.dump());
                        s->alive.store(false);
                        return;
                    }
                } catch (...) {
                    json out; out["error"] = "invalid json";
                    ws_send_text(s->fd, out.dump());
                }
                got_text_msg = true;
                (void)got_text_msg;
            } else if (frame.opcode == 0x2 || frame.opcode == 0x0) {  // binary audio
                std::lock_guard<std::mutex> lock(s->mtx);
                const int16_t * p = (const int16_t *)frame.payload.data();
                size_t count = frame.payload.size() / sizeof(int16_t);
                for (size_t i = 0; i < count; i++) {
                    s->audio.push_back((float)p[i] / 32768.0f);
                }
                // cap rolling buffer
                if ((int)s->audio.size() > Session::max_buffer_samples) {
                    size_t drop = s->audio.size() - Session::max_buffer_samples;
                    s->audio.erase(s->audio.begin(), s->audio.begin() + drop);
                }
                s->new_samples.fetch_add((int)count);
                s->has_new_audio.store(true);
            }
        }
    }
    s->alive.store(false);
}

static void session_processor(Session * s) {
    while (s->alive.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(300));
        if (!s->alive.load()) break;
        if (s->new_samples.load() < Session::min_new_samples) continue;

        s->new_samples.store(0);
        std::string text = s->run_whisper(false);
        if (!s->alive.load()) break;
        json out;
        out["text"] = text;
        out["is_final"] = false;
        if (!ws_send_text(s->fd, out.dump())) {
            s->alive.store(false);
            return;
        }
        fprintf(stderr, "[stream] %s\n", text.c_str());
    }
}

static void handle_connection(int fd, struct whisper_context * ctx, const server_config * cfg) {
    if (!ws_handshake(fd)) { close(fd); return; }
    fprintf(stderr, "[ws] client connected\n");

    Session s;
    s.fd = fd;
    s.ctx = ctx;
    s.cfg = cfg;
    s.language = cfg->language;
    s.translate = cfg->translate;

    std::thread reader(session_reader, &s);
    std::thread processor(session_processor, &s);

    reader.join();
    s.alive.store(false);
    if (processor.joinable()) processor.join();

    ws_send(s.fd, 0x8, {});  // send close frame
    close(fd);
    fprintf(stderr, "[ws] client disconnected\n");
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

int main(int argc, char ** argv) {
    ggml_backend_load_all();

    server_config cfg;

    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        if (a == "-m" && i + 1 < argc)        { cfg.model = argv[++i]; }
        else if (a == "--model" && i + 1 < argc) { cfg.model = argv[++i]; }
        else if (a == "-t" && i + 1 < argc)   { cfg.n_threads = std::atoi(argv[++i]); }
        else if (a == "-fa")                  { cfg.flash_attn = true; }
        else if (a == "--no-fa")              { cfg.flash_attn = false; }
        else if (a == "--convert")            { /* no-op: raw PCM is sent directly */ }
        else if (a == "-bs" && i + 1 < argc)  { cfg.beam_size = std::atoi(argv[++i]); }
        else if (a == "--host" && i + 1 < argc) { cfg.host = argv[++i]; }
        else if (a == "--port" && i + 1 < argc) { cfg.port = std::atoi(argv[++i]); }
        else if (a == "-l" && i + 1 < argc)   { cfg.language = argv[++i]; }
        else if (a == "--language" && i + 1 < argc) { cfg.language = argv[++i]; }
        else if (a == "--translate")          { cfg.translate = true; }
        else if (a == "--cpu")                { cfg.use_gpu = false; }
    }

    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu    = cfg.use_gpu;
    cparams.flash_attn = cfg.flash_attn;

    fprintf(stderr, "[ws] loading model %s\n", cfg.model.c_str());
    struct whisper_context * ctx = whisper_init_from_file_with_params(cfg.model.c_str(), cparams);
    if (ctx == nullptr) {
        fprintf(stderr, "error: failed to initialize whisper context\n");
        return 3;
    }
    fprintf(stderr, "[ws] model loaded, listening on %s:%d\n", cfg.host.c_str(), cfg.port);

    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) { perror("socket"); return 1; }
    int yes = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons((uint16_t)cfg.port);
    addr.sin_addr.s_addr = (cfg.host == "0.0.0.0") ? INADDR_ANY : inet_addr(cfg.host.c_str());

    if (bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); return 1;
    }
    if (listen(listen_fd, 8) < 0) {
        perror("listen"); return 1;
    }

    while (true) {
        int client_fd = accept(listen_fd, nullptr, nullptr);
        if (client_fd < 0) { perror("accept"); continue; }
        std::thread(handle_connection, client_fd, ctx, &cfg).detach();
    }

    whisper_free(ctx);
    close(listen_fd);
    return 0;
}
