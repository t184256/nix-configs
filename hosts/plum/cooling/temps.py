#!/usr/bin/env python3
import collections
import http.client
import json
import socket
import sys
import threading
import time
import psutil
import sensors
import pynvml
from common import (
    RESET, _lerp, _fg, pwm_to_db_rel, pct_to_db_rel, find_hwmon, gpu_max_temp
)


VRAM_GB = 24
FANLISTENER_HOST, FANLISTENER_PORT = '127.0.0.1', 9271
SGLANG_HOST, SGLANG_PORT = '192.168.99.53', 11111
ENGINE_TG_TPS_MAX = 150
ENGINE_PP_TPS_MAX = 200
# Window for rate differencing: long enough to span the gap between batch
# updates, short enough that a phase change still shows promptly.
ENGINE_RATE_WINDOW = 4.0

DB_OVER = 20
FANS = {  # name: (max_rpm, profile, pwm_n)
    'CPU Fan':       (2010, 'cpu0',  1),
    'Pump Fan':      (2400, 'case2', 2),
    'System Fan #1': (2423, 'case3', 3),
    'System Fan #2': (3030, 'case4', 4),
    'System Fan #3': (3000, 'case5', 5),
    'System Fan #4': (2100, 'case6', 6),
    'System Fan #5': (2370, 'case7', 7),
    'System Fan #6': (2365, 'case8', 8),
}


class LoudnessMonitor:
    def __init__(self, port):
        self._port = port
        self._lock = threading.Lock()
        self._db = self._base = None
        threading.Thread(target=self._poll, daemon=True).start()

    def _poll(self):
        while True:
            db = base = None
            try:
                with socket.socket(socket.AF_INET,
                                   socket.SOCK_DGRAM) as s:
                    s.settimeout(1.0)
                    s.sendto(b'?', (FANLISTENER_HOST, self._port))
                    data, _ = s.recvfrom(256)
                    parsed = json.loads(data)
                    base = parsed.get('base', parsed['db_ema'])
                    db = parsed['db_ema'] - base
            except Exception:
                pass
            with self._lock:
                self._db = db
                self._base = base
            time.sleep(0.5)

    def db(self):
        with self._lock:
            return self._db

    def base(self):
        with self._lock:
            return self._base


EngineStats = collections.namedtuple(
    'EngineStats',
    'tg_tps pp_tps reuse_tps kv_pct requests decode_rate accept_rate '
    'reuse_share accept_session')
EngineStats.__new__.__defaults__ = (0.0,) * len(EngineStats._fields)


