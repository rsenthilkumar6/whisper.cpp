import 'package:equatable/equatable.dart';

/// Lifecycle of a dictation session.
enum RecordingStatus {
  /// No active session.
  idle,

  /// Connecting to the whisper server.
  connecting,

  /// Actively capturing audio and streaming transcripts.
  recording,

  /// Stop requested; waiting for / displaying the final transcript.
  finalizing,

  /// A recoverable error occurred (connection failed, permission denied, …).
  error,
}

/// Immutable UI state for the recording overlay.
class RecordingState extends Equatable {
  const RecordingState({
    this.status = RecordingStatus.idle,
    this.transcript = '',
    this.message = '',
    this.hasError = false,
  });

  final RecordingStatus status;
  final String transcript;
  final String message;
  final bool hasError;

  bool get isRecording =>
      status == RecordingStatus.recording ||
      status == RecordingStatus.connecting ||
      status == RecordingStatus.finalizing;

  RecordingState copyWith({
    RecordingStatus? status,
    String? transcript,
    String? message,
    bool? hasError,
  }) {
    return RecordingState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      message: message ?? this.message,
      hasError: hasError ?? this.hasError,
    );
  }

  @override
  List<Object?> get props => [status, transcript, message, hasError];
}
