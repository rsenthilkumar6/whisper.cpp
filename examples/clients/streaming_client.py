#!/usr/bin/env python3
"""
Streaming voice dictation client with rich terminal UI.
Connects to whisper-websocket-stream on M5 Max.
Press F1 to start, press again to stop.
"""

import asyncio
import json
import threading
import subprocess
import sys
import queue
import time
import math
from collections import deque

import numpy as np
import sounddevice as sd
import websockets
from pynput import keyboard
from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel
from rich.live import Live
from rich.text import Text
from rich.table import Table
from rich.progress_bar import ProgressBar
from rich.align import Align
from rich.style import Style

# ===== THEME =====
THEME = {
    "bg": "rgb(17,17,23)",
    "surface": "rgb(30,30,46)",
    "surface2": "rgb(40,40,60)",
    "accent": "rgb(137,180,250)",
    "accent2": "rgb(180,190,254)",
    "green": "rgb(166,227,161)",
    "yellow": "rgb(249,226,175)",
    "red": "rgb(243,139,168)",
    "muted": "rgb(147,153,178)",
    "text": "rgb(205,214,244)",
    "subtext": "rgb(166,173,200)",
    "blue": "rgb(137,180,250)",
    "teal": "rgb(148,226,213)",
}
# ==================

# ===== CONFIGURATION =====
M5_IP = "m5max.local"
WS_URL = f"ws://{M5_IP}:9002"
SAMPLE_RATE = 16000
CHUNK_DURATION = 0.2
CHANNELS = 1
DTYPE = 'int16'
MAX_HISTORY = 50
VU_HISTORY_SECS = 2
# =========================

console = Console()


class VUMeter:
    def __init__(self, history_secs=VU_HISTORY_SECS, sample_rate=30):
        self.history = deque(maxlen=history_secs * sample_rate)
        self.sample_rate = sample_rate

    def add_sample(self, audio_data):
        if isinstance(audio_data, bytes):
            arr = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32)
        else:
            arr = audio_data.astype(np.float32)
        rms = float(np.sqrt(np.mean(arr ** 2))) if len(arr) > 0 else 0
        db = 20 * math.log10(max(rms, 1)) if rms > 0 else -60
        db = max(db, -60)
        self.history.append(db)

    def get_level(self):
        if not self.history:
            return 0
        recent = list(self.history)[-int(self.sample_rate * 0.3):]
        avg_db = sum(recent) / len(recent)
        normalized = max(0, min(1, (avg_db + 60) / 60))
        return normalized

    def render(self):
        level = self.get_level()
        bar = ProgressBar(total=1, completed=level, width=30)
        panel = Panel(bar, title="🎤 Audio Level", border_style=Style(color=THEME["muted"]), padding=(0, 1))
        return panel


class TranscriptionHistory:
    def __init__(self, max_items=MAX_HISTORY):
        self.items = deque(maxlen=max_items)
        self.current = ""

    def update_current(self, text):
        self.current = text

    def finalize_current(self):
        if self.current.strip():
            timestamp = time.strftime("%H:%M:%S")
            self.items.append((timestamp, self.current.strip()))
        self.current = ""

    def render(self, height=10):
        lines = []
        for ts, text in list(self.items)[-height:]:
            ts_text = Text(f"{ts} ", style=Style(color=THEME["muted"]))
            txt = Text(text, style=Style(color=THEME["text"]))
            line = Text.assemble(ts_text, txt)
            lines.append(line)

        if self.current.strip():
            lines.append(Text("─" * 60, style=Style(color=THEME["surface2"])))
            current_text = Text(self.current, style=Style(color=THEME["accent"], bold=True))
            lines.append(Text.assemble(Text("→ ", style=Style(color=THEME["green"])), current_text))

        if not lines:
            lines.append(Text("Awaiting transcription...", style=Style(color=THEME["muted"], italic=True)))

        return Panel(
            "\n".join(str(line) for line in lines) if lines else "",
            title="📜 Transcription History",
            border_style=Style(color=THEME["muted"]),
            padding=(1, 2),
            height=height + 4,
        )


