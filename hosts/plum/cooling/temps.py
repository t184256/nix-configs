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
LOUDNESS_SID, LOUDNESS_TOP = ('127.0.0.1', 9271), ('192.168.98.1', 9271)
SGLANG_HOST, SGLANG_PORT = '192.168.99.53', 11111
ENGINE_TG_TPS_MAX = 150
ENGINE_PP_TPS_MAX = 200
# Window for rate differencing: long enough to span the gap between batch
# updates, short enough that a phase change still shows promptly.
ENGINE_RATE_WINDOW = 4.0

HDDTEMP_HOST, HDDTEMP_PORT = '127.0.0.1', 7634
HDD_DEVICE = '/dev/sda'

DB_OVER = 20
FANS = {  # name: (max_rpm, profile, hwmon, ch), see mapping.txt
    'cin':  (2000, 'case2', 'nct6799',    2),
    'rto':  (3000, 'case1', 'arctic_fan', 7),
    'r4t':  (3300, 'case3', 'nct6799',    3),
    'r4m':  (3550, 'case3', 'nct6799',    1),
    'r4b':  (3100, 'case3', 'nct6799',    4),
    'tre':  (2410, 'case7', 'arctic_fan', 6),
    'tfr':  (2410, 'case7', 'arctic_fan', 1),
    'fto':  (3050, 'case2', 'arctic_fan', 2),
    'fmi':  (2440, 'case5', 'arctic_fan', 3),
    'fbo':  (2380, 'case6', 'arctic_fan', 4),
    'bma':  (3000, 'case4', 'arctic_fan', 5),
}


class LoudnessMonitor:
    def __init__(self, addr):
        self._addr = addr
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
                    s.sendto(b'?', self._addr)
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


class HddTempMonitor:
    def __init__(self):
        self._lock = threading.Lock()
        self._temp = None
        threading.Thread(target=self._poll, daemon=True).start()

    def _poll(self):
        while True:
            temp = None
            try:
                with socket.create_connection(
                        (HDDTEMP_HOST, HDDTEMP_PORT), timeout=1.0) as s:
                    data = s.makefile('rb').read().decode()
                # one '|/dev/sda|MODEL|34|C|' per monitored drive
                fields = data.split('|')
                if HDD_DEVICE in fields:
                    value = fields[fields.index(HDD_DEVICE) + 2]
                    if value.lstrip('-').isdigit():
                        temp = int(value)
            except Exception:
                pass
            with self._lock:
                self._temp = temp
            time.sleep(5)

    def temp(self):
        with self._lock:
            return self._temp


EngineStats = collections.namedtuple(
    'EngineStats',
    'tg_tps pp_tps kv_pct requests decode_rate accept_rate '
    'reuse_share accept_session blocked pending')
EngineStats.__new__.__defaults__ = (0.0,) * len(EngineStats._fields)


