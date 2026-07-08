#!/bin/bash
set -e  # exit on first error

echo "🚀 Starting whisper-server..."

# HTTP Server with VAD
# ./build/bin/whisper-server \
#   -m models/ggml-large-v3.bin \
#   -t 8 \
#   -fa \
#   --vad -vm models/vad.bin \
#   --convert \
#   -bs 5 \
#   --host 0.0.0.0 \
#   --port 9002

# HTTP Server
# ./build/bin/whisper-server \
#   -m models/ggml-large-v3.bin \
#   -t 8 \
#   -fa \
#   --convert \
#   -bs 5 \
#   --host 0.0.0.0 \
#   --port 9002

# Streaming Server
./build/bin/whisper-websocket-stream \
  -m models/ggml-large-v3.bin \
  -t 8 \
  -fa \
  --convert \
  -bs 5 \
  --host 0.0.0.0 \
  --port 9002

echo "✅ whisper-server exited."
