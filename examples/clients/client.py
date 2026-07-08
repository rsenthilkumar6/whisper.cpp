#!/usr/bin/env python3
"""
Global hotkey dictation tool.
Press Fn (or any configured key) to start recording, press again to stop,
transcribe via M5 Max, and insert at cursor.
"""

import os
import subprocess
import sys
import tempfile
import threading
import time

import requests
import sounddevice as sd
from pynput import keyboard
from scipy.io.wavfile import write

# ===== CONFIGURATION =====
M5_IP = "m5max.local"  # Replace with your M5 Max IP
SERVER_URL = f"http://{M5_IP}:9002/inference"
SAMPLE_RATE = 16000
RECORDING_DURATION = 30  # Max seconds per recording
HOTKEY = keyboard.Key.f1  # Use F1 key (works on MacBooks)
# =========================


class VoiceHotkey:
    def __init__(self):
        self.is_recording = False
        self.audio_data = None
        self.listener = None
        self.recording_thread = None

    def start_recording(self):
        """Start recording audio in a background thread."""
        if self.is_recording:
            return
        self.is_recording = True
        print("🎤 Recording... (press Fn again to stop)")
        self.recording_thread = threading.Thread(target=self._record)
        self.recording_thread.start()

    def _record(self):
        """Record audio for a fixed duration or until stopped."""
        try:
            self.audio_data = sd.rec(
                int(RECORDING_DURATION * SAMPLE_RATE),
                samplerate=SAMPLE_RATE,
                channels=1,
                dtype="int16",
            )
            sd.wait()  # Wait until recording is complete
        except Exception as e:
            print(f"Recording error: {e}")
            self.audio_data = None
        finally:
            self.is_recording = False
            print("⏹️ Recording stopped.")

    def stop_and_transcribe(self):
        """Stop recording, send to M5, and insert at cursor."""
        if not self.is_recording:
            return

        # Stop recording by truncating the audio
        sd.stop()
        self.is_recording = False

        if self.recording_thread and self.recording_thread.is_alive():
            self.recording_thread.join(timeout=1)

        if self.audio_data is None:
            print("❌ No audio recorded.")
            return

        print("📡 Transcribing via M5 Max...")
        try:
            # Save audio to temp file
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                write(tmp.name, SAMPLE_RATE, self.audio_data)
                tmp_path = tmp.name

            # Send to M5 Max
            with open(tmp_path, "rb") as f:
                files = {"file": ("audio.wav", f, "audio/wav")}
                resp = requests.post(SERVER_URL, files=files, timeout=60)

            # Clean up
            os.unlink(tmp_path)

            if resp.status_code == 200:
                transcription = resp.text.strip()
                print(f"✅ Transcription: {transcription}")
                self.insert_text(transcription)
            else:
                print(f"❌ Server error: {resp.status_code} - {resp.text}")

        except requests.exceptions.ConnectionError:
            print("❌ Cannot connect to M5 Max server.")
        except Exception as e:
            print(f"❌ Error: {e}")
        finally:
            self.audio_data = None

    def insert_text(self, text):
        """Insert text at the current cursor position using AppleScript."""
        # Escape special characters for AppleScript
        escaped = text.replace('"', '\\"').replace("\n", "\\n")
        script = f"""
        tell application "System Events"
            keystroke "{escaped}"
        end tell
        """
        try:
            subprocess.run(["osascript", "-e", script], check=True)
            print("✅ Text inserted at cursor.")
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to insert text: {e}")
            # Fallback: copy to clipboard
            subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=True)
            print("📋 Text copied to clipboard instead.")

    def on_press(self, key):
        """Handle key press events."""
        if key == HOTKEY:
            if not self.is_recording:
                self.start_recording()
            else:
                # If already recording, stop and transcribe
                threading.Thread(target=self.stop_and_transcribe).start()

    def run(self):
        """Start the global hotkey listener."""
        print(f"🚀 Voice Hotkey Tool started.")
        print(f"📡 Using M5 Max at: {M5_IP}")
        print(
            f"🔑 Press {HOTKEY} to start recording, press again to stop and transcribe."
        )
        print("Press Ctrl+C to exit.")

        with keyboard.Listener(on_press=self.on_press) as listener:
            self.listener = listener
            listener.join()


if __name__ == "__main__":
    app = VoiceHotkey()
    try:
        app.run()
    except KeyboardInterrupt:
        print("\n👋 Exiting...")
        sys.exit(0)


