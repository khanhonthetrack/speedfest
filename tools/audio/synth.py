"""Small numpy-only synthesis toolkit for SpeedFest's generated audio.

Everything that has to loop is built in the *circular* domain: filters are applied with
FFTs over the whole loop, delays use np.roll and events past the end wrap around to the
start. A loop rendered this way has no seam at all.

No scipy: the only dependencies are numpy, the stdlib and ffmpeg (for Ogg Vorbis).
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100


# --------------------------------------------------------------------------- utils

def rng(seed: int) -> np.random.Generator:
	return np.random.default_rng(seed)


def db(x: float) -> float:
	return 10.0 ** (x / 20.0)


def t_axis(n: int, sr: int = SR) -> np.ndarray:
	return np.arange(n) / sr


def normalize_peak(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
	m = float(np.max(np.abs(x))) if x.size else 0.0
	if m < 1e-12:
		return x
	return x * (db(peak_db) / m)


def normalize_rms(x: np.ndarray, rms_db: float) -> np.ndarray:
	r = float(np.sqrt(np.mean(x * x)))
	if r < 1e-12:
		return x
	return x * (db(rms_db) / r)


def soft_clip(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
	return np.tanh(x * drive) / np.tanh(drive)


def fade(x: np.ndarray, fin: float = 0.002, fout: float = 0.01, sr: int = SR) -> np.ndarray:
	x = x.copy()
	a = max(1, int(fin * sr))
	b = max(1, int(fout * sr))
	env_in = np.linspace(0.0, 1.0, a)
	env_out = np.linspace(1.0, 0.0, b)
	if x.ndim == 1:
		x[:a] *= env_in
		x[-b:] *= env_out
	else:
		x[:a] *= env_in[:, None]
		x[-b:] *= env_out[:, None]
	return x


def env_ad(n: int, attack: float, decay: float, sr: int = SR, curve: float = 1.0) -> np.ndarray:
	"""Attack then exponential decay (decay = time constant in seconds)."""
	t = t_axis(n, sr)
	a = np.clip(t / max(attack, 1e-5), 0.0, 1.0) ** curve
	d = np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-5))
	return a * d


def env_adsr(n: int, a: float, d: float, s: float, r: float, gate: float, sr: int = SR) -> np.ndarray:
	"""Linear-ish ADSR. gate = note-on length in seconds; n should cover gate + release."""
	t = t_axis(n, sr)
	e = np.zeros(n)
	att = np.clip(t / max(a, 1e-5), 0, 1)
	dec = s + (1 - s) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-5))
	e = np.where(t < a, att, dec)
	g = min(gate, n / sr)
	gi = int(g * sr)
	level_at_gate = e[gi - 1] if gi > 0 else 0.0
	rel = level_at_gate * np.exp(-np.maximum(t - g, 0) / max(r, 1e-5))
	e = np.where(t < g, e, rel)
	return e


# --------------------------------------------------------------------------- spectral filters

def freqs_for(n: int, sr: int = SR) -> np.ndarray:
	return np.fft.rfftfreq(n, 1.0 / sr)


def apply_mag(x: np.ndarray, mag: np.ndarray) -> np.ndarray:
	"""Circular zero-phase filtering by a magnitude response (per rfft bin)."""
	if x.ndim == 2:
		return np.stack([apply_mag(x[:, c], mag) for c in range(x.shape[1])], axis=1)
	X = np.fft.rfft(x)
	return np.fft.irfft(X * mag, n=x.shape[0])


def lp_mag(f: np.ndarray, fc: float, order: float = 2.0) -> np.ndarray:
	return 1.0 / np.sqrt(1.0 + (f / max(fc, 1e-3)) ** (2 * order))


def hp_mag(f: np.ndarray, fc: float, order: float = 2.0) -> np.ndarray:
	r = f / max(fc, 1e-3)
	return r ** order / np.sqrt(1.0 + r ** (2 * order))


def bp_mag(f: np.ndarray, fc: float, q: float) -> np.ndarray:
	"""Second-order band-pass magnitude (peak 1 at fc)."""
	f = np.maximum(f, 1e-3)
	x = f / fc - fc / f
	return 1.0 / np.sqrt(1.0 + (q * x) ** 2)


def lowpass(x, fc, order=2.0, sr=SR):
	return apply_mag(x, lp_mag(freqs_for(x.shape[0], sr), fc, order))


def highpass(x, fc, order=2.0, sr=SR):
	return apply_mag(x, hp_mag(freqs_for(x.shape[0], sr), fc, order))


def bandpass(x, fc, q, sr=SR):
	return apply_mag(x, bp_mag(freqs_for(x.shape[0], sr), fc, q))


def noise(n: int, seed: int) -> np.ndarray:
	return rng(seed).standard_normal(n)


def pink(n: int, seed: int) -> np.ndarray:
	f = freqs_for(n)
	m = 1.0 / np.sqrt(np.maximum(f, 20.0))
	return normalize_rms(apply_mag(noise(n, seed), m), -12)


def filtered_sweep(src: np.ndarray, fc_fn, q: float = 2.0, kind: str = "bp", chunks: int = 48, sr: int = SR) -> np.ndarray:
	"""Time-varying filter by overlap-add of Hann-windowed blocks.

	fc_fn(u) gives the cutoff/centre for u in [0, 1] (position in the signal)."""
	n = src.shape[0]
	hop = max(64, n // chunks)
	win_len = hop * 2
	win = np.hanning(win_len)
	out = np.zeros(n + win_len)
	pad = np.concatenate([src, np.zeros(win_len)])
	f = freqs_for(win_len, sr)
	pos = 0
	while pos < n:
		seg = pad[pos:pos + win_len] * win
		u = min(1.0, (pos + hop) / n)
		fc = fc_fn(u)
		if kind == "bp":
			m = bp_mag(f, fc, q)
		elif kind == "lp":
			m = lp_mag(f, fc, q)
		else:
			m = hp_mag(f, fc, q)
		out[pos:pos + win_len] += np.fft.irfft(np.fft.rfft(seg) * m, n=win_len)
		pos += hop
	# Hann windows at 50% overlap sum to 1 (except at the first half-block).
	return out[:n]


# --------------------------------------------------------------------------- oscillators

class WaveBank:
	"""Band-limited wavetables indexed by 'cutoff in harmonics'.

	A table for cutoff h holds one period of a waveform whose k-th harmonic is scaled by a
	resonant low-pass response at k/h. Oscillators read it with linear interpolation in phase
	and in log(h), so a filter sweep is just a curve of h over time and nothing aliases."""

	SIZE = 2048
	LEVELS = 48

	def __init__(self, shape: str = "saw", reso: float = 0.0, order: float = 2.0):
		self.h_grid = np.geomspace(0.6, 900.0, self.LEVELS)
		k = np.arange(1, self.SIZE // 2)
		if shape == "saw":
			base = 1.0 / k
		elif shape == "square":
			base = np.where(k % 2 == 1, 1.0 / k, 0.0)
		elif shape == "tri":
			base = np.where(k % 2 == 1, 1.0 / (k * k), 0.0) * np.where(((k - 1) // 2) % 2 == 0, 1, -1)
		elif shape == "pulse25":
			base = np.abs(np.sin(np.pi * k * 0.25)) / k
		else:
			raise ValueError(shape)
		tables = np.zeros((self.LEVELS, self.SIZE))
		for i, h in enumerate(self.h_grid):
			r = k / h
			g = 1.0 / np.sqrt(1.0 + r ** (2 * order))
			if reso > 0:
				g = g * (1.0 + reso * np.exp(-((r - 1.0) / 0.25) ** 2))
			spec = np.zeros(self.SIZE // 2 + 1, dtype=complex)
			spec[1:self.SIZE // 2] = base * g * (-1j) * (self.SIZE / 2)
			tables[i] = np.fft.irfft(spec, n=self.SIZE)
		self.tables = tables / np.max(np.abs(tables[-1]))

	def render(self, freq: np.ndarray, cutoff_hz: np.ndarray, phase0: float = 0.0, sr: int = SR) -> np.ndarray:
		freq = np.asarray(freq, dtype=float)
		n = freq.shape[0]
		cutoff_hz = np.broadcast_to(np.asarray(cutoff_hz, dtype=float), (n,))
		ph = (phase0 + np.cumsum(freq) / sr) % 1.0
		# harmonics allowed: below the cutoff and below Nyquist
		h = np.minimum(cutoff_hz / np.maximum(freq, 1.0), (sr * 0.45) / np.maximum(freq, 1.0))
		lh = np.log(np.clip(h, self.h_grid[0], self.h_grid[-1]))
		lg = np.log(self.h_grid)
		fi = np.interp(lh, lg, np.arange(self.LEVELS))
		i0 = np.floor(fi).astype(int)
		i1 = np.minimum(i0 + 1, self.LEVELS - 1)
		w = fi - i0
		p = ph * self.SIZE
		j0 = np.floor(p).astype(int) % self.SIZE
		j1 = (j0 + 1) % self.SIZE
		pf = p - np.floor(p)
		a = self.tables[i0, j0] * (1 - pf) + self.tables[i0, j1] * pf
		b = self.tables[i1, j0] * (1 - pf) + self.tables[i1, j1] * pf
		return a * (1 - w) + b * w


_BANKS: dict = {}


def bank(shape: str = "saw", reso: float = 0.0) -> WaveBank:
	key = (shape, round(reso, 3))
	if key not in _BANKS:
		_BANKS[key] = WaveBank(shape, reso)
	return _BANKS[key]


def sine(freq, n: int, phase0: float = 0.0, sr: int = SR) -> np.ndarray:
	freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
	return np.sin(2 * np.pi * (phase0 + np.cumsum(freq) / sr))


def midi_hz(m: float) -> float:
	return 440.0 * 2.0 ** ((m - 69) / 12.0)


# --------------------------------------------------------------------------- mixing helpers

def add_wrap(dst: np.ndarray, src: np.ndarray, start: int) -> None:
	"""Add src into dst at start, wrapping around the end (for seamless loops)."""
	n = dst.shape[0]
	start %= n
	m = src.shape[0]
	pos = 0
	while pos < m:
		take = min(m - pos, n - start)
		dst[start:start + take] += src[pos:pos + take]
		pos += take
		start = 0


def add_at(dst: np.ndarray, src: np.ndarray, start: int) -> None:
	"""Add src into dst at start, truncating at the end (for one-shots)."""
	n = dst.shape[0]
	if start >= n:
		return
	take = min(src.shape[0], n - start)
	dst[start:start + take] += src[:take]


def pan(x: np.ndarray, p: float) -> np.ndarray:
	"""Mono -> stereo with an equal-power pan, p in [-1, 1]."""
	a = (p + 1) * np.pi / 4
	return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def reverb_ir(seconds: float, seed: int, damp_hz: float = 6000.0, predelay: float = 0.012, sr: int = SR) -> np.ndarray:
	"""Stereo synthetic reverb impulse response: decorrelated decaying noise that gets darker."""
	n = int(seconds * sr)
	t = t_axis(n, sr)
	out = np.zeros((n, 2))
	for c in range(2):
		nz = noise(n, seed + c)
		bright = nz * np.exp(-t * 6.9 / (seconds * 0.45))
		dark = lowpass(nz, damp_hz * 0.35) * np.exp(-t * 6.9 / seconds)
		ir = lowpass(bright, damp_hz) + dark * 1.6
		pd = int(predelay * sr)
		ir = np.concatenate([np.zeros(pd), ir])[:n]
		out[:, c] = ir
	return out / np.sqrt(np.sum(out ** 2) / 2)


def convolve_circular(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
	"""Circular convolution of a stereo loop with a stereo IR (IR shorter than the loop)."""
	n = x.shape[0]
	out = np.zeros_like(x)
	for c in range(x.shape[1]):
		h = np.zeros(n)
		h[:ir.shape[0]] = ir[:, c]
		out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c]) * np.fft.rfft(h), n=n)
	return out


def convolve_linear(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
	n = x.shape[0] + ir.shape[0]
	if x.ndim == 1:
		x = np.stack([x, x], axis=1)
	out = np.zeros((n, 2))
	for c in range(2):
		out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c], n=n) * np.fft.rfft(ir[:, c], n=n), n=n)
	return out


def pingpong_circular(x: np.ndarray, delay_s: float, feedback: float, taps: int = 6, damp_hz: float = 4500.0, sr: int = SR) -> np.ndarray:
	"""Circular ping-pong delay (stereo in, stereo wet out)."""
	d = int(delay_s * sr)
	mono = x.mean(axis=1)
	wet = np.zeros_like(x)
	cur = mono
	f = freqs_for(x.shape[0], sr)
	m = lp_mag(f, damp_hz, 1.0)
	for i in range(1, taps + 1):
		cur = np.fft.irfft(np.fft.rfft(np.roll(cur, d)) * m, n=x.shape[0])
		g = feedback ** (i - 1)
		wet[:, (i + 1) % 2] += cur * g
	return wet


# --------------------------------------------------------------------------- output

def write_wav(path: str, x: np.ndarray, sr: int = SR) -> None:
	x = np.clip(x, -1.0, 1.0)
	data = (x * 32767.0).astype("<i2")
	ch = 1 if x.ndim == 1 else x.shape[1]
	with wave.open(path, "wb") as w:
		w.setnchannels(ch)
		w.setsampwidth(2)
		w.setframerate(sr)
		w.writeframes(data.tobytes())


def write_ogg(path: str, x: np.ndarray, quality: float = 3.0, sr: int = SR) -> int:
	"""Encode to Ogg Vorbis with ffmpeg. Returns the file size in bytes."""
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with tempfile.TemporaryDirectory() as td:
		wav = os.path.join(td, "x.wav")
		write_wav(wav, x, sr)
		subprocess.run(
			["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality), path],
			check=True,
		)
	return os.path.getsize(path)


def spectrogram_png(ogg_path: str, png_path: str, width: int = 1024, height: int = 384) -> None:
	"""Spectrogram image via ffmpeg's showspectrumpic (for eyeballing the sounds)."""
	os.makedirs(os.path.dirname(png_path), exist_ok=True)
	subprocess.run(
		["ffmpeg", "-y", "-loglevel", "error", "-i", ogg_path, "-lavfi",
			f"showspectrumpic=s={width}x{height}:mode=combined:scale=log:fscale=lin:legend=1", png_path],
		check=True,
	)
