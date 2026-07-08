#!/usr/bin/env bash
# Build and launch Whisper Bar (macOS Flutter dictation client).
set -euo pipefail
cd "$(dirname "$0")"

echo "→ Fetching dependencies…"
flutter pub get

echo "→ Running on macOS…"
flutter run -d macos "$@"
