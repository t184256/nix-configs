#!/usr/bin/env python3

# Fan control algorithm:
# CPU/GPU fan speeds determine the "acoustic budget" (max dB, not sum).
# (More sensitive mic could measure a full GPU fan loudness sum matrix.)
# The budget caps each case fan's PWM via reverse lookup in
# acoustic_profile.PROFILES with linear interpolation.
# Fan PWM is linear from TEMP_MIN at 0 to cap PWM at TEMP_MAX,
# extending linearly beyond TEMP_MAX (thermal need overrides acoustics).
# Exhaust lag: case3 <= 0.95*case8 PWM, case4 <= 0.95*case7 PWM.

import signal
import time
import pynvml
from acoustic_profile import PROFILES
from common import profile_db, K, find_hwmon

EXHAUST   = [3, 4]    # top SYS_FAN1, rear SYS_FAN2
INTAKE    = [6, 7, 8] # bottom SYS_FAN4, top-front SYS_FAN5, mid SYS_FAN6
TEMP_MIN  = 30        # °C: below this, case fans are off
TEMP_MAX  = 80        # °C: case fans hit their acoustic cap at this temp
LOG_EVERY = 10        # seconds between log lines


def budget_cap_pct(profile, budget_db):
    """Highest % where the fan stays at or below budget_db loudness."""
    if profile[K] <= budget_db:
        return 100.0
    if profile[0] > budget_db:
        return 0.0
    for i in range(K - 1, -1, -1):
        if profile[i] <= budget_db:
            t = (budget_db - profile[i]) / (profile[i + 1] - profile[i])
            return min(100.0, (i + t) * 100 / K)
    return 0.0


def temp_to_pwm(temp, cap_pwm):
    """Linear from TEMP_MIN@0 to TEMP_MAX@cap_pwm, extending beyond."""
    if temp <= TEMP_MIN:
        return 0
    return min(255, int(
        (temp - TEMP_MIN) / (TEMP_MAX - TEMP_MIN) * cap_pwm
    ))


def pwm_write(fans, value, enable=False):
    key = '_enable' if enable else ''
    for n in fans:
        (hwmon / f'pwm{n}{key}').write_text(str(value))


def gpu_fan_auto(h):
    policy = pynvml.NVML_FAN_POLICY_TEMPERATURE_CONTINOUS_SW
    for j in range(pynvml.nvmlDeviceGetNumFans(h)):
        pynvml.nvmlDeviceSetFanControlPolicy(h, j, policy)


def gpu_fan_pct(h):
    fans = range(pynvml.nvmlDeviceGetNumFans(h))
    pcts = [pynvml.nvmlDeviceGetFanSpeed_v2(h, j) for j in fans]
    return sum(pcts) / len(pcts)


def log_fan(name, pwm, cap):
    pct     = round(pwm * 100 / 255)
    cap_pct = round(cap * 100 / 255)
    db      = profile_db(PROFILES[name], pct)
    cap_db  = profile_db(PROFILES[name], cap_pct)
    return f'{name}: {pct}/{cap_pct}% {db:.2f}/{cap_db:.2f}dB'


pynvml.nvmlInit()
gpu0  = pynvml.nvmlDeviceGetHandleByIndex(0)
gpu1  = pynvml.nvmlDeviceGetHandleByIndex(1)
hwmon = find_hwmon('nct6687')


def restore(sig=None, frame=None):
    gpu_fan_auto(gpu0)
    gpu_fan_auto(gpu1)
    pwm_write([1] + EXHAUST + INTAKE, 99, enable=True)
    pynvml.nvmlShutdown()


signal.signal(signal.SIGTERM, restore)
signal.signal(signal.SIGINT, restore)

gpu_fan_auto(gpu0)
gpu_fan_auto(gpu1)
pwm_write([1], 99, enable=True)
pwm_write(EXHAUST + INTAKE, 1, enable=True)

last_log = 0.0

try:
    while True:
        t_sensor = pynvml.NVML_TEMPERATURE_GPU
        temp = max(pynvml.nvmlDeviceGetTemperature(gpu0, t_sensor),
                   pynvml.nvmlDeviceGetTemperature(gpu1, t_sensor))

        g0_pct  = gpu_fan_pct(gpu0)
        g1_pct  = gpu_fan_pct(gpu1)
        cpu_pct = int((hwmon / 'pwm1').read_text()) * 100 / 255
        g0_db   = profile_db(PROFILES['gpu0'], g0_pct)
        g1_db   = profile_db(PROFILES['gpu1'], g1_pct)
        cpu_db  = profile_db(PROFILES['cpu0'], cpu_pct)
        budget  = max(cpu_db, g0_db, g1_db)

        def cap(name):
            return int(budget_cap_pct(PROFILES[name], budget) * 255 / 100)

        cap6 = cap('case6')
        cap7 = cap('case7')
        cap8 = cap('case8')
        cap3 = min(cap('case3'), int(0.95 * cap8))
        cap4 = min(cap('case4'), int(0.95 * cap7))

        pwm6 = temp_to_pwm(temp, cap6)
        pwm7 = temp_to_pwm(temp, cap7)
        pwm8 = temp_to_pwm(temp, cap8)
        pwm3 = temp_to_pwm(temp, cap3)
        pwm4 = temp_to_pwm(temp, cap4)

        pwm_write([6], pwm6)
        pwm_write([7], pwm7)
        pwm_write([8], pwm8)
        pwm_write([3], pwm3)
        pwm_write([4], pwm4)

        now = time.monotonic()
        if now - last_log >= LOG_EVERY:
            last_log = now
            print(
                f'cpu0: {cpu_pct:.0f}% {cpu_db:.2f}dB, '
                f'gpu0: {g0_pct:.0f}% {g0_db:.2f}dB, '
                f'gpu1: {g1_pct:.0f}% {g1_db:.2f}dB, '
                f'noise budget: {budget:.2f}dB',
                flush=True,
            )
            print(
                ', '.join(log_fan(n, pwm, cap_) for n, pwm, cap_ in [
                    ('case6', pwm6, cap6),
                    ('case7', pwm7, cap7),
                    ('case8', pwm8, cap8),
                ]),
                flush=True,
            )
            print(
                ', '.join(log_fan(n, pwm, cap_) for n, pwm, cap_ in [
                    ('case3', pwm3, cap3),
                    ('case4', pwm4, cap4),
                ]),
                flush=True,
            )

        time.sleep(1)
finally:
    restore()
