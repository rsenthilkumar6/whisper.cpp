import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../domain/server_config.dart';

class TranscriptEvent {
  const TranscriptEvent(this.text, this.isFinal);

  final String text;
  final bool isFinal;
}

class ConnectionResult {
  const ConnectionResult(this.ok, [this.message = '']);

  final bool ok;
  final String message;
}

class WhisperClient {
  Socket? _socket;
  StreamSubscription? _subscription;
  bool _disposed = false;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  final void Function(TranscriptEvent) onTranscript;
  final void Function(String) onError;
  final void Function() onClosed;

  WhisperClient({
    required this.onTranscript,
    required this.onError,
    required this.onClosed,
  });

  bool get isConnected => _socket != null && !_disposed;

  Future<void> connect(ServerConfig config) async {
    final host = config.host;
    final port = config.port;

    try {
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 8),
      );
    } on SocketException catch (e) {
      onError('Cannot reach $host:$port. ${e.message}');
      return;
    } on TimeoutException {
      onError('Connection timed out. Is whisper-websocket-stream running at $host:$port?');
      return;
    } on Object catch (e) {
      onError('Failed to connect to $host:$port. $e');
      return;
    }

    final handshakeSuccess = await _doHandshake(host, port);
    if (!handshakeSuccess || _disposed) return;

    _socket!.write(jsonEncode({
      'config': {
        'language': config.language,
        'task': config.translate ? 'translate' : 'transcribe',
        'translate': config.translate,
      },
    }));
    await _socket!.flush();

    _messageController.stream.listen(
      _onMessage,
      onError: (Object e) {
        if (!_disposed) onError('Connection error: $e');
      },
      onDone: () {
        if (!_disposed) onClosed();
      },
      cancelOnError: false,
    );

    _subscription = _socket!.listen(
      _onRawData,
      onError: (Object e) {
        if (!_disposed) onError('Socket error: $e');
      },
      onDone: () {
        if (!_disposed) onClosed();
      },
      cancelOnError: false,
    );
  }

  String _encodeBase64(List<int> bytes) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (int i = 0; i < bytes.length; i += 3) {
      int v = bytes[i] << 16;
      if (i + 1 < bytes.length) v |= bytes[i + 1] << 8;
      if (i + 2 < bytes.length) v |= bytes[i + 2];
      result.write(chars[(v >> 18) & 0x3F]);
      result.write(chars[(v >> 12) & 0x3F]);
      result.write(i + 1 < bytes.length ? chars[(v >> 6) & 0x3F] : '=');
      result.write(i + 2 < bytes.length ? chars[v & 0x3F] : '=');
    }
    return result.toString();
  }

  Future<bool> _doHandshake(String host, int port) async {
    final keyBytes = List<int>.generate(16, (_) => Random().nextInt(256));
    final key = base64Encode(keyBytes);
    final request = StringBuffer()
      ..write('GET / HTTP/1.1\r\n')
      ..write('Host: $host:$port\r\n')
      ..write('Upgrade: websocket\r\n')
      ..write('Connection: Upgrade\r\n')
      ..write('Sec-WebSocket-Key: $key\r\n')
      ..write('Sec-WebSocket-Version: 13\r\n')
      ..write('Origin: http://localhost\r\n')
      ..write('\r\n');

    _socket!.write(request.toString());

    final completer = Completer<bool>();
    final buffer = <int>[];
    final sub = _socket!.listen(
      (data) {
        buffer.addAll(data);
        final str = utf8.decode(buffer, allowMalformed: true);
        if (str.contains('\r\n\r\n')) {
          completer.complete(str.startsWith('HTTP/1.1 101'));
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.complete(false);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    _socket!.setSubscriptionHandler(() {});

    final success = await completer.future.timeout(const Duration(seconds: 8));
    await sub.cancel();
    _socket!.setReadHandler(true);
    return success;
  }

  void _onRawData(Uint8List data) {
    _frameBuffer.addAll(data);
    _processFrames();
  }

  final List<int> _frameBuffer = [];

  void _processFrames() {
    while (true) {
      if (_frameBuffer.length < 2) return;

      final opcode = _frameBuffer[0] & 0x0F;
      final masked = (_frameBuffer[1] & 0x80) != 0;
      int len = _frameBuffer[1] & 0x7F;
      int idx = 2;

      if (len == 126) {
        if (_frameBuffer.length < idx + 2) return;
        len = (_frameBuffer[idx] << 8) | _frameBuffer[idx + 1];
        idx += 2;
      } else if (len == 127) {
        if (_frameBuffer.length < idx + 8) return;
        len = 0;
        for (int i = 0; i < 8; i++) len = (len << 8) | _frameBuffer[idx + i];
        idx += 8;
      }

      if (masked) idx += 4;
      if (_frameBuffer.length < idx + len) return;

      if (opcode == 0x0 || opcode == 0x1 || opcode == 0x2) {
        final payload = _frameBuffer.sublist(idx, idx + len);
        if (opcode == 0x1) {
          _messageController.add(utf8.decode(payload));
        }
      } else if (opcode == 0x8) {
        _frameBuffer.clear();
        onClosed();
        return;
      } else if (opcode == 0x9) {
        // ping — send pong
        final pong = Uint8List.fromList([0x8A, 0x00]);
        _socket?.add(pong);
      }

      _frameBuffer.removeRange(0, idx + len);
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>?;
      if (data == null) return;
      if (data.containsKey('error')) {
        onError(data['error'].toString());
      } else if (data.containsKey('text')) {
        final text = (data['text'] as String?) ?? '';
        final isFinal = (data['is_final'] as bool?) ?? false;
        onTranscript(TranscriptEvent(text, isFinal));
      }
    } catch (_) {
      onError('Malformed server message');
    }
  }

  void sendAudio(Uint8List pcm) {
    if (_disposed) return;
    final frame = _buildFrame(0x2, pcm);
    _socket?.add(frame);
  }

  void sendEof() {
    if (_disposed) return;
    final data = utf8.encode(jsonEncode({'eof': true}));
    final frame = _buildFrame(0x1, data);
    _socket?.add(frame);
  }

  Uint8List _buildFrame(int opcode, List<int> payload) {
    final mask = List<int>.generate(4, (_) => Random().nextInt(256));
    final masked = <int>[];
    for (int i = 0; i < payload.length; i++) {
      masked.add(payload[i] ^ mask[i & 3]);
    }

    final out = <int>[];
    out.add(0x80 | opcode);
    if (payload.length < 126) {
      out.add(0x80 | payload.length);
    } else if (payload.length < 65536) {
      out.add(0x80 | 126);
      out.add((payload.length >> 8) & 0xFF);
      out.add(payload.length & 0xFF);
    } else {
      out.add(0x80 | 127);
      for (int i = 7; i >= 0; i--) out.add((payload.length >> (8 * i)) & 0xFF);
    }
    out.addAll(mask);
    out.addAll(masked);
    return Uint8List.fromList(out);
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
  }

  static Future<ConnectionResult> test(ServerConfig config) async {
    try {
      final socket = await Socket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 8),
      );
      await socket.close();
      return const ConnectionResult(true);
    } on TimeoutException {
      return ConnectionResult(false,
          'Timed out connecting to ${config.host}:${config.port}.');
    } on SocketException catch (e) {
      return ConnectionResult(false, '${e.message}');
    } on Object catch (e) {
      return ConnectionResult(false, '$e');
    }
  }
}