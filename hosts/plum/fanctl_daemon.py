#!/usr/bin/env python3
import json
import signal
import socketserver
from pathlib import Path

PORT = 9272

ALL_FANS = [3, 4, 6, 7, 8]  # exhaust: 3,4  intake: 6,7,8


def find_hwmon(name):
    for path in Path('/sys/class/hwmon').iterdir():
        try:
            if (path / 'name').read_text().strip() == name:
                return path
        except OSError:
            pass
    raise RuntimeError(f'{name} hwmon not found')


hwmon = find_hwmon('nct6687')


def set_fan(n, pwm):
    (hwmon / f'pwm{n}_enable').write_text('1')
    (hwmon / f'pwm{n}').write_text(str(pwm))


def restore():
    for n in ALL_FANS:
        (hwmon / f'pwm{n}_enable').write_text('99')


def handle_sigterm(sig, frame):
    restore()
    raise SystemExit(0)


signal.signal(signal.SIGTERM, handle_sigterm)


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        try:
            cmd = json.loads(self.rfile.readline())
            if cmd['cmd'] == 'set':
                set_fan(cmd['fan'], cmd['pwm'])
                self.wfile.write(b'{"ok": true}\n')
            elif cmd['cmd'] == 'restore':
                restore()
                self.wfile.write(b'{"ok": true}\n')
            else:
                self.wfile.write(b'{"ok": false, "error": "unknown cmd"}\n')
        except Exception as e:
            self.wfile.write((json.dumps({'ok': False, 'error': str(e)}) + '\n').encode())


try:
    with socketserver.TCPServer(('', PORT), Handler) as server:
        print(f"Fan control daemon listening on port {PORT}")
        server.serve_forever()
finally:
    restore()
