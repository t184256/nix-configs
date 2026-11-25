#!/usr/bin/env python3

# Case fan control algorithm:
# CPU/GPU fan speeds determine two "acoustic budgets" (one per mic, max dB).
# Each budget caps case fan PWM via reverse lookup in its own acoustic profile.
# The final cap is the minimum of both budgets' caps (more restrictive wins).
# Case fan speed is linear from TEMP_MIN at 0 to cap at TEMP_MAX,
# extending linearly beyond TEMP_MAX (thermal need overrides acoustics).
# Exhaust lag (matched sizes, see mapping.txt):
#   rto <= 0.95*bma                     (rear-top 120mm vs bottom 120mm)
#   tre, tfr <= 0.95*(fmi + fbo)/2      (top 140mm vs front 140mm)
#   ble, bri <= bma                     (small bottom helpers)
# Fan names, positions and channels: ../mapping.txt
# Profiles are keyed by the same names (measurement/calibrate.py).
# The CPU cooler (cin=mb2, cou=mb5) is not ours: it stays on the EC.

import signal
import time

import pynvml
from acoustic_profile import PROFILES_SID, PROFILES_TOP
from common import K, find_hwmon, gpu_max_temp, profile_db

# name: (hwmon, pwm/tach number), see ../mapping.txt
CHANNELS = {
    'rto': ('arctic_fan', 7),
    'r4t': ('nct6799',    3),
    'r4m': ('nct6799',    1),
    'r4b': ('nct6799',    4),
    'tre': ('arctic_fan', 6),
    'tfr': ('arctic_fan', 1),
    'fto': ('arctic_fan', 2),
    'fmi': ('arctic_fan', 3),
    'fbo': ('arctic_fan', 4),
    'bma': ('arctic_fan', 5),
    'ble': ('arctic_fan', 10),
    'bri': ('arctic_fan', 9),
}

EXHAUST = ['rto', 'r4t', 'r4m', 'r4b', 'tre', 'tfr']
INTAKE  = ['bma', 'ble', 'bri', 'fto', 'fmi', 'fbo']

SAFE_PWM = 80  # duty left on every controlled channel on exit
TEMP_MIN = 40  # °C: below this, case fans are off
TEMP_MAX = 85  # °C: case fans hit their acoustic cap at this temp
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


def pwm_write(names, value):
    for name in names:
        PWM[name].write_text(str(value))


def gpu_fan_pct(h):
    fans = range(pynvml.nvmlDeviceGetNumFans(h))
    pcts = [pynvml.nvmlDeviceGetFanSpeed_v2(h, j) for j in fans]
    return sum(pcts) / len(pcts)


def log_fan(name, pwm, cap):
    pct = round(pwm * 100 / 255)
    cap_pct = round(cap * 100 / 255)
    db_sid = profile_db(PROFILES_SID[name], pct)
    db_top = profile_db(PROFILES_TOP[name], pct)
    cap_db_sid = profile_db(PROFILES_SID[name], cap_pct)
    cap_db_top = profile_db(PROFILES_TOP[name], cap_pct)
    return (f'{name}: {pct}/{cap_pct}% '
            f'{db_sid:.1f},{db_top:.1f}->{cap_db_sid:.1f},{cap_db_top:.1f}dBA')


pynvml.nvmlInit()
gpu0  = pynvml.nvmlDeviceGetHandleByIndex(0)
gpu1  = pynvml.nvmlDeviceGetHandleByIndex(1)
HWONS = {'nct6799': find_hwmon('nct6799'),
         'arctic_fan': find_hwmon('arctic_fan')}
PWM = {name: HWONS[hwmon] / f'pwm{ch}'
       for name, (hwmon, ch) in CHANNELS.items()}
# motherboard's SuperIO needs manual mode; Arctic controller has no pwm_enable
MANUAL = [HWONS[hwmon] / f'pwm{ch}_enable'
          for hwmon, ch in CHANNELS.values() if hwmon == 'nct6799']


def cap(name, budget_sid, budget_top):
    """Cap using both budgets; the more restrictive one wins."""
    c_sid = budget_cap_pct(PROFILES_SID[name], budget_sid)
    c_top = budget_cap_pct(PROFILES_TOP[name], budget_top)
    return int(min(c_sid, c_top) * 255 / 100)


def restore(sig=None, frame=None):
    pwm_write(EXHAUST + INTAKE, SAFE_PWM)
    pynvml.nvmlShutdown()


signal.signal(signal.SIGTERM, restore)
signal.signal(signal.SIGINT, restore)

for enable in MANUAL:
    enable.write_text('1')
pwm_write(EXHAUST + INTAKE, 1)

last_log = 0.0

try:
    while True:
        temp = max(gpu_max_temp(gpu0), gpu_max_temp(gpu1))

        g0_pct = gpu_fan_pct(gpu0)
        g1_pct = gpu_fan_pct(gpu1)

        # Two independent budgets, one per microphone
        # (GPU-driven; the cpu cooler isn't mapped, TODO: map)
        budget_sid = (
            max(
                profile_db(PROFILES_SID['gpu0'], g0_pct),
                profile_db(PROFILES_SID['gpu1'], g1_pct),
            ) - DB_OFFSET
        )
        budget_top = (
            max(
                profile_db(PROFILES_TOP['gpu0'], g0_pct),
                profile_db(PROFILES_TOP['gpu1'], g1_pct),
            ) - DB_OFFSET
        )

        caps = {name: cap(name, budget_sid, budget_top)
                for name in EXHAUST + INTAKE}

        # exhaust lag: never outrun the matched intake
        caps['rto'] = min(caps['rto'], int(0.95 * caps['bma']))
        top_in = int(0.95 * (caps['fmi'] + caps['fbo']) / 2)
        caps['tre'] = min(caps['tre'], top_in)
        caps['tfr'] = min(caps['tfr'], top_in)
        caps['ble'] = min(caps['ble'], caps['bma'])
        caps['bri'] = min(caps['bri'], caps['bma'])

        pwms = {name: temp_to_pwm(temp, caps[name])
                for name in EXHAUST + INTAKE}
        for name, pwm in pwms.items():
            pwm_write([name], pwm)

        now = time.monotonic()
        if now - last_log >= LOG_EVERY:
            last_log = now
            print(
                f'gpu0: {g0_pct:.0f}%, '
                f'gpu1: {g1_pct:.0f}%, '
                f'budget sid={budget_sid:.2f}dB top={budget_top:.2f}dB',
                flush=True,
            )
            print(
                'intake:  ' + ', '.join(
                    log_fan(name, pwms[name], caps[name]) for name in INTAKE
                ),
                flush=True,
            )
            print(
                'exhaust: ' + ', '.join(
                    log_fan(name, pwms[name], caps[name]) for name in EXHAUST
                ),
                flush=True,
            )

        time.sleep(1)
finally:
    restore()
