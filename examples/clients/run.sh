#!/bin/bash
set -e  # exit on first error

if [ ! -d ".venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv .venv
    # Use the venv's pip directly
    .venv/bin/pip install --upgrade pip
    .venv/bin/pip install sounddevice websockets pynput rich numpy
else
    echo "✅ Virtual environment already exists."
fi

# Define a helper to run Python scripts inside the venv
PYTHON=".venv/bin/python3"

# Launch the streaming (WebSocket) dictation client.
# Make sure the whisper-websocket-stream server is running first (see server.sh).
$PYTHON examples/clients/streaming_client.py
