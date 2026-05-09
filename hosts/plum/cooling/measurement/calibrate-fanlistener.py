#!/usr/bin/env python3
import json
import socketserver
import sys
import threading
from collections import deque
import numpy as np
import sounddevice as sd

PORT        = 9271
BLOCK_SIZE  = 4096
WINDOW_SECS = 10.0

buf      = deque()
buf_lock = threading.Lock()


def rms_to_db(rms):
    return 20 * np.log10(rms) if rms > 0 else -np.inf


def current_db():
    with buf_lock:
        if not buf:
            return None
        data = np.concatenate(list(buf))
    return rms_to_db(np.sqrt(np.mean(data ** 2)))


def audio_thread(device):
    sample_rate   = int(sd.query_devices(device)['default_samplerate'])
    window_blocks = int(WINDOW_SECS * sample_rate / BLOCK_SIZE)

    def callback(indata, frames, time, status):
        with buf_lock:
            buf.append(indata[:, 0].copy())
            while len(buf) > window_blocks:
                buf.popleft()
        db = current_db()
        print(f'\r{db:8.2f} dB', end='', flush=True)

    with sd.InputStream(samplerate=sample_rate, blocksize=BLOCK_SIZE,
                        channels=1, callback=callback, device=device):
        threading.Event().wait()


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        db = current_db()
        self.wfile.write((json.dumps({'db': float(db)}) + '\n').encode())


if len(sys.argv) < 2:
    print(sd.query_devices())
    print("Usage: calibrate-fanlistener <device_index>")
    sys.exit(1)

device = int(sys.argv[1])
threading.Thread(target=audio_thread, args=(device,), daemon=True).start()

with socketserver.TCPServer(('', PORT), Handler) as server:
    print(f"Loudness daemon listening on port {PORT}")
    server.serve_forever()
