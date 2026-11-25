#!/usr/bin/env python3
import json
import signal
import socketserver
from pathlib import Path
import pynvml

PORT = 9272

# mb* is the motherboard SuperIO (manual mode via pwm<n>_enable),
# fc* the ARCTIC USB fan controller: no pwm_enable, every write sends 10 duties
PROVIDER_HWON = {'mb': 'nct6799', 'fc': 'arctic_fan'}
PROVIDER_CHANNELS = {
    'mb': [1, 2, 3, 4, 5, 6, 7],
    'fc': list(range(1, 11)),
}


def find_hwmon(name):
    for path in Path('/sys/class/hwmon').iterdir():
        try:
            if (path / 'name').read_text().strip() == name:
                return path
        except OSError:
            pass
    raise RuntimeError(f'{name} hwmon not found')


def build_channels():
    chans = {}
    for provider, nums in PROVIDER_CHANNELS.items():
        try:
            hwmon = find_hwmon(PROVIDER_HWON[provider])
        except RuntimeError as e:
            print(f'{e}; no {provider}* channels')
            continue
        for n in nums:
            pwm = hwmon / f'pwm{n}'
            if pwm.exists():
                chans[f'{provider}{n}'] = {
                    'pwm': pwm,
                    'enable': hwmon / f'pwm{n}_enable',
                    'tach': hwmon / f'fan{n}_input',
                }
    return chans


CHANNELS = build_channels()

WRITTEN = {}  # last written per channel, to skip redundant writes

SNAPSHOT = {}
for _key, _ch in CHANNELS.items():
    _snap = {'pwm': _ch['pwm'].read_text().strip()}
    if _ch['enable'].exists():
        _snap['enable'] = _ch['enable'].read_text().strip()
    SNAPSHOT[_key] = _snap

pynvml.nvmlInit()
gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)


def channel_name(name):
    if name not in CHANNELS:
        raise KeyError(f'unknown channel {name}, '
                       f'have: {", ".join(CHANNELS)}')
    return name


def set_channel(name, pwm):
    if WRITTEN.get(name) == pwm:
        return
    ch = CHANNELS[name]
    if ch['enable'].exists():
        ch['enable'].write_text('1')
    ch['pwm'].write_text(str(pwm))
    WRITTEN[name] = pwm


def read_channels():
    out = {}
    for name, ch in CHANNELS.items():
        row = {'pwm': ch['pwm'].read_text().strip()}
        if ch['enable'].exists():
            row['enable'] = ch['enable'].read_text().strip()
        if ch['tach'].exists():
            row['rpm'] = ch['tach'].read_text().strip()
        out[name] = row
    return out


def set_gpu_fan(gpu, fan_idx, pct):
    pynvml.nvmlDeviceSetFanControlPolicy(
        gpu, fan_idx, pynvml.NVML_FAN_POLICY_MANUAL)
    pynvml.nvmlDeviceSetFanSpeed_v2(gpu, fan_idx, pct)


def restore():
    for name, snap in SNAPSHOT.items():
        ch = CHANNELS[name]
        for part in ('enable', 'pwm'):
            if part not in snap:
                continue
            try:
                ch[part].write_text(snap[part])
            except OSError as e:
                print(f'restore {name}.{part}={snap[part]} failed: {e}')
    WRITTEN.clear()


def handle_sigterm(sig, frame):
    restore()
    pynvml.nvmlShutdown()
    raise SystemExit(0)


signal.signal(signal.SIGTERM, handle_sigterm)


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        try:
            cmd = json.loads(self.rfile.readline())
            if cmd['cmd'] == 'set_pwm':
                set_channel(channel_name(cmd['ch']), cmd['pwm'])
                self.wfile.write(b'{"ok": true}\n')
            elif cmd['cmd'] == 'set_gpu':
                gpu = gpu0 if cmd['gpu'] == 0 else gpu1
                set_gpu_fan(gpu, cmd['fan'], cmd['pct'])
                self.wfile.write(b'{"ok": true}\n')
            elif cmd['cmd'] == 'read':
                self.wfile.write(
                    (json.dumps({'ok': True, 'data': read_channels()})
                     + '\n').encode())
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
