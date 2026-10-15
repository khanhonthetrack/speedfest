"""Engine loops for the three cars, plus the shared car loops (turbo, nitro, squeal, wind).

Each car gets four seamless mono loops recorded at a known base rpm:
  <car>_idle, <car>_mid, <car>_high : on-throttle layers, crossfaded and pitch-shifted by rpm
  <car>_off                         : off-throttle burble/overrun, mixed in when lifting
EngineAudio sets pitch_scale = rpm / base_rpm, so the base rpms printed here must match
LAYERS in game/audio/engine_audio.gd (gen_all.py writes them to engine_layers.json too).

Model: a train of band-limited combustion impulses (one per firing event, per exhaust bank),
shaped by causal resonators (exhaust/intake pipes) and a low-pass tilt, plus pulse-gated
noise ("rasp") and a little waveshaping. Everything is built circularly over a whole number
of engine cycles, so the loops are seamless.
"""
from __future__ import annotations

import numpy as np

import synth as S

SR = S.SR

# Firing events within one 720-degree cycle: (crank angle, bank)
V8_CROSSPLANE = [(i * 90.0, b) for i, b in enumerate([0, 1, 1, 0, 1, 0, 0, 1])]  # 1-8-4-3-6-5-7-2, GM banks
V12_FLAT = [(i * 60.0, i % 2) for i in range(12)]
ROTARY_2 = [(i * 180.0, i % 2) for i in range(4)]  # two rotors, one power pulse per rotor per shaft turn


CARS = {
	# Kaze: light JDM coupe, twin-rotor rotary -> high, buzzy, raspy
	"kaze": {
		"events": ROTARY_2,
		"idle_rpm": 1100.0, "redline": 9000.0,
		"bases": {"idle": 1100.0, "mid": 3200.0, "high": 7200.0, "off": 4200.0},
		"bright_hz": 2600.0,
		"reso": [(520.0, 3.0, 1.0), (1450.0, 4.0, 0.7), (2900.0, 5.0, 0.45), (5200.0, 4.0, 0.2)],
		"bank_delay": [0.0, 0.00035],
		"bank_gain": [1.0, 0.9],
		"tilt_hz": 2600.0,
		"rasp": 0.3, "rasp_band": (2200.0, 1.5), "rasp_tau": 0.15,
		"drive": 2.2,
		"var": {"idle": 0.22, "mid": 0.1, "high": 0.05, "off": 0.6},
		"jitter": 0.004,
		"sub": 0.15,
		"whine": (6.0, 0.0),
		"turbo": 1.0,
	},
	# Brute: American muscle, cross-plane V8 -> deep, lumpy, burbly
	"brute": {
		"events": V8_CROSSPLANE,
		"idle_rpm": 800.0, "redline": 6800.0,
		"bases": {"idle": 800.0, "mid": 2400.0, "high": 5400.0, "off": 3200.0},
		"bright_hz": 650.0,
		"reso": [(95.0, 2.0, 1.0), (240.0, 3.0, 0.8), (620.0, 3.5, 0.45), (1300.0, 3.0, 0.2)],
		"bank_delay": [0.0, 0.0019],
		"bank_gain": [1.0, 0.75],
		"tilt_hz": 900.0,
		"rasp": 0.2, "rasp_band": (900.0, 1.0), "rasp_tau": 0.3,
		"drive": 2.8,
		"var": {"idle": 0.45, "mid": 0.22, "high": 0.1, "off": 0.75},
		"jitter": 0.012,
		"sub": 0.5,
		"whine": (0.0, 0.0),
		"turbo": 0.25,
	},
	# Veloce: Euro supercar, flat-plane V12 -> smooth, bright, screaming
	"veloce": {
		"events": V12_FLAT,
		"idle_rpm": 1200.0, "redline": 8800.0,
		"bases": {"idle": 1200.0, "mid": 3400.0, "high": 7400.0, "off": 4400.0},
		"bright_hz": 3200.0,
		"reso": [(700.0, 3.0, 0.7), (1650.0, 5.0, 1.0), (3300.0, 6.0, 0.7), (5600.0, 5.0, 0.35)],
		"bank_delay": [0.0, 0.0006],
		"bank_gain": [1.0, 0.95],
		"tilt_hz": 6000.0,
		"rasp": 0.12, "rasp_band": (3600.0, 1.5), "rasp_tau": 0.2,
		"drive": 1.8,
		"var": {"idle": 0.12, "mid": 0.05, "high": 0.03, "off": 0.45},
		"jitter": 0.003,
		"sub": 0.1,
		"whine": (12.0, 0.08),
		"turbo": 0.55,
	},
}

LOOP_SECONDS = {"idle": 1.6, "mid": 1.2, "high": 1.0, "off": 1.6}


