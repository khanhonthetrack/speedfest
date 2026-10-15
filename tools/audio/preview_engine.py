"""Offline preview of the in-game engine mix (a Python port of EngineAudio's local mix).

Renders a short drive for each car (idle, full-throttle pulls through three gears, a lift with
blow-off, nitro, a drift) from the generated .ogg loops, so the result can be listened to and
checked (spectrogram, peaks) without running the game.

usage: python3 tools/audio/preview_engine.py OUT_DIR [car ...]
"""
from __future__ import annotations

import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_engines as E  # noqa: E402
import synth as S  # noqa: E402

SR = S.SR
GEN = os.path.abspath(os.path.join(HERE, "..", "..", "game", "audio", "generated"))
FPS = 60


def load(name: str) -> np.ndarray:
	out = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(GEN, name + ".ogg"), "-f", "f32le", "-ac", "1", "-"], capture_output=True, check=True).stdout
	return np.frombuffer(out, dtype="<f4").astype(float)


def smoothstep(a: float, b: float, x: float) -> float:
	t = min(1.0, max(0.0, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)


def scenario() -> list:
	"""Per-frame (rpm_ratio, throttle, speed, drift, nitro, grounded)."""
	f = []
	for _ in range(60):
		f.append((0.0, 0.0, 0.0, 0.0, False, True))
	speed = 0.0
	for gear in range(3):
		lo = 0.35 if gear else 0.05
		for i in range(110):
			r = lo + (1.0 - lo) * i / 110
			speed += 0.9 / (gear + 1)
			f.append((r, 1.0, speed, 0.0, False, True))
	for i in range(40):  # bounce off the limiter
		f.append((1.0, 1.0, speed, 0.0, False, True))
	for i in range(80):  # lift
		f.append((max(0.3, 1.0 - i / 80), 0.0, speed, 0.0, False, True))
	for i in range(120):  # back on, nitro
		f.append((0.5 + 0.4 * i / 120, 1.0, speed, 0.0, i > 30, True))
	for i in range(100):  # drift
		f.append((0.7, 0.8, speed * 0.8, 0.8, False, True))
	for i in range(60):
		f.append((0.2, 0.0, 30.0, 0.0, False, True))
	return f


def render(car: str) -> np.ndarray:
	c = E.CARS[car]
	idle, red = c["idle_rpm"], c["redline"]
	bases = dict(c["bases"])
	loops = {k: load(f"eng_{car}_{k}") for k in ("idle", "mid", "high", "off")}
	extra = {k: load("car_" + k) for k in ("turbo", "nitro", "squeal", "wind")}
	frames = scenario()
	spf = SR // FPS
	n = len(frames) * spf
	keys = list(loops) + list(extra)
	gains = {k: np.zeros(len(frames)) for k in keys}
	pitches = {k: np.ones(len(frames)) for k in keys}
	rpm = idle
	thr = 0.0
	speed = 0.0
	drift = 0.0
	boost = 0.0
	nitro_g = 0.0
	sq_g = 0.0
	dt = 1.0 / FPS
	for i, (rr, t_thr, t_sp, t_dr, t_ni, t_gr) in enumerate(frames):
		t_rpm = idle + (red - idle) * rr
		rpm += (t_rpm - rpm) * (1 - np.exp(-dt * 14))
		thr += (t_thr - thr) * (1 - np.exp(-dt * 12))
		speed += (t_sp - speed) * (1 - np.exp(-dt * 8))
		drift += (t_dr - drift) * (1 - np.exp(-dt * 10))
		rn = min(1, max(0, (rpm - idle) / (red - idle)))
		load_gain = (0.95 + (0.42 - 0.95) * rn) * (1 - thr) + thr
		limiter = 0.55 if (t_rpm >= red * 0.995 and thr > 0.5 and (i * dt) % 0.075 < 0.03) else 1.0
		x1 = np.sqrt(bases["idle"] * bases["mid"])
		x2 = np.sqrt(bases["mid"] * bases["high"])
		t1 = smoothstep(x1 * 0.8, x1 * 1.25, rpm)
		t2 = smoothstep(x2 * 0.82, x2 * 1.2, rpm)
		g = S.db(-4.5) * load_gain * limiter
		for k, w in (("idle", np.cos(t1 * np.pi / 2)), ("mid", np.sin(t1 * np.pi / 2) * np.cos(t2 * np.pi / 2)), ("high", np.sin(t2 * np.pi / 2))):
			gains[k][i] = w * g
			pitches[k][i] = rpm / bases[k]
		gains["off"][i] = (1 - thr) * smoothstep(idle * 1.4, idle * 2.6, rpm) * 0.85 * S.db(-4.5)
		pitches["off"][i] = rpm / bases["off"]
		want = thr * smoothstep(0.25, 0.9, rn) if t_thr > 0.4 else 0.0
		rate = 1.6 if want > boost else 7.0
		boost += np.clip(want - boost, -rate * dt, rate * dt)
		gains["turbo"][i] = boost ** 1.5 * c["turbo"] * 0.22
		pitches["turbo"][i] = 0.55 + 0.75 * boost
		nitro_g += np.clip((1.0 if t_ni else 0.0) - nitro_g, -3 * dt, 8 * dt)
		gains["nitro"][i] = nitro_g * 0.5
		pitches["nitro"][i] = 0.9 + min(1, speed / 300) * 0.25
		sq = smoothstep(0.12, 0.6, drift) * (1 if t_gr else 0) * min(1, max(0, (speed - 8) / 25))
		sq_g += np.clip(sq - sq_g, -4 * dt, 6 * dt)
		gains["squeal"][i] = sq_g * 0.42
		pitches["squeal"][i] = 0.88 + 0.22 * drift + min(speed / 400, 0.15)
		sp = min(1.2, speed / 300)
		gains["wind"][i] = sp ** 1.6 * 0.45
		pitches["wind"][i] = 0.75 + 0.45 * sp
	out = np.zeros(n)
	src = {**loops, **extra}
	for k in keys:
		x = src[k]
		g = np.repeat(gains[k], spf)
		p = np.repeat(pitches[k], spf)
		# smooth the per-frame steps a little like the audio server's volume ramp
		pos = np.cumsum(p) % x.shape[0]
		i0 = np.floor(pos).astype(int)
		fr = pos - i0
		y = x[i0] * (1 - fr) + x[(i0 + 1) % x.shape[0]] * fr
		out += y * g
	return out


def main() -> None:
	out_dir = sys.argv[1]
	cars = sys.argv[2:] or list(E.CARS)
	os.makedirs(out_dir, exist_ok=True)
	for car in cars:
		x = render(car)
		peak = float(np.max(np.abs(x)))
		print(f"{car}: {x.shape[0] / SR:.1f}s peak {20 * np.log10(peak):.1f} dBFS")
		path = os.path.join(out_dir, f"preview_{car}.ogg")
		S.write_ogg(path, np.clip(x, -1, 1), 4)
		S.spectrogram_png(path, os.path.join(out_dir, f"preview_{car}.png"))


if __name__ == "__main__":
	main()
