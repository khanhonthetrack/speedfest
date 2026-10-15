"""One-shot sound effects: UI, race events and car events. All mono, short."""
from __future__ import annotations

import numpy as np

import synth as S

SR = S.SR


def _tone(freq: float, dur: float, shape: str = "sine", cutoff: float = 6000.0, attack: float = 0.002, decay: float = 0.1) -> np.ndarray:
	n = int(dur * SR)
	if shape == "sine":
		x = S.sine(freq, n)
	else:
		x = S.bank(shape).render(np.full(n, freq), np.full(n, cutoff))
	return S.fade(x * S.env_ad(n, attack, decay), 0.0005, min(0.03, dur * 0.4))


def _bell(freq: float, dur: float, decay: float = 0.4, bright: float = 1.0) -> np.ndarray:
	"""FM-ish bell: a few inharmonic partials with faster decay up high."""
	n = int(dur * SR)
	t = S.t_axis(n)
	x = np.zeros(n)
	for ratio, g, dk in [(1.0, 1.0, 1.0), (2.0, 0.5 * bright, 0.6), (2.76, 0.3 * bright, 0.45), (4.07, 0.15 * bright, 0.3), (5.4, 0.08 * bright, 0.2)]:
		x += g * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (decay * dk))
	return x * np.clip(t / 0.002, 0, 1)


def _out(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
	return S.fade(S.normalize_peak(x, peak_db), 0.001, 0.02)


# --------------------------------------------------------------------------- UI

def ui_click() -> np.ndarray:
	n = int(0.06 * SR)
	t = S.t_axis(n)
	x = np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.012)
	x += 0.5 * S.bandpass(S.noise(n, 1), 4000, 2.0) * np.exp(-t / 0.004)
	return _out(x, -4)


def ui_hover() -> np.ndarray:
	n = int(0.05 * SR)
	t = S.t_axis(n)
	x = np.sin(2 * np.pi * 2600 * t) * np.exp(-t / 0.008) * np.clip(t / 0.003, 0, 1)
	return _out(x, -12)


def ui_back() -> np.ndarray:
	a = _tone(880, 0.12, "tri", decay=0.05)
	b = _tone(587.3, 0.2, "tri", decay=0.08)
	x = np.zeros(int(0.28 * SR))
	S.add_at(x, a, 0)
	S.add_at(x, b, int(0.07 * SR))
	return _out(x, -5)


def ui_confirm() -> np.ndarray:
	x = np.zeros(int(0.5 * SR))
	for i, m in enumerate([76, 83, 88]):  # E5 B5 E6
		S.add_at(x, _bell(S.midi_hz(m), 0.4, 0.15, 0.6) * (1.0 - 0.15 * i), int(i * 0.055 * SR))
	return _out(x, -3)


def ui_error() -> np.ndarray:
	x = np.zeros(int(0.32 * SR))
	for i in range(2):
		S.add_at(x, _tone(155.6, 0.16, "square", cutoff=1400, attack=0.003, decay=0.05), int(i * 0.14 * SR))
	return _out(x, -4)


# --------------------------------------------------------------------------- race events

def sfx_checkpoint() -> np.ndarray:
	"""Bright two-note chime with a short shimmer."""
	x = np.zeros(int(0.9 * SR))
	S.add_at(x, _bell(S.midi_hz(88), 0.9, 0.3), 0)  # E6
	S.add_at(x, _bell(S.midi_hz(95), 0.8, 0.35), int(0.07 * SR))  # B6
	sh = S.highpass(S.noise(x.shape[0], 5), 7000) * np.exp(-S.t_axis(x.shape[0]) / 0.15) * 0.08
	return _out(x + sh, -2)


