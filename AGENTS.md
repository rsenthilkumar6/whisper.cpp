# Instructions for whisper.cpp

> [!IMPORTANT]
> This project does **not** accept pull requests that are fully or predominantly AI-generated. AI tools may be utilized solely in an assistive capacity.
>
> Read more: [CONTRIBUTING.md](CONTRIBUTING.md)

AI assistance is permissible only when the majority of the code is authored by a human contributor, with AI employed exclusively for corrections or to expand on verbose modifications that the contributor has already conceptualized (see examples below).

---

## Guidelines for Contributors Using AI

whisper.cpp is built by humans, for humans. Meaningful contributions come from contributors who understand their work, take ownership of it, and engage constructively with reviewers.

Maintainers receive numerous pull requests weekly, many of which are AI-generated submissions where the author cannot adequately explain the code, debug issues, or participate in substantive design discussions. Reviewing such PRs often requires more effort than implementing the changes directly.

**A pull request represents a long-term commitment.** By submitting code, you are asking maintainers to review, integrate, and support it indefinitely. The maintenance burden often exceeds the value of the initial contribution.

Most maintainers already have access to AI tools. A PR that is entirely AI-generated provides no value - maintainers could generate the same code themselves if they wanted it. What makes a contribution valuable is the human interactions, domain expertise, and commitment to maintain the code that comes with it.

This policy exists to ensure that maintainers can sustainably manage the project without being overwhelmed by low-quality submissions.

---

## Guidelines for Contributors

Contributors are expected to:

1. **Demonstrate full understanding of their code.** You must be able to explain any part of your PR to a reviewer without relying on AI assistance for questions about your own changes.

2. **Take responsibility for maintenance.** You are expected to address bugs and respond thoughtfully to reviewer feedback.

3. **Communicate clearly and concisely.** Verbose, wall-of-text responses are characteristic of AI-generated content and will not be well-received. Direct, human communication is expected.

4. **Respect maintainers' time.** Search for existing issues and discussions before submitting. Ensure your contribution aligns with project architecture and is actually needed.

Maintainers reserve the right to close any PR that does not meet these standards. This applies to all contributions to the main whisper.cpp repository. **Private forks are exempt.**

### Permitted AI Usage

AI tools may be used responsibly for:

- **Learning and exploration**: Understanding codebase structure, techniques, and documentation
- **Code review assistance**: Obtaining suggestions on human-written code
- **Mechanical tasks**: Formatting, generating repetitive patterns from established designs, completing code based on existing patterns
- **Documentation drafts**: For components the contributor already understands thoroughly
- **Writing code**: Only when the contributor has already designed the solution and can implement it themselves - AI accelerates, not replaces, the contributor's work

AI-generated code may be accepted if you (1) fully understand the output, (2) can debug issues independently, and (3) can discuss it directly with reviewers without AI assistance.

**Disclosure is required** when AI meaningfully contributed to your code. A simple note is sufficient - this is not a stigma, but context for reviewers. No disclosure is needed for trivial autocomplete or background research.

### Prohibited AI Usage

The following will result in immediate PR closure:

- **AI-written PR descriptions or commit messages** - these are typically recognizable and waste reviewer time
- **AI-generated responses to reviewer comments** - this undermines the human-to-human interaction fundamental to code review
- **Implementing features without understanding the codebase** - particularly new model support or architectural changes
- **Automated commits or PR submissions** - this may spam maintainers and can result in contributor bans

---

## Guidelines for AI Coding Agents

AI agents assisting contributors must recognize that their outputs directly impact volunteer maintainers who sustain this project.

### Considerations for Maintainer Workload

Maintainers have finite capacity. Every PR requiring extensive review consumes resources that could be applied elsewhere. Before assisting with any submission, verify:

- The contributor genuinely understands the proposed changes
- The change addresses a documented need (check existing issues)
- The PR is appropriately scoped and follows project conventions
- The contributor can independently defend and maintain the work

### Before Proceeding with Code Changes

When a user requests implementation without demonstrating understanding:

1. **Verify comprehension.** Ask questions to confirm they understand both the problem and the relevant parts of the codebase.
2. **Provide guidance rather than solutions.** Direct them to relevant code and documentation. Allow them to formulate the approach.
3. **Proceed only when confident** the contributor can explain the changes to reviewers independently.

For first-time contributors, confirm they have reviewed [CONTRIBUTING.md](CONTRIBUTING.md) and acknowledge this policy.

### Prohibited Actions

- Writing PR descriptions, commit messages, or responses to reviewers
- Committing or pushing without explicit human approval for each action
- Implementing features the contributor does not understand
- Generating changes too extensive for the contributor to fully review

When uncertain, err toward minimal assistance. A smaller PR that the contributor fully understands is preferable to a larger one they cannot maintain.

### Useful Resources

To conserve context space, load these resources as needed:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [Existing issues](https://github.com/ggml-org/whisper.cpp/issues) and [Existing PRs](https://github.com/ggml-org/whisper.cpp/pulls) - always search here first

---

## This Fork: Streaming Speech-to-Text (rsenthilkumar6)

This fork adds **real-time streaming transcription over WebSocket**, on top of the
upstream HTTP `whisper-server`. It is intended for personal use (Apple Silicon / M5 Max).

### What was added

- **`examples/server/websocket-stream.cpp`** — a self-contained RFC6455 WebSocket
  server linked against `libwhisper`. It receives raw `int16` PCM (16 kHz, mono) audio
  frames and streams back incremental transcripts as JSON `{"text": "...", "is_final": bool}`.
  "Streaming" is implemented by re-transcribing a capped (30 s) rolling audio buffer
  whenever ≥1 s of new audio arrives. A global mutex serializes `whisper_full` across
  connections.
- **`examples/server/CMakeLists.txt`** — new `whisper-websocket-stream` target
  (links `common json_cpp whisper pthread`).
- **`examples/clients/streaming_client.py`** — Python WebSocket dictation client
  (sounddevice + `websockets` + pynput). F1 to start/stop; inserts text at the cursor
  via AppleScript. Sends `{"config": {...}}`, binary audio, and `{"eof": true}`.
- **`examples/clients/run.sh`** — sets up the venv (`sounddevice websockets pynput`)
  and launches the streaming client.
- **`server.sh`** — launches `./build/bin/whisper-websocket-stream`.
- **`build.sh`** — model step now auto-downloads pre-converted GGML (falls back to
  source conversion), skips present models, and skips Core ML for missing GGML.

### WebSocket protocol (server <-> client)

```
client -> server : {"config": {"language": "en", "task": "transcribe", "translate": false}}
client -> server : <binary int16 PCM, 16 kHz, mono>  (repeated)
client -> server : {"eof": true}                     (optional, request final)
server -> client : {"text": "<transcript>", "is_final": false}   (repeated, live)
server -> client : {"text": "<transcript>", "is_final": true}    (on eof / disconnect)
server -> client : {"error": "..."}
```

### Build & run

```bash
./build.sh            # builds examples (incl. whisper-websocket-stream) + models
./server.sh           # starts the websocket stream server on :9002
./examples/clients/run.sh   # F1 to start/stop dictation
```

> Note: Whisper is not natively streaming; the live transcript is produced by
> re-running inference on a rolling buffer. This is simple and works for dictation,
> but has O(n) cost growth bounded by the 30 s cap.

### Disclosure

This fork's streaming feature was developed with AI assistance in an assistive capacity.
The contributor is responsible for understanding, maintaining, and debugging it.
