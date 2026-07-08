# Changelog

All notable changes to this fork are documented here.

## [Unreleased]

### Added
- **WebSocket streaming server** (`examples/server/websocket-stream.cpp`): a
  self-contained RFC6455 server that accepts raw `int16` PCM (16 kHz, mono) audio
  over a WebSocket and streams back incremental transcripts as
  `{"text": "...", "is_final": bool}`. Streaming is implemented by re-transcribing
  a capped 30 s rolling buffer whenever ≥1 s of new audio arrives; a global mutex
  serializes `whisper_full` across connections.
- **`whisper-websocket-stream` build target** in `examples/server/CMakeLists.txt`
  (links `common json_cpp whisper pthread`).
- **Python streaming client** (`examples/clients/streaming_client.py`): records from
  the microphone with `sounddevice`, streams audio via `websockets`, and inserts the
  live transcript at the cursor (AppleScript) on F1 start/stop.
- **`examples/clients/run.sh`**: provisions the venv (`sounddevice websockets
  pynput`) and launches the streaming client.
- **`server.sh`**: launches `./build/bin/whisper-websocket-stream` on `:9002`.

### Changed
- **`build.sh`**: the model step now checks for existing GGML files, downloads the
  pre-converted GGML (via `models/download-ggml-model.sh`) as the primary path, and
  falls back to source conversion (`make <model>`) only when the download fails. It
  skips Core ML generation for any model whose GGML is missing.

### Fixed
- Streaming transcription now actually works: previously `server.sh` referenced
  `whisper-websocket-stream`, which did not exist (the repo only shipped the HTTP
  `whisper-server`). The missing WebSocket server is now implemented and built.

## WebSocket protocol

```
client -> server : {"config": {"language": "en", "task": "transcribe", "translate": false}}
client -> server : <binary int16 PCM, 16 kHz, mono>  (repeated)
client -> server : {"eof": true}                     (optional, request final)
server -> client : {"text": "<transcript>", "is_final": false}   (repeated, live)
server -> client : {"text": "<transcript>", "is_final": true}    (on eof / disconnect)
server -> client : {"error": "..."}
```
