#!/usr/bin/env python3
import http.client
import json
import socket
import sys
import threading
import time
import psutil
import sensors
import pynvml
from common import RESET, _lerp, _fg, pwm_to_db_rel, pct_to_db_rel, find_hwmon


VRAM_GB = 24
FANLISTENER_HOST, FANLISTENER_PORT = '127.0.0.1', 9271
VLLM_HOST, VLLM_PORT = '192.168.99.53', 11111
VLLM_MAX_SEQS  = 4    # --max-num-seqs
VLLM_PP_TPS_MAX = 400  # computed-prefill peak (cache-heavy workload)
VLLM_TG_TPS_MAX = 120  # decode peak (DFlash thinking mode)
VLLM_DELTA_WINDOW = 0.3  # seconds of history for TPS / ACC window
VLLM_PP_BURST_WINDOW = 5.0  # seconds; burst-aware PP TPS history
DB_MIN, DB_OVER = 0, 5
FANS = {  # name: (max_rpm, profile, pwm_n)
    'CPU Fan':       (2000, 'cpu0',  1),
    'Pump Fan':      (2423, 'case2', 2),
    'System Fan #1': (2423, 'case3', 3),
    'System Fan #2': (1186, 'case4', 4),
    'System Fan #3': (1693, 'case5', 5),
    'System Fan #5': (1775, 'case7', 7),
    'System Fan #6': (2423, 'case8', 8),
}


class LoudnessMonitor:
    def __init__(self):
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
                    s.sendto(b'?', (FANLISTENER_HOST,
                                    FANLISTENER_PORT))
                    data, _ = s.recvfrom(256)
                    parsed = json.loads(data)
                    base = parsed.get('base', parsed['db'])
                    db = parsed['db'] - base
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


