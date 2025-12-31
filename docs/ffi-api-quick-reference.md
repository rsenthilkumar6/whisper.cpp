# Whisper.cpp FFI API Quick Reference

Fast lookup for functions, type mappings, and code snippets.

---

## Type Mappings (C → Dart FFI)

| C Type | Dart FFI Type | Dart Type |
|--------|---------------|-----------|
| `int` | `Int32` | `int` |
| `int32_t` | `Int32` | `int` |
| `int64_t` | `Int64` | `int` |
| `size_t` | `Size` / `Uint64` | `int` |
| `float` | `Float` | `double` |
| `double` | `Double` | `double` |
| `bool` | `Bool` | `bool` |
| `char *` | `Pointer<Utf8>` | `String` |
| `const char *` | `Pointer<Utf8>` | `String` |
| `float *` | `Pointer<Float>` | `Float32List` |
| `void *` | `Pointer<Void>` | - |
| `whisper_context *` | `Pointer<Void>` | - |
| `whisper_state *` | `Pointer<Void>` | - |
| `whisper_token` | `Int32` | `int` |

---

## Constants

```dart
const int WHISPER_SAMPLE_RATE = 16000;  // Required sample rate
const int WHISPER_N_FFT = 400;
const int WHISPER_HOP_LENGTH = 160;
const int WHISPER_CHUNK_SIZE = 30;      // Max seconds per chunk

// Sampling strategies
const int WHISPER_SAMPLING_GREEDY = 0;
const int WHISPER_SAMPLING_BEAM_SEARCH = 1;
```

---

## Function Quick Reference

### Context Management

| Function | Returns | Isolate? | Description |
|----------|---------|----------|-------------|
| `whisper_context_default_params()` | `params` | No | Get default context params |
| `whisper_init_from_file_with_params(path, params)` | `ctx*` | YES | Load model from file |
| `whisper_init_from_buffer_with_params(buf, size, params)` | `ctx*` | YES | Load model from memory |
| `whisper_init_state(ctx)` | `state*` | No | Create separate state |
| `whisper_free(ctx)` | void | No | Free context |
| `whisper_free_state(state)` | void | No | Free state |

### Transcription

| Function | Returns | Isolate? | Description |
|----------|---------|----------|-------------|
| `whisper_full_default_params(strategy)` | `params` | No | Get default full params |
| `whisper_full(ctx, params, samples, n)` | `int` | YES | Run full pipeline |
| `whisper_full_with_state(ctx, state, params, samples, n)` | `int` | YES | Run with specific state |
| `whisper_full_parallel(ctx, params, samples, n, procs)` | `int` | YES | Parallel transcription |

### Result Extraction

| Function | Returns | Isolate? | Description |
|----------|---------|----------|-------------|
| `whisper_full_n_segments(ctx)` | `int` | No | Number of segments |
| `whisper_full_get_segment_text(ctx, i)` | `char*` | No | Segment text |
| `whisper_full_get_segment_t0(ctx, i)` | `int64` | No | Start time (cs) |
| `whisper_full_get_segment_t1(ctx, i)` | `int64` | No | End time (cs) |
| `whisper_full_n_tokens(ctx, seg)` | `int` | No | Tokens in segment |
| `whisper_full_get_token_text(ctx, seg, tok)` | `char*` | No | Token text |
| `whisper_full_get_token_p(ctx, seg, tok)` | `float` | No | Token probability |
| `whisper_full_get_token_data(ctx, seg, tok)` | `data` | No | Full token info |
| `whisper_full_get_segment_speaker_turn_next(ctx, i)` | `bool` | No | Speaker change? |

### Language

| Function | Returns | Isolate? | Description |
|----------|---------|----------|-------------|
| `whisper_lang_id(lang)` | `int` | No | Get lang ID |
| `whisper_lang_str(id)` | `char*` | No | Get lang code |
| `whisper_lang_max_id()` | `int` | No | Max lang ID |
| `whisper_lang_auto_detect(ctx, offset, threads, probs)` | `int` | YES | Detect language |
| `whisper_is_multilingual(ctx)` | `int` | No | Multilingual model? |

### VAD

| Function | Returns | Isolate? | Description |
|----------|---------|----------|-------------|
| `whisper_vad_default_params()` | `params` | No | Default VAD params |
| `whisper_vad_init_from_file_with_params(path, params)` | `ctx*` | YES | Load VAD model |
| `whisper_vad_segments_from_samples(ctx, params, samples, n)` | `segs*` | YES | Detect speech |
| `whisper_vad_segments_n_segments(segs)` | `int` | No | Number of segments |
| `whisper_vad_segments_get_segment_t0(segs, i)` | `float` | No | Start time (s) |
| `whisper_vad_segments_get_segment_t1(segs, i)` | `float` | No | End time (s) |
| `whisper_vad_free_segments(segs)` | void | No | Free segments |
| `whisper_vad_free(ctx)` | void | No | Free VAD context |

