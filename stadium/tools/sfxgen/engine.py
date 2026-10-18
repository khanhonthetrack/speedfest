"""Our own engine sound for the Stadium car, synthesized (no recordings): a high-revving
four-cylinder racing engine built from its firing pulses (2 a revolution: at TMNF's 11000 rpm
limit the fundamental is 367 Hz, where TMNF's own engine tops out). One loop per layer, each rendered at the layer's base
rpm; the game plays them pitched by rpm / base rpm and crossfaded by rpm and throttle in the way
TMNF's engine does (audio/tm_car_audio.gd), so at any rpm every layer has the same fundamental.

Model, per layer (rpm, load):
- the crank turns at rpm / 60 Hz with a slow random wander (a real engine never holds a pitch);
  4 cylinders fire twice a revolution, each with its own strength (+-12%: the half-order
  components that give an engine its texture) and a tiny timing jitter;
- each firing is an exhaust pressure pulse: a sharp rise and a ring at the exhaust's resonance,
  plus a low thump; the pulses run through a short pipe (a comb filter) and the body's low-pass;
- under load the intake roars (band-passed noise opened by each firing) and the pulses are hard
  and saturated; off load (coasting, engine braking) the pulses are weak, the valvetrain and gear
  whine come through, and the exhaust crackles now and then;
- a seamless loop: rendered long, its end crossfaded into its start.
Writes stadium/audio/sfx/engine_<layer>.wav (mono 16-bit 44.1 kHz) and their Godot imports (loop),
and shift.wav: a gear change's clunk (a dull knock and a short metallic tick).
usage: python3 stadium/tools/sfxgen/engine.py   (numpy, scipy)"""
import os, wave, math
import numpy as np
from scipy import signal

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'audio', 'sfx'))

## layer: (base rpm, load 0..1, seconds, seed). The game's TmCarAudio.LAYERS uses the same rpms.
LAYERS = {
    'idle': (1200.0, 0.35, 2.0, 1),
    'low': (3600.0, 1.0, 1.6, 2),
    'mid': (6600.0, 1.0, 1.4, 3),
    'high': (9600.0, 1.0, 1.4, 4),
    'coast_low': (3600.0, 0.0, 1.6, 5),
    'coast_high': (9000.0, 0.0, 1.4, 6),
}


def wander(n, rng, depth, rate_hz):
    """A slow random multiplier around 1 (smooth noise)."""
    k = max(int(SR / rate_hz), 1)
    pts = rng.standard_normal(n // k + 3)
    x = np.interp(np.arange(n) / k, np.arange(len(pts)), pts)
    x = signal.lfilter([1 - 0.995], [1, -0.995], x)
    x /= max(np.std(x), 1e-6)
    return 1.0 + depth * x


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], 'band')
    return signal.lfilter(b, a, x)


def lowpass(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), 'low')
    return signal.lfilter(b, a, x)


def highpass(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), 'high')
    return signal.lfilter(b, a, x)


