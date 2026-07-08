import 'dart:async' show Timer, unawaited;
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants.dart';
import '../services/audio_capture.dart';
import '../services/settings_repository.dart';
import '../services/text_inserter.dart';
import '../services/tray_service.dart';
import '../services/whisper_client.dart';
import '../services/window_service.dart';
import 'recording_state.dart';

class RecordingCubit extends Cubit<RecordingState> {
  RecordingCubit({
    required this._audio,
    required this._inserter,
    required this._window,
    required this._tray,
    required this._settings,
  }) : super(const RecordingState());

  final AudioCapture _audio;
  final TextInserter _inserter;
  final WindowService _window;
  final TrayService _tray;
  final SettingsRepository _settings;

  WhisperClient? _client;
  Timer? _hideTimer;
  String _lastInserted = '';

  Future<void> toggle() async {
    if (state.isRecording) {
      await stop();
    } else {
      await start();
    }
  }

  Future<void> start() async {
    if (state.isRecording) return;

    emit(state.copyWith(
      status: RecordingStatus.connecting,
      transcript: '',
      message: 'Connecting…',
      hasError: false,
    ));
    await _window.showPopup();
    await _tray.setRecording(true);

    final granted = await _audio.requestPermission();
    if (!granted) {
      _fail('Microphone access denied. Enable it in System Settings.');
      return;
    }

    final config = await _settings.load();

    _client = WhisperClient(
      onTranscript: _onTranscript,
      onError: (error) {
        _fail(error);
      },
      onClosed: _onClosed,
    );

    await _client!.connect(config);

    if (state.hasError) return;

    _lastInserted = '';
    await _audio.start(_onAudioChunk);

    emit(state.copyWith(
      status: RecordingStatus.recording,
      message: 'Listening…',
    ));
  }

  void _onAudioChunk(Uint8List pcm) {
    if (state.status == RecordingStatus.recording) {
      _client?.sendAudio(pcm);
    }
  }

  void _onTranscript(TranscriptEvent event) {
    emit(state.copyWith(
      status: event.isFinal
          ? RecordingStatus.finalizing
          : RecordingStatus.recording,
      transcript: event.text,
      message: event.isFinal ? 'Done' : 'Listening…',
    ));

    if (event.text.startsWith(_lastInserted)) {
      final suffix = event.text.substring(_lastInserted.length);
      if (suffix.trim().isNotEmpty) {
        _insert(suffix);
      }
    } else if (event.text.isNotEmpty) {
      _insert(event.text);
    }
    _lastInserted = event.text;
  }

  Future<void> _insert(String text) async {
    final result = await _inserter.insert(text);
    if (result == InsertResult.copiedToClipboard) {
      emit(state.copyWith(
        message: 'Paste manually (⌘V) \u2014 grant Accessibility for auto-type',
      ));
    }
  }

  void _onClosed() {
    _scheduleHide();
  }

  Future<void> stop() async {
    if (!state.isRecording) return;
    _client?.sendEof();
    emit(state.copyWith(
      status: RecordingStatus.finalizing,
      message: 'Finalizing\u2026',
    ));
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppConstants.finalDisplayDelay, _finish);
  }

  Future<void> _finish() async {
    _hideTimer?.cancel();
    _hideTimer = null;
    await _audio.stop();
    await _client?.disconnect();
    _client = null;
    await _tray.setRecording(false);
    await _window.hide();
    emit(const RecordingState());
  }

  void _fail(String message) {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppConstants.errorDisplayDelay, _finish);
    emit(state.copyWith(
      status: RecordingStatus.error,
      hasError: true,
      message: message,
    ));
    unawaited(_window.showPopup());
  }

  @override
  Future<void> close() async {
    _hideTimer?.cancel();
    await _audio.dispose();
    await _client?.disconnect();
    await super.close();
  }
}