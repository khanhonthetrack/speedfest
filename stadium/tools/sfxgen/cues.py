"""Our own race and menu cues, synthesized (no recordings) to sound like TMNF's (M10-5): each cue's
length, loudness envelope and octave spectrum follow what tools/research/tmnf/sound_survey.py
measured on TMNF's own (numbers only, below; TMNF's files stay outside the repo).
- beep (3, 2, 1): a clean tone at 756 Hz (its octave at -26 dB), 1.1 s, struck and fading about
  10 dB a second;
- go: the crowd roaring as the race starts, 1.4 s, as loud in the lows as in the voices' range;
- checkpoint: a swoosh, a low thump under bright air, its tail fading over 1.5 s;
- cheer / cheer_big: the crowd cheering at the finish as TMNF does by medal: a cheer with some
  applause for silver and bronze, a big one with applause and whistles for gold and author;
- hit (a wall): a broadband crash with a rattle, 0.7 s; land (after a jump): a heavy thump on the
  road, 1.1 s;
- move (menu focus): a 50 ms blip around 750 Hz; click (menu confirm): a 0.1 s "tock" at 260 Hz with
  its harmonics (TMNF's Forever menus' own effects, not the older interface set's);
- wind: a gusty air loop for speed, brighter than a plain rumble (its band peaks at 500-1000 Hz).
Writes stadium/audio/sfx/<cue>.ogg (mono, Vorbis via ffmpeg) and prints each cue's octave bands
next to the target. usage: python3 stadium/tools/sfxgen/cues.py   (numpy, scipy, ffmpeg)"""
import os, subprocess, tempfile, wave
import numpy as np
from scipy import signal

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'audio', 'sfx'))
BANDS = [63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

## The targets, measured on TMNF's cues: octave bands (dB from the strongest), envelope (dB every
## 50 ms from the start), length (s).
TARGET = {
    'go': ([0, 0, 0, -1, -2, -4, -12, -24, -42],
           [-7, -3, -4, -8, -2, -2, -5, -6, -8, -8, -10, -7, -12, -9, -10, -11, -10, -13, -17, -18, -22, -25, -30, -31,
            -37, -37, -40, -41, -44], 1.41),
    'checkpoint': ([0, -5, -11, -14, -13, -7, 0, 0, -5],
                   [-61, -11, -1, -10, -13, -13, -23, -23, -20, -34, -36, -36, -37, -35, -36, -36, -35, -34, -37, -42,
                    -41, -43, -42, -45, -46, -48, -48, -50, -50, -50], 1.5),
    'cheer_big': ([0, 0, -4, -6, -12, -15, -6, -7, -30],
               [-40, -34, -28, -26, -12, -6, -2, -7, -12, -7, -9, -9, -11, -11, -20, -12, -11, -19, -15, -17, -15, -15,
                -15, -21, -16, -18, -17, -22, -27, -27, -31, -30, -32, -41, -55, -56], 1.8),
    'cheer': ([0, 0, -4, -6, -12, -8, -12, -10, -31],
               [-37, -31, -25, -22, -4, -2, 0, -7, -11, -10, -10, -11, -13, -14, -12, -12, -10, -17, -9, -16, -17, -13,
                -13, -15, -13, -15, -22, -15, -22, -23, -25, -28, -35, -40, -56, -62], 1.8),
    'hit': ([-7, -3, -3, -2, -3, -2, 0, -3, -17], [-10, -2, -2, -2, -1, -3, -3, -2, -4, -2, -6, -5, -8, -17, -34], 0.725),
    'land': ([0, -2, 0, -3, -3, 0, -7, -13, -30],
             [-30, -6, -6, -1, -1, -4, -11, -11, -12, -16, -17, -20, -29, -32, -26, -23, -30, -27, -36, -39, -45, -35], 1.09),
    'click': ([-62, -44, 0, -3, -6, -17, -28, -41, -60], [0, -3], 0.108),
    'move': ([-43, -24, -14, 0, 0, -10, -17, -27, -60], [-6], 0.051),
    'wind': ([-44, -10, -4, 0, -2, -10, -22, -31, -38], [], 4.0),
}


def shaped_noise(n, octaves_db, rng):
    """White noise given an octave spectrum (dB per band of BANDS, interpolated on log frequency)."""
    x = rng.standard_normal(n)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    lf = np.log2(np.maximum(f, 20.0))
    # the target is a band's energy; a band an octave wide holds twice the bins of the one below,
    # so the per-bin level falls 3 dB an octave on top of the target
    per_bin = np.array(octaves_db, float) - 10 * np.log10(np.array(BANDS, float) / BANDS[0])
    g_db = np.interp(lf, np.log2(BANDS), per_bin, left=per_bin[0] - 30, right=per_bin[-1] - 20)
    X *= 10 ** (g_db / 20.0)
    y = np.fft.irfft(X, n)
    return y / (np.max(np.abs(y)) + 1e-12)


def env_from(db_steps, n, step_s=0.05):
    """A smooth gain curve through the envelope's points (dB every step_s)."""
    t = np.arange(n) / SR
    pts = np.arange(len(db_steps)) * step_s + step_s * 0.5
    g = np.interp(t, pts, np.array(db_steps, float), left=db_steps[0], right=-80.0)
    return 10 ** (g / 20.0)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype='band', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype='low', fs=SR, output='sos'), x)