def render(rpm, load, seconds, seed):
    rng = np.random.default_rng(seed)
    n = int((seconds + 0.25) * SR)
    t = np.arange(n) / SR
    f_rev = rpm / 60.0 * wander(n, rng, 0.004, 6.0)
    crank = np.cumsum(2 * np.pi * f_rev / SR)          # radians
    pulses_per_rev = 2
    # firing events: the crank crossing each cylinder's angle
    cyl = 4
    amp = 1.0 + 0.12 * rng.standard_normal(cyl)
    events = np.zeros(n)
    fire_angle = crank * pulses_per_rev / (2 * np.pi)   # counts firings
    idx = np.nonzero(np.diff(np.floor(fire_angle)) > 0)[0] + 1
    for j, i in enumerate(idx):
        jit = int(rng.normal(0, 0.00004 * SR))
        k = min(max(i + jit, 0), n - 1)
        events[k] += amp[j % cyl] * (1.0 + 0.05 * rng.standard_normal())
    # the exhaust pulse: a ring at the pipe's resonance, a thump below it
    f_ring = 260.0 + 0.02 * rpm
    tau = np.arange(int(0.012 * SR)) / SR
    ring = np.exp(-tau / (0.0016 + 0.0012 * load)) * np.sin(2 * np.pi * f_ring * tau)
    thump = np.exp(-tau / 0.005) * np.sin(2 * np.pi * (70.0 + 0.008 * rpm) * tau)
    edge = np.exp(-tau / 0.0004)
    kern = (0.5 + 0.9 * load) * ring + (0.9 + 0.6 * load) * thump + 0.15 * edge
    exhaust = signal.fftconvolve(events, kern)[:n]
    # a short pipe: comb filter (delay ~ 2 x 0.9 m)
    d = int(SR * 2 * 0.9 / 343.0)
    exhaust = exhaust + 0.45 * np.concatenate([np.zeros(d), exhaust[:-d]])
    # the intake roar, opened by each firing, under load
    env = signal.fftconvolve(events, np.exp(-tau / 0.003))[:n]
    roar = bandpass(rng.standard_normal(n), 700.0, 2200.0) * env * (0.03 + 0.12 * load)
    # mechanical whine: valvetrain and gearbox orders (stronger off load, relatively)
    whine = (0.06 * np.sin(crank * 6.5) + 0.04 * np.sin(crank * 11.0 + 1.3) + 0.025 * np.sin(crank * 17.5 + 0.4))
    whine *= (0.5 + 0.8 * (1 - load)) * (0.6 + rpm / 11000.0)
    # off load: crackles in the exhaust
    crack = np.zeros(n)
    if load < 0.3:
        for i in idx:
            if rng.random() < 0.04:
                L = int(0.004 * SR)
                if i + L < n:
                    crack[i:i + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / (0.0012 * SR)) * 0.8
        crack = highpass(crack, 800.0)
    x = exhaust + roar + whine + crack
    # body and muffler: low-pass, a little presence, saturation under load
    x = lowpass(x, 2400.0 + 1400.0 * load, 3)
    x = x + 0.08 * bandpass(x, 1200.0, 2600.0)
    x = highpass(x, 35.0)
    x /= max(np.percentile(np.abs(x), 99.5), 1e-6)
    drive = 1.2 + 1.6 * load
    x = np.tanh(drive * x) / np.tanh(drive)
    # a seamless loop: crossfade the extra tail into the start
    L = int(seconds * SR)
    fade = n - L
    out = x[:L].copy()
    w = np.linspace(0.0, 1.0, fade)
    out[:fade] = out[:fade] * w + x[L:L + fade] * (1 - w)
    out *= 0.7 / max(np.sqrt(np.mean(out ** 2)) * 3.0, 1e-6)   # rms ~ -13 dBFS
    return np.clip(out, -1.0, 1.0)


def shift_clunk():
    rng = np.random.default_rng(9)
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    knock = np.sin(2 * np.pi * 95.0 * t) * np.exp(-t / 0.018)
    tick = bandpass(rng.standard_normal(n), 2500.0, 6000.0) * np.exp(-t / 0.004)
    x = knock + 0.35 * tick
    return 0.6 * x / np.max(np.abs(x))


def write_wav(path, x, loop=True):
    data = (np.clip(x, -1, 1) * 32000.0).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    imp = path + '.import'
    if not os.path.exists(imp):
        with open(imp, 'w') as f:
            f.write('[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\n'
                    'force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\n'
                    'edit/trim=false\nedit/normalize=false\nedit/loop_mode=%d\nedit/loop_begin=0\nedit/loop_end=-1\n'
                    'compress/mode=0\n' % (2 if loop else 0))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, (rpm, load, sec, seed) in LAYERS.items():
        x = render(rpm, load, sec, seed)
        p = os.path.join(OUT, 'engine_%s.wav' % name)
        write_wav(p, x)
        S = np.abs(np.fft.rfft(x * np.hanning(len(x))))
        f = np.fft.rfftfreq(len(x), 1 / SR)
        print('%-11s rpm %5.0f load %.1f  rms %.3f  centroid %5.0f Hz' % (name, rpm, load, np.sqrt(np.mean(x ** 2)), (S * f).sum() / S.sum()))
    write_wav(os.path.join(OUT, 'shift.wav'), shift_clunk(), loop=False)


def turbo_whoosh():
    """The turbo pad: a rush of air sweeping up (band-passed noise, 300 -> 3000 Hz) with a
    turbine's whine rising over it, a quick attack, a long tail."""
    rng = np.random.default_rng(11)
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    seg = 1024
    for i in range(0, n, seg):
        f = 300.0 + 2700.0 * min(i / n * 1.6, 1.0)
        b, a = signal.butter(2, [f * 0.6 / (SR / 2), min(f * 1.6, SR / 2 - 100) / (SR / 2)], 'band')
        out[i:i + seg] = signal.lfilter(b, a, noise[max(i - 2048, 0):i + seg])[-len(out[i:i + seg]):]
    whine_f = 900.0 + 1700.0 * (1 - np.exp(-t / 0.35))
    whine = np.sin(np.cumsum(2 * np.pi * whine_f / SR)) * 0.25
    env = (1 - np.exp(-t / 0.02)) * np.exp(-t / 0.55)
    x = (out / np.max(np.abs(out)) + whine) * env
    return 0.7 * x / np.max(np.abs(x))


if __name__ == '__main__':
    write_wav(os.path.join(OUT, 'turbo.wav'), turbo_whoosh(), loop=False)
    print('turbo.wav')