### Low-Level

| Function | Returns | Isolate? | Description |
|----------|---------|----------|-------------|
| `whisper_pcm_to_mel(ctx, samples, n, threads)` | `int` | YES | PCM to mel |
| `whisper_encode(ctx, offset, threads)` | `int` | YES | Run encoder |
| `whisper_decode(ctx, tokens, n, past, threads)` | `int` | YES | Run decoder |
| `whisper_tokenize(ctx, text, tokens, max)` | `int` | No | Text to tokens |

### Utility

| Function | Returns | Isolate? | Description |
|----------|---------|----------|-------------|
| `whisper_print_timings(ctx)` | void | No | Print timings |
| `whisper_get_timings(ctx)` | `timings*` | No | Get timings struct |
| `whisper_print_system_info()` | `char*` | No | System capabilities |
| `whisper_token_to_str(ctx, token)` | `char*` | No | Token to string |

---

## Dart FFI Snippets

### Load Library

```dart
DynamicLibrary _loadLib() {
  if (Platform.isMacOS) return DynamicLibrary.open('libwhisper.dylib');
  if (Platform.isLinux) return DynamicLibrary.open('libwhisper.so');
  if (Platform.isWindows) return DynamicLibrary.open('whisper.dll');
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.isAndroid) return DynamicLibrary.open('libwhisper.so');
  throw UnsupportedError('Unsupported platform');
}
```

### Lookup Function

```dart
// Native type signature
typedef WhisperFreeNative = Void Function(Pointer<Void> ctx);
// Dart type signature
typedef WhisperFree = void Function(Pointer<Void> ctx);

final whisperFree = _lib.lookupFunction<WhisperFreeNative, WhisperFree>('whisper_free');
```

### String to Native

```dart
final pathPtr = path.toNativeUtf8();
try {
  final ctx = whisperInitFromFile(pathPtr, params);
} finally {
  calloc.free(pathPtr);
}
```

### Native String to Dart

```dart
final textPtr = whisperFullGetSegmentText(ctx, i);
final text = textPtr.toDartString();  // Copies string
```

### Audio Buffer

```dart
// List<double> to native float array
Pointer<Float> _toNativeFloat(List<double> samples) {
  final ptr = calloc<Float>(samples.length);
  for (var i = 0; i < samples.length; i++) {
    ptr[i] = samples[i];
  }
  return ptr;
}

// Usage
final samplesPtr = _toNativeFloat(audioSamples);
try {
  whisperFull(ctx, params, samplesPtr, audioSamples.length);
} finally {
  calloc.free(samplesPtr);
}
```

### Struct Definition

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
```

### Callback Setup

```dart
// Callback type
typedef ProgressCallbackNative = Void Function(
  Pointer<Void> ctx,
  Pointer<Void> state,
  Int32 progress,
  Pointer<Void> userData,
);

// Static callback function
@pragma('vm:entry-point')
void _onProgress(Pointer<Void> ctx, Pointer<Void> state, int progress, Pointer<Void> userData) {
  // Handle progress
}

// Create native callable
final callback = NativeCallable<ProgressCallbackNative>.listener(_onProgress);
params.ref.progressCallback = callback.nativeFunction;

// IMPORTANT: Keep callback alive, call callback.close() when done
```

---

## Common Patterns

### Basic Transcription

```dart
// 1. Load (in isolate)
final ctx = whisperInitFromFileWithParams(pathPtr, contextParams);

// 2. Setup params
final params = whisperFullDefaultParams(WHISPER_SAMPLING_GREEDY);
params.nThreads = 4;
params.language = 'en'.toNativeUtf8();

// 3. Transcribe (in isolate)
final result = whisperFull(ctx, params, samplesPtr, nSamples);

// 4. Get results
final n = whisperFullNSegments(ctx);
for (var i = 0; i < n; i++) {
  final text = whisperFullGetSegmentText(ctx, i).toDartString();
  final t0 = whisperFullGetSegmentT0(ctx, i);
  final t1 = whisperFullGetSegmentT1(ctx, i);
}

// 5. Cleanup
whisperFree(ctx);
```

### Streaming with Callbacks

```dart
// Setup new segment callback
params.singleSegment = true;
params.newSegmentCallback = callback.nativeFunction;
params.newSegmentCallbackUserData = sendPortAddress;

// In callback: extract segments incrementally
void onNewSegment(..., int nNew, ...) {
  final total = whisperFullNSegmentsFromState(state);
  for (var i = total - nNew; i < total; i++) {
    final text = whisperFullGetSegmentTextFromState(state, i).toDartString();
    sendPort.send(text);
  }
}
```

### Language Auto-Detection

```dart
// Convert audio to mel first
whisperPcmToMel(ctx, samplesPtr, nSamples, threads);

