"""Weather sounds: rain ambience (seamless loop), thunder and puddle splash (one-shots). Mono."""
from __future__ import annotations

import numpy as np

import synth as S

SR = S.SR


def amb_rain() -> np.ndarray:
	"""Steady rain: pink hiss + dense droplet ticks + a soft low wash. 6 s, seamless.

	Everything is built circularly (FFT filtering of noise, add_wrap for the drops), so the end
	joins the start without a seam.
	"""
	n = int(SR * 6.0)
	f = S.freqs_for(n)
	hiss = S.apply_mag(S.noise(n, 701), S.hp_mag(f, 500, 1.0) * S.lp_mag(f, 8000, 1.5) / np.sqrt(np.maximum(f, 200.0) / 200.0))
	wash = S.apply_mag(S.noise(n, 702), S.lp_mag(f, 380, 2.0))
	drops = np.zeros(n)
	r = S.rng(703)
	for _ in range(2600):
		m = int(SR * r.uniform(0.004, 0.02))
		t = S.t_axis(m)
		tick = S.bandpass(S.noise(m, int(r.integers(1, 1 << 30))), r.uniform(1800, 6500), 1.5) * np.exp(-t / r.uniform(0.002, 0.006))
		S.add_wrap(drops, tick * r.uniform(0.2, 1.0), int(r.integers(0, n)))
	x = S.normalize_rms(hiss, -22) + S.normalize_rms(wash, -30) + S.normalize_rms(drops, -26)
	t = S.t_axis(n)
	x *= 1.0 + 0.08 * np.sin(2 * np.pi * t / 6.0) + 0.05 * np.sin(2 * np.pi * 2 * t / 6.0 + 1.3)
	return S.normalize_peak(x, -3)


def sfx_thunder() -> np.ndarray:
	"""Thunder: a sharp crack, then a long rolling rumble with a few swells. ~5 s."""
	n = int(5.0 * SR)
	t = S.t_axis(n)
	r = S.rng(711)
	crack = S.highpass(S.noise(n, 712), 900) * np.clip(t / 0.003, 0, 1) * np.exp(-t / 0.07)
	rumble = S.lowpass(S.noise(n, 713), 160, 2.0)
	roll = S.bandpass(S.noise(n, 714), 420, 0.8)
	env = np.zeros(n)
	for k in range(6):
		c = r.uniform(0.15, 2.6) + 0.12 * k
		w = r.uniform(0.25, 0.7)
		env += r.uniform(0.5, 1.0) * np.exp(-((t - c) / w) ** 2)
	env = env / env.max() * np.exp(-t / 2.2) * np.clip(t / 0.05, 0, 1)
	x = crack * 0.7 + S.normalize_peak(rumble * env, -2) + 0.35 * S.normalize_peak(roll * env, -6)
	return S.fade(S.normalize_peak(S.soft_clip(x, 1.4), -1), 0.001, 0.6)


def sfx_splash() -> np.ndarray:
	"""Driving through a puddle at speed: a wet 'shhhk' sweep plus spatter. ~0.5 s."""
	n = int(0.55 * SR)
	t = S.t_axis(n)
	sweep = S.filtered_sweep(S.noise(n, 721), lambda v: 2600 - 1700 * v, q=0.9)
	body = S.lowpass(S.noise(n, 722), 700, 2.0) * np.exp(-t / 0.08)
	env = np.clip(t / 0.006, 0, 1) * np.exp(-t / 0.16)
	x = sweep * env + 0.6 * body
	r = S.rng(723)
	for _ in range(40):
		m = int(SR * 0.012)
		tt = S.t_axis(m)
		blip = S.bandpass(S.noise(m, int(r.integers(1, 1 << 30))), r.uniform(1500, 5000), 2.0) * np.exp(-tt / 0.003)
		S.add_at(x, blip * r.uniform(0.1, 0.4), int(r.uniform(0.02, 0.45) * SR))
	return S.fade(S.normalize_peak(x, -2), 0.001, 0.05)


ALL = {
	"amb_rain": amb_rain,
	"sfx_thunder": sfx_thunder,
	"sfx_splash": sfx_splash,
}
