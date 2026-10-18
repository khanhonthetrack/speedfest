"""An offline preview of the engine as the game plays it (TmCarAudio): a standing start on full
throttle with TMNF's acceleration (16 m/s2 to 101 km/h, 11 to 201, 7 to 401, 5.5 above), the six
gears, the layers pitched and crossfaded the same way; then a lift off to coast. For listening,
not shipped. usage: python3 preview.py OUT.wav"""
import sys, os, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from engine import SR, OUT, write_wav

GEAR_TOP = [85.0, 110.0, 160.0, 220.0, 370.0, 400.0]
SHIFT_UP = [0.0, 0.95, 0.9, 0.95, 0.95, 1.0]
SHIFT_DOWN = [0.0, 0.0, 0.5, 0.57, 0.55, 0.6]
RPM_IDLE, RPM_MAX = 1200.0, 11000.0
LAYERS = [  # as TmCarAudio.LAYERS
    ("engine_idle", 1200.0, 0.85, (0.0, 0.0), (1700.0, 3800.0), True),
    ("engine_low", 3600.0, 0.6, (500.0, 1600.0), (5200.0, 8000.0), True),
    ("engine_mid", 6600.0, 0.75, (3600.0, 6000.0), (8200.0, 12000.0), True),
    ("engine_high", 9600.0, 0.9, (6600.0, 9200.0), (1e9, 1e9), True),
    ("engine_coast_low", 3600.0, 0.8, (0.0, 600.0), (6500.0, 12000.0), False),
    ("engine_coast_high", 9000.0, 0.55, (5000.0, 7500.0), (1e9, 1e9), False),
]


def load(name):
    with wave.open(os.path.join(OUT, name + '.wav')) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def main(path):
    dt = 1.0 / 200.0
    v = 0.0
    gear = 1
    rpm = RPM_IDLE
    thr = 0.0
    ticks = []
    t = 0.0
    shift_until = -1.0
    while t < 27.0:
        gas = 1.0 if 0.6 < t < 22.0 else 0.0
        if gas > 0:
            kmh = v * 3.6
            a = 16.0 if kmh < 101 else 11.0 if kmh < 201 else 7.0 if kmh < 401 else 5.5
            v += a * dt
        else:
            v = max(0.0, v - (1.0 + 0.3 * v) * dt)
        kmh = v * 3.6
        thr += (gas - thr) * (1 - np.exp(-dt * 8.0))
        up = False
        while gear < 6 and kmh > SHIFT_UP[gear] * GEAR_TOP[gear - 1]:
            gear += 1
            up = True
        while gear > 1 and kmh < SHIFT_DOWN[gear - 1] * GEAR_TOP[gear - 2]:
            gear -= 1
        if up and thr > 0.5:
            shift_until = t + 0.07
        target = min(max(kmh / GEAR_TOP[gear - 1] * RPM_MAX, RPM_IDLE), RPM_MAX)
        if gas > 0.5 and target >= RPM_MAX * 0.97:
            target -= 260.0 * (0.5 + 0.5 * np.sin(t * 1000 * 0.11))
        step = 26000.0 * dt
        rpm = min(max(target, rpm - step * 1.6), rpm + step)
        ticks.append((rpm, thr, 0.45 if t < shift_until else 1.0))
        t += dt
    ticks = np.array(ticks)
    n = int(len(ticks) * dt * SR)
    ts = np.arange(n) / SR
    rpm_s = np.interp(ts, np.arange(len(ticks)) * dt, ticks[:, 0])
    thr_s = np.interp(ts, np.arange(len(ticks)) * dt, ticks[:, 1])
    dip_s = np.interp(ts, np.arange(len(ticks)) * dt, ticks[:, 2])
    out = np.zeros(n)
    for name, base, vol, fin, fout, on in LAYERS:
        x = load(name)
        pos = np.cumsum(rpm_s / base) % len(x)
        i0 = pos.astype(int)
        frac = pos - i0
        sig = x[i0] * (1 - frac) + x[(i0 + 1) % len(x)] * frac
        w = np.full(n, vol)
        if fin[1] > fin[0]:
            w *= smoothstep(fin[0], fin[1], rpm_s)
        if fout[1] > fout[0] and fout[0] < 1e8:
            w *= 1 - smoothstep(fout[0], fout[1], rpm_s)
        w *= thr_s * dip_s if on else (1 - thr_s) * 0.85
        out += sig * w * 0.8
    out /= max(np.max(np.abs(out)), 1e-6) / 0.8
    write_wav(path, out, loop=False)
    if os.path.exists(path + '.import'):
        os.remove(path + '.import')
    print('preview', path, '%.1f s' % (n / SR))


if __name__ == '__main__':
    main(sys.argv[1])
