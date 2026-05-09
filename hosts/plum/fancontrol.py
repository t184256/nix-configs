#!/usr/bin/env python3
import signal
import time
from pathlib import Path
import pynvml

EXHAUST = [3, 4]  # top SYS_FAN1 (fan3), rear SYS_FAN2 (fan4)
INTAKE = [6, 7, 8]  # bottom SYS_FAN4 (fan6), top front SYS_FAN5 (fan7),
                    # mid + bottom front SYS_FAN6 (fan8)
TEMP_MIN = 70
TEMP_MAX = 100
DELTA = 20  # intake leads exhaust by this PWM


def find_hwmon(name):
    for path in Path('/sys/class/hwmon').iterdir():
        try:
            if (path / 'name').read_text().strip() == name:
                return path
        except OSError:
            pass
    raise RuntimeError(f'{name} hwmon not found')


def pwm_write(hwmon, fans, value):
    for n in fans:
        (hwmon / f'pwm{n}').write_text(str(value))


def pwm_enable(hwmon, fans, value):
    for n in fans:
        (hwmon / f'pwm{n}_enable').write_text(str(value))


def gpu_max_temp(gpu0, gpu1):
    t = pynvml.NVML_TEMPERATURE_GPU
    return max(pynvml.nvmlDeviceGetTemperature(gpu0, t),
               pynvml.nvmlDeviceGetTemperature(gpu1, t))


def gpu_avg_fan_pct(gpu0, gpu1):
    pcts = []
    for h in gpu0, gpu1:
        for j in range(pynvml.nvmlDeviceGetNumFans(h)):
            pcts.append(pynvml.nvmlDeviceGetFanSpeed_v2(h, j))
    return sum(pcts) / len(pcts)


pynvml.nvmlInit()
gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)
hwmon = find_hwmon('nct6687')


def restore(sig=None, frame=None):
    pwm_enable(hwmon, EXHAUST + INTAKE, 99)
    pynvml.nvmlShutdown()


signal.signal(signal.SIGTERM, restore)
signal.signal(signal.SIGINT, restore)

pwm_enable(hwmon, EXHAUST + INTAKE, 1)

try:
    while True:
        temp = gpu_max_temp(gpu0, gpu1)
        if temp <= TEMP_MIN:
            temp_e = 0
        elif temp >= TEMP_MAX:
            temp_e = 255
        else:
            temp_e = (temp - TEMP_MIN) * 255 // (TEMP_MAX - TEMP_MIN)

        fan_e = int(gpu_avg_fan_pct(gpu0, gpu1) * 255 / 100)

        base = max(temp_e, fan_e)
        i = base
        e = 255 if temp >= TEMP_MAX else max(0, base - DELTA)

        pwm_write(hwmon, EXHAUST, e)
        pwm_write(hwmon, INTAKE,  i)

        time.sleep(1)
finally:
    restore()
