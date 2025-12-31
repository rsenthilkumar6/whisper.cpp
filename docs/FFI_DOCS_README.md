# Whisper.cpp FFI Documentation for Dart/Flutter

Quick reference documentation for integrating whisper.cpp with Flutter/Dart via FFI.

## Document Index

| Document | Purpose |
|----------|---------|
| [ffi-overview.md](./ffi-overview.md) | Architecture, concepts, memory management |
| [ffi-integration.md](./ffi-integration.md) | Complete API reference with Dart examples |
| [ffi-api-quick-reference.md](./ffi-api-quick-reference.md) | Function lookup, snippets, type mappings |

## Quick Decision Guide

### What operation do you need?

| Task | Functions | Isolate? |
|------|-----------|----------|
| Load model | `whisper_init_from_file_with_params` | YES |
| Transcribe audio | `whisper_full` | YES |
| Real-time streaming | `whisper_full` + callbacks | YES |
| Get results | `whisper_full_get_segment_*` | No |
| Free resources | `whisper_free` | No |
| Language detection | `whisper_lang_auto_detect` | YES |
| VAD processing | `whisper_vad_*` | YES |

### Must Use Isolate (Long-running operations)

```
whisper_init_from_file_with_params  - Model loading (1-10s)
whisper_full                        - Transcription (varies)
whisper_full_parallel               - Parallel transcription
whisper_pcm_to_mel                  - Audio preprocessing
whisper_encode                      - Encoder pass
whisper_decode                      - Decoder pass
whisper_lang_auto_detect            - Language detection
whisper_vad_detect_speech           - VAD processing
```

### Safe on Main Thread (Fast operations)

```
whisper_full_n_segments             - Get segment count
whisper_full_get_segment_text       - Get text
whisper_full_get_segment_t0/t1      - Get timestamps
whisper_full_get_token_*            - Token access
whisper_free                        - Cleanup
whisper_context_default_params      - Get defaults
whisper_full_default_params         - Get defaults
whisper_lang_id                     - Language lookup
whisper_token_to_str                - Token to string
```

## Audio Format Requirements

```
Sample Rate: 16000 Hz (WHISPER_SAMPLE_RATE)
Format: 32-bit float PCM (-1.0 to 1.0)
Channels: Mono
Max Duration: 30 seconds per chunk
```

## Memory Estimates

| Model | Disk | RAM |
|-------|------|-----|
| tiny | 75 MB | ~273 MB |
| base | 142 MB | ~388 MB |
| small | 466 MB | ~852 MB |
| medium | 1.5 GB | ~2.1 GB |
| large | 2.9 GB | ~3.9 GB |

## Minimal Dart FFI Flow

```dart
// 1. Load model (in isolate)
final ctx = whisperInitFromFileWithParams(modelPath, params);

// 2. Transcribe (in isolate)
final result = whisperFull(ctx, fullParams, samples, nSamples);

// 3. Get results (main thread OK)
final nSegments = whisperFullNSegments(ctx);
for (var i = 0; i < nSegments; i++) {
  final text = whisperFullGetSegmentText(ctx, i).toDartString();
  final t0 = whisperFullGetSegmentT0(ctx, i);
  final t1 = whisperFullGetSegmentT1(ctx, i);
}

// 4. Cleanup
whisperFree(ctx);
```

## Key Architecture Points

1. **Thread Safety**: Same context must NOT be used by multiple threads concurrently
2. **Isolates**: All heavy operations in separate isolate via SendPort/ReceivePort
3. **Callbacks**: Segment/progress callbacks must be static or top-level Dart functions
4. **Memory**: Context owns all memory; calling `whisper_free` releases everything
5. **Pointers**: `const char*` returns are owned by context - copy if needed long-term

## Common Patterns

### Isolate Command Pattern
```dart
enum WhisperCommand { load, transcribe, free }

class WhisperRequest {
  final WhisperCommand command;
  final SendPort replyPort;
  final dynamic data;
}
```

### Progress Reporting
```dart
// Native callback -> Dart via NativeCallable
void progressCallback(Pointer<whisper_context> ctx,
                      Pointer<whisper_state> state,
                      int progress, Pointer<Void> userData) {
  // Send progress to main isolate
}
```

### Streaming Transcription
```dart
// Use new_segment_callback to get incremental results
params.new_segment_callback = nativeSegmentCallback;
params.new_segment_callback_user_data = sendPortAddress;
```

## Next Steps

1. Read [ffi-overview.md](./ffi-overview.md) for architecture details
2. Use [ffi-integration.md](./ffi-integration.md) for implementation
3. Reference [ffi-api-quick-reference.md](./ffi-api-quick-reference.md) during coding