class SglangMonitor:
    def __init__(self):
        self._lock = threading.Lock()
        self._stats = EngineStats()
        self._conn = None
        self._hist = {}   # key -> deque of (monotonic time, cumulative value)
        self._polls = 0   # successful fetches; rates need two
        self._acc_sum = 0.0
        self._acc_n = 0
        threading.Thread(target=self._poll, daemon=True).start()

    @staticmethod
    def _metric(text, name, **labels):
        total, matched = 0.0, False
        for line in text.splitlines():
            if not line.startswith((name + '{', name + ' ')):
                continue
            if 'tp_rank="' in line and 'tp_rank="0"' not in line:
                continue  # avoid doubling
            for key, val in labels.items():
                if f'{key}="{val}"' not in line:
                    break
            else:
                try:
                    total += float(line.rsplit(' ', 1)[1])
                    matched = True
                except (IndexError, ValueError):
                    pass
        return total if matched else None

    def _rate(self, text, key, name, **labels):
        now = time.monotonic()
        cur = self._metric(text, name, **labels)
        if cur is None:
            return 0.0
        hist = self._hist.setdefault(key, collections.deque(maxlen=64))
        # engine restart resets counters; drop history when they go back
        if hist and cur < hist[-1][1]:
            hist.clear()
        hist.append((now, cur))
        cutoff = now - ENGINE_RATE_WINDOW
        while len(hist) > 2 and hist[0][0] < cutoff:
            hist.popleft()
        t0, v0 = hist[0]
        dt = now - t0
        return 0.0 if dt <= 0 else (cur - v0) / dt

    def _fetch_metrics(self):
        for attempt in range(2):
            try:
                if self._conn is None:
                    self._conn = http.client.HTTPConnection(
                        SGLANG_HOST, SGLANG_PORT, timeout=1.0)
                self._conn.request('GET', '/metrics',
                                   headers={'Connection': 'keep-alive'})
                return self._conn.getresponse().read().decode()
            except Exception:
                self._conn = None
                if attempt == 0:
                    continue
        return None

    def _poll(self):
        active = False
        while True:
            t0 = time.monotonic()
            text = self._fetch_metrics()
            if text is not None:
                def num(name, **labels):
                    v = self._metric(text, name, **labels)
                    return 0.0 if v is None else v

                running = int(num('sglang:num_running_reqs'))
                # gen_throughput is the engine's own decode rate, but it is
                # latched: sglang holds the last value for 30 s after decode
                # stops, so gate it on the decode counter actually moving.
                decode_rate = self._rate(text, 'dec',
                                         'sglang:realtime_tokens_total',
                                         mode='decode')
                tg = num('sglang:gen_throughput')
                tg_tps = tg if decode_rate > 5 else 0.0
                acc = num('sglang:spec_accept_rate')
                if running > 0 and acc > 0:
                    self._acc_sum += acc
                    self._acc_n += 1
                cached = num('sglang:realtime_tokens_total',
                             mode='prefill_cache')
                computed = num('sglang:realtime_tokens_total',
                               mode='prefill_compute')
                stats = EngineStats(
                    tg_tps=tg_tps,
                    pp_tps=self._rate(
                        text, 'pp', 'sglang:realtime_tokens_total',
                        mode='prefill_compute'),
                    reuse_tps=self._rate(
                        text, 'reuse', 'sglang:realtime_tokens_total',
                        mode='prefill_cache'),
                    kv_pct=num('sglang:token_usage') * 100.0,
                    requests=running,
                    decode_rate=decode_rate,
                    accept_rate=acc,
                    accept_session=(self._acc_sum / self._acc_n
                                    if self._acc_n else 0.0),
                    # Lifetime reuse share: cached / (cached + computed).
                    # Exact rather than sampled, so idling cannot skew it.
                    reuse_share=cached / max(1.0, cached + computed) * 100.0,
                )
                with self._lock:
                    self._stats = stats
                    self._polls += 1
                active = running > 0
            elapsed = time.monotonic() - t0
            time.sleep(max(0, (0.1 if active else 0.5) - elapsed))

    def ready(self, timeout=5.0):  # rates are available
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            with self._lock:
                if self._polls >= 2:
                    return True
            time.sleep(0.1)
        return False

    def values(self):
        with self._lock:
            return self._stats


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


def gw_color(frac):
    # 0.=51 (20%), 1.=255 (100%)
    v = int(51 + min(1.0, frac) * 204)
    return f'\033[38;2;{v};{v};{v}m'


def gwyor_color(frac):
    frac = max(0.0, frac)
    if frac < 0.25:
        return gw_color(frac / 0.25)
    if frac < 0.5:
        t = (frac - 0.25) / 0.25
        return _fg(_lerp((255, 255, 255), (255, 220, 0), t))
    if frac < 0.75:
        t = (frac - 0.5) / 0.25
        return _fg(_lerp((255, 220, 0), (255, 120, 0), t))
    t = min(1.0, (frac - 0.75) / 0.25)
    return _fg(_lerp((255, 120, 0), (255, 0, 0), t))


def db_color(db):
    return gwyor_color(db / DB_OVER)


def fan_color(db_rel):
    return gwyor_color(db_rel / DB_OVER)


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


def fan_db(sensor_name):
    _, profile, pwm_n = FANS[sensor_name]
    pwm = int((nct_hwmon / f'pwm{pwm_n}').read_text())
    return pwm_to_db_rel(profile, pwm)


def fan(fans, name, vert=True, width=11):
    top_rpm, top_max = int(fans[name]), FANS[name][0]
    if vert:
        arrows = fan_arrows_vert(top_rpm, top_max, width=width)
    else:
        arrows = fan_arrow_hor(top_rpm, top_max)
    text = f'{fan_color(fan_db(name))}{top_rpm:4d} RPM{RESET}'
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


