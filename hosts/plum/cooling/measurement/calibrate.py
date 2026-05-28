#!/usr/bin/env python3
import atexit
import json
import socket
import statistics
import sys
import time

FANCTL_HOST   = '192.168.99.53'
FANCTL_PORT   = 9272
LOUDNESS_HOST = '192.168.99.53'
MICS = [
    ('usb',    9271),
    ('analog', 9272),
]

K               = 20    # steps  (produces K+1 speed points)
N               = 100   # measurements per step
MEASURE_GAP_SEC = 2.0   # seconds between measurements
SPINUP_SEC      = 60.0  # seconds to wait after setting fan speed high
SPINDOWN_SEC    = 60.0  # seconds to wait after stalling the fans
INTERSPEED_SEC  = 15.0  # seconds to wait after changing fans speed a bit
DELTA_SILENCE   = 0.1   # dB to stop going lower

SPEEDS = [round(100 * i / K) for i in range(K + 1)]

ALL_GPU_FANS  = [(0, 0), (0, 1), (1, 0), (1, 1)]
ALL_PWM_FANS  = [1, 2, 3, 4, 5, 6, 7, 8]  # 1=cpu0, rest=case fans
PWM_FAN_NAMES = {1: 'cpu0', 2: 'case2', 3: 'case3', 4: 'case4',
                 5: 'case5', 6: 'case6', 7: 'case7', 8: 'case8'}

# Each target: name, own gpu fans [(gpu,fan),...], own pwm fans [n,...]
ALL_TARGETS = [
    ('gpu0',  [(0, 0), (0, 1)], []),
    ('gpu1',  [(1, 0), (1, 1)], []),
    ('cpu0',  [], [1]),
    ('case2', [], [2]),
    ('case3', [], [3]),
    ('case4', [], [4]),
    ('case5', [], [5]),
    ('case6', [], [6]),
    ('case7', [], [7]),
    ('case8', [], [8]),
]
ALL_TARGET_NAMES = [name for name, *_ in ALL_TARGETS]

args = sys.argv[1:]
if args:
    unknown = set(args) - set(ALL_TARGET_NAMES)
    if unknown:
        print(f'unknown targets: {", ".join(sorted(unknown))}')
        print(f'valid: {", ".join(ALL_TARGET_NAMES)}')
        sys.exit(1)
    TARGETS = [t for t in ALL_TARGETS if t[0] in args]
else:
    TARGETS = ALL_TARGETS


def fanctl(cmd):
    s = socket.create_connection((FANCTL_HOST, FANCTL_PORT), timeout=5)
    s.sendall(json.dumps(cmd).encode() + b'\n')
    result = json.loads(s.recv(1024))
    s.close()
    if not result.get('ok'):
        raise RuntimeError(result.get('error', 'unknown error'))
    return result


def measure_db(port, retry=3):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.settimeout(2)
        s.sendto(b'?', (LOUDNESS_HOST, port))
        try:
            data, _ = s.recvfrom(256)
        except TimeoutError:
            if not retry:
                raise
            return measure_db(port, retry=retry-1)
        return json.loads(data)['db_avg']


def measure_all_mics():
    """Query all mics; return dict  label -> [N readings]."""
    mic_measurements = {label: [] for label, _ in MICS}
    for i in range(N):
        for label, port in MICS:
            db = measure_db(port)
            mic_measurements[label].append(db)
            print(f' {label}: {db:.2f}', end='', flush=True)
        print()
        if i < N - 1:
            time.sleep(MEASURE_GAP_SEC)
    return mic_measurements


def restore():
    print(' * restore all fans to auto')
    fanctl({'cmd': 'restore'})


atexit.register(restore)


def stall_except(own_gpu_fans, own_pwm_fans):
    stalled = []
    for gpu, fan in ALL_GPU_FANS:
        if (gpu, fan) not in own_gpu_fans:
            fanctl({'cmd': 'set_gpu', 'gpu': gpu, 'fan': fan, 'pct': 0})
            stalled.append(f'gpu{gpu}f{fan}')
    for n in ALL_PWM_FANS:
        if n not in own_pwm_fans:
            fanctl({'cmd': 'set_case', 'fan': n, 'pwm': 0})
            stalled.append(PWM_FAN_NAMES[n])
    print(f' * stalled: {", ".join(stalled)}')


def set_speed(pct, own_gpu_fans, own_pwm_fans):
    for gpu, fan in own_gpu_fans:
        fanctl({'cmd': 'set_gpu', 'gpu': gpu, 'fan': fan, 'pct': pct})
    for n in own_pwm_fans:
        fanctl({'cmd': 'set_case', 'fan': n, 'pwm': pct * 255 // 100})


def sleep_countdown(secs, label):
    print(f' * {label}: waiting {secs}s', end='', flush=True)
    steps = int(secs) // 2
    for i in range(steps):
        time.sleep(2)
        print('.', end='', flush=True)
    time.sleep(secs - steps * 2)
    print()


# Per-mic results:  all_results[label][target_name] = [K+1 dB values]
all_results = {label: {} for label, _ in MICS}

for name, own_gpu_fans, own_pwm_fans in TARGETS:
    # --- silence baseline (all fans off) ---
    print(f'--- silence before testing f{name} ---')
    stall_except([], [])
    sleep_countdown(SPINDOWN_SEC, f'{name} @ stall')
    mic_data = measure_all_mics()
    silences = {}
    for label, readings in mic_data.items():
        sil = round(statistics.median(readings), 2)
        silences[label] = sil
        print(f' silence {label}: {sil:.2f} dB')

    thresholds = {label: sil + DELTA_SILENCE
                  for label, sil in silences.items()}

    # --- sweep speeds from 100% down ---
    done = {label: False for label, _ in MICS}
    for i, pct in enumerate(SPEEDS[::-1]):
        if all(done.values()):
            break
        print(f'--- {name} @ {pct}% ---')
        stall_except(own_gpu_fans, own_pwm_fans)
        set_speed(pct, own_gpu_fans, own_pwm_fans)
        sleep_countdown(INTERSPEED_SEC if i else SPINUP_SEC,
                        f'spin-up {name}@{pct}%')

        mic_data = measure_all_mics()
        for label, readings in mic_data.items():
            if done[label]:
                continue
            med = round(statistics.median(readings), 2)
            print(f' median {label}: {med:.2f} dB')
            all_results[label].setdefault(name, []).append(med)
            if med <= thresholds[label]:
                print(f'  enough for {name} ({label})')
                done[label] = True

    # Pad each mic's profile so it has len(SPEEDS) entries
    for label, _ in MICS:
        results = all_results[label].get(name, [])
        # Find floor: min of silence and last measured value for this mic
        pad = min(silences[label], results[-1] if results else silences[label])
        padded = [pad] * (len(SPEEDS) - len(results)) + results[::-1]
        all_results[label][name] = padded
        pad = ' ' * (6 - len(name))
        vals = '[' + ', '.join(f'{v:.2f}' for v in padded) + ']'
        print(f"    '{name}':{pad}{vals},  # [{label}]")

# --- emit PROFILES_USB = {...} and PROFILES_ANALOG = {...} ---
print()
for label, _ in MICS:
    var = f'PROFILES_{label.upper()}'
    print(f'{var} = {{')
    for name, *_ in TARGETS:
        print(f'    {name!r}: {all_results[label][name]},')
    print('}')
    print()