// Detect language
final probs = calloc<Float>(whisperLangMaxId() + 1);
final langId = whisperLangAutoDetect(ctx, 0, threads, probs);
final lang = whisperLangStr(langId).toDartString();
calloc.free(probs);
```

### VAD + Transcription

```dart
// 1. Load VAD model
final vadCtx = whisperVadInitFromFileWithParams(vadPath, vadParams);

// 2. Detect speech segments
final segs = whisperVadSegmentsFromSamples(vadCtx, vadParams, samples, n);
final nSegs = whisperVadSegmentsNSegments(segs);

// 3. Extract speech-only audio
for (var i = 0; i < nSegs; i++) {
  final t0 = whisperVadSegmentsGetSegmentT0(segs, i);
  final t1 = whisperVadSegmentsGetSegmentT1(segs, i);
  // Extract samples from t0 to t1
}

// 4. Transcribe speech segments only
whisperFull(ctx, params, speechSamples, nSpeechSamples);

// 5. Cleanup
whisperVadFreeSegments(segs);
whisperVadFree(vadCtx);
```

### Parallel Processing

```dart
// Load model without state
final ctx = whisperInitFromFileWithParamsNoState(path, params);

// Create states for parallel workers
final state1 = whisperInitState(ctx);
final state2 = whisperInitState(ctx);

// Process in parallel isolates
await Future.wait([
  Isolate.run(() => whisperFullWithState(ctx, state1, params, audio1, n1)),
  Isolate.run(() => whisperFullWithState(ctx, state2, params, audio2, n2)),
]);

// Cleanup
whisperFreeState(state1);
whisperFreeState(state2);
whisperFree(ctx);
```

---

## Error Handling Patterns

```dart
// Check init result
final ctx = whisperInitFromFileWithParams(path, params);
if (ctx == nullptr) throw Exception('Failed to load model');

// Check transcription result
final result = whisperFull(ctx, params, samples, n);
if (result != 0) throw Exception('Transcription failed: $result');

// Safe cleanup pattern
Pointer<Void>? ctx;
try {
  ctx = whisperInitFromFileWithParams(path, params);
  // ... use ctx
} finally {
  if (ctx != null) whisperFree(ctx);
}
```

---

## Performance Tips

1. **Thread count**: `Platform.numberOfProcessors` for max performance
2. **Flash attention**: Enable with `params.flashAttn = true`
3. **GPU**: Enable with `params.useGpu = true` (Metal on macOS)
4. **Single segment**: Use `params.singleSegment = true` for streaming
5. **No timestamps**: Use `params.noTimestamps = true` if not needed
6. **Beam search**: Use for quality, greedy for speed
7. **VAD**: Pre-filter silence for faster processing

---

## Timestamp Conversions

```dart
// whisper timestamps are in centiseconds (1/100 sec)
// t0, t1 values from whisper_full_get_segment_t0/t1

Duration toDuration(int centiseconds) {
  return Duration(milliseconds: centiseconds * 10);
}

String toTimestamp(int cs) {
  final ms = cs * 10;
  final s = (ms ~/ 1000) % 60;
  final m = (ms ~/ 60000) % 60;
  final h = ms ~/ 3600000;
  final msRem = ms % 1000;
  return '${h.toString().padLeft(2, '0')}:'
         '${m.toString().padLeft(2, '0')}:'
         '${s.toString().padLeft(2, '0')}.'
         '${msRem.toString().padLeft(3, '0')}';
}

// Example: t0=1234 -> "00:00:12.340"
```

---

## Model Sizes Reference

| Model | Parameters | Disk | RAM | Speed |
|-------|------------|------|-----|-------|
| tiny | 39M | 75 MB | 273 MB | ~32x |
| base | 74M | 142 MB | 388 MB | ~16x |
| small | 244M | 466 MB | 852 MB | ~6x |
| medium | 769M | 1.5 GB | 2.1 GB | ~2x |
| large | 1550M | 2.9 GB | 3.9 GB | 1x |

Speed relative to real-time on M1 Mac.

---

## Language Codes

Common codes for `params.language`:

| Code | Language |
|------|----------|
| `en` | English |
| `zh` | Chinese |
| `de` | German |
| `es` | Spanish |
| `ru` | Russian |
| `ko` | Korean |
| `fr` | French |
| `ja` | Japanese |
| `pt` | Portuguese |
| `tr` | Turkish |
| `pl` | Polish |
| `it` | Italian |
| `auto` | Auto-detect |

Full list: 99 languages supported. Use `whisper_lang_max_id()` + `whisper_lang_str(id)` to enumerate.
