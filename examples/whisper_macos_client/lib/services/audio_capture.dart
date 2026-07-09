import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import '../core/constants.dart';

/// Captures microphone audio and exposes it as a stream of raw int16 PCM
/// frames (16 kHz, mono) — exactly what the whisper server expects.
///
/// Also provides a real-time RMS level stream for UI visualization.
class AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _subscription;
  final _levelController = StreamController<double>.broadcast();

  /// Whether a recording session is currently active.
  bool get isRecording => _subscription != null;

  /// Stream of RMS audio levels (0.0 to 1.0) for real-time waveform visualization.
  Stream<double> get levelStream => _levelController.stream;

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
    _subscription = stream.listen((Uint8List chunk) {
      onData(chunk);
      _emitLevel(chunk);
    });
  }

  void _emitLevel(Uint8List pcm) {
    if (pcm.length < 2) return;
    // Calculate RMS of int16 samples
    double sumSq = 0;
    final int count = pcm.length ~/ 2;
    for (int i = 0; i < count; i++) {
      final sample = (pcm[i * 2] | (pcm[i * 2 + 1] << 8)) / 32768.0;
      sumSq += sample * sample;
    }
    final rms = math.sqrt(sumSq / count);
    _levelController.add(rms.clamp(0.0, 1.0));
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
    await _levelController.close();
  }
}
