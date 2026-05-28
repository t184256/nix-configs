#!/usr/bin/env python3
import json
import os
import socketserver
import time
import sys
import threading
import numpy as np
import sounddevice as sd

PORT = int(os.environ.get('PORT', '9271'))
BLOCK_SIZE = 4096
LOOKBACK_HOURS = 24
LOOKBACK_MINUTES = LOOKBACK_HOURS * 60
EMA_TAU = 2.0


class MinutesTracker:
    def __init__(self):
        self.minutes = []
        self.base = None
        self.cur_power_sum = 0.0
        self.cur_count = 0

    def add(self, db):
        self.cur_power_sum += 10 ** (db / 10)
        self.cur_count += 1

        if not self.minutes:
            if self.base is None or db < self.base:
                self.base = db  # a running minimum for the first minute

        if self.cur_count != 60:
            return

        cur_avg = 10 * np.log10(self.cur_power_sum / self.cur_count)
        self.cur_power_sum = self.cur_count = 0

        if not self.minutes: # first averaged minute replaces the min estimate
            self.base = cur_avg

        if len(self.minutes) >= LOOKBACK_MINUTES:
            evicted = self.minutes.pop(0)
            if evicted <= self.base:
                self.base = min(self.minutes, default=None)

        self.minutes.append(cur_avg)
        if self.base is None or cur_avg < self.base:
            self.base = cur_avg


def find_input_device(name):
    while True:
        try:
            for i, dev in enumerate(sd.query_devices()):
                if (name.lower() in dev['name'].lower()
                        and dev['max_input_channels'] > 0):
                    print(f'found device {i}: {dev["name"]}',
                          flush=True)
                    return i
        except Exception:
            pass
        print(f'waiting for device: {name}', flush=True)
        time.sleep(2)


if len(sys.argv) < 2:
    print(sd.query_devices())
    print("Usage: fanlistener <device_index|hw:X,Y|name>")
    sys.exit(1)

try:
    device = int(sys.argv[1])
except ValueError:
    if sys.argv[1].startswith('hw:'):
        device = sys.argv[1]
    else:
        device = find_input_device(sys.argv[1])

sample_rate = int(sd.query_devices(device)['default_samplerate'])
SECOND = sample_rate
buf = np.zeros(2 * SECOND + BLOCK_SIZE)
buf_len = 0
db_avg = None
db_ema = None
prev_sec_power = None
ema_power = 0.0
tracker = MinutesTracker()
lock = threading.Lock()


def _a_weight_raw(freqs):
    f2 = freqs ** 2
    with np.errstate(divide='ignore', invalid='ignore'):
        w = (12194.0**2 * freqs**4) / (
            (f2 + 20.6**2)
            * np.sqrt((f2 + 107.7**2) * (f2 + 737.9**2))
            * (f2 + 12194.0**2)
        )
    return np.nan_to_num(w)


_norm = _a_weight_raw(np.array([1000.0]))[0]

_fft_freqs_sec = np.fft.rfftfreq(SECOND, d=1.0 / sample_rate)
_aw_sq_sec = (_a_weight_raw(_fft_freqs_sec) / _norm) ** 2

_fft_freqs_block = np.fft.rfftfreq(BLOCK_SIZE, d=1.0 / sample_rate)
_aw_sq_block = (_a_weight_raw(_fft_freqs_block) / _norm) ** 2

_ema_alpha = BLOCK_SIZE / (EMA_TAU * sample_rate)


def _aw_power(data, aw_sq):
    n = len(data)
    return float(np.sum(np.abs(np.fft.rfft(data)) ** 2 * aw_sq)) / n ** 2


def audio_callback(indata, frames, _, status):
    global buf_len, db_avg, db_ema, prev_sec_power, ema_power

    block = indata[:, 0]

    # EMA: single writer, no lock needed
    bp = _aw_power(block, _aw_sq_block)
    ema_power = bp if ema_power == 0.0 else (
        _ema_alpha * bp + (1 - _ema_alpha) * ema_power
    )

    with lock:
        buf[buf_len:buf_len + BLOCK_SIZE] = block
        buf_len += BLOCK_SIZE

        if buf_len >= 2 * SECOND:
            sec_power = _aw_power(buf[:SECOND], _aw_sq_sec)
            if sec_power > 0:
                tracker.add(10 * np.log10(sec_power))
                if prev_sec_power is not None:
                    avg = (prev_sec_power + sec_power) / 2
                    db_avg = float(10 * np.log10(avg))
                prev_sec_power = sec_power
            buf[:buf_len - SECOND] = buf[SECOND:buf_len]
            buf_len -= SECOND

        db_ema = float(10 * np.log10(ema_power)) if ema_power > 0 else None

    if db_ema is not None:
        print(f'\r{db_ema:8.2f} dB(A)', end='', flush=True)


def audio_thread(device):
    with sd.InputStream(samplerate=sample_rate, blocksize=BLOCK_SIZE,
                        channels=1, callback=audio_callback, device=device):
        threading.Event().wait()


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        while db_avg is None or db_ema is None or tracker.base is None:
            time.sleep(0.1)
        with lock:
            response = json.dumps({
                'db_avg': db_avg,
                'db_ema': db_ema,
                'base': tracker.base,
            }).encode() + b'\n'
        self.server.socket.sendto(response, self.client_address)


threading.Thread(target=audio_thread, args=(device,), daemon=True).start()

with socketserver.UDPServer(('', PORT), Handler) as server:
    print(f"Loudness daemon listening on port {PORT}")
    server.serve_forever()