class SglangMonitor:
    def __init__(self):
        self._lock = threading.Lock()
        self._stats = EngineStats()
        self._conn = None
        self._loads_conn = None
        self._dec_base = None  # (monotonic, decode counter) at window anchor
        self._pend_prev = None  # last waiting-uncached sample
        self._pend_ep_t = None  # start of current drain episode
        self._pend_ep_drop = 0.0  # sum of downward jumps in it
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

    def _fetch_loads(self):
        for attempt in range(2):
            try:
                if self._loads_conn is None:
                    self._loads_conn = http.client.HTTPConnection(
                        SGLANG_HOST, SGLANG_PORT, timeout=1.0)
                self._loads_conn.request('GET', '/v1/loads',
                                         headers={'Connection': 'keep-alive'})
                return json.loads(self._loads_conn.getresponse().read())
            except Exception:
                self._loads_conn = None
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
                now = time.monotonic()
                dec = num('sglang:realtime_tokens_total', mode='decode')
                base = self._dec_base
                if (base is None or dec < base[1]
                        or now - base[0] >= ENGINE_RATE_WINDOW):
                    base = self._dec_base = (now, dec)
                dt = now - base[0]
                decode_rate = (dec - base[1]) / dt if dt > 0 else 0.0
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
                blocked = pending = 0
                loads = self._fetch_loads()
                if loads is not None:
                    for ld in loads.get('loads', ()):
                        blocked += int(ld.get('num_waiting_reqs', 0))
                        pending += int(
                            ld.get('num_waiting_uncached_tokens', 0))
                pp_tps = 0.0
                now = time.monotonic()
                if pending > 0 and self._pend_prev is not None:
                    delta = self._pend_prev - pending
                    if delta > 0:
                        self._pend_ep_drop += delta
                    elif delta < 0:
                        self._pend_ep_t, self._pend_ep_drop = now, 0.0
                    if self._pend_ep_t is not None:
                        age = now - self._pend_ep_t
                        if age > 0:
                            pp_tps = self._pend_ep_drop / age
                self._pend_prev = pending
                stats = EngineStats(
                    tg_tps=tg_tps,
                    pp_tps=pp_tps,
                    kv_pct=num('sglang:token_usage') * 100.0,
                    requests=running,
                    decode_rate=decode_rate,
                    accept_rate=acc,
                    accept_session=(self._acc_sum / self._acc_n
                                    if self._acc_n else 0.0),
                    # Lifetime reuse share: cached / (cached + computed).
                    # Exact rather than sampled, so idling cannot skew it.
                    reuse_share=cached / max(1.0, cached + computed) * 100.0,
                    blocked=blocked,
                    pending=pending,
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


def _hor_arrow(frac):
    if frac > 0.75:
        return '⬱'
    elif frac > 0.50:
        return '⥢'
    elif frac > 0.25:
        return '←'
    return ':'


def fan_arrow_hor(rpm, rpm_max):
    return _hor_arrow(rpm / rpm_max)


def fan_hwmon(slot):
    _, _, hname, _ = FANS[slot]
    return nct_hwmon if hname == 'nct6799' else arctic_hwmon


def fan_db(slot):
    _, profile, _, ch = FANS[slot]
    pwm = int((fan_hwmon(slot) / f'pwm{ch}').read_text())
    return pwm_to_db_rel(profile, pwm)


def fan(slot, vert=True, width=11):
    top_max = FANS[slot][0]
    top_rpm = int((fan_hwmon(slot) / f'fan{FANS[slot][3]}_input').read_text())
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


def _kfmt(v):
    v = int(v)
    return f'{v // 1000}k' if v >= 1000 else f'{v:03d}'


def get_lines(nct, gpu0, gpu1, engine, loudness_sid, loudness_top, disk):
    sensors_data = chip_data(nct)
    ct = int(sensors_data["TSI0_TEMP"])
    ct = f'{temp_color(ct)}{ct:3d}°{RESET}'
    st = int(sensors_data["SYSTIN"])
    st = f'{temp_color(st)}{st:3d}°{RESET}'
    cp = int(psutil.cpu_percent())
    cp = f'{gw_color(cp / 100)}{cp:3d}%{RESET}'
    ht_val = disk.temp()
    ht = (f'{temp_color(ht_val, 40, 55)}{ht_val:3d}°{RESET}'
          if ht_val is not None else '    ')

    cpu_fans, cpu_tx = fan('cin', vert=False)  # cpu cooler
    cpu_line = f'{cpu_fans}{cp}{ct}{cpu_fans}'
    top_r, top_r_tx = fan('tre')  # top exhaust (2 fans)
    top_f, _ = fan('tfr')
    bot_fans, bot_tx = fan('bma', width=11)  # bottom intake
    tr, tr_txt = fan('rto', vert=False)  # rear-top exhaust
    mf, mf_txt = fan('fmi', vert=False)  # front-mid intake
    bf, bf_txt = fan('fbo', vert=False)  # front-bottom
    tf, tf_txt = fan('fto', vert=False)  # front-top intake
    r4t_sig, r4t_txt = fan('r4t', vert=False)  # across-GPU rear-top exhaust
    r4m_sig, r4m_txt = fan('r4m', vert=False)  # across-GPU rear-middle exhaust
    r4b_sig, r4b_txt = fan('r4b', vert=False)  # across-GPU rear-bottom exhaust
    r4t = f'{r4t_txt} {r4t_sig}'
    r4m = f'{r4m_txt} {r4m_sig}'
    r4b = f'{r4b_txt} {r4b_sig}'
    tf = f' {tf}'
    mf = f' {mf}'
    bf = f' {bf}'
    tr, tr_ = f' {tr}', f' {tr}   '

    r0, u0, t0, f0, w0 = gpu(gpu0, 'gpu0')
    r1, u1, t1, f1, w1 = gpu(gpu1, 'gpu1')

    es = engine.values()

    if es.blocked:
        n = '*' if es.blocked > 9 else es.blocked
        top_fill = (f'─↓{_fg((255, 0, 0))}{n}{RESET}↓'
                    + '─' * (7 - len(str(n))))
    elif es.pp_tps > 5:
        top_fill = '─↓─↓──────'
    else:
        top_fill = '──────────'
    if es.pp_tps > 5:
        c = gw_color(es.pp_tps / ENGINE_PP_TPS_MAX)
        r = min(9999, int(es.pp_tps))
        sv = f'{r:4d}/{_kfmt(es.pending)}'
        pp_col = f' {c}{sv}{RESET}' + ' ' * max(0, 9 - len(sv))
    else:
        pp_col = '          '

    decoding = es.tg_tps > 5

    if es.requests > 0:
        kc = gw_color(es.kv_pct / 100)
        kv_fill = f'{kc}{int(es.kv_pct):3d}%{RESET}─────'
    else:
        kv_fill = '─────────'
    if decoding:
        n_dec = es.requests
        if n_dec > 1:
            dc = _fg((255, 0, 0)) if n_dec > 2 else _fg((255, 220, 0))
            n = '*' if n_dec > 9 else n_dec
            bot_fill = f'─↓{dc}{n}{RESET}↓' + '─' * (7 - len(str(n)))
        else:
            bot_fill = '─↓─↓──────'
    else:
        bot_fill = '──────────'

    if decoding:
        eng1 = (f'{gw_color(es.tg_tps / ENGINE_TG_TPS_MAX)}'
                f'{int(es.tg_tps):5d} TG{RESET}')
        ac = int(es.accept_rate * 100)
        eng2 = f'{gwyor_color(es.accept_rate)}{ac:3d}% ac{RESET}'
    else:
        eng1 = f'{gw_color(0)}{int(es.reuse_share):4d}% pc{RESET}'
        eng2 = (f'{gw_color(0)}{int(es.accept_session * 100):3d}% ac{RESET}')

    _db_top = loudness_top.db()
    mic_top = (f'{db_color(_db_top)}{_db_top:6.1f} dB{RESET} '
               if _db_top is not None else '          ')
    _base_top = loudness_top.base()
    base_top = (f'{gw_color(0)}{_base_top:6.1f} dB{RESET} '
                if _base_top is not None else '          ')

    _db_sid = loudness_sid.db()
    mic_sid = (f'{db_color(_db_sid)}{_db_sid:6.1f} dB{RESET} '
               if _db_sid is not None else '          ')
    _base_sid = loudness_sid.base()
    base_sid = (f'{gw_color(0)}{_base_sid:6.1f} dB{RESET} '
                if _base_sid is not None else '          ')
    return [
        f'          ┌──{ top_r}─{ top_f}──┐           {mic_top}',
        f'          │                {top_r_tx}  {tf}           {base_top}',
        f'          │     ┌────────┐           {tf} {tf_txt}',
        f'         {tr_}  {cpu_line} {cpu_tx}  {tf}',
        f' {tr_txt}{tr_}  └────────┘            │',
        f'         {tr}{pp_col}{st} {ht}       {mf}',
        f'          │┌{top_fill}──────────────┐{mf} {mf_txt}',
        f' {     r4t}│{r0} {u0}{t0} {f0} {w0} │{mf}',
        f' {     r4m}├{kv_fill}───────────────┤ │',
        f' {     r4b}│{r1} {u1}{t1} {f1} {w1} │{bf}',
        f'          │└{bot_fill}──────────────┘{bf} {bf_txt}',
        f'{ mic_sid}│{eng1}{eng2} {   bot_tx}  {bf}',
        f'{base_sid}└──────────────{ bot_fans}──┘',
    ]


pynvml.nvmlInit()
try:
    nct = next(c for c in sensors.get_detected_chips()
               if 'nct6799' in str(c))
    nct_hwmon = find_hwmon('nct6799')
    arctic_hwmon = find_hwmon('arctic_fan')
    gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
    gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)
    engine = SglangMonitor()
    loudness_sid = LoudnessMonitor(LOUDNESS_SID)
    loudness_top = LoudnessMonitor(LOUDNESS_TOP)
    disk = HddTempMonitor()
    once = '-1' in sys.argv
    if once:
        engine.ready()
    try:
        while True:
            lines = get_lines(nct, gpu0, gpu1, engine,
                              loudness_sid, loudness_top, disk)
            print('\n'.join(lines))
            if once:
                break
            time.sleep(0.2)
            print(f'\033[{len(lines)}A', end='')
    except KeyboardInterrupt:
        pass
finally:
    pynvml.nvmlShutdown()
