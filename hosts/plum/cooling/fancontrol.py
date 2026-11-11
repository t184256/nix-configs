#!/usr/bin/env python3

# Case fan control algorithm:
# CPU/GPU fan speeds determine two "acoustic budgets" (one per mic, max dB).
# Each budget caps case fan PWM via reverse lookup in its own acoustic profile.
# The final cap is the minimum of both budgets' caps (more restrictive wins).
# Case fan speed is linear from TEMP_MIN at 0 to cap at TEMP_MAX,
# extending linearly beyond TEMP_MAX (thermal need overrides acoustics).
# Exhaust lag (matched 120mm: case4, case1; matched 140mm:
# case5, case6, case7): case1 <= 0.95*case4,
# case7 <= 0.95*(case5+case6)/2.
# fan2 (front-top intake) is not controlled: its tach is the EC's CPU_Opt
# and writing to it drives the CPU cooler too (pinning it to 0 when cold).
#
# Channel map (confirmed by ear, third pass, 2026-11-09):
#   1=top-rear exhaust (120mm)
#   2=front-top intake (120mm, uncontrolled; its tach is the EC's CPU_Opt
#                       and writing to it drives the CPU cooler as well!)
#   3=rear-bottom exhaust (3x small ones)
#   4=bottom intake (120mm + a pair of small helpers)
#   5=front-mid intake (140mm)
#   6=front-bottom intake (140mm)
#   7=top exhaust (two fans, loudest)

import signal
import time
import pynvml
from acoustic_profile import PROFILES_USB, PROFILES_ANALOG
from common import profile_db, K, find_hwmon, gpu_max_temp

EXHAUST = [1, 3, 7]  # top-rear, rear-bottom, top
INTAKE = [4, 5, 6]  # bottom, front-mid, front-bottom (2 is the EC's CPU_Opt)
TEMP_MIN  = 40  # °C: below this, case fans are off
TEMP_MAX  = 85  # °C: case fans hit their acoustic cap at this temp
LOG_EVERY = 10  # seconds between log lines
DB_OFFSET = 0  # run case fans this many dB quieter than the estimated noise



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
    for n in fans:
        if enable:
            (hwmon / f'pwm{n}_enable').write_text('1')
        (hwmon / f'pwm{n}').write_text(str(value))



def gpu_fan_pct(h):
    fans = range(pynvml.nvmlDeviceGetNumFans(h))
    pcts = [pynvml.nvmlDeviceGetFanSpeed_v2(h, j) for j in fans]
    return sum(pcts) / len(pcts)


def log_fan(name, pwm, cap):
    pct = round(pwm * 100 / 255)
    cap_pct = round(cap * 100 / 255)
    db_usb = profile_db(PROFILES_USB[name], pct)
    db_ana = profile_db(PROFILES_ANALOG[name], pct)
    cap_db_usb = profile_db(PROFILES_USB[name], cap_pct)
    cap_db_ana = profile_db(PROFILES_ANALOG[name], cap_pct)
    return (f'{name}: {pct}/{cap_pct}% '
            f'{db_usb:.1f},{db_ana:.1f}->{cap_db_usb:.1f},{cap_db_ana:.1f}dBA')


pynvml.nvmlInit()
gpu0  = pynvml.nvmlDeviceGetHandleByIndex(0)
gpu1  = pynvml.nvmlDeviceGetHandleByIndex(1)
hwmon = find_hwmon('nct6799')


def cap(name, budget_usb, budget_analog):
    """Cap using both budgets; the more restrictive one wins."""
    c_usb = budget_cap_pct(PROFILES_USB[name], budget_usb)
    c_ana = budget_cap_pct(PROFILES_ANALOG[name], budget_analog)
    return int(min(c_usb, c_ana) * 255 / 100)


def restore(sig=None, frame=None):
    # fan2 is not ours to restore: it drives the CPU cooler via the EC
    pwm_write([1, 3, 4, 5, 6, 7], 99, enable=True)
    pynvml.nvmlShutdown()


signal.signal(signal.SIGTERM, restore)
signal.signal(signal.SIGINT, restore)

pwm_write(EXHAUST + INTAKE, 1, enable=True)

last_log = 0.0

try:
    while True:
        temp = max(gpu_max_temp(gpu0), gpu_max_temp(gpu1))

        g0_pct = gpu_fan_pct(gpu0)
        g1_pct = gpu_fan_pct(gpu1)

        # Two independent budgets, one per microphone
        # (GPU-driven; the cpu cooler wasn't mapped TODO: map)
        budget_usb = (
            max(
                profile_db(PROFILES_USB['gpu0'], g0_pct),
                profile_db(PROFILES_USB['gpu1'], g1_pct),
            ) - DB_OFFSET
        )
        budget_analog = (
            max(
                profile_db(PROFILES_ANALOG['gpu0'], g0_pct),
                profile_db(PROFILES_ANALOG['gpu1'], g1_pct),
            ) - DB_OFFSET
        )

        cap3 = cap('case3', budget_usb, budget_analog)
        cap4 = cap('case4', budget_usb, budget_analog)
        cap5 = cap('case5', budget_usb, budget_analog)
        cap6 = cap('case6', budget_usb, budget_analog)
        # top-rear exhaust is capped by matching bottom intake
        cap1 = min(cap('case1', budget_usb, budget_analog),
                   int(0.95 * cap4))
        # top exhaust (matched pair) is capped by matching front-bottom/mid
        cap7 = min(cap('case7', budget_usb, budget_analog),
                   int(0.95 * (cap5 + cap6) / 2))

        pwm1 = temp_to_pwm(temp, cap1)
        pwm3 = temp_to_pwm(temp, cap3)
        pwm4 = temp_to_pwm(temp, cap4)
        pwm5 = temp_to_pwm(temp, cap5)
        pwm6 = temp_to_pwm(temp, cap6)
        pwm7 = temp_to_pwm(temp, cap7)

        pwm_write([1], pwm1)
        pwm_write([3], pwm3)
        pwm_write([4], pwm4)
        pwm_write([5], pwm5)
        pwm_write([6], pwm6)
        pwm_write([7], pwm7)

        now = time.monotonic()
        if now - last_log >= LOG_EVERY:
            last_log = now
            print(
                f'gpu0: {g0_pct:.0f}%, '
                f'gpu1: {g1_pct:.0f}%, '
                f'budget usb={budget_usb:.2f}dB analog={budget_analog:.2f}dB',
                flush=True,
            )
            pwms = {1: pwm1, 3: pwm3, 4: pwm4,
                    5: pwm5, 6: pwm6, 7: pwm7}
            caps = {1: cap1, 3: cap3, 4: cap4,
                    5: cap5, 6: cap6, 7: cap7}
            print(
                'intake:  ' + ', '.join(
                    log_fan(f'case{n}', pwms[n], caps[n])
                    for n in INTAKE
                ),
                flush=True,
            )
            print(
                'exhaust: ' + ', '.join(
                    log_fan(f'case{n}', pwms[n], caps[n])
                    for n in EXHAUST
                ),
                flush=True,
            )

        time.sleep(1)
finally:
    restore()
