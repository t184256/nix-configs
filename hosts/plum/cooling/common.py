from pathlib import Path
from acoustic_profile import PROFILES

RESET = '\033[0m'


def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _fg(rgb):
    r, g, b = rgb
    return f'\033[38;2;{r};{g};{b}m'


db_baseline = min(v for p in PROFILES.values() for v in p)
K = len(next(iter(PROFILES.values()))) - 1


def profile_db(profile, pct):
    i = pct * K / 100
    lo, hi = int(i), min(int(i) + 1, K)
    if lo == hi:
        return profile[lo]
    return profile[lo] + (profile[hi] - profile[lo]) * (i - lo)


def pct_to_db_rel(name, pct):
    return profile_db(PROFILES[name], pct) - db_baseline


def pwm_to_db_rel(name, pwm):
    return pct_to_db_rel(name, pwm * 100 / 255)


def color_db(db_rel):
    if db_rel < 3:
        t = max(0.0, db_rel) / 3
        return _fg(_lerp((80, 80, 80), (200, 200, 200), t))
    if db_rel <= 6:
        return _fg(_lerp((255, 220, 0), (255, 120, 0), (db_rel - 3) / 3))
    if db_rel <= 9:
        return _fg(_lerp((255, 120, 0), (255, 0, 0), (db_rel - 6) / 3))
    return _fg((255, 0, 0))


def find_hwmon(name):
    for p in Path('/sys/class/hwmon').iterdir():
        try:
            if (p / 'name').read_text().strip() == name:
                return p
        except OSError:
            pass
    raise RuntimeError(f'{name} hwmon not found')
