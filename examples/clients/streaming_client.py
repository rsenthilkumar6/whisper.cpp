#!/usr/bin/env python3
"""
Streaming voice dictation client using sounddevice.
Connects to whisper-websocket-stream on M5 Max.
Press F1 to start, press again to stop.
"""

import asyncio
import json
import threading
import subprocess
import sys
import queue
import sounddevice as sd
import websockets
from pynput import keyboard

# ===== CONFIGURATION =====
M5_IP = "m5max.local"          # or use IP like "192.168.1.100"
WS_URL = f"ws://{M5_IP}:9002"
SAMPLE_RATE = 16000
CHUNK_DURATION = 0.2           # 200ms per chunk (adjust for latency)
CHANNELS = 1
DTYPE = 'int16'
# =========================

class StreamingVoiceClient:
    def __init__(self):
        self.is_recording = False
        self.is_running = True
        self.websocket = None
        self.audio_queue = queue.Queue()
        self.last_inserted_text = ""
        self.loop = None
        self.send_task = None
        self.recv_task = None

    def insert_text(self, text):
        """Insert new text incrementally at cursor."""
        if not text or text == self.last_inserted_text:
            return

        # Only insert the new part
        if text.startswith(self.last_inserted_text):
            new_text = text[len(self.last_inserted_text):]
        else:
            new_text = text

        if not new_text:
            return

        self.last_inserted_text = text

        escaped = new_text.replace('"', '\\"').replace('\n', '\\n')
        script = f'''
        tell application "System Events"
            keystroke "{escaped}"
        end tell
        '''
        try:
            subprocess.run(['osascript', '-e', script], check=True)
        except subprocess.CalledProcessError:
            # Fallback to clipboard
            subprocess.run(['pbcopy'], input=new_text.encode('utf-8'), check=True)

    def audio_callback(self, indata, frames, time, status):
        """Called by sounddevice for each audio block."""
        if status:
            print(f"Audio status: {status}", file=sys.stderr)
        if self.is_recording:
            # Convert to bytes and put in queue for sending
            self.audio_queue.put(indata.tobytes())

    async def send_audio(self):
        """Pull audio from queue and send via WebSocket."""
        try:
            while self.is_recording:
                try:
                    chunk = self.audio_queue.get(timeout=0.1)
                    if self.websocket:
                        await self.websocket.send(chunk)
                except queue.Empty:
                    await asyncio.sleep(0.01)
        except asyncio.CancelledError:
            pass
        finally:
            # Send end-of-stream marker
            if self.websocket:
                await self.websocket.send(json.dumps({"eof": True}))

    async def receive_transcriptions(self):
        """Receive and process partial transcriptions."""
        try:
            async for message in self.websocket:
                try:
                    data = json.loads(message)
                    if "text" in data:
                        text = data["text"].strip()
                        if text:
                            print(f"\r📝 {text}", end="", flush=True)
                            self.insert_text(text)
                    elif "error" in data:
                        print(f"\n❌ Server error: {data['error']}")
                except json.JSONDecodeError:
                    # Raw text response
                    text = message.strip()
                    if text:
                        print(f"\r📝 {text}", end="", flush=True)
                        self.insert_text(text)
        except websockets.exceptions.ConnectionClosed:
            print("\n🔌 Connection closed by server")

    async def connect_and_run(self):
        """Connect, send config, start streaming."""
        try:
            self.websocket = await websockets.connect(WS_URL)
            print(f"✅ Connected to {WS_URL}")

            # Send initial configuration (adjust as needed)
            config = {
                "config": {
                    "language": "en",
                    "task": "transcribe",
                    "translate": False,
                    "model": "large-v3-turbo"  # optional if server already has model
                }
            }
            await self.websocket.send(json.dumps(config))
            print("📤 Sent initial config")

            # Start send and receive tasks
            self.send_task = asyncio.create_task(self.send_audio())
            self.recv_task = asyncio.create_task(self.receive_transcriptions())

            # Wait for either to finish (will happen on stop)
            await asyncio.gather(self.send_task, self.recv_task)

        except websockets.exceptions.ConnectionClosedError:
            print("❌ Connection lost")
        except Exception as e:
            print(f"❌ Error: {e}")

    def start_recording(self):
        """Start the recording session."""
        if self.is_recording:
            return
        self.is_recording = True
        self.last_inserted_text = ""
        print("🎤 Recording... (press F1 again to stop)")

        # Open audio stream with callback
        self.stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype=DTYPE,
            blocksize=int(SAMPLE_RATE * CHUNK_DURATION),
            callback=self.audio_callback
        )
        self.stream.start()

        # Run the async loop
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        try:
            self.loop.run_until_complete(self.connect_and_run())
        except KeyboardInterrupt:
            pass
        finally:
            self.loop.close()
            self.stream.stop()
            self.stream.close()

    def stop_recording(self):
        """Stop the recording session."""
        self.is_recording = False
        # Cancel async tasks
        if self.send_task:
            self.send_task.cancel()
        if self.recv_task:
            self.recv_task.cancel()
        # Close WebSocket
        if self.websocket:
            asyncio.run_coroutine_threadsafe(
                self.websocket.close(), self.loop
            )
        print("\n⏹️ Recording stopped")

    def on_press(self, key):
        """Handle key press events."""
        if key == keyboard.Key.f1:
            if not self.is_recording:
                threading.Thread(target=self.start_recording, daemon=True).start()
            else:
                self.stop_recording()

    def run(self):
        """Start the global hotkey listener."""
        print(f"🚀 Streaming Voice Client started.")
        print(f"🔗 Connecting to: {WS_URL}")
        print(f"🔑 Press F1 to start recording, press again to stop.")
        print("Press Ctrl+C to exit.")

        with keyboard.Listener(on_press=self.on_press) as listener:
            self.listener = listener
            listener.join()

if __name__ == "__main__":
    client = StreamingVoiceClient()
    try:
        client.run()
    except KeyboardInterrupt:
        print("\n👋 Exiting...")
        sys.exit(0)
