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
LOUDNESS_PORT = 9271

K             = 20    # steps  (produces K+1 speed points)
N             = 200   # measurements per step
MEASURE_GAP   = 1.0   # seconds between measurements
SPINUP_SECS   = 60.0  # seconds to wait after setting fan speed
RESTORE_SECS  = 30.0  # seconds to restore (all fans to auto) between steps

SPEEDS = [round(100 * i / K) for i in range(K + 1)]

ALL_GPU_FANS  = [(0, 0), (0, 1), (1, 0), (1, 1)]
ALL_PWM_FANS  = [1, 3, 4, 6, 7, 8]  # 1=cpu0, rest=case fans
PWM_FAN_NAMES = {1: 'cpu0', 3: 'case3', 4: 'case4',
                 6: 'case6', 7: 'case7', 8: 'case8'}

# Each target: name, own gpu fans [(gpu,fan),...], own pwm fans [n,...]
ALL_TARGETS = [
    ('gpu0',  [(0, 0), (0, 1)], []),
    ('gpu1',  [(1, 0), (1, 1)], []),
    ('cpu0',  [], [1]),
    ('case3', [], [3]),
    ('case4', [], [4]),
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


def measure_db():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.settimeout(5)
        s.sendto(b'?', (LOUDNESS_HOST, LOUDNESS_PORT))
        data, _ = s.recvfrom(256)
        return json.loads(data)['db']


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


all_results = {}
for name, own_gpu_fans, own_pwm_fans in TARGETS:
    results = {}
    for pct in SPEEDS:
        print(f'--- {name} @ {pct}% ---')
        stall_except(own_gpu_fans, own_pwm_fans)
        set_speed(pct, own_gpu_fans, own_pwm_fans)
        sleep_countdown(SPINUP_SECS, f'spin-up {name}@{pct}%')

        measurements = []
        for i in range(N):
            db = measure_db()
            measurements.append(db)
            if i % 10 == 0:
                print(' ', end='', flush=True)
            end = '\n' if (i % 10 == 9 or i == N - 1) else ' '
            print(f'{db:.2f}', end=end, flush=True)
            if i < N - 1:
                time.sleep(MEASURE_GAP)
        med = statistics.median(measurements)
        results[pct] = med
        print(f' median: {med:.2f} dB')
        restore()
        sleep_countdown(RESTORE_SECS, f'cooldown after {name}@{pct}%')

    all_results[name] = results

    dbs = [round(results[pct], 2) for pct in SPEEDS]
    print(f'{name!r}: {dbs},')

print('\nPROFILES = {')
for name, *_ in TARGETS:
    dbs = [round(all_results[name][pct], 2) for pct in SPEEDS]
    print(f'    {name!r}: {dbs},')
print('}')
