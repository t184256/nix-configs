#!/usr/bin/env python3
import json
import socket
import sys

SOCKET_PATH = '/run/lactd.sock'

GPUS = {
    '10DE:2204-1043:87AF-0000:11:00.0': ('ASUS', 200),
    '10DE:2204-1462:3884-0000:01:00.0': ('MSI',  300),
}


def lact_request(sock, command, **args):
    msg = json.dumps({'command': command, 'args': args or None}) + '\n'
    sock.sendall(msg.encode())
    buf = b''
    while not buf.endswith(b'\n'):
        chunk = sock.recv(1 << 20)
        if not chunk:
            break
        buf += chunk
    resp = json.loads(buf)
    if resp.get('status') != 'ok':
        raise RuntimeError(f'{command} failed: {resp}')
    return resp['data']


def get_vf_curve(sock, gpu_id):
    data = lact_request(sock, 'device_clocks_info', id=gpu_id)
    table = data.get('table')
    if not table or table.get('type') != 'nvidia':
        raise RuntimeError(f'No nvidia clocks table for {gpu_id}')
    return table['value']['gpu_vf_curve']


def main():
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(SOCKET_PATH)
        curves = {}
        for gpu_id, (name, offset) in GPUS.items():
            try:
                curves[gpu_id] = get_vf_curve(s, gpu_id)
            except Exception as e:
                print(f'warning: {name} ({gpu_id}): {e}', file=sys.stderr)

    if not curves:
        sys.exit('no VF curve data retrieved')

    names_offsets = [(gid, *GPUS[gid]) for gid in GPUS if gid in curves]
    header_parts = ', '.join(f'{n} +{o}' for _, n, o in names_offsets)
    print(f'# Baseline VF curves (base->base+offset MHz; {header_parts} P0 offset):')
    print(f'# {"idx":>3}  {"mV":>4}', end='')
    for _, name, _ in names_offsets:
        print(f'  {name:<13}', end='')
    print()

    # zip by index; assume all curves share the same indices
    first_curve = curves[names_offsets[0][0]]
    for pt in first_curve:
        idx = pt['index']
        mv  = pt['base_voltage']
        print(f'# {idx:3d}  {mv:4d}', end='')
        for gpu_id, _, offset in names_offsets:
            if gpu_id not in curves:
                print(f'  {"N/A":<13}', end='')
                continue
            row = next((p for p in curves[gpu_id] if p['index'] == idx), None)
            if row is None:
                print(f'  {"N/A":<13}', end='')
                continue
            base = row['base_freq']
            print(f'  {base:4d}->{base+offset:4d}  ', end='')
        print()


if __name__ == '__main__':
    main()
