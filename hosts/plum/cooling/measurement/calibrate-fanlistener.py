#!/usr/bin/env python3
import json
import socketserver
import time
import sys
import threading
import numpy as np
import sounddevice as sd

PORT = 9271
BLOCK_SIZE = 4096
LOOKBACK_HOURS = 24
LOOKBACK_MINUTES = LOOKBACK_HOURS * 60


def rms_to_db(data):
    rms = np.sqrt(np.mean(data ** 2))
    return float(20 * np.log10(rms)) if rms > 0 else None


class MinutesTracker:
    def __init__(self):
        self.minutes = []
        self.base = None
        self.cur_sum = 0.0
        self.cur_count = 0

    def add(self, db):
        self.cur_sum += db
        self.cur_count += 1
        if self.cur_count < 60:
            return

        cur_avg = self.cur_sum / self.cur_count
        self.cur_sum = self.cur_count = 0

        if len(self.minutes) >= LOOKBACK_MINUTES:
            evicted = self.minutes.pop(0)
            if evicted <= self.base:
                self.base = min(self.minutes, default=None)

        self.minutes.append(cur_avg)
        if self.base is None or cur_avg < self.base:
            self.base = cur_avg


if len(sys.argv) < 2:
    print(sd.query_devices())
    print("Usage: calibrate-fanlistener <device_index>")
    sys.exit(1)

try:
    device = int(sys.argv[1])
except ValueError:
    device = sys.argv[1]

sample_rate = int(sd.query_devices(device)['default_samplerate'])
SECOND = sample_rate
buf = np.zeros(2 * SECOND + BLOCK_SIZE)
buf_len = 0
latest_db = None
tracker = MinutesTracker()
lock = threading.Lock()


def audio_callback(indata, frames, _, status):
    global buf_len, latest_db
    with lock:
        buf[buf_len:buf_len+BLOCK_SIZE] = indata[:, 0]
        buf_len += BLOCK_SIZE
        if buf_len >= 2 * SECOND:  # slice off the oldest second
            old_db = rms_to_db(buf[:SECOND])
            if old_db is not None:
                tracker.add(old_db)
            buf[:buf_len - SECOND] = buf[SECOND:buf_len]
            buf_len -= SECOND

        if buf_len >= SECOND:  # calculate the current value
            latest_db = rms_to_db(buf[buf_len-SECOND:buf_len])
            if latest_db is not None:
                print(f'\r{latest_db:8.2f} dB', end='', flush=True)


def audio_thread(device):
    with sd.InputStream(samplerate=sample_rate, blocksize=BLOCK_SIZE,
                        channels=1, callback=audio_callback, device=device):
        threading.Event().wait()


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        with lock:
            db = latest_db
            base = tracker.base
        if db is None or base is None:
            return
        response = json.dumps({'db': db, 'base': base}).encode() + b'\n'
        self.server.socket.sendto(response, self.client_address)


threading.Thread(target=audio_thread, args=(device,), daemon=True).start()

with socketserver.UDPServer(('', PORT), Handler) as server:
    print(f"Loudness daemon listening on port {PORT}")
    server.serve_forever()
