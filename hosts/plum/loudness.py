#!/usr/bin/env python3
import numpy as np
import sounddevice as sd

SAMPLE_RATE = 44100
BLOCK_SIZE  = 4096


def rms_to_db(rms):
    return 20 * np.log10(rms) if rms > 0 else -np.inf


def callback(indata, frames, time, status):
    rms = np.sqrt(np.mean(indata ** 2))
    db = rms_to_db(rms)
    bar = '█' * max(0, int(db + 80))
    print(f'\r{db:6.1f} dB  {bar:<60}', end='', flush=True)


with sd.InputStream(samplerate=SAMPLE_RATE, blocksize=BLOCK_SIZE,
                    channels=1, callback=callback):
    print("Measuring loudness, Ctrl-C to stop")
    try:
        sd.sleep(10 ** 9)
    except KeyboardInterrupt:
        print()
