#!/usr/bin/env python3
import json
import signal
import socketserver
from pathlib import Path
import pynvml

PORT = 9272

ALL_FANS = [1, 3, 4, 6, 7, 8]  # cpu: 1  exhaust: 3,4  intake: 6,7,8


def find_hwmon(name):
    for path in Path('/sys/class/hwmon').iterdir():
        try:
            if (path / 'name').read_text().strip() == name:
                return path
        except OSError:
            pass
    raise RuntimeError(f'{name} hwmon not found')


hwmon = find_hwmon('nct6687')

pynvml.nvmlInit()
gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)


def set_case_fan(n, pwm):
    (hwmon / f'pwm{n}_enable').write_text('1')
    (hwmon / f'pwm{n}').write_text(str(pwm))


def set_gpu_fan(gpu, fan_idx, pct):
    pynvml.nvmlDeviceSetFanControlPolicy(
        gpu, fan_idx, pynvml.NVML_FAN_POLICY_MANUAL)
    pynvml.nvmlDeviceSetFanSpeed_v2(gpu, fan_idx, pct)


def restore():
    for n in ALL_FANS:
        (hwmon / f'pwm{n}_enable').write_text('99')
    policy = pynvml.NVML_FAN_POLICY_TEMPERATURE_CONTINOUS_SW
    for gpu in (gpu0, gpu1):
        for i in range(pynvml.nvmlDeviceGetNumFans(gpu)):
            pynvml.nvmlDeviceSetFanControlPolicy(gpu, i, policy)


def handle_sigterm(sig, frame):
    restore()
    pynvml.nvmlShutdown()
    raise SystemExit(0)


signal.signal(signal.SIGTERM, handle_sigterm)


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        try:
            cmd = json.loads(self.rfile.readline())
            if cmd['cmd'] == 'set_case':
                set_case_fan(cmd['fan'], cmd['pwm'])
                self.wfile.write(b'{"ok": true}\n')
            elif cmd['cmd'] == 'set_gpu':
                gpu = gpu0 if cmd['gpu'] == 0 else gpu1
                set_gpu_fan(gpu, cmd['fan'], cmd['pct'])
                self.wfile.write(b'{"ok": true}\n')
            elif cmd['cmd'] == 'restore':
                restore()
                self.wfile.write(b'{"ok": true}\n')
            else:
                self.wfile.write(b'{"ok": false, "error": "unknown cmd"}\n')
        except Exception as e:
            self.wfile.write(
                (json.dumps({'ok': False, 'error': str(e)}) + '\n').encode())


try:
    with socketserver.TCPServer(('', PORT), Handler) as server:
        print(f"Fan control daemon listening on port {PORT}")
        server.serve_forever()
finally:
    restore()
    pynvml.nvmlShutdown()
