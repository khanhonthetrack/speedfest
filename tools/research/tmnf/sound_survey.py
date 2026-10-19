"""Measures sounds, numbers only: for each WAV, its length, loudness envelope (attack, peak, decay to
-20 dB), the strongest partials (Hz and level) in a few time slices, the pitch over time
(autocorrelation) and the spectral centroid. Used to make our own cues sound like TMNF's (M10-5):
run it on TMNF's local WAVs (never in the repo) and on ours, compare, retune our generators.
usage: python3 -I tools/research/tmnf/sound_survey.py FILE.wav [...] [--slices=4] [--partials=6]"""
import sys
import wave
import numpy as np


def load(path):
    with wave.open(path, 'rb') as w:
        n, ch, sw, rate = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(n)
    dt = {1: np.uint8, 2: np.int16, 4: np.int32}[sw]
    a = np.frombuffer(raw, dt).astype(np.float64)
    if sw == 1:
        a = (a - 128.0) / 128.0
    else:
        a /= float(2 ** (8 * sw - 1))
    if ch > 1:
        a = a.reshape(-1, ch).mean(axis=1)
    return a, rate


def envelope(a, rate, win_ms=10):
    w = max(1, int(rate * win_ms / 1000))
    n = len(a) // w
    if n == 0:
        return np.array([np.sqrt(np.mean(a ** 2))]), w
    e = np.sqrt(np.mean(a[:n * w].reshape(n, w) ** 2, axis=1))
    return e, w


def partials(seg, rate, k):
    if len(seg) < 64:
        return []
    win = np.hanning(len(seg))
    sp = np.abs(np.fft.rfft(seg * win))
    f = np.fft.rfftfreq(len(seg), 1.0 / rate)
    sp[f < 40] = 0
    out = []
    peak = sp.max() + 1e-12
    s = sp.copy()
    for _ in range(k):
        i = int(np.argmax(s))
        if s[i] <= peak * 0.03:
            break
        out.append((f[i], 20 * np.log10(s[i] / peak)))
        lo, hi = max(0, i - 6), i + 7
        s[lo:hi] = 0
    return out


def pitch(seg, rate):
    seg = seg - seg.mean()
    if len(seg) < 256 or np.max(np.abs(seg)) < 1e-4:
        return 0.0
    c = np.correlate(seg, seg, 'full')[len(seg) - 1:]
    lo, hi = int(rate / 4000), int(rate / 50)
    if hi >= len(c):
        return 0.0
    i = lo + int(np.argmax(c[lo:hi]))
    return rate / i if c[i] > 0.3 * c[0] else 0.0


def centroid(seg, rate):
    sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    f = np.fft.rfftfreq(len(seg), 1.0 / rate)
    return float((sp * f).sum() / (sp.sum() + 1e-12))


def main():
    files = [a for a in sys.argv[1:] if not a.startswith('--')]
    opts = dict(a[2:].split('=') for a in sys.argv[1:] if a.startswith('--'))
    slices = int(opts.get('slices', 4))
    k = int(opts.get('partials', 6))
    for p in files:
        a, rate = load(p)
        e, w = envelope(a, rate)
        pk = int(np.argmax(e))
        db = 20 * np.log10(e / (e[pk] + 1e-12) + 1e-9)
        after = np.nonzero(db[pk:] < -20)[0]
        decay = (after[0] * 10) if len(after) else (len(e) - pk) * 10
        start = np.nonzero(db > -30)[0]
        att = (pk - start[0]) * 10 if len(start) else 0
        print('%s: %.3f s @ %d Hz, peak %.2f (rms %.3f) at %d ms, attack %d ms, -20 dB after %d ms, centroid %.0f Hz'
              % (p.split('/')[-1], len(a) / rate, rate, np.max(np.abs(a)), e[pk], pk * 10, att, decay, centroid(a, rate)))
        n = len(a)
        for s in range(slices):
            seg = a[int(n * s / slices):int(n * (s + 1) / slices)]
            ps = partials(seg, rate, k)
            print('   slice %d: pitch %.0f Hz, centroid %.0f Hz, partials %s' % (
                s, pitch(seg[:min(len(seg), 4096)], rate), centroid(seg, rate) if len(seg) > 64 else 0,
                ', '.join('%.0f(%.0f)' % (f, d) for f, d in ps)))
        # octave bands over the whole sound (dB from the strongest)
        sp = np.abs(np.fft.rfft(a * np.hanning(len(a)))) ** 2
        f = np.fft.rfftfreq(len(a), 1.0 / rate)
        bands = [63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        en = np.array([sp[(f >= b / 1.414) & (f < b * 1.414)].sum() for b in bands]) + 1e-20
        print('   octaves ' + ' '.join('%d:%.0f' % (b, 10 * np.log10(x / en.max())) for b, x in zip(bands, en)))
        # the envelope in 50 ms steps (dB), for the shape
        step = 5
        print('   env dB/50ms: ' + ' '.join('%.0f' % db[i] for i in range(0, min(len(db), 80 * step), step)))


if __name__ == '__main__':
    main()
