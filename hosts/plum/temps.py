#!/usr/bin/env python3
import sys
import time
import psutil
import sensors
import pynvml

RESET = '\033[0m'


VRAM_GB = 24
MAX_RPM = {
    'CPU Fan':        2000,  # approx
    'System Fan #1':  2423,
    'System Fan #2':  1186,
    'System Fan #4':  1693,
    'System Fan #5':  1775,
    'System Fan #6':  2423,
}


def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _fg(rgb):
    r, g, b = rgb
    return f'\033[38;2;{r};{g};{b}m'


def temp_color(t, t_min=45, t_max=80):
    # blue=0, grey=0.25, yellow=0.5, orange=0.75, red=1.0
    # grey maps to t_min, red maps to t_max
    keys = [
        (100, 150, 255),  # blue
        (160, 160, 160),  # grey
        (255, 220,   0),  # yellow
        (255, 120,   0),  # orange
        (255,   0,   0),  # red
    ]
    f = max(0.0, min(1.0, 0.25 + 0.75 * (t - t_min) / (t_max - t_min)))
    pos = f * (len(keys) - 1)
    i = min(int(pos), len(keys) - 2)
    return _fg(_lerp(keys[i], keys[i + 1], pos - i))


def frac_color(frac):
    # 0.=51 (20%), 1.=255 (100%)
    v = int(51 + min(1.0, frac) * 204)
    return f'\033[38;2;{v};{v};{v}m'


def fan_arrows_vert(rpm, rpm_max, width=11):
    frac = rpm / rpm_max
    for threshold, spacing in [(0.75, 1), (0.50, 2), (0.25, 3), (0.10, 5)]:
        if frac > threshold:
            chars = [' '] * width
            for i in range(0, width, spacing):
                chars[i] = '↑'
            return ''.join(chars)
    return '·' * width


def fan_arrow_hor(rpm, rpm_max):
    frac = rpm / rpm_max
    if frac > 0.75:
        return '⬱'
    elif frac > 0.50:
        return '⥢'
    elif frac > 0.25:
        return '←'
    return ':'

def fan(fans, name, vert=True, width=11):
    top_rpm, top_max = int(fans[name]), int(MAX_RPM[name])
    if vert:
        arrows = fan_arrows_vert(top_rpm, top_max, width=width)
    else:
        arrows = fan_arrow_hor(top_rpm, top_max)
    text = f'{frac_color(top_rpm / top_max)}{top_rpm:4d} RPM{RESET}'
    return arrows, text


def chip_data(chip):
    data = {}
    for feature in chip.get_features():
        label = chip.get_label(feature)
        for sf in chip.get_all_subfeatures(feature):
            if sf.name.endswith('_input'):
                data[label] = chip.get_value(sf.number)
                break
    return data


def gpu(h):
    r = int(pynvml.nvmlDeviceGetMemoryInfo(h).used // 1024**3)
    r = f'{frac_color(r / VRAM_GB)}{r:3d}G{RESET}'
    u = int(pynvml.nvmlDeviceGetUtilizationRates(h).gpu)
    u = f'{frac_color(u / 100)}{u:3d}%{RESET}'
    t = int(pynvml.nvmlDeviceGetTemperature(h, pynvml.NVML_TEMPERATURE_GPU))
    t = f'{temp_color(t)}{t:3d}°{RESET}'
    f = int(pynvml.nvmlDeviceGetFanSpeed(h))
    f = f'{frac_color(f / 100)}{f:3d}%{RESET}'
    w_max = pynvml.nvmlDeviceGetPowerManagementLimit(h)
    w = pynvml.nvmlDeviceGetPowerUsage(h)
    w = f'{frac_color(w / w_max)}{int(w / 1000):3d}W{RESET}'
    return r, u, t, f, w


def get_lines(nct, gpu0, gpu1):
    sensors_data = chip_data(nct)
    ct = int(sensors_data["CPU"])
    ct = f'{temp_color(ct)}{ct:3d}°{RESET}'
    st = int(sensors_data["System"])
    st = f'{temp_color(st)}{st:3d}°{RESET}'
    cp = int(psutil.cpu_percent())
    cp = f'{frac_color(cp / 100)}{cp:3d}%{RESET}'

    top_fans, top_tx = fan(sensors_data, 'System Fan #2', vert=True)
    bot_f, bot_tx = fan(sensors_data, 'System Fan #4', vert=True, width=7)
    tf, tf_txt = fan(sensors_data, 'System Fan #5', vert=False)
    bf, bf_txt = fan(sensors_data, 'System Fan #6', vert=False)
    bk, bk_txt = fan(sensors_data, 'System Fan #2', vert=False)
    tf = f' {tf}'
    bf = f' {bf}'
    bk = f' {bk}  '
    _, cpu_tx = fan(sensors_data, 'CPU Fan', vert=True)

    r0, u0, t0, f0, w0 = gpu(gpu0)
    r1, u1, t1, f1, w1 = gpu(gpu1)

    return [
        f'          ┌──{ top_fans}─{ top_fans}──┐',
        f'          │                {top_tx}  {tf}',
        f'          │     ┌────────┐           {tf} {tf_txt}',
        f'         {bk}   │{cp}{ct}│ {cpu_tx}  {tf}',
        f' {bk_txt}{bk}   └────────┘            │',
        f'         {bk}        {st}            {bf}',
        f'          │┌────────────────────────┐{bf}',
        f'          ││{r0} {u0}{t0} {f0} {w0} │{bf}',
        f'          │├────────────────────────┤ │ {bf_txt}',
        f'          ││{r1} {u1}{t1} {f1} {w1} │{bf}',
        f'          │└────────────────────────┘{bf}',
        f'          │                {bot_tx}  {bf}',
        f'          └─────────────────{bot_f}───┘',
    ]


pynvml.nvmlInit()
try:
    nct = next(c for c in sensors.get_detected_chips()
               if 'nct6687' in str(c))
    gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
    gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)
    once = '-1' in sys.argv
    try:
        while True:
            lines = get_lines(nct, gpu0, gpu1)
            print('\n'.join(lines))
            if once:
                break
            time.sleep(0.2)
            print(f'\033[{len(lines)}A', end='')
    except KeyboardInterrupt:
        pass
finally:
    pynvml.nvmlShutdown()
