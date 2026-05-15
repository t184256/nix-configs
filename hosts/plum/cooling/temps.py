#!/usr/bin/env python3
import http.client
import sys
import threading
import time
import psutil
import sensors
import pynvml
from common import RESET, _lerp, _fg, pwm_to_db_rel, pct_to_db_rel, find_hwmon


VRAM_GB = 24
VLLM_HOST, VLLM_PORT = '192.168.99.53', 11111
VLLM_MAX_SEQS  = 4    # --max-num-seqs
VLLM_PP_TPS_MAX = 400  # computed-prefill peak (cache-heavy workload)
VLLM_TG_TPS_MAX = 120  # decode peak (DFlash thinking mode)
VLLM_DELTA_WINDOW = 0.3  # seconds of history for TPS / ACC window
FANS = {  # name: (max_rpm, profile, pwm_n)
    'CPU Fan':       (2000, 'cpu0',  1),
    'System Fan #1': (2423, 'case3', 3),
    'System Fan #2': (1186, 'case4', 4),
    'System Fan #4': (1693, 'case6', 6),
    'System Fan #5': (1775, 'case7', 7),
    'System Fan #6': (2423, 'case8', 8),
}


class VllmMonitor:
    def __init__(self):
        self._lock = threading.Lock()
        self._pp_tps = self._tg_tps = self._kv_pct = 0.0
        self._reqs = 0
        self._acc = self._acc_cum = self._pc_pct = 0.0
        self._reusing = self._prefilling = False
        self._raw_prompt = self._raw_pr = 0.0
        self._history = []  # (t, prompt, gen, acc, draft, pp_computed)
        self._prev_kv = 0.0
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

    def _poll(self):
        while True:
            t0 = time.monotonic()
            text = self._fetch()
            active = False
            if text is not None:
                run = int(self._metric(text, 'vllm:num_requests_running'))
                prompt = self._metric(
                    text, 'vllm:prompt_tokens_by_source_total',
                    'source="local_compute"')
                gen   = self._metric(text, 'vllm:generation_tokens_total')
                pr    = self._metric(
                    text, 'vllm:prompt_tokens_by_source_total',
                    'source="local_cache_hit"')
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
                    with self._lock:
                        self._history.append(
                            (now, prompt, gen, acc, draft, pp_computed))
                        while now - self._history[0][0] > VLLM_DELTA_WINDOW:
                            self._history.pop(0)
                        base, top = self._history[0], self._history[-1]
                        dt = top[0] - base[0]
                        if dt > 0:
                            self._tg_tps = max(0, (top[2] - base[2]) / dt)
                            self._pp_tps = max(0, (top[5] - base[5]) / dt)
                            d_draft = top[4] - base[4]
                            if d_draft > 0:
                                self._acc = (top[3] - base[3]) / d_draft
                        self._prefilling = self._pp_tps > 5
                        # Reuse: KV growing but no tokens being computed
                        self._reusing = kv > self._prev_kv and not self._prefilling
                        self._prev_kv = kv
                        self._acc_cum = acc / draft if draft > 0 else 0.0
                        self._kv_pct = kv * 100
                        self._reqs = run
                        self._pc_pct = (
                            pc_h / pc_q * 100 if pc_q > 0 else 0.0)
                        self._raw_prompt = prompt
                        self._raw_pr = pr
                else:
                    with self._lock:
                        self._history.append((now, prompt, gen, 0.0, 0.0, 0.0))
                        while now - self._history[0][0] > VLLM_DELTA_WINDOW:
                            self._history.pop(0)
                        self._prev_kv = 0.0
                        self._reqs = 0
                        self._pp_tps = self._tg_tps = 0.0
                        self._reusing = self._prefilling = False
            elapsed = time.monotonic() - t0
            time.sleep(max(0, (0.1 if active else 0.5) - elapsed))

    def values(self):
        with self._lock:
            return (self._pp_tps, self._tg_tps,
                    self._kv_pct, self._reqs,
                    self._acc, self._acc_cum, self._pc_pct,
                    self._reusing, self._prefilling,
                    self._raw_prompt, self._raw_pr)


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


def fan_color(db_rel):
    if db_rel < 1:
        return frac_color(db_rel)              # 20% grey → white
    if db_rel < 2:
        return _fg(_lerp((255, 255, 255), (255, 220, 0), db_rel - 1))
    if db_rel < 3:
        return _fg(_lerp((255, 220, 0), (255, 120, 0), db_rel - 2))
    if db_rel < 4:
        return _fg(_lerp((255, 120, 0), (255, 0, 0), db_rel - 3))
    return _fg((255, 0, 0))


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
    r = f'{frac_color(r / VRAM_GB)}{r:3d}G{RESET}'
    u = int(pynvml.nvmlDeviceGetUtilizationRates(h).gpu)
    u = f'{frac_color(u / 100)}{u:3d}%{RESET}'
    t = int(pynvml.nvmlDeviceGetTemperature(h, pynvml.NVML_TEMPERATURE_GPU))
    t = f'{temp_color(t)}{t:3d}°{RESET}'
    f_pct = int(pynvml.nvmlDeviceGetFanSpeed(h))
    db_rel = pct_to_db_rel(profile_name, f_pct)
    f = f'{fan_color(db_rel)}{f_pct:3d}%{RESET}'
    w_max = pynvml.nvmlDeviceGetPowerManagementLimit(h)
    w = pynvml.nvmlDeviceGetPowerUsage(h)
    w = f'{frac_color(w / w_max)}{int(w / 1000):3d}W{RESET}'
    return r, u, t, f, w