def gpu(h, profile_name):
    r = int(pynvml.nvmlDeviceGetMemoryInfo(h).used // 1024**3)
    r = f'{gw_color(r / VRAM_GB)}{r:3d}G{RESET}'
    u = int(pynvml.nvmlDeviceGetUtilizationRates(h).gpu)
    u = f'{gw_color(u / 100)}{u:3d}%{RESET}'
    t = gpu_max_temp(h)
    t = f'{temp_color(t)}{t:3d}°{RESET}'
    num_fans = pynvml.nvmlDeviceGetNumFans(h)
    speeds = [pynvml.nvmlDeviceGetFanSpeed_v2(h, i) for i in range(num_fans)]
    f_pct = int(sum(speeds) / num_fans)
    db_rel = pct_to_db_rel(profile_name, f_pct)
    f = f'{fan_color(db_rel)}{f_pct:3d}%{RESET}'
    w_max = pynvml.nvmlDeviceGetPowerManagementLimit(h)
    w = pynvml.nvmlDeviceGetPowerUsage(h)
    reasons = pynvml.nvmlDeviceGetCurrentClocksThrottleReasons(h)
    sw_slowdown = bool(reasons &
                       pynvml.nvmlClocksThrottleReasonSwThermalSlowdown)
    power_cap = bool(reasons &
                     pynvml.nvmlClocksThrottleReasonSwPowerCap)
    other_throttle = bool(reasons &
                          ~pynvml.nvmlClocksThrottleReasonSwThermalSlowdown &
                          ~pynvml.nvmlClocksThrottleReasonSwPowerCap &
                          ~pynvml.nvmlClocksThrottleReasonGpuIdle)
    if sw_slowdown:
        w_col = _fg((255, 0, 0))
    elif power_cap:
        w_col = _fg((255, 220, 0))
    elif other_throttle:
        w_col = _fg((160, 0, 255))
    else:
        w_col = gw_color(w / w_max)
    w = f'{w_col}{int(w / 1000):3d}W{RESET}'
    return r, u, t, f, w


def get_lines(nct, gpu0, gpu1, engine, loudness_usb, loudness_analog):
    sensors_data = chip_data(nct)
    ct = int(sensors_data["CPU"])
    ct = f'{temp_color(ct)}{ct:3d}°{RESET}'
    st = int(sensors_data["System"])
    st = f'{temp_color(st)}{st:3d}°{RESET}'
    cp = int(psutil.cpu_percent())
    cp = f'{gw_color(cp / 100)}{cp:3d}%{RESET}'

    cpu_fans, cpu_tx = fan(sensors_data, 'CPU Fan', vert=False)
    cpu_line = f'{cpu_fans}{cp}{ct}{cpu_fans}'
    top_fans, top_tx = fan(sensors_data, 'Pump Fan')
    bot_fans, bot_tx = fan(sensors_data, 'System Fan #3', width=11)
    tf, tf_txt = fan(sensors_data, 'System Fan #1', vert=False)
    mf, mf_txt = fan(sensors_data, 'System Fan #5', vert=False)
    bf, bf_txt = fan(sensors_data, 'System Fan #6', vert=False)
    tr, tr_txt = fan(sensors_data, 'System Fan #2', vert=False)
    br, _ = fan(sensors_data, 'System Fan #4', vert=False)
    tf = f' {tf}'
    mf = f' {mf}'
    bf = f' {bf}'
    tr, tr_ = f' {tr}', f' {tr}   '
    br = f'   {br}'

    r0, u0, t0, f0, w0 = gpu(gpu0, 'gpu0')
    r1, u1, t1, f1, w1 = gpu(gpu1, 'gpu1')

    es = engine.values()
    active = (es.requests > 0 or es.decode_rate > 5
              or es.pp_tps > 5 or es.reuse_tps > 5)

    if active and es.reuse_tps > es.pp_tps and es.reuse_tps > 5:
        pp_col = f' {gw_color(0)}{min(9999, int(es.reuse_tps)):4d} KV{RESET}  '
        top_fill = f'─{gw_color(0)}↓─↓{RESET}──────'
    elif active and es.pp_tps > 5:
        c = gw_color(es.pp_tps / ENGINE_PP_TPS_MAX)
        pp_col = f' {c}{min(9999, int(es.pp_tps)):4d} PP{RESET}  '
        top_fill = '─↓─↓──────'
    else:
        pp_col = '          '
        top_fill = '──────────'

    if active:
        kc = gw_color(es.kv_pct / 100)
        kv_fill = f'{kc}{int(es.kv_pct):3d}%{RESET}─────'
        n_dec = es.requests
        if n_dec > 1:
            dc = _fg((255, 0, 0)) if n_dec > 2 else _fg((255, 220, 0))
            bot_fill = f'─↓{dc}{n_dec}{RESET}↓──────'
        elif n_dec == 1:
            bot_fill = '─↓─↓──────'
        else:
            bot_fill = '──────────'
        eng1 = (f'{gw_color(es.tg_tps / ENGINE_TG_TPS_MAX)}'
                f'{int(es.tg_tps):5d} TG{RESET}')
        ac = int(es.accept_rate * 100)
        eng2 = f'{gwyor_color(es.accept_rate)}{ac:3d}% ac{RESET}'
    else:
        kv_fill = '─────────'
        bot_fill = '──────────'
        # lifetime stats at rest
        eng1 = f'{gw_color(0)}{int(es.reuse_share):4d}% pc{RESET}'
        eng2 = (f'{gw_color(0)}{int(es.accept_session * 100):3d}% ac{RESET}')

    _db_usb = loudness_usb.db()
    db_usb = (f'{db_color(_db_usb)}{_db_usb:6.1f} dB{RESET} '
              if _db_usb is not None else '          ')
    _base_usb = loudness_usb.base()
    base_usb = (f'{gw_color(0)}{_base_usb:6.1f} dB{RESET} '
                if _base_usb is not None else '          ')

    _db_analog = loudness_analog.db()
    db_ana = (f'{db_color(_db_analog)}{_db_analog:6.1f} dB{RESET} '
              if _db_analog is not None else '          ')
    _base_analog = loudness_analog.base()
    base_ana = (f'{gw_color(0)}{_base_analog:6.1f} dB{RESET} '
                if _base_analog is not None else '          ')
    return [
        f'          ┌──{ top_fans}─{ top_fans}──┐           {  db_usb}',
        f'          │                {top_tx}  {tf}           {base_usb}',
        f'          │     ┌────────┐           {tf} {tf_txt}',
        f'         {tr_}  {cpu_line} {cpu_tx}  {tf}',
        f' {tr_txt}{tr_}  └────────┘            │',
        f'         {tr}{pp_col}{st}            {mf}',
        f'          │┌{top_fill}──────────────┐{mf} {mf_txt}',
        f'       {br}│{r0} {u0}{t0} {f0} {w0} │{mf}',
        f'       {br}├{kv_fill}───────────────┤ │',
        f'       {br}│{r1} {u1}{t1} {f1} {w1} │{bf}',
        f'          │└{bot_fill}──────────────┘{bf} {bf_txt}',
        f'{  db_ana}│{eng1}{eng2} {bot_tx}  {bf}',
        f'{base_ana}└──────────────{ bot_fans}──┘',
    ]


pynvml.nvmlInit()
try:
    nct = next(c for c in sensors.get_detected_chips()
               if 'nct6687' in str(c))
    nct_hwmon = find_hwmon('nct6687')
    gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
    gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)
    engine = SglangMonitor()
    loudness_usb = LoudnessMonitor(port=9271)
    loudness_analog = LoudnessMonitor(port=9272)
    once = '-1' in sys.argv
    if once:
        engine.ready()
    try:
        while True:
            lines = get_lines(nct, gpu0, gpu1, engine,
                              loudness_usb, loudness_analog)
            print('\n'.join(lines))
            if once:
                break
            time.sleep(0.2)
            print(f'\033[{len(lines)}A', end='')
    except KeyboardInterrupt:
        pass
finally:
    pynvml.nvmlShutdown()
