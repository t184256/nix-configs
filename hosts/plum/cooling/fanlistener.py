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

IGNORED = ('null', 'default', 'pulse', 'jack')

NAMES = {
    'USB Microphone': 'top',
    'USB PnP': 'side',
}


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


class DeviceListener:

    def __init__(self, index):
        self.index = index
        dev = sd.query_devices(index)
        self.name = dev['name']
        self.key = next((k for pat, k in NAMES.items() if pat in self.name),
                        self.name)
        self.sample_rate = int(dev['default_samplerate'])
        self.second = self.sample_rate
        self.buf = np.zeros(2 * self.second + BLOCK_SIZE)
        self.buf_len = 0
        self.db_avg = None
        self.db_ema = None
        self.prev_sec_power = None
        self.ema_power = 0.0
        self.tracker = MinutesTracker()
        self.lock = threading.Lock()

        freqs = np.fft.rfftfreq(self.second, d=1.0 / self.sample_rate)
        self._aw_sq_sec = (_a_weight_raw(freqs) / _norm) ** 2
        freqs = np.fft.rfftfreq(BLOCK_SIZE, d=1.0 / self.sample_rate)
        self._aw_sq_block = (_a_weight_raw(freqs) / _norm) ** 2
        self._ema_alpha = BLOCK_SIZE / (EMA_TAU * self.sample_rate)

    def _aw_power(self, data, aw_sq):
        n = len(data)
        return float(np.sum(np.abs(np.fft.rfft(data)) ** 2 * aw_sq)) / n ** 2

    def callback(self, indata, frames, time_info, status):
        block = indata[:, 0]

        # EMA: single writer, no lock needed
        bp = self._aw_power(block, self._aw_sq_block)
        self.ema_power = bp if self.ema_power == 0.0 else (
            self._ema_alpha * bp + (1 - self._ema_alpha) * self.ema_power)

        with self.lock:
            self.buf[self.buf_len:self.buf_len + BLOCK_SIZE] = block
            self.buf_len += BLOCK_SIZE

            if self.buf_len >= 2 * self.second:
                sec_power = self._aw_power(self.buf[:self.second],
                                           self._aw_sq_sec)
                if sec_power > 0:
                    self.tracker.add(10 * np.log10(sec_power))
                    if self.prev_sec_power is not None:
                        avg = (self.prev_sec_power + sec_power) / 2
                        self.db_avg = float(10 * np.log10(avg))
                    self.prev_sec_power = sec_power
                self.buf[:self.buf_len - self.second] = \
                    self.buf[self.second:self.buf_len]
                self.buf_len -= self.second

            self.db_ema = (float(10 * np.log10(self.ema_power))
                           if self.ema_power > 0 else None)

    def run(self):
        try:
            with sd.InputStream(samplerate=self.sample_rate,
                                 blocksize=BLOCK_SIZE,
                                 channels=1,
                                 callback=self.callback,
                                 device=self.index):
                threading.Event().wait()
        except Exception as e:
            print(f'{self.name}: {e}', flush=True)


def find_input_devices(filters):
    while True:
        try:
            devices = sd.query_devices()
        except Exception:
            devices = []
        indices = [
            i for i, dev in enumerate(devices)
            if dev['max_input_channels'] > 0
            and not any(x in dev['name'].lower() for x in IGNORED)
            and (not filters
                 or any(f.lower() in dev['name'].lower() for f in filters))
        ]
        if indices:
            return indices
        print('waiting for input devices...', flush=True)
        time.sleep(2)


filters = sys.argv[1:]

listeners = [DeviceListener(i) for i in find_input_devices(filters)]
for l in listeners:
    print(f'listening to {l.key!r} [{l.name}, index {l.index}, '
          f'{l.sample_rate} Hz]', flush=True)

for l in listeners:
    threading.Thread(target=l.run, daemon=True).start()


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        response = {}
        for l in listeners:
            with l.lock:
                response[l.key] = {
                    'db_avg': l.db_avg,
                    'db_ema': l.db_ema,
                    'base': l.tracker.base,
                }
        self.server.socket.sendto(
            (json.dumps(response) + '\n').encode(),
            self.client_address)


with socketserver.UDPServer(('', PORT), Handler) as server:
    print(f'Loudness daemon listening on port {PORT}', flush=True)
    server.serve_forever()
