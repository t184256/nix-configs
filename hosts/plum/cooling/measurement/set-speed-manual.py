#!/usr/bin/env python3
# testing tool talking to calibrate-fancontroller
# ./set-speed-manual.py fc1 127 mb4 255

import json
import socket
import sys

FANCTL_HOST = '192.168.99.53'
FANCTL_PORT = 9272


def fanctl(cmd):
    s = socket.create_connection((FANCTL_HOST, FANCTL_PORT), timeout=10)
    s.sendall(json.dumps(cmd).encode() + b'\n')
    result = json.loads(s.recv(4096))
    s.close()
    if not result.get('ok'):
        raise SystemExit(result.get('error', 'unknown error'))
    return result


args = sys.argv[1:]
assert len(args) % 2 != 1

pairs = list(zip(args[::2], args[1::2]))
for ch, duty in pairs:
    fanctl({'cmd': 'set_pwm', 'ch': ch, 'pwm': int(duty)})
print('  '.join(f'{ch}={duty}' for ch, duty in pairs))

others = [ch for ch in fanctl({'cmd': 'read'})['data']
          if ch not in dict(pairs)]
for ch in others:
    fanctl({'cmd': 'set_pwm', 'ch': ch, 'pwm': 0})
print(f'stalled: {", ".join(others)}')