class VllmMonitor:
    def __init__(self):
        self._lock = threading.Lock()
        self._tg_tps = self._kv_pct = 0.0
        self._reqs = 0
        self._acc = self._acc_cum = self._pc_pct = 0.0
        self._reusing = False
        self._n_pp = self._n_dec = 0
        self._history = []  # (t, gen, acc, draft)
        self._prev_kv = 0.0
        self._pp_burst_tps = 0.0
        self._pp_bursts = []      # poll-thread only; no lock needed
        self._prev_pp_computed = None  # poll-thread only
        self._conn = None
        threading.Thread(target=self._poll, daemon=True).start()

    def _connect(self):
        self._conn = http.client.HTTPConnection(
            VLLM_HOST, VLLM_PORT, timeout=1.0)

    @staticmethod
    def _metric(text, name, label=None):
        prefix = name + '{'
        for line in text.splitlines():
            if line.startswith(prefix) and (label is None or label in line):
                try:
                    return float(line.split()[-1])
                except ValueError:
                    pass
        return 0.0

    def _fetch(self):
        for attempt in range(2):
            try:
                if self._conn is None:
                    self._connect()
                self._conn.request('GET', '/metrics',
                                   headers={'Connection': 'keep-alive'})
                r = self._conn.getresponse()
                return r.read().decode()
            except Exception:
                self._conn = None
                if attempt == 0:
                    continue
        return None

    @staticmethod
    def _trim(buf, now, window):
        while buf and now - buf[0][0] > window:
            buf.pop(0)

    def _poll(self):
        while True:
            t0 = time.monotonic()
            text = self._fetch()
            active = False
            if text is not None:
                run = int(self._metric(text, 'vllm:num_requests_running'))
                gen   = self._metric(text, 'vllm:generation_tokens_total')
                now = time.monotonic()
                if run > 0:
                    active = True
                    kv    = self._metric(text, 'vllm:kv_cache_usage_perc')
                    acc   = self._metric(
                        text, 'vllm:spec_decode_num_accepted_tokens_total')
                    draft = self._metric(
                        text, 'vllm:spec_decode_num_draft_tokens_total')
                    pc_h  = self._metric(text, 'vllm:prefix_cache_hits_total')
                    pc_q  = self._metric(
                        text, 'vllm:prefix_cache_queries_total')
                    pp_computed = self._metric(
                        text, 'vllm:prefill_tokens_computed_total')
                    n_pp  = int(self._metric(
                        text, 'vllm:num_requests_prefilling'))
                    n_dec = int(self._metric(
                        text, 'vllm:num_requests_decoding'))
                    delta = 0.0
                    if self._prev_pp_computed is not None:
                        delta = pp_computed - self._prev_pp_computed
                        if delta > 0:
                            self._pp_bursts.append((now, delta))
                    self._prev_pp_computed = pp_computed
                    self._trim(self._pp_bursts, now, VLLM_PP_BURST_WINDOW)
                    burst_tps = 0.0
                    if len(self._pp_bursts) >= 2:
                        total = sum(d for _, d in self._pp_bursts)
                        span = (self._pp_bursts[-1][0]
                                - self._pp_bursts[0][0])
                        if span > 0:
                            burst_tps = total / span
                    with self._lock:
                        self._history.append((now, gen, acc, draft))
                        self._trim(self._history, now, VLLM_DELTA_WINDOW)
                        base, top = self._history[0], self._history[-1]
                        dt = top[0] - base[0]
                        if dt > 0:
                            self._tg_tps = max(0, (top[1] - base[1]) / dt)
                            d_draft = top[3] - base[3]
                            if d_draft > 0:
                                self._acc = (top[2] - base[2]) / d_draft
                        self._pp_burst_tps = burst_tps
                        self._reusing = kv > self._prev_kv and delta <= 0
                        self._prev_kv = kv
                        self._acc_cum = acc / draft if draft > 0 else 0.0
                        self._kv_pct = kv * 100
                        self._reqs = run
                        self._pc_pct = (
                            pc_h / pc_q * 100 if pc_q > 0 else 0.0)
                        self._n_pp  = n_pp
                        self._n_dec = n_dec
                else:
                    self._pp_bursts.clear()
                    self._prev_pp_computed = None
                    with self._lock:
                        self._history.append((now, gen, 0.0, 0.0))
                        self._trim(self._history, now, VLLM_DELTA_WINDOW)
                        self._prev_kv = 0.0
                        self._reqs = 0
                        self._tg_tps = 0.0
                        self._reusing = False
                        self._n_pp = self._n_dec = 0
                        self._pp_burst_tps = 0.0
            elapsed = time.monotonic() - t0
            time.sleep(max(0, (0.1 if active else 0.5) - elapsed))

    def values(self):
        with self._lock:
            return (self._tg_tps,
                    self._kv_pct, self._reqs,
                    self._acc, self._acc_cum, self._pc_pct,
                    self._reusing,
                    self._pp_burst_tps,
                    self._n_pp, self._n_dec)


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
    return gwyor_color((db - DB_MIN) / (DB_OVER - DB_MIN))


def fan_color(db_rel):
    return gwyor_color(db_rel / 4)


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
    t = int(pynvml.nvmlDeviceGetTemperature(h, pynvml.NVML_TEMPERATURE_GPU))
    t = f'{temp_color(t)}{t:3d}°{RESET}'
    f_pct = int(pynvml.nvmlDeviceGetFanSpeed(h))
    db_rel = pct_to_db_rel(profile_name, f_pct)
    f = f'{fan_color(db_rel)}{f_pct:3d}%{RESET}'
    w_max = pynvml.nvmlDeviceGetPowerManagementLimit(h)
    w = pynvml.nvmlDeviceGetPowerUsage(h)
    w = f'{gw_color(w / w_max)}{int(w / 1000):3d}W{RESET}'
    return r, u, t, f, w


