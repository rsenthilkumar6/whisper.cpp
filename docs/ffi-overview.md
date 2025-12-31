# Whisper.cpp FFI Overview

Architecture, concepts, and best practices for Dart FFI integration.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Core Data Structures](#core-data-structures)
- [Processing Pipeline](#processing-pipeline)
- [Isolate Strategy](#isolate-strategy)
- [Memory Management](#memory-management)
- [Callback Patterns](#callback-patterns)
- [Thread Safety](#thread-safety)

---

## Architecture Overview

### Whisper.cpp Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter/Dart Layer                       │
├─────────────────────────────────────────────────────────────┤
│  WhisperService (High-level API)                            │
│    ├── Model management                                      │
│    ├── Transcription interface                               │
│    └── Result handling                                       │
├─────────────────────────────────────────────────────────────┤
│  WhisperIsolate (Background processing)                     │
│    ├── SendPort/ReceivePort communication                   │
│    ├── Command dispatch                                      │
│    └── Callback bridging                                     │
├─────────────────────────────────────────────────────────────┤
│  FFI Bindings (dart:ffi + ffigen)                           │
│    ├── Native function pointers                              │
│    ├── Struct definitions                                    │
│    └── Memory helpers                                        │
├─────────────────────────────────────────────────────────────┤
│                    libwhisper.dylib                          │
│    ├── whisper.cpp (core implementation)                    │
│    └── ggml (tensor operations)                              │
└─────────────────────────────────────────────────────────────┘
```

### High-Level Flow

```
Audio Input (PCM float32, 16kHz)
        │
        ▼
┌───────────────────┐
│  Mel Spectrogram  │ ← whisper_pcm_to_mel
└───────────────────┘
        │
        ▼
┌───────────────────┐
│     Encoder       │ ← whisper_encode
└───────────────────┘
        │
        ▼
┌───────────────────┐
│     Decoder       │ ← whisper_decode (iterative)
└───────────────────┘
        │
        ▼
┌───────────────────┐
│  Text Segments    │ ← whisper_full_get_segment_*
└───────────────────┘
```

---

## Core Data Structures

### whisper_context (Opaque)

Main context holding model weights and state.

```c
struct whisper_context;  // Opaque - never access internals
```

**Dart FFI:**
```dart
typedef WhisperContext = Pointer<Void>;

// Create
final ctx = whisperInitFromFileWithParams(path, params);

// Use
whisperFull(ctx, fullParams, samples, nSamples);

// Free
whisperFree(ctx);
```

### whisper_state (Opaque)

Processing state, can be created separately for parallel processing.

```c
struct whisper_state;  // Created by whisper_init_state()
```

**Use Case:** Multiple concurrent transcriptions with same model
```dart
// One context, multiple states
final ctx = whisperInitFromFileWithParamsNoState(path, params);
final state1 = whisperInitState(ctx);
final state2 = whisperInitState(ctx);

// Parallel processing
whisperFullWithState(ctx, state1, params, audio1, n1);
whisperFullWithState(ctx, state2, params, audio2, n2);

// Cleanup
whisperFreeState(state1);
whisperFreeState(state2);
whisperFree(ctx);
```

### whisper_context_params

Model loading configuration.

```c
struct whisper_context_params {
    bool  use_gpu;           // Enable GPU acceleration
    bool  flash_attn;        // Flash attention (faster)
    int   gpu_device;        // CUDA device ID
    bool  dtw_token_timestamps;  // DTW token timestamps
    // ... alignment heads config
};
```

**Dart FFI:**
```dart
final class WhisperContextParams extends Struct {
  @Bool()
  external bool useGpu;

  @Bool()
  external bool flashAttn;

  @Int32()
  external int gpuDevice;

  @Bool()
  external bool dtwTokenTimestamps;

  // ... more fields
}

// Get defaults
final params = whisperContextDefaultParams();
params.useGpu = true;
params.flashAttn = true;
```

### whisper_full_params

Transcription configuration.

```c
struct whisper_full_params {
    enum whisper_sampling_strategy strategy;  // GREEDY or BEAM_SEARCH

    int n_threads;           // Processing threads
    int n_max_text_ctx;      // Max tokens from past
    int offset_ms;           // Start offset
    int duration_ms;         // Duration to process

    bool translate;          // Translate to English
    bool no_context;         // Don't use past transcription
    bool no_timestamps;      // Skip timestamp generation
    bool single_segment;     // Force single segment
    bool print_special;      // Print special tokens
    bool print_progress;     // Print progress
    bool print_realtime;     // Print in realtime
    bool print_timestamps;   // Print timestamps

    // Token-level timestamps
    bool  token_timestamps;
    float thold_pt;          // Token probability threshold
    float thold_ptsum;       // Sum probability threshold
    int   max_len;           // Max segment chars
    bool  split_on_word;     // Split on word boundary
    int   max_tokens;        // Max tokens per segment

    // Prompt
    const char * initial_prompt;
    const whisper_token * prompt_tokens;
    int prompt_n_tokens;

    // Language
    const char * language;   // "en", "auto", etc.
    bool detect_language;

    // Decoding
    float temperature;
    float max_initial_ts;
    float length_penalty;
    float temperature_inc;
    float entropy_thold;
    float logprob_thold;
    float no_speech_thold;

    // Strategy-specific
    struct { int best_of; } greedy;
    struct { int beam_size; float patience; } beam_search;

    // Callbacks
    whisper_new_segment_callback new_segment_callback;
    void * new_segment_callback_user_data;

    whisper_progress_callback progress_callback;
    void * progress_callback_user_data;

    whisper_encoder_begin_callback encoder_begin_callback;
    void * encoder_begin_callback_user_data;

    // VAD
    bool vad;
    const char * vad_model_path;
    struct whisper_vad_params vad_params;
};
```

### whisper_token_data

Token information with probabilities and timestamps.

```c
typedef struct whisper_token_data {
    whisper_token id;    // Token ID
    whisper_token tid;   // Timestamp token ID
    float p;             // Probability
    float plog;          // Log probability
    float pt;            // Timestamp probability
    float ptsum;         // Sum timestamp probabilities
    int64_t t0;          // Start time (if token timestamps)
    int64_t t1;          // End time
    int64_t t_dtw;       // DTW timestamp
    float vlen;          // Voice length
} whisper_token_data;
```

---

## Processing Pipeline

### Standard Transcription (whisper_full)

```dart
// In isolate
Future<TranscriptionResult> transcribe(String audioPath) async {
  // 1. Load audio to PCM float32
  final samples = await loadAudioPcm(audioPath);

  // 2. Get default params
  final params = whisperFullDefaultParams(WhisperSamplingStrategy.greedy);
  params.nThreads = Platform.numberOfProcessors;
  params.language = 'en'.toNativeUtf8();
  params.printProgress = false;

  // 3. Run transcription (BLOCKING - must be in isolate)
  final result = whisperFull(ctx, params, samples, samples.length);
  if (result != 0) throw Exception('Transcription failed: $result');

  // 4. Extract results
  final segments = <Segment>[];
  final nSegments = whisperFullNSegments(ctx);

  for (var i = 0; i < nSegments; i++) {
    segments.add(Segment(
      text: whisperFullGetSegmentText(ctx, i).toDartString(),
      start: whisperFullGetSegmentT0(ctx, i),
      end: whisperFullGetSegmentT1(ctx, i),
    ));
  }

  return TranscriptionResult(segments);
}
```

### Streaming/Real-time Pattern

```dart
// Setup callbacks before whisper_full
void setupStreamingCallbacks(Pointer<WhisperFullParams> params, SendPort port) {
  // Static callback function
  void onNewSegment(
    Pointer<WhisperContext> ctx,
    Pointer<WhisperState> state,
    int nNew,
    Pointer<Void> userData,
  ) {
    final nSegments = whisperFullNSegmentsFromState(state);
    for (var i = nSegments - nNew; i < nSegments; i++) {
      final text = whisperFullGetSegmentTextFromState(state, i).toDartString();
      final t0 = whisperFullGetSegmentT0FromState(state, i);
      final t1 = whisperFullGetSegmentT1FromState(state, i);

      // Send to main isolate
      port.send(SegmentUpdate(text, t0, t1));
    }
  }

  final callback = NativeCallable<whisper_new_segment_callback>.listener(
    onNewSegment,
  );

  params.ref.newSegmentCallback = callback.nativeFunction;
  params.ref.singleSegment = true;  // Important for streaming
}
```

### Low-Level Pipeline (Advanced)

For custom processing:

```dart
// 1. PCM to Mel spectrogram
whisperPcmToMel(ctx, samples, nSamples, nThreads);

// 2. Auto-detect language (optional)
final langProbs = calloc<Float>(whisperLangMaxId() + 1);
final langId = whisperLangAutoDetect(ctx, 0, nThreads, langProbs);
final language = whisperLangStr(langId).toDartString();
calloc.free(langProbs);

// 3. Encode
whisperEncode(ctx, 0, nThreads);

// 4. Decode (iterative)
final tokens = <int>[];
while (true) {
  whisperDecode(ctx, tokensPtr, tokens.length, pastTokens, nThreads);
  final logits = whisperGetLogits(ctx);
  final nextToken = sampleFromLogits(logits);
  if (nextToken == whisperTokenEot(ctx)) break;
  tokens.add(nextToken);
}
```

---

## Isolate Strategy

### Why Isolates?

| Operation | Duration | Must Use Isolate |
|-----------|----------|------------------|
| Model loading | 1-10s | YES |
| whisper_full (30s audio) | 2-30s | YES |
| whisper_pcm_to_mel | 100-500ms | YES |
| whisper_encode | 500ms-5s | YES |
| Get segment text | <1ms | No |
| Get timestamps | <1ms | No |
| Free context | <10ms | No |

### Recommended Architecture

```dart
class WhisperIsolate {
  late final SendPort _sendPort;
  final _responseController = StreamController<dynamic>.broadcast();

  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    WhisperContext? ctx;

    receivePort.listen((message) {
      final request = message as WhisperRequest;

      switch (request.command) {
        case WhisperCommand.load:
          ctx = _loadModel(request.data as String);
          request.replyPort.send(LoadResult(success: ctx != null));
          break;

        case WhisperCommand.transcribe:
          if (ctx == null) {
            request.replyPort.send(TranscribeResult.error('No model loaded'));
            return;
          }
          final result = _transcribe(ctx!, request.data);
          request.replyPort.send(result);
          break;

        case WhisperCommand.free:
          if (ctx != null) {
            whisperFree(ctx!);
            ctx = null;
          }
          request.replyPort.send(FreeResult());
          break;
      }
    });
  }

  Future<void> spawn() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntry, receivePort.sendPort);
    _sendPort = await receivePort.first;
  }
}
```

### Command Pattern

```dart
enum WhisperCommand {
  load,
  transcribe,
  transcribeStream,
  detectLanguage,
  cancel,
  free,
}

class WhisperRequest {
  final WhisperCommand command;
  final SendPort replyPort;
  final dynamic data;
  final SendPort? progressPort;  // For streaming updates
}
```

---

## Memory Management

### Ownership Rules

| Function | Ownership | Action Required |
|----------|-----------|-----------------|
| `whisper_init_*` | Caller owns context | Must call `whisper_free` |
| `whisper_init_state` | Caller owns state | Must call `whisper_free_state` |
| `whisper_full_get_segment_text` | Context owns | Copy if needed beyond context lifetime |
| `whisper_token_to_str` | Context owns | Copy if needed |
| `whisper_context_default_params` | Returns struct | No free needed |
| `whisper_full_default_params` | Returns struct | No free needed |

### Dart Memory Patterns

```dart
// Allocating audio buffer
final samplesPtr = calloc<Float>(nSamples);
try {
  // Copy Dart list to native
  for (var i = 0; i < samples.length; i++) {
    samplesPtr[i] = samples[i];
  }

  whisperFull(ctx, params, samplesPtr, nSamples);
} finally {
  calloc.free(samplesPtr);
}

// String handling
final pathPtr = path.toNativeUtf8();
try {
  final ctx = whisperInitFromFileWithParams(pathPtr, params);
} finally {
  calloc.free(pathPtr);
}

// Copying returned strings (owned by context)
final textPtr = whisperFullGetSegmentText(ctx, i);
final text = textPtr.toDartString();  // Safe copy to Dart

// Context cleanup
whisperFree(ctx);  // Frees all internal resources
```

### Preventing Leaks

```dart
class WhisperContext {
  Pointer<Void>? _ptr;
  bool _disposed = false;

  WhisperContext._(this._ptr);

  static WhisperContext? load(String path) {
    final pathPtr = path.toNativeUtf8();
    try {
      final params = whisperContextDefaultParams();
      final ptr = whisperInitFromFileWithParams(pathPtr, params);
      if (ptr == nullptr) return null;
      return WhisperContext._(ptr);
    } finally {
      calloc.free(pathPtr);
    }
  }

  void dispose() {
    if (!_disposed && _ptr != null) {
      whisperFree(_ptr!);
      _ptr = null;
      _disposed = true;
    }
  }

  // Use try/finally pattern
  Future<void> transcribe() async {
    if (_disposed) throw StateError('Context disposed');
    // ...
  }
}
```

---

## Callback Patterns

### Callback Types

```c
// New segment callback - called when new text is available
typedef void (*whisper_new_segment_callback)(
    struct whisper_context * ctx,
    struct whisper_state * state,
    int n_new,          // Number of new segments
    void * user_data
);

// Progress callback - called periodically with progress %
typedef void (*whisper_progress_callback)(
    struct whisper_context * ctx,
    struct whisper_state * state,
    int progress,       // 0-100
    void * user_data
);

// Encoder begin callback - return false to abort
typedef bool (*whisper_encoder_begin_callback)(
    struct whisper_context * ctx,
    struct whisper_state * state,
    void * user_data
);
```

### Dart Callback Implementation

```dart
// Define callback type
typedef WhisperNewSegmentCallback = Void Function(
  Pointer<Void> ctx,
  Pointer<Void> state,
  Int32 nNew,
  Pointer<Void> userData,
);

// Top-level or static callback function (required!)
void _onNewSegment(
  Pointer<Void> ctx,
  Pointer<Void> state,
  int nNew,
  Pointer<Void> userData,
) {
  // Get SendPort from userData
  final portAddress = userData.address;
  final port = SendPort.fromRawHandle(portAddress);

  // Collect segments
  final segments = <String>[];
  final nTotal = whisperFullNSegmentsFromState(state);
  for (var i = nTotal - nNew; i < nTotal; i++) {
    segments.add(whisperFullGetSegmentTextFromState(state, i).toDartString());
  }

  port.send(NewSegmentsMessage(segments));
}

// Create native callable
final callback = NativeCallable<WhisperNewSegmentCallback>.listener(
  _onNewSegment,
);

// Set in params
params.ref.newSegmentCallback = callback.nativeFunction;
params.ref.newSegmentCallbackUserData = Pointer.fromAddress(port.hashCode);

// IMPORTANT: Keep callback alive until transcription completes
// callback.close() when done
```

### Abort Pattern

```dart
// Encoder begin callback for cancellation
bool _onEncoderBegin(
  Pointer<Void> ctx,
  Pointer<Void> state,
  Pointer<Void> userData,
) {
  final cancelFlag = userData.cast<Bool>();
  return !cancelFlag.value;  // Return false to abort
}

// Usage
final cancelFlag = calloc<Bool>()..value = false;
params.ref.encoderBeginCallback = encoderBeginCallback.nativeFunction;
params.ref.encoderBeginCallbackUserData = cancelFlag.cast();

// To cancel from another isolate:
cancelFlag.value = true;
```

---

## Thread Safety

### Rules

1. **Single Context Rule**: Never use same `whisper_context` from multiple threads simultaneously
2. **State Isolation**: Use separate `whisper_state` for parallel processing with same model
3. **Callback Thread**: Callbacks execute on the calling thread (isolate)

### Safe Pattern - One Isolate Per Context

```dart
// SAFE: Each isolate has its own context
class WhisperWorker {
  Pointer<Void>? _ctx;

  void init(String modelPath) {
    // Context created and used only in this isolate
    _ctx = whisperInitFromFileWithParams(modelPath, params);
  }

  void transcribe(List<double> audio) {
    // Only this isolate accesses _ctx
    whisperFull(_ctx!, params, samples, nSamples);
  }
}
```

### Safe Pattern - Shared Model, Separate States

```dart
// SAFE: Multiple states, one model
class SharedModelWorker {
  static Pointer<Void>? _sharedCtx;
  Pointer<Void>? _state;

  static void loadModel(String path) {
    // Load model without state
    _sharedCtx = whisperInitFromFileWithParamsNoState(path, params);
  }

  void createState() {
    // Each worker gets own state
    _state = whisperInitState(_sharedCtx!);
  }

  void transcribe(List<double> audio) {
    // Use own state with shared model
    whisperFullWithState(_sharedCtx!, _state!, params, samples, nSamples);
  }

  void dispose() {
    if (_state != null) {
      whisperFreeState(_state!);
      _state = null;
    }
  }
}
```

### UNSAFE Pattern - Avoid

```dart
// UNSAFE: Same context accessed from multiple isolates
class UnsafeWorker {
  static Pointer<Void>? _sharedCtx;

  void transcribe(List<double> audio) {
    // DANGER: Multiple isolates calling whisper_full on same context
    whisperFull(_sharedCtx!, params, samples, nSamples);
  }
}
```

---

## Error Handling

### Return Codes

```c
// Most functions return:
// 0  = success
// <0 = error

int whisper_full(...);           // 0 on success
int whisper_pcm_to_mel(...);     // 0 on success
int whisper_encode(...);         // 0 on success
int whisper_decode(...);         // 0 on success
```

### Null Checks

```dart
// Init functions return nullptr on failure
final ctx = whisperInitFromFileWithParams(path, params);
if (ctx == nullptr) {
  throw Exception('Failed to load model: $path');
}

// State init
final state = whisperInitState(ctx);
if (state == nullptr) {
  whisperFree(ctx);
  throw Exception('Failed to create state');
}
```

### Dart Error Pattern

```dart
class WhisperException implements Exception {
  final String message;
  final int? code;
  WhisperException(this.message, [this.code]);
}

class WhisperService {
  void _checkResult(int result, String operation) {
    if (result != 0) {
      throw WhisperException('$operation failed', result);
    }
  }

  Future<void> transcribe(List<double> audio) async {
    final result = whisperFull(ctx, params, samples, nSamples);
    _checkResult(result, 'whisper_full');
  }
}
```
