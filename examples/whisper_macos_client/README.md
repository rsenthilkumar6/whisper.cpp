# Whisper Bar — macOS dictation client for whisper.cpp

A menu-bar dictation app for macOS, built with Flutter/Dart, that streams your
voice to the `whisper-websocket-stream` server (see `../server/websocket-stream.cpp`)
and inserts the transcript at the cursor — similar in spirit to
[Wispr Flow](https://wisprflow.ai/) and [Superwhisper](https://superwhisper.com/).

```
Press hotkey → floating recorder appears → speak → live transcript streams in →
release hotkey → final text is inserted at the cursor of whatever app you were in.
```

> This client talks to the **streaming** server added in this fork
> (`examples/server/websocket-stream`), **not** the upstream HTTP `whisper-server`.

---

## 1. Feature spec

| Requirement | Status |
| --- | --- |
| Global hotkey starts/stops a recording session | ✅ (`hotkey_manager`, Carbon global hotkey) |
| Floating, animated "live" recording popup | ✅ (non-activating borderless `NSWindow` + `AnimatedContainer`/`AnimatedBuilder`) |
| Real-time incremental transcription | ✅ (suffix-only insertion, like the Python client) |
| Text inserted at the cursor of the frontmost app | ✅ (AppleScript `System Events` keystroke, clipboard fallback) |
| Menu-bar (status bar) icon with Start/Stop, Settings, Quit | ✅ (`system_tray`, icon swaps to red while recording) |
| Configurable server host/port/language + hotkey | ✅ (persisted via `shared_preferences`) |
| macOS agent app (no Dock icon) | ✅ (`LSUIElement`) |

### Out of scope (future work)
- Multi-language auto-detect UI, push-to-talk mouse buttons, audio-level driven
  waveform, history/export, onboarding for permissions.

---

## 2. How it works (protocol)

The client is a drop-in Flutter replacement for `examples/clients/streaming_client.py`.
It speaks the exact same wire protocol (`examples/server/websocket-stream.cpp`):

1. Connect to `ws://<host>:<port>` (default `ws://m5max.local:9002`).
2. Send a JSON config frame: `{"config": {"language": "en", "task": "transcribe", "translate": false}}`.
3. Stream raw **int16 PCM, 16 kHz, mono** audio as **binary** WebSocket frames.
4. On stop, send `{"eof": true}` to request the final transcript.
5. Receive `{"text": "<transcript>", "is_final": bool}` (or `{"error": "..."}`).

The server re-transcribes a capped 30 s rolling buffer, so each message carries the
**full** current transcript. The client therefore tracks the last inserted text and
only types the new suffix at the cursor (identical strategy to the Python client).

---

## 3. Architecture & design patterns

The codebase follows a pragmatic **layered architecture** so the UI, state, and
I/O are decoupled and individually testable.

```
lib/
├── main.dart                 # Entry: bootstrap, DI, wire tray + hotkey
├── app.dart                 # MaterialApp, routes, BlocProvider, navigator key
├── core/
│   ├── constants.dart       # Protocol / geometry constants (single source)
│   └── di.dart              # Service locator (get_it) — composition root
├── domain/
│   └── server_config.dart   # Pure, immutable settings model (Equatable)
├── services/                # "Dumb" I/O adapters (no Flutter/BLoC deps)
│   ├── whisper_client.dart  # WebSocket protocol client
│   ├── audio_capture.dart   # Microphone → int16 PCM stream (record plugin)
│   ├── text_inserter.dart   # AppleScript keystroke + clipboard fallback
│   ├── window_service.dart  # MethodChannel → native floating window
│   ├── hotkey_service.dart  # Global hotkey registration + presets
│   ├── tray_service.dart    # Menu-bar icon + context menu
│   └── settings_repository.dart # Persistence (shared_preferences)
├── state/
│   ├── recording_state.dart # Immutable UI state (Equatable)
│   └── recording_cubit.dart # Single coordinator (orchestration logic)
└── ui/
    ├── recording_popup.dart  # Floating overlay widget (BlocBuilder)
    ├── waveform.dart         # Animated equalizer (TickerProvider)
    └── settings_sheet.dart   # Settings form
```

### Patterns used
- **Repository pattern** — `SettingsRepository` isolates storage; UI/services never
  touch `SharedPreferences` directly.
- **Dependency Injection** — `get_it` registers services in one composition root
  (`core/di.dart`); widgets pull what they need. No manual `new` wiring in the tree.
- **BLoC / Cubit (state management)** — `RecordingCubit` is the *only* place that
  knows how a session flows (connect → capture → insert → finalize). Services stay
  stateless and side-effect-only; the UI is a pure function of `RecordingState`.
- **Separation of concerns** — `services/` have zero Flutter/BLoC imports; `ui/` has
  zero networking/process logic. This keeps business rules unit-testable.
- **Immutable models** — `ServerConfig` and `RecordingState` extend `Equatable` for
  value equality and predictable `copyWith` updates.
- **Native bridge via MethodChannel** — the floating, non-activating overlay is
  implemented in Swift (`macos/Runner/MainFlutterWindow.swift`) and driven by a tiny
  channel, keeping Flutter code platform-agnostic.

### Why the window is "non-activating"
For dictation to land in the *right* app, the recorder must never steal focus.
The native `NSWindow` is `borderless`, `level = .floating`, and overrides
`canBecomeKey/Main` to `false` while recording, so it floats above everything yet
the previously-focused app keeps the cursor. The same window flips to an
*activatable* mode for the Settings sheet.

---

## 4. macOS requirements & permissions

Because the app launches external processes (`osascript`) and opens a raw socket,
the **App Sandbox is disabled** (`macos/Runner/*entitlements`). That is expected for
a local developer/personal tool.

You must grant two permissions in **System Settings → Privacy & Security**:

1. **Microphone** — prompted automatically on first record (TCC).
2. **Accessibility** — required so `System Events` can type at the cursor.
   If it is missing, the app falls back to copying the transcript to the clipboard
   and shows *"Paste manually (⌘V)"*. Open it from the error hint or run:
   ```bash
   open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
   ```

The global hotkey uses a Carbon hotkey, which works **without** Accessibility.

---

## 5. Build & run

Prerequisites: Flutter 3.44+ (stable) on macOS, Xcode command-line tools, and the
`whisper-websocket-stream` server built & running (see `../server/CMakeLists.txt`).

```bash
cd examples/whisper_macos_client

# One-time: fetch dependencies
flutter pub get

# Debug run (opens the app, menu-bar icon appears)
flutter run -d macos

# Release build (self-contained .app)
flutter build macos --release
# → build/macos/Build/Products/Release/whisper_macos_client.app
```

Then start the server on the M5 Max / target machine:

```bash
# from the whisper.cpp repo root
./build.sh                 # builds examples incl. whisper-websocket-stream
./server.sh                # listens on :9002
```

Point the client at it via **Settings…** in the tray menu (default `m5max.local:9002`).

### Usage
1. Click the menu-bar icon (or press the hotkey — default **F9**).
2. Speak. The floating bubble shows the live transcript.
3. Press the hotkey again (or click the stop button) to finalize.
4. The text is inserted where your cursor was.

---

## 6. Dependencies (pub.dev)

| Package | Purpose |
| --- | --- |
| `web_socket_channel` | WebSocket transport matching the server protocol |
| `record` | Microphone capture → 16 kHz mono int16 PCM stream |
| `hotkey_manager` | Global hotkey registration |
| `system_tray` | Menu-bar icon + context menu |
| `flutter_bloc` + `bloc` | Predictable state management (Cubit) |
| `get_it` | Service-locator dependency injection |
| `equatable` | Value-equality for models/state |
| `shared_preferences` | Persist settings across launches |

---

## 7. Known limitations
- Whisper is not natively streaming; the live transcript is produced by
  re-running inference on a rolling buffer (bounded 30 s), exactly like the
  reference Python client. Cost grows with the cap.
- Text insertion uses `osascript`; if Accessibility is denied it gracefully falls
  back to the clipboard.
- Tested for personal use on Apple Silicon macOS.