def get_lines(nct, gpu0, gpu1, vllm, loudness):
    sensors_data = chip_data(nct)
    ct = int(sensors_data["CPU"])
    ct = f'{temp_color(ct)}{ct:3d}°{RESET}'
    st = int(sensors_data["System"])
    st = f'{temp_color(st)}{st:3d}°{RESET}'
    cp = int(psutil.cpu_percent())
    cp = f'{gw_color(cp / 100)}{cp:3d}%{RESET}'

    top_fans, top_tx = fan(sensors_data, 'Pump Fan')
    bot_f, bot_tx = fan(sensors_data, 'System Fan #3', width=7)
    tf, tf_txt = fan(sensors_data, 'System Fan #1', vert=False)
    mf, mf_txt = fan(sensors_data, 'System Fan #5', vert=False)
    bf, bf_txt = fan(sensors_data, 'System Fan #6', vert=False)
    bk, bk_txt = fan(sensors_data, 'System Fan #2', vert=False)
    tf = f' {tf}'
    mf = f' {mf}'
    bf = f' {bf}'
    bk, bk_ = f' {bk}', f' {bk}   '
    _, cpu_tx = fan(sensors_data, 'CPU Fan')

    r0, u0, t0, f0, w0 = gpu(gpu0, 'gpu0')
    r1, u1, t1, f1, w1 = gpu(gpu1, 'gpu1')
    (tg_tps, kv_pct, reqs, acc, acc_cum, pc_pct,
     reusing, pp_burst_tps, n_pp, n_dec) = vllm.values()
    active = reqs > 0

    if active and reusing:
        pp_col = f'{gw_color(0)}REUSE KV{RESET}  '
        top_fill = f'─{gw_color(0)}↓─↓{RESET}──────'
    elif active and tg_tps > 5:
        pp_col = '          '
        top_fill = '──────────'
    elif active and pp_burst_tps > 5:
        pp_tps = min(9999, int(pp_burst_tps))
        c = gw_color(pp_burst_tps / VLLM_PP_TPS_MAX)
        pp_col = f' {c}{pp_tps:4d} PP{RESET}  '
        top_fill = (f'─↓{gw_color(n_pp/VLLM_MAX_SEQS)}{n_pp}{RESET}↓──────'
                    if n_pp > 1 else '─↓─↓──────')
    else:
        pp_col = '          '
        top_fill = '──────────'
    if active:
        kv_fill = f'{gw_color(kv_pct/100)}{int(kv_pct):3d}%{RESET}─────'
        if n_dec > 1:
            dc = _fg((255, 0, 0)) if n_dec > 2 else _fg((255, 220, 0))
            bot_fill = f'─↓{dc}{n_dec}{RESET}↓──────'
        else:
            bot_fill = '──────────'
        _vllm1 = (f'{gw_color(tg_tps/VLLM_TG_TPS_MAX)}'
                  f'{int(tg_tps):5d} TG{RESET}')
        vllm2 = f'{gwyor_color(acc)}{int(acc*100):3d}% ac{RESET}'
    else:
        kv_fill = '─────────'
        bot_fill = '──────────'
        _vllm1 = f'{gw_color(0)}{int(pc_pct):4d}% pc{RESET}'
        vllm2 = f'{gw_color(0)}{int(acc_cum*100):3d}% ac{RESET}'

    _db = loudness.db()
    db_str = (f'{db_color(_db)}{_db:6.1f} dB{RESET} '
              if _db is not None else '          ')
    _base = loudness.base()
    base_str = (f'{gw_color(0)}{_base:6.1f} dB{RESET} '
                if _base is not None else '          ')
    return [
        f'{db_str}┌──{ top_fans}─{ top_fans}──┐',
        f'{base_str}│                {top_tx}  {tf}',
        f'          │     ┌────────┐           {tf} {tf_txt}',
        f'         {bk_}  │{cp}{ct}│ {cpu_tx}  {tf}',
        f' {bk_txt}{bk_}  └────────┘            │',
        f'         {bk}{pp_col}{st}            {mf}',
        f'          │┌{top_fill}──────────────┐{mf} {mf_txt}',
        f'          ││{r0} {u0}{t0} {f0} {w0} │{mf}',
        f'          │├{kv_fill}───────────────┤ │',
        f'          ││{r1} {u1}{t1} {f1} {w1} │{bf}',
        f'          │└{bot_fill}──────────────┘{bf} {bf_txt}',
        f'          │{_vllm1}{vllm2} {bot_tx}  {bf}',
        f'          └─────────────────{bot_f}───┘',
    ]


pynvml.nvmlInit()
try:
    nct = next(c for c in sensors.get_detected_chips()
               if 'nct6687' in str(c))
    nct_hwmon = find_hwmon('nct6687')
    gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
    gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)
    vllm = VllmMonitor()
    loudness = LoudnessMonitor()
    once = '-1' in sys.argv
    try:
        while True:
            lines = get_lines(nct, gpu0, gpu1, vllm, loudness)
            print('\n'.join(lines))
            if once:
                break
            time.sleep(0.2)
            print(f'\033[{len(lines)}A', end='')
    except KeyboardInterrupt:
        pass
finally:
    pynvml.nvmlShutdown()