def get_lines(nct, gpu0, gpu1, vllm):
    sensors_data = chip_data(nct)
    ct = int(sensors_data["CPU"])
    ct = f'{temp_color(ct)}{ct:3d}°{RESET}'
    st = int(sensors_data["System"])
    st = f'{temp_color(st)}{st:3d}°{RESET}'
    cp = int(psutil.cpu_percent())
    cp = f'{frac_color(cp / 100)}{cp:3d}%{RESET}'

    top_fans, top_tx = fan(sensors_data, 'System Fan #1')
    bot_f, bot_tx = fan(sensors_data, 'System Fan #4', width=7)
    tf, tf_txt = fan(sensors_data, 'System Fan #5', vert=False)
    bf, bf_txt = fan(sensors_data, 'System Fan #6', vert=False)
    bk, bk_txt = fan(sensors_data, 'System Fan #2', vert=False)
    tf = f' {tf}'
    bf = f' {bf}'
    bk, bk_ = f' {bk}', f' {bk}   '
    _, cpu_tx = fan(sensors_data, 'CPU Fan')

    r0, u0, t0, f0, w0 = gpu(gpu0, 'gpu0')
    r1, u1, t1, f1, w1 = gpu(gpu1, 'gpu1')
    (pp_tps, tg_tps, kv_pct, reqs, acc, acc_cum, pc_pct,
     reusing, prefilling, raw_prompt, raw_pr) = vllm.values()
    active = reqs > 0

    if active and reusing:
        pp_col = f'{frac_color(0)}REUSE KV{RESET}   '
        top_fill = f'─{frac_color(0)}↓─↓{RESET}──────'
    elif active and prefilling:
        c = frac_color(pp_tps / VLLM_PP_TPS_MAX)
        pp_col = f' {c}{int(pp_tps):4d} PP{RESET}  '
        top_fill = '─↓─↓──────'
    else:
        #pp_col = '         '
        c = frac_color(0)
        pp_col = f'  {c}{int(pp_tps):4d} pp{RESET} '
        top_fill = '──────────'
    if active:
        kv_fill = f'{frac_color(kv_pct/100)}{int(kv_pct):3d}%{RESET}─────'
        if reqs > 1:
            reqs_col = _fg((255, 0, 0)) if reqs > 2 else _fg((255, 220, 0))
            bot_fill = f'─↓{reqs_col}{reqs}{RESET}↓──────'
        else:
            bot_fill = '──────────'
        _vllm1 = (f'{frac_color(tg_tps/VLLM_TG_TPS_MAX)}'
                  f'{int(tg_tps):5d} TG{RESET}')
        vllm2 = f'{frac_color(acc)}{int(acc*100):3d}% ac{RESET}'
    else:
        kv_fill = '─────────'
        bot_fill = '──────────'
        _vllm1 = f'{frac_color(0)}{int(pc_pct):4d}% pc{RESET}'
        vllm2 = f'{frac_color(0)}{int(acc_cum*100):3d}% ac{RESET}'

    return [
        f'          ┌──{ top_fans}─{ top_fans}──┐',
        f'          │                {top_tx}  {tf}',
        f'          │     ┌────────┐           {tf} {tf_txt}',
        f'         {bk_}  │{cp}{ct}│ {cpu_tx}  {tf}',
        f' {bk_txt}{bk_}  └────────┘            │',
        f'         {bk}{pp_col}{st}            {bf}',
        f'          │┌{top_fill}──────────────┐{bf}',
        f'          ││{r0} {u0}{t0} {f0} {w0} │{bf}',
        f'          │├{kv_fill}───────────────┤ │ {bf_txt}',
        f'          ││{r1} {u1}{t1} {f1} {w1} │{bf}',
        f'          │└{bot_fill}──────────────┘{bf}',
        f'          │{_vllm1}{vllm2} {bot_tx}  {bf}',
        f'          └─────────────────{bot_f}───┘',
        f'  lc={int(raw_prompt)} pr={int(raw_pr)} kv={kv_pct:.1f}%',
    ]


pynvml.nvmlInit()
try:
    nct = next(c for c in sensors.get_detected_chips()
               if 'nct6687' in str(c))
    nct_hwmon = find_hwmon('nct6687')
    gpu0 = pynvml.nvmlDeviceGetHandleByIndex(0)
    gpu1 = pynvml.nvmlDeviceGetHandleByIndex(1)
    vllm = VllmMonitor()
    once = '-1' in sys.argv
    try:
        while True:
            lines = get_lines(nct, gpu0, gpu1, vllm)
            print('\n'.join(lines))
            if once:
                break
            time.sleep(0.2)
            print(f'\033[{len(lines)}A', end='')
    except KeyboardInterrupt:
        pass
finally:
    pynvml.nvmlShutdown()