def fade(x, ms_in=2.0, ms_out=20.0):
    a, b = int(SR * ms_in / 1000), int(SR * ms_out / 1000)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def norm(x, peak=0.89):
    return x * (peak / (np.max(np.abs(x)) + 1e-12))


def beep():
    n = int(SR * 1.11)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 756 * t) + 10 ** (-26 / 20) * np.sin(2 * np.pi * 1512 * t + 0.3)
    g = 10 ** ((-1.0 - 10.0 * t) / 20)              # -1 dB falling to -12 dB at the end
    return norm(fade(x * g, 8, 25), 0.85)


def shouts(n, rng, count, start_s, len_s, lo_hz, hi_hz):
    """Voices shouting: a sawtooth at a voice's pitch, wavering, through two vowel formants."""
    out = np.zeros(n)
    formants = [(700, 1150), (550, 1700), (450, 850), (650, 1050), (400, 2000)]
    for _ in range(count):
        st = int(SR * rng.uniform(*start_s))
        ln = int(SR * rng.uniform(*len_s))
        if st >= n:
            continue
        ln = min(ln, n - st)
        t = np.arange(ln) / SR
        f0 = rng.uniform(lo_hz, hi_hz) * (1 + 0.06 * np.sin(2 * np.pi * rng.uniform(4, 7) * t)
                                         + 0.15 * (t / max(t[-1], 1e-3)) * rng.uniform(-1, 1))
        ph = np.cumsum(f0) / SR
        saw = 2 * (ph % 1.0) - 1
        f1, f2 = formants[rng.integers(len(formants))]
        v = bandpass(saw, f1 * 0.8, f1 * 1.25) + 0.6 * bandpass(saw, f2 * 0.85, f2 * 1.2)
        e = np.minimum(1, t / rng.uniform(0.04, 0.15)) * np.minimum(1, (t[-1] - t) / rng.uniform(0.1, 0.4) + 1e-3)
        out[st:st + ln] += v * e * rng.uniform(0.3, 1.0)
    return out


def claps(n, rng, rate_hz, start_s, end_s):
    """Applause: many short bright bursts at random times."""
    out = np.zeros(n)
    k = int(rate_hz * (end_s - start_s))
    burst = int(SR * 0.012)
    for _ in range(k):
        st = int(SR * rng.uniform(start_s, end_s))
        if st + burst >= n:
            continue
        b = rng.standard_normal(burst) * np.exp(-np.arange(burst) / (burst * 0.25))
        out[st:st + burst] += b * rng.uniform(0.2, 1.0)
    return bandpass(out, 900, 9000)


def whistles(n, rng, count, start_s):
    """Finger whistles: a pure tone gliding up then down."""
    out = np.zeros(n)
    for _ in range(count):
        st = int(SR * rng.uniform(*start_s))
        ln = int(SR * rng.uniform(0.35, 0.9))
        ln = min(ln, n - st)
        if ln <= 0:
            continue
        t = np.arange(ln) / SR
        u = t / t[-1]
        f = rng.uniform(2200, 3400) * (1 + 0.18 * np.sin(np.pi * u) - 0.05 * u)
        x = np.sin(2 * np.pi * np.cumsum(f) / SR)
        e = np.sin(np.pi * np.clip(u * 1.1, 0, 1)) ** 0.7
        out[st:st + ln] += x * e * rng.uniform(0.4, 1.0)
    return out


def crowd(name, seed, voices, clap_rate, whistle_count):
    octaves, env, length = TARGET[name]
    rng = np.random.default_rng(seed)
    n = int(SR * length)
    bed = shaped_noise(n, octaves, rng)
    v = shouts(n, rng, voices, (0.0, 0.25), (0.5, length * 0.85), 110, 330)
    v = v / (np.max(np.abs(v)) + 1e-12)
    x = bed * 0.75 + v * 0.55
    if clap_rate:
        c = claps(n, rng, clap_rate, 0.2, length * 0.8)
        x += 0.45 * c / (np.max(np.abs(c)) + 1e-12)
    if whistle_count:
        w = whistles(n, rng, whistle_count, (0.25, length * 0.6))
        x += 0.18 * w / (np.max(np.abs(w)) + 1e-12)
    # a slow flutter, the crowd breathing
    t = np.arange(n) / SR
    x *= 1 + 0.12 * np.sin(2 * np.pi * 3.1 * t) * np.sin(2 * np.pi * 0.7 * t + 1)
    return norm(fade(x * env_from(env, n), 3, 60))


def checkpoint():
    octaves, env, length = TARGET['checkpoint']
    rng = np.random.default_rng(11)
    n = int(SR * length)
    air = shaped_noise(n, octaves, rng)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (58 + 30 * np.exp(-t / 0.03)) * t) * np.exp(-np.maximum(t - 0.08, 0) / 0.09)
    thump *= np.minimum(1, t / 0.06)
    x = air * env_from(env, n) + 0.7 * thump * (t < 0.6)
    # the swoosh's sweep: the air's centre rising through the burst
    return norm(fade(x, 2, 40))


