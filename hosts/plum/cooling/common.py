import ctypes
import functools
from pathlib import Path
from acoustic_profile import PROFILES_USB, PROFILES_ANALOG
import pynvml

RESET = '\033[0m'

# Hotspot temperature via NvAPI (NVML doesn't expose it)
# Function IDs and struct layout are taken from from LACT
@functools.cache
def _nvapi():
    INIT  = 0x0150e828
    ENUM  = 0xe5ac921f
    BUS   = 0x1be0b8e5
    THERM = 0x65fe3aad

    class Thermals(ctypes.Structure):
        _fields_ = [('version', ctypes.c_uint32),
                    ('mask',    ctypes.c_int32),
                    ('values',  ctypes.c_int32 * 40)]
    TV = ctypes.sizeof(Thermals) | (2 << 16)

    lib = ctypes.CDLL('/run/opengl-driver/lib/libnvidia-api.so.1')
    qi  = lib.nvapi_QueryInterface
    qi.restype, qi.argtypes = ctypes.c_void_p, [ctypes.c_uint32]

    def fn(id, *t):
        return ctypes.CFUNCTYPE(ctypes.c_int, *t)(qi(id))

    fn(INIT)()

    Arr = ctypes.c_void_p * 64
    cnt, arr = ctypes.c_uint32(0), Arr()
    fn(ENUM, ctypes.POINTER(Arr), ctypes.POINTER(ctypes.c_uint32))(
        ctypes.byref(arr), ctypes.byref(cnt))

    get_bus = fn(BUS,   ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32))
    therm   = fn(THERM, ctypes.c_void_p, ctypes.POINTER(Thermals))

    gpus = {}
    for i in range(cnt.value):
        h, bid = arr[i], ctypes.c_uint32(0)
        get_bus(h, ctypes.byref(bid))
        s = Thermals(version=TV, mask=1)
        therm(h, ctypes.byref(s))
        for bit in range(32):
            s.mask = 1 << bit
            if therm(h, ctypes.byref(s)) != 0:
                s.mask -= 1
                break
        gpus[bid.value] = (h, s.mask)

    def hotspot(bus):
        h, mask = gpus[bus]
        s = Thermals(version=TV, mask=mask)
        therm(h, ctypes.byref(s))
        v = s.values[9] // 256
        return v if 0 < v < 255 else None

    return hotspot


def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _fg(rgb):
    r, g, b = rgb
    return f'\033[38;2;{r};{g};{b}m'


_ALL_PROFILES = [PROFILES_USB, PROFILES_ANALOG]
_db_bases = [min(min(prof) for prof in profs.values())
             for profs in _ALL_PROFILES]
K = len(PROFILES_USB['cpu0']) - 1


def profile_db(profile, pct):
    i = pct * K / 100
    lo, hi = int(i), min(int(i) + 1, K)
    if lo == hi:
        return profile[lo]
    return profile[lo] + (profile[hi] - profile[lo]) * (i - lo)


def pct_to_db_rel(name, pct):
    return max(profile_db(profs[name], pct) - base
               for profs, base in zip(_ALL_PROFILES, _db_bases))


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


def _pci_bus_number(h):
    pci = pynvml.nvmlDeviceGetPciInfo(h)
    raw = pci.busId
    if isinstance(raw, bytes):
        raw = raw.decode()
    return int(raw.rstrip('\x00').split(':')[1], 16)


def gpu_max_temp(h):
    t  = pynvml.nvmlDeviceGetTemperature(h, pynvml.NVML_TEMPERATURE_GPU)
    hs = _nvapi()(_pci_bus_number(h))
    return max(t, hs) if hs is not None else t


def find_hwmon(name):
    for p in Path('/sys/class/hwmon').iterdir():
        try:
            if (p / 'name').read_text().strip() == name:
                return p
        except OSError:
            pass
    raise RuntimeError(f'{name} hwmon not found')