class StatusBar:
    def __init__(self):
        self.recording = False
        self.connected = False
        self.elapsed = 0
        self.status_text = "Idle"
        self.status_style = THEME["muted"]

    def render(self):
        parts = []
        if self.connected:
            status = "● Connected" if self.recording else "○ Connected"
            color = THEME["green"] if self.recording else THEME["muted"]
        else:
            status = "◌ Disconnected"
            color = THEME["red"]

        rec_indicator = "🔴 REC" if self.recording else "⚫ Idle"
        rec_color = THEME["red"] if self.recording else THEME["muted"]

        elapsed_str = time.strftime("%H:%M:%S", time.gmtime(self.elapsed)) if self.recording else "--:--:--"

        parts.append(Text(f" {status} ", style=Style(color=color, bold=True)))
        parts.append(Text(f"│ ", style=Style(color=THEME["surface2"])))
        parts.append(Text(f"{rec_indicator}", style=Style(color=rec_color, bold=self.recording)))
        parts.append(Text(f" │ ", style=Style(color=THEME["surface2"])))
        parts.append(Text(f"⏱ {elapsed_str}", style=Style(color=THEME["teal"])))
        parts.append(Text(f" │ ", style=Style(color=THEME["surface2"])))
        parts.append(Text(f"🔑 F1: Toggle  ", style=Style(color=THEME["accent2"])))
        parts.append(Text(f"⎋ Ctrl+C: Quit", style=Style(color=THEME["yellow"])))

        return Panel(
            Text.assemble(*parts),
            border_style=Style(color=THEME["surface2"]),
            padding=(0, 1),
            style=Style(bgcolor=THEME["surface"]),
        )


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
        self.start_time = 0

        self.vu = VUMeter()
        self.history = TranscriptionHistory()
        self.status = StatusBar()

    def insert_text(self, text):
        if not text or text == self.last_inserted_text:
            return
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
            subprocess.run(['pbcopy'], input=new_text.encode('utf-8'), check=True)

    def audio_callback(self, indata, frames, time_info, status):
        if status:
            pass
        if self.is_recording:
            bytes_data = indata.tobytes()
            self.audio_queue.put(bytes_data)
            self.vu.add_sample(bytes_data)

    async def send_audio(self):
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
            if self.websocket:
                await self.websocket.send(json.dumps({"eof": True}))

    async def receive_transcriptions(self):
        try:
            async for message in self.websocket:
                try:
                    data = json.loads(message)
                    if "text" in data:
                        text = data["text"].strip()
                        if text:
                            self.history.update_current(text)
                            self.insert_text(text)
                        if data.get("is_final", False):
                            self.history.finalize_current()
                    elif "error" in data:
                        pass
                except json.JSONDecodeError:
                    text = message.strip()
                    if text:
                        self.history.update_current(text)
                        self.insert_text(text)
        except websockets.exceptions.ConnectionClosed:
            self.status.connected = False
            self.history.finalize_current()

    async def connect_and_run(self):
        try:
            self.websocket = await websockets.connect(WS_URL)
            self.status.connected = True

            config = {
                "config": {
                    "language": "en",
                    "task": "transcribe",
                    "translate": False,
                    "model": "large-v3-turbo"
                }
            }
            await self.websocket.send(json.dumps(config))

            self.send_task = asyncio.create_task(self.send_audio())
            self.recv_task = asyncio.create_task(self.receive_transcriptions())
            await asyncio.gather(self.send_task, self.recv_task)

        except websockets.exceptions.ConnectionClosedError:
            self.status.connected = False
        except Exception:
            self.status.connected = False

    def start_recording(self):
        if self.is_recording:
            return
        self.is_recording = True
        self.last_inserted_text = ""
        self.start_time = time.time()
        self.status.recording = True
        self.status.status_text = "Recording"
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)

        self.stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype=DTYPE,
            blocksize=int(SAMPLE_RATE * CHUNK_DURATION),
            callback=self.audio_callback
        )
        self.stream.start()

        try:
            self.loop.run_until_complete(self.connect_and_run())
        except KeyboardInterrupt:
            pass
        finally:
            self.is_recording = False
            self.status.recording = False
            self.loop.close()
            self.stream.stop()
            self.stream.close()

    def stop_recording(self):
        self.is_recording = False
        self.status.recording = False
        self.history.finalize_current()
        if self.send_task:
            self.send_task.cancel()
        if self.recv_task:
            self.recv_task.cancel()
        loop = self.loop
        if self.websocket and loop and loop.is_running():
            asyncio.run_coroutine_threadsafe(
                self.websocket.close(), loop
            )

    def on_press(self, key):
        if key == keyboard.Key.f1:
            if not self.is_recording:
                threading.Thread(target=self.start_recording, daemon=True).start()
            else:
                self.stop_recording()

    def build_layout(self):
        layout = Layout()
        layout.split(
            Layout(name="header", size=1),
            Layout(name="body"),
            Layout(name="footer", size=8),
        )

        title = Text.assemble(
            Text("🎙 ", style=Style(color=THEME["muted"])),
            Text("whisper", style=Style(color=THEME["accent"], bold=True)),
            Text(".cpp", style=Style(color=THEME["teal"], bold=True)),
            Text("  Streaming Dictation", style=Style(color=THEME["subtext"])),
        )
        header = Panel(
            Align.center(title),
            style=Style(bgcolor=THEME["surface"], color=THEME["muted"]),
            border_style=Style(color=THEME["surface2"]),
            padding=(0, 0),
            height=1,
        )
        layout["header"].update(header)

        body = Table.grid(padding=(1, 1))
        body.add_column("left", ratio=2)
        body.add_column("right", ratio=1)

        status = self.status.render()
        history = self.history.render()
        vu = self.vu.render()

        body.add_row(
            history,
            vu
        )
        layout["body"].update(body)
        layout["footer"].update(status)

        return layout

    def render_loop(self):
        with Live(
            self.build_layout(),
            console=console,
            screen=True,
            refresh_per_second=15,
        ) as live:
            while self.is_running:
                if self.is_recording:
                    self.status.elapsed = time.time() - self.start_time
                layout = self.build_layout()
                live.update(layout)
                time.sleep(1 / 15)

    def run(self):
        title = Text.assemble(
            Text("\n"
                 "╭──────────────────────────────────────────╮\n"
                 "│                                          │\n"
                 "│    "),
            Text("🎙  whisper.cpp Streaming Dictation", style=Style(color=THEME["accent"], bold=True)),
            Text("    │\n"
                 "│                                          │\n"
                 "│  "),
            Text("Connected to: ", style=Style(color=THEME["subtext"])),
            Text(WS_URL, style=Style(color=THEME["teal"])),
            Text("  │\n"
                 "│                                          │\n"
                 "│  "),
            Text("🔑 Press ", style=Style(color=THEME["subtext"])),
            Text("F1", style=Style(color=THEME["accent"], bold=True)),
            Text(" to start recording, ", style=Style(color=THEME["subtext"])),
            Text("F1", style=Style(color=THEME["accent"], bold=True)),
            Text(" again to stop   │\n"
                 "│  "),
            Text("⎋ Press ", style=Style(color=THEME["subtext"])),
            Text("Ctrl+C", style=Style(color=THEME["yellow"], bold=True)),
            Text(" to exit            │\n"
                 "│                                          │\n"
                 "╰──────────────────────────────────────────╯\n",
                 style=Style(color=THEME["muted"])),
        )

        console.print(title)
        console.print(f"   {Text('Initializing...', style=Style(color=THEME['muted'], italic=True))}")

        listener_thread = threading.Thread(target=self._run_listener, daemon=True)
        listener_thread.start()

        try:
            self.render_loop()
        except KeyboardInterrupt:
            self.is_running = False
            if self.is_recording:
                self.stop_recording()
            console.print(f"\n\n   {Text('👋 Goodbye!', style=Style(color=THEME['green']))}")
            sys.exit(0)

    def _run_listener(self):
        with keyboard.Listener(on_press=self.on_press) as listener:
            self.listener = listener
            listener.join()


if __name__ == "__main__":
    client = StreamingVoiceClient()
    client.run()