def crash(name, seed, rattles):
    """An impact: shaped noise under the envelope, a low thump at the start and loose parts
    rattling (short bright bursts thinning out)."""
    octaves, env, length = TARGET[name]
    rng = np.random.default_rng(seed)
    n = int(SR * length)
    t = np.arange(n) / SR
    x = shaped_noise(n, octaves, rng) * env_from(env, n)
    thump = np.sin(2 * np.pi * (55 + 60 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.08) * np.minimum(1, t / 0.004)
    x += 0.8 * thump
    burst = int(SR * 0.006)
    for _ in range(rattles):
        st = int(SR * min(rng.exponential(0.12), length * 0.8))
        if st + burst < n:
            x[st:st + burst] += rng.standard_normal(burst) * np.exp(-np.arange(burst) / (burst * 0.3)) * rng.uniform(0.2, 0.8) \
                * np.exp(-st / SR / 0.25)
    return norm(fade(x, 0.5, 30))


def move():
    """A short blip: three close partials (760, 624, 487 Hz), up in 30 ms and gone by 50 ms."""
    n = int(SR * TARGET['move'][2])
    t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((760, 1.0), (624, 0.7), (487, 0.45)))
    x = x + 0.15 * np.random.default_rng(9).standard_normal(n)     # a little air, for its top
    e = np.sin(np.pi * np.clip(t / t[-1], 0, 1)) ** 1.5
    return norm(x * e, 0.7)


def click():
    """A tock: 260 Hz with its harmonics, struck and dying in 0.1 s."""
    n = int(SR * TARGET['click'][2])
    t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((260, 1.0), (521, 0.63), (790, 0.35), (1050, 0.15)))
    x *= np.exp(-t / 0.035) * np.minimum(1, t / 0.0015)
    return norm(fade(x, 0, 5), 0.8)


def wind():
    octaves, _, length = TARGET['wind']
    rng = np.random.default_rng(7)
    n = int(SR * length)
    x = shaped_noise(n, octaves, rng)
    t = np.arange(n) / SR
    # gusts: slow loudness and brightness changes, whole cycles over the loop so it joins seamlessly
    g = 1 + 0.25 * np.sin(2 * np.pi * t / length * 3 + 0.5) + 0.12 * np.sin(2 * np.pi * t / length * 7)
    bright = bandpass(x, 900, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * t / length * 2))
    x = x * g + 0.35 * bright
    return norm(x, 0.5)          # a loop: no fades (FFT-shaped noise is periodic: its end meets its start)


def match_octaves(x, target, iters=4):
    """A static EQ that pulls the sound's octave bands onto the target (a few passes)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    lf = np.log2(np.maximum(f, 20.0))
    for _ in range(iters):
        corr = np.clip(np.array(target, float) - np.array(octaves_of(x)), -24, 24)
        g = 10 ** (np.interp(lf, np.log2(BANDS), corr, left=corr[0], right=corr[-1]) / 20.0)
        x = np.fft.irfft(np.fft.rfft(x) * g, n)
    return x


def octaves_of(x):
    sp = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    en = np.array([sp[(f >= b / 1.414) & (f < b * 1.414)].sum() for b in BANDS]) + 1e-20
    return [10 * np.log10(e / en.max()) for e in en]


def write_ogg(name, x):
    path = os.path.join(OUT, name + '.ogg')
    with tempfile.TemporaryDirectory() as d:
        w = os.path.join(d, 'x.wav')
        with wave.open(w, 'wb') as fw:
            fw.setnchannels(1)
            fw.setsampwidth(2)
            fw.setframerate(SR)
            fw.writeframes((np.clip(x, -1, 1) * 32000).astype(np.int16).tobytes())
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', w, '-c:a', 'libvorbis', '-q:a', '5', path], check=True)
    return path


def main():
    cues = {
        'beep': beep(),
        'go': crowd('go', 21, voices=40, clap_rate=0, whistle_count=0),
        'checkpoint': checkpoint(),
        'cheer': crowd('cheer', 22, voices=30, clap_rate=120, whistle_count=1),
        'cheer_big': crowd('cheer_big', 23, voices=50, clap_rate=260, whistle_count=6),
        'hit': crash('hit', 31, 40),
        'land': crash('land', 32, 12),
        'ui_move': move(),
        'ui_click': click(),
        'wind': wind(),
    }
    for name, x in cues.items():
        key = {'ui_click': 'click', 'ui_move': 'move'}.get(name, name)
        if key in TARGET:
            x = norm(match_octaves(x, TARGET[key][0]), 0.5 if name == 'wind' else 0.89)
            if name != 'wind':
                x = fade(x, 1, 20)
        write_ogg(name, x)
        got = ' '.join('%.0f' % v for v in octaves_of(x))
        want = ' '.join('%d' % v for v in TARGET[key][0]) if key in TARGET else '-'
        print('%-10s %.2f s  octaves %s   (TMNF %s)' % (name, len(x) / SR, got, want))


if __name__ == '__main__':
    main()