def _chord_stab(midis: list, dur: float, cutoff0: float, cutoff1: float, seed: int, shape: str = "saw") -> np.ndarray:
	n = int(dur * SR)
	t = S.t_axis(n)
	x = np.zeros(n)
	cut = cutoff1 + (cutoff0 - cutoff1) * np.exp(-t / (dur * 0.35))
	r = S.rng(seed)
	for m in midis:
		for det in (-0.08, 0.0, 0.08):
			f = S.midi_hz(m + det)
			x += S.bank(shape).render(np.full(n, f), cut, phase0=r.random())
	return x * S.env_adsr(n, 0.005, dur * 0.3, 0.5, dur * 0.25, dur * 0.6)


def sfx_finish() -> np.ndarray:
	"""Finish fanfare: rising arpeggio into a big held chord with a cymbal swell."""
	x = np.zeros(int(2.4 * SR))
	notes = [69, 73, 76, 81]  # A major arpeggio
	for i, m in enumerate(notes):
		S.add_at(x, _tone(S.midi_hz(m), 0.3, "saw", cutoff=4500, decay=0.12) * 0.6, int(i * 0.08 * SR))
	chord = _chord_stab([57, 64, 69, 73, 76], 2.0, 6000, 900, 7)
	S.add_at(x, chord * 0.5, int(0.32 * SR))
	S.add_at(x, _bell(S.midi_hz(93), 1.6, 0.5) * 0.35, int(0.32 * SR))
	n = x.shape[0]
	cym = S.highpass(S.noise(n, 9), 5000) * np.exp(-np.maximum(S.t_axis(n) - 0.32, 0) / 0.6) * (S.t_axis(n) > 0.32) * 0.12
	return _out(x + cym, -1.5)


def sfx_pb() -> np.ndarray:
	"""New personal best: sparkly ascending bells over a warm chord."""
	x = np.zeros(int(2.2 * SR))
	for i, m in enumerate([76, 79, 83, 88, 91, 95]):
		S.add_at(x, _bell(S.midi_hz(m), 1.0, 0.35) * 0.55, int(i * 0.07 * SR))
	S.add_at(x, _chord_stab([52, 59, 64, 67, 71], 1.8, 3000, 700, 3) * 0.35, int(0.4 * SR))
	return _out(x, -1.5)


def sfx_countdown() -> np.ndarray:
	n = int(0.32 * SR)
	t = S.t_axis(n)
	x = S.bank("square").render(np.full(n, 880.0), np.full(n, 5000.0)) * 0.5 + np.sin(2 * np.pi * 880 * t)
	env = np.clip(t / 0.003, 0, 1) * np.where(t < 0.16, 1.0, np.exp(-(t - 0.16) / 0.03))
	return _out(x * env, -3)


def sfx_go() -> np.ndarray:
	n = int(0.9 * SR)
	t = S.t_axis(n)
	x = S.bank("square").render(np.full(n, 1760.0), np.full(n, 7000.0)) * 0.5 + np.sin(2 * np.pi * 1760 * t)
	x += 0.6 * np.sin(2 * np.pi * 880 * t)
	env = np.clip(t / 0.003, 0, 1) * np.where(t < 0.45, 1.0, np.exp(-(t - 0.45) / 0.08))
	return _out(x * env, -2)


def sfx_respawn() -> np.ndarray:
	"""Digital 'warp': a falling-then-rising zap over a filtered whoosh."""
	n = int(0.7 * SR)
	t = S.t_axis(n)
	u = t / t[-1]
	f = 300 + 1500 * (1 - u) ** 2 + 900 * u ** 3
	zap = S.bank("saw").render(f, f * 6) * np.exp(-t / 0.3) * 0.4
	wh = S.filtered_sweep(S.noise(n, 13), lambda v: 3000 * (1 - v) + 400, q=2.5) * np.sin(np.pi * u) * 1.2
	return _out(zap + wh, -3)


