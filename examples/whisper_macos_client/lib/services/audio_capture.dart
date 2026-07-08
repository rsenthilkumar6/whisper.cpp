import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../core/constants.dart';

/// Captures microphone audio and exposes it as a stream of raw int16 PCM
/// frames (16 kHz, mono) — exactly what the whisper server expects.
///
/// Internally wraps the `record` plugin's `startStream`, which emits
/// `Uint8List` chunks of encoded audio. With [AudioEncoder.pcm16bits] those
/// chunks are plain little-endian int16 samples.
class AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _subscription;

  /// Whether a recording session is currently active.
  bool get isRecording => _subscription != null;

  /// Prompt for microphone access if not yet granted.
  Future<bool> requestPermission() => _recorder.hasPermission();

  /// Begin streaming audio. [onData] is invoked for every captured chunk.
  Future<void> start(void Function(Uint8List) onData) async {
    if (isRecording) return;

    final config = const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: AppConstants.sampleRate,
      numChannels: AppConstants.numChannels,
    );

    final stream = await _recorder.startStream(config);
    _subscription = stream.listen(onData);
  }

  /// Stop streaming and release the audio session.
  Future<void> stop() async {
    if (!isRecording) return;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // stop() may throw if the engine was already torn down; safe to ignore.
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
