import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

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
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _disposed = false;

  final void Function(TranscriptEvent) onTranscript;
  final void Function(String) onError;
  final void Function() onClosed;

  WhisperClient({
    required this.onTranscript,
    required this.onError,
    required this.onClosed,
  });

  bool get isConnected => _channel != null && !_disposed;

  Future<void> connect(ServerConfig config) async {
    final url = config.wsUrl;
    try {
      final wsUrl = Uri.parse(url);
      _channel = WebSocketChannel.connect(wsUrl);
      await _channel!.ready.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      onError('Connection timed out. Is whisper-websocket-stream running at $url?');
      return;
    } on WebSocketChannelException catch (e) {
      final msg = e.message ?? '';
      if (msg.contains('HttpException') || msg.contains('header')) {
        onError(
          'Could not connect to $url. Ensure whisper-websocket-stream is running.\n'
          '($msg)',
        );
      } else {
        onError('Connection failed: $msg');
      }
      return;
    } on WebSocketException catch (e) {
      onError('WebSocket error: ${e.message}');
      return;
    } on HttpException catch (e) {
      onError(
        'The whisper server at $url closed the connection unexpectedly.\n'
        'Ensure whisper-websocket-stream is running (${e.message}).',
      );
      return;
    } on HandshakeException catch (e) {
      onError(
        'Cannot reach $url.\n'
        '${e.message}',
      );
      return;
    } on SocketException catch (e) {
      onError(
        'Cannot reach $url.\n'
        '${e.message}',
      );
      return;
    } on Object catch (e) {
      onError(
        'Failed to connect to $url.\n'
        '${e.runtimeType}: $e',
      );
      return;
    }

    _channel!.sink.add(
      jsonEncode({
        'config': {
          'language': config.language,
          'task': config.translate ? 'translate' : 'transcribe',
          'translate': config.translate,
        },
      }),
    );

    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: (Object e) {
        if (!_disposed) onError('Connection error: $e');
      },
      onDone: () {
        if (!_disposed) onClosed();
      },
      cancelOnError: false,
    );
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;
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
    if (!_disposed) _channel?.sink.add(pcm);
  }

  void sendEof() {
    if (!_disposed) _channel?.sink.add(jsonEncode({'eof': true}));
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  static Future<ConnectionResult> test(ServerConfig config) async {
    final url = config.wsUrl;
    try {
      final wsUrl = Uri.parse(url);
      final channel = WebSocketChannel.connect(wsUrl);
      await channel.ready.timeout(const Duration(seconds: 8));
      await channel.sink.close();
      return const ConnectionResult(true);
    } on TimeoutException {
      return ConnectionResult(false,
          'Timed out connecting to $url.\nIs whisper-websocket-stream running?');
    } on WebSocketException catch (e) {
      return ConnectionResult(false, e.message);
    } on HttpException catch (e) {
      return ConnectionResult(false,
          'Server at $url closed connection unexpectedly (${e.message}).');
    } on HandshakeException catch (e) {
      return ConnectionResult(false, e.message);
    } on SocketException catch (e) {
      return ConnectionResult(false, e.message);
    } on Object catch (e) {
      return ConnectionResult(false, '${e.runtimeType}: $e');
    }
  }
}