def sfx_boost() -> np.ndarray:
	"""Boost pad: rising whoosh plus a bright synth sweep."""
	n = int(0.8 * SR)
	t = S.t_axis(n)
	u = t / t[-1]
	wh = S.filtered_sweep(S.noise(n, 21), lambda v: 400 + 5000 * v ** 1.5, q=1.8) * np.sin(np.pi * np.minimum(u * 1.4, 1.0))
	f = 220 * 2 ** (2.0 * u)
	sw = S.bank("saw").render(f, f * 8) * np.exp(-t / 0.4) * 0.25
	return _out(wh + sw, -2)


def sfx_wall_hit() -> np.ndarray:
	"""Crunchy impact: thump + metal clang partials + scrape noise."""
	n = int(0.6 * SR)
	t = S.t_axis(n)
	thump = np.sin(2 * np.pi * (55 + 60 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.08)
	clang = np.zeros(n)
	r = S.rng(33)
	for fr in [420.0, 713.0, 1190.0, 1730.0, 2650.0]:
		clang += r.uniform(0.3, 0.7) * np.sin(2 * np.pi * fr * t + r.uniform(0, 6)) * np.exp(-t / r.uniform(0.05, 0.15))
	crunch = S.bandpass(S.noise(n, 34), 2200, 0.7) * np.exp(-t / 0.05)
	x = thump * 1.2 + clang * 0.4 + crunch * 0.5
	return _out(S.soft_clip(x, 1.5), -1)


def sfx_land() -> np.ndarray:
	"""Landing thud: low body thump plus a short suspension rattle."""
	n = int(0.5 * SR)
	t = S.t_axis(n)
	thump = np.sin(2 * np.pi * np.cumsum(50 + 90 * np.exp(-t / 0.025)) / SR) * np.exp(-t / 0.12)
	body = S.bandpass(S.noise(n, 43), 220, 1.2) * np.exp(-t / 0.05) * 0.9
	rattle = S.bandpass(S.noise(n, 44), 1500, 1.0) * np.exp(-t / 0.03) * 0.3
	for k, dly in enumerate((0.05, 0.09, 0.14)):  # suspension/body rattles
		i = int(dly * SR)
		m = n - i
		rattle[i:] += S.bandpass(S.noise(m, 45 + k), 900 + 300 * k, 2.0) * np.exp(-S.t_axis(m) / 0.012) * 0.25
	return _out(S.soft_clip(thump + S.normalize_peak(body, -2) + rattle, 1.5), -1)


def sfx_blowoff() -> np.ndarray:
	"""Turbo blow-off valve: sharp 'pssh' that falls in pitch, with a little flutter."""
	n = int(0.55 * SR)
	t = S.t_axis(n)
	src = S.noise(n, 55) * (1.0 + 0.5 * np.sin(2 * np.pi * 38 * t))
	x = S.filtered_sweep(src, lambda v: 5200 * (1 - 0.6 * v), q=1.6)
	env = np.clip(t / 0.004, 0, 1) * np.exp(-t / 0.12)
	return _out(x * env, -2)


def sfx_nitro_start() -> np.ndarray:
	"""Nitro kick-in: a quick 'fwoosh' building into the nitro loop."""
	n = int(0.6 * SR)
	t = S.t_axis(n)
	u = t / t[-1]
	x = S.filtered_sweep(S.noise(n, 66), lambda v: 600 + 2800 * v, q=1.2)
	env = np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.35)
	return _out(x * env, -2)


ALL = {
	"ui_click": ui_click,
	"ui_hover": ui_hover,
	"ui_back": ui_back,
	"ui_confirm": ui_confirm,
	"ui_error": ui_error,
	"sfx_checkpoint": sfx_checkpoint,
	"sfx_finish": sfx_finish,
	"sfx_pb": sfx_pb,
	"sfx_countdown": sfx_countdown,
	"sfx_go": sfx_go,
	"sfx_respawn": sfx_respawn,
	"sfx_boost": sfx_boost,
	"sfx_wall_hit": sfx_wall_hit,
	"car_land": sfx_land,
	"car_blowoff": sfx_blowoff,
	"car_nitro_start": sfx_nitro_start,
}