def _place_impulses(n: int, times: np.ndarray, amps: np.ndarray) -> np.ndarray:
	"""Band-limited impulses (windowed sinc, fractional position), wrapped circularly."""
	x = np.zeros(n)
	p = times * SR
	i0 = np.floor(p).astype(int)
	frac = p - i0
	taps = np.arange(-12, 13)
	k = taps[None, :] - frac[:, None]
	w = np.sinc(k) * (0.5 + 0.5 * np.cos(np.pi * np.clip(k / 13.0, -1, 1)))
	idx = (i0[:, None] + taps[None, :]) % n
	np.add.at(x, idx.ravel(), (w * amps[:, None]).ravel())
	return x


def _resonator(f: np.ndarray, f0: float, q: float) -> np.ndarray:
	fs = np.maximum(f, 1e-3)
	return 1.0 / (1.0 + 1j * q * (fs / f0 - f0 / fs))


def render_layer(car: str, layer: str, seed: int) -> tuple[np.ndarray, float]:
	c = CARS[car]
	rpm = c["bases"][layer]
	cycle = 120.0 / rpm
	n_cycles = max(2, int(round(LOOP_SECONDS[layer] / cycle)))
	n = int(round(n_cycles * cycle * SR))
	cycle = n / SR / n_cycles  # exact: whole cycles fit the loop
	rpm = 120.0 / cycle
	r = S.rng(seed)
	f = S.freqs_for(n)
	var = c["var"][layer]
	off = layer == "off"
	# --- events
	times = []
	amps = []
	banks = []
	# slow per-loop modulation with an integer number of periods (keeps the loop seamless)
	lump_periods = max(1, int(round(n_cycles / 3)))
	for ci in range(n_cycles):
		for (ang, b) in c["events"]:
			t = (ci + ang / 720.0) * cycle
			t += r.normal(0, c["jitter"]) * cycle / len(c["events"])
			a = 1.0 + var * r.normal()
			if off:
				a = abs(a) * (0.35 if r.random() < 0.6 else 1.0)
			ph = 2 * np.pi * lump_periods * t / (n / SR)
			a *= 1.0 + 0.5 * var * np.sin(ph)
			times.append(t % (n / SR))
			amps.append(max(0.05, a) * c["bank_gain"][b])
			banks.append(b)
	times = np.array(times)
	amps = np.array(amps)
	banks = np.array(banks)
	# --- pulse spectrum: half-sine bump of width w (brightness), resonators, tilt
	fb = c["bright_hz"] * (0.6 if off else 1.0)
	bump = 1.0 / (1.0 + (f / fb) ** 2)
	res = np.zeros_like(f, dtype=complex) + 0.35
	for (f0, q, g) in c["reso"]:
		res += g * _resonator(f, f0, q)
	tilt_hz = c["tilt_hz"] * (0.45 if off else 1.0) * (0.85 if layer == "idle" else 1.0)
	tilt = 1.0 / (1.0 + 1j * f / tilt_hz)
	y = np.zeros(n)
	for b in (0, 1):
		m = banks == b
		if not np.any(m):
			continue
		x = _place_impulses(n, (times[m] + c["bank_delay"][b]) % (n / SR), amps[m])
		Xs = np.fft.rfft(x)
		bank_res = res * (1.0 if b == 0 else np.exp(-1j * 2 * np.pi * f * 0.00011))
		y += np.fft.irfft(Xs * bump * bank_res * tilt, n=n)
	y = S.normalize_rms(y, -16)
	# --- rasp: noise gated by the pulse envelope
	gate = np.zeros(n)
	gi = (times * SR).astype(int) % n
	np.add.at(gate, gi, amps)
	tau = c["rasp_tau"] * cycle / len(c["events"]) * 2
	kern = np.exp(-S.t_axis(n) / max(tau, 1e-4))
	env = np.fft.irfft(np.fft.rfft(gate) * np.fft.rfft(kern), n=n)
	env /= max(1e-9, np.max(env))
	fc, q = c["rasp_band"]
	nz = S.apply_mag(S.noise(n, seed + 7), S.bp_mag(f, fc * (0.6 if off else 1.0), q))
	rasp = S.normalize_rms(nz * env, -16) * c["rasp"] * (0.6 if off else 1.0)
	# --- sub rumble at the cycle rate and mechanical whine (integer periods in the loop)
	t = S.t_axis(n)
	fire = len(c["events"]) / cycle  # firing frequency
	sub = c["sub"] * 0.3 * np.sin(2 * np.pi * (fire / 2) * t) * (1.0 if layer != "high" else 0.5)
	order, wg = c["whine"]
	whine = 0.0
	if wg > 0:
		whine = wg * 0.2 * np.sin(2 * np.pi * (order / cycle) * t)
	mix = y + rasp + sub + whine
	if off:
		mix += _crackles(n, seed + 11, car) * (1.0 if car != "veloce" else 0.4)
	mix = S.highpass(mix, 28.0, 2.0)
	mix = S.normalize_rms(mix, -14)
	mix = S.soft_clip(mix * 0.9, c["drive"])
	mix = S.normalize_peak(mix, -1.0)
	gain = {"idle": 0.62, "mid": 0.85, "high": 1.0, "off": 0.6}[layer]
	return mix * gain, rpm


def _crackles(n: int, seed: int, car: str) -> np.ndarray:
	"""Sparse overrun pops for the off-throttle layer."""
	r = S.rng(seed)
	out = np.zeros(n)
	count = {"kaze": 9, "brute": 7, "veloce": 4}[car]
	for _ in range(count):
		ln = int(SR * r.uniform(0.006, 0.02))
		pop = S.noise(ln, int(r.integers(1 << 30))) * S.env_ad(ln, 0.0005, ln / SR / 4)
		pop = S.bandpass(pop, r.uniform(700, 2500), 0.8)
		S.add_wrap(out, S.normalize_peak(pop, -3) * r.uniform(0.3, 0.7), int(r.integers(n)))
	return out


# --------------------------------------------------------------------------- shared loops

def turbo_loop() -> tuple[np.ndarray, float]:
	"""Turbo spool whistle, base 3000 Hz (pitch-shifted by boost in game)."""
	dur = 1.0
	n = int(SR * dur)
	t = S.t_axis(n)
	f0 = 3000.0
	tone = np.sin(2 * np.pi * f0 * t + 0.4 * np.sin(2 * np.pi * 7 * t))
	tone += 0.25 * np.sin(2 * np.pi * 2 * f0 * t)
	hiss = S.normalize_rms(S.bandpass(S.noise(n, 31), f0, 6.0), -20)
	air = S.normalize_rms(S.bandpass(S.noise(n, 32), 5500, 1.0), -26)
	x = S.normalize_rms(tone, -20) + hiss + air
	return S.normalize_peak(x, -3), f0


def nitro_loop() -> np.ndarray:
	"""Roaring nitrous jet: band-limited noise with a slow 'flutter'."""
	n = int(SR * 2.0)
	t = S.t_axis(n)
	f = S.freqs_for(n)
	nz = S.noise(n, 41)
	m = S.hp_mag(f, 250, 1.5) * S.lp_mag(f, 3500, 1.5) + 0.5 * S.bp_mag(f, 900, 1.5)
	x = S.apply_mag(nz, m)
	x *= 1.0 + 0.12 * np.sin(2 * np.pi * 11 * t) + 0.08 * np.sin(2 * np.pi * 17 * t)
	return S.normalize_peak(x, -2)


def squeal_loop() -> np.ndarray:
	"""Tire squeal: a wobbling ~1 kHz tone with a few partials over scrubbing noise."""
	n = int(SR * 2.0)
	t = S.t_axis(n)
	r = S.rng(51)
	x = np.zeros(n)
	for (fr, g) in [(950.0, 1.0), (1420.0, 0.45), (2100.0, 0.25)]:
		vib = 0.0
		for k in (3, 5, 9):  # integer Hz -> seamless over 2 s
			vib = vib + r.uniform(0.004, 0.012) * np.sin(2 * np.pi * k * t + r.uniform(0, 6.28)) / (2 * np.pi * k)
		ph = 2 * np.pi * fr * (t + vib * 6.0)
		x += g * np.sin(ph)
	amp = 0.75 + 0.25 * np.sin(2 * np.pi * 4 * t) * np.sin(2 * np.pi * 1.5 * t)
	x *= amp
	nz = S.normalize_rms(S.bandpass(S.noise(n, 52), 1600, 1.2), -18)
	x = S.normalize_rms(x, -15) + nz
	x = S.soft_clip(x, 1.5)
	return S.normalize_peak(x, -2)


def wind_loop() -> np.ndarray:
	"""Wind rush: low-passed pink-ish noise with slow swells."""
	n = int(SR * 4.0)
	t = S.t_axis(n)
	f = S.freqs_for(n)
	nz = S.noise(n, 61)
	m = S.lp_mag(f, 1400, 1.0) / np.sqrt(np.maximum(f, 40.0) / 40.0) + 0.15 * S.bp_mag(f, 3000, 1.0)
	x = S.apply_mag(nz, m)
	x *= 1.0 + 0.15 * np.sin(2 * np.pi * 0.5 * t) + 0.1 * np.sin(2 * np.pi * 1.25 * t + 1.0)
	return S.normalize_peak(x, -2)
