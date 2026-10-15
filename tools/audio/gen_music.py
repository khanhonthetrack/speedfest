"""Two original synthwave loops: music_menu (96 BPM, A minor) and music_race (128 BPM, E minor).

Rendered circularly: notes and effect tails that run past the end wrap to the start, and the
reverb and delays are circular convolutions, so both tracks loop seamlessly.
Instruments: kick/snare/clap/hats/crash, saw bass with filter envelope, detuned saw pads,
pulse pluck arpeggio, saw lead with vibrato, sidechain ducking on the kick.
"""
from __future__ import annotations

import numpy as np

import synth as S

SR = S.SR

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
	"G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def chord(name: str) -> tuple[int, list[int]]:
	"""'Am' -> (root pitch class, intervals). Supports maj, m, sus2, 7."""
	root = name[0] + (name[1] if len(name) > 1 and name[1] in "#b" else "")
	q = name[len(root):]
	iv = {"": [0, 4, 7], "m": [0, 3, 7], "sus2": [0, 2, 7], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "7": [0, 4, 7, 10]}[q]
	return NOTE[root], iv


class Song:
	def __init__(self, bpm: float, bars: int, seed: int):
		self.bpm = bpm
		self.bars = bars
		self.spb = 60.0 / bpm
		self.n = int(round(bars * 4 * self.spb * SR))
		self.r = S.rng(seed)
		self.buses = {k: np.zeros((self.n, 2)) for k in ("drums", "bass", "pad", "arp", "lead", "fx")}
		self.rev = np.zeros((self.n, 2))
		self.dly = np.zeros((self.n, 2))
		self.kicks: list[int] = []

	def idx(self, beat: float) -> int:
		return int(round(beat * self.spb * SR))

	def put(self, bus: str, beat: float, mono: np.ndarray, pan: float = 0.0, rev: float = 0.0, dly: float = 0.0, gain: float = 1.0) -> None:
		st = S.pan(mono * gain, pan)
		i = self.idx(beat)
		S.add_wrap(self.buses[bus], st, i)
		if rev > 0:
			S.add_wrap(self.rev, st * rev, i)
		if dly > 0:
			S.add_wrap(self.dly, st * dly, i)

	def put_st(self, bus: str, beat: float, st: np.ndarray, rev: float = 0.0, dly: float = 0.0) -> None:
		i = self.idx(beat)
		S.add_wrap(self.buses[bus], st, i)
		if rev > 0:
			S.add_wrap(self.rev, st * rev, i)
		if dly > 0:
			S.add_wrap(self.dly, st * dly, i)

	# ------------------------------------------------------------------ drums
	def kick(self, beat: float, vel: float = 1.0) -> None:
		self.put("drums", beat, KICK * vel, 0.0, rev=0.02)
		self.kicks.append(self.idx(beat))

	def snare(self, beat: float, vel: float = 1.0, rev: float = 0.35) -> None:
		self.put("drums", beat, SNARE * vel, 0.0, rev=rev)

	def clap(self, beat: float, vel: float = 1.0) -> None:
		self.put("drums", beat, CLAP * vel, 0.05, rev=0.3)

	def hat(self, beat: float, vel: float = 1.0, open_: bool = False) -> None:
		x = HAT_O if open_ else HAT_C
		self.put("drums", beat, x * vel * (0.9 + 0.2 * self.r.random()), 0.25 if open_ else -0.2, rev=0.05)

	def crash(self, beat: float, vel: float = 1.0) -> None:
		self.put("drums", beat, CRASH * vel, 0.1, rev=0.25)

	def riser(self, beat: float, beats: float, vel: float = 1.0) -> None:
		n = self.idx(beats)
		u = np.linspace(0, 1, n)
		x = S.filtered_sweep(S.noise(n, int(self.r.integers(1 << 30))), lambda v: 300 + 7000 * v ** 2, q=1.5)
		x = x * u ** 2 * vel * 0.35
		self.put("fx", beat, x, 0.0, rev=0.4)

	# ------------------------------------------------------------------ pitched
	def bass(self, beat: float, beats: float, midi: int, vel: float = 1.0, bright: float = 1.0) -> None:
		dur = beats * self.spb
		n = int((dur + 0.08) * SR)
		t = S.t_axis(n)
		f = np.full(n, S.midi_hz(midi))
		cut = 180 + 1300 * bright * vel * np.exp(-t / 0.09)
		x = S.bank("saw").render(f, cut) * 0.8 + S.bank("square").render(f, cut * 0.8) * 0.35
		x += 0.55 * S.sine(f, n)  # weight
		x *= S.env_adsr(n, 0.003, 0.2, 0.75, 0.04, dur * 0.92)
		self.put("bass", beat, x * vel * 0.3, 0.0)

	def pad(self, beat: float, beats: float, midis: list[int], vel: float = 1.0, cutoff: float = 1800.0) -> None:
		dur = beats * self.spb
		n = int((dur + 1.2) * SR)
		t = S.t_axis(n)
		st = np.zeros((n, 2))
		env = S.env_adsr(n, 0.35, 1.0, 0.85, 0.9, dur)
		cut = cutoff * (1.0 + 0.25 * np.sin(2 * np.pi * 0.2 * t + self.r.random() * 6))
		for m in midis:
			for k, det in enumerate((-0.11, 0.0, 0.12)):
				x = S.bank("saw").render(np.full(n, S.midi_hz(m + det)), cut, phase0=self.r.random())
				p = (-0.7, 0.0, 0.7)[k]
				st += S.pan(x, p)
		st *= env[:, None] * vel * 0.22 / max(1, len(midis)) ** 0.5
		self.put_st("pad", beat, st, rev=0.45)

	def pluck(self, beat: float, midi: int, vel: float = 1.0, pan: float = 0.0, decay: float = 0.16, cutoff: float = 2600.0) -> None:
		n = int((decay * 5 + 0.02) * SR)
		t = S.t_axis(n)
		f = np.full(n, S.midi_hz(midi))
		cut = 350 + cutoff * np.exp(-t / (decay * 0.6))
		x = S.bank("pulse25").render(f, cut) * S.env_ad(n, 0.002, decay)
		self.put("arp", beat, x * vel * 0.5, pan, rev=0.25, dly=0.35)

	def lead(self, beat: float, beats: float, midi: int, vel: float = 1.0, bright: float = 1.0) -> None:
		dur = beats * self.spb
		n = int((dur + 0.4) * SR)
		t = S.t_axis(n)
		vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.3, 0, 1)
		f = S.midi_hz(midi) * vib
		cut = (2000 + 1600 * np.exp(-t / 0.2)) * bright
		x = S.bank("saw").render(f, cut) + 0.7 * S.bank("saw").render(f * 1.006, cut, phase0=0.3)
		x += 0.3 * S.bank("square").render(f * 0.5, cut * 0.5)
		x *= S.env_adsr(n, 0.015, 0.3, 0.8, 0.22, dur * 0.95)
		self.put("lead", beat, x * vel * 0.36, 0.0, rev=0.3, dly=0.3)

	# ------------------------------------------------------------------ mix
	def render(self, sidechain: dict, delay_beats: float = 0.75, reverb_s: float = 2.6, master_gain_db: float = 0.0) -> np.ndarray:
		# sidechain gain curve from the kicks (circular)
		pulse = np.zeros(self.n)
		for k in self.kicks:
			pulse[k % self.n] = 1.0
		ln = int(0.32 * SR)
		tt = S.t_axis(ln)
		shape = np.clip(tt / 0.006, 0, 1) * np.exp(-tt / 0.11)
		kern = np.zeros(self.n)
		kern[:ln] = shape
		duck = np.fft.irfft(np.fft.rfft(pulse) * np.fft.rfft(kern), n=self.n)
		duck = np.clip(duck, 0, 1)
		mix = np.zeros((self.n, 2))
		for name, bus in self.buses.items():
			d = sidechain.get(name, 0.0)
			if d > 0:
				bus = bus * (1.0 - d * duck)[:, None]
			mix += bus
		# delay -> also into reverb
		wet_d = S.pingpong_circular(self.dly, delay_beats * self.spb, 0.45, taps=5)
		ir = S.reverb_ir(reverb_s, 7, damp_hz=5500)
		wet_r = S.convolve_circular(self.rev + wet_d * 0.3, ir)
		wet_r = S.highpass(wet_r, 180, 1.0)
		mix += wet_d * 0.55 + wet_r * 0.28
		mix = S.highpass(mix, 28, 2.0)
		# gentle glue: soft clip at a moderate level, then peak normalise
		mix = S.normalize_peak(mix, -1.0) * S.db(master_gain_db)
		mix = S.soft_clip(mix * 1.15, 1.4)
		return S.normalize_peak(mix, -1.0)


# ---------------------------------------------------------------------- drum samples

def _mk_drums() -> None:
	global KICK, SNARE, CLAP, HAT_C, HAT_O, CRASH
	n = int(0.45 * SR)
	t = S.t_axis(n)
	f = 46 + 110 * np.exp(-t / 0.035) + 40 * np.exp(-t / 0.006)
	k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22)
	k += S.bandpass(S.noise(n, 1), 3500, 1.0) * np.exp(-t / 0.003) * 0.25
	KICK = S.normalize_peak(S.soft_clip(k, 1.6), -1) * 0.95
	n = int(0.5 * SR)
	t = S.t_axis(n)
	body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.06) + 0.5 * np.sin(2 * np.pi * 330 * t) * np.exp(-t / 0.04)
	nz = S.bandpass(S.noise(n, 2), 3800, 0.6) * np.exp(-t / 0.13)
	SNARE = S.normalize_peak(body * 0.6 + nz, -1) * 0.6
	clap = np.zeros(n)
	for i, off in enumerate((0.0, 0.011, 0.022, 0.034)):
		ln = n - int(off * SR)
		tt = S.t_axis(ln)
		burst = S.bandpass(S.noise(ln, 10 + i), 1300, 1.2) * np.exp(-tt / (0.008 if i < 3 else 0.12))
		clap[int(off * SR):] += burst
	CLAP = S.normalize_peak(clap, -1) * 0.5
	n = int(0.09 * SR)
	t = S.t_axis(n)
	HAT_C = S.normalize_peak(S.highpass(S.noise(n, 3), 8000, 2) * np.exp(-t / 0.018), -1) * 0.22
	n = int(0.5 * SR)
	t = S.t_axis(n)
	HAT_O = S.normalize_peak(S.highpass(S.noise(n, 4), 7000, 2) * np.exp(-t / 0.13), -1) * 0.18
	n = int(2.5 * SR)
	t = S.t_axis(n)
	CRASH = S.normalize_peak(S.highpass(S.noise(n, 5), 4500, 1.5) * np.exp(-t / 0.7), -1) * 0.22


KICK = SNARE = CLAP = HAT_C = HAT_O = CRASH = np.zeros(1)


def _voicing(name: str, base: int = 57, n: int = 4) -> list[int]:
	"""Close voicing of the chord around `base` (midi)."""
	root, iv = chord(name)
	notes = []
	for o in range(-1, 4):
		for i in iv:
			m = 12 * (o + 4) + root + i
			if base - 2 <= m:
				notes.append(m)
	notes = sorted(set(notes))
	return notes[:n]


def _bass_root(name: str, octave: int = 2) -> int:
	root, _ = chord(name)
	return 12 * (octave + 1) + root


def _arp_notes(name: str, base: int) -> list[int]:
	root, iv = chord(name)
	tones = [m for m in range(base, base + 25) if (m - root) % 12 in [i % 12 for i in iv]]
	return tones[:5]


def _play_melody(s: Song, bar0: int, bars: list, vel: float = 1.0, bright: float = 1.0, octave: int = 0) -> None:
	for b, notes in enumerate(bars):
		beat = (bar0 + b) * 4
		for (m, d) in notes:
			if m is not None:
				s.lead(beat, d * 0.98, m + 12 * octave, vel * (0.9 + 0.1 * s.r.random()), bright)
			beat += d


# ---------------------------------------------------------------------- menu track

def music_menu() -> np.ndarray:
	_mk_drums()
	s = Song(96.0, 32, 101)
	main = ["Am", "F", "C", "G"] * 2
	bridge = ["F", "G", "Em", "Am", "F", "G", "E", "E"]
	prog = main + main + bridge + main
	for bar, ch in enumerate(prog):
		sec = bar // 8
		b0 = bar * 4
		# pads everywhere, slightly brighter in the middle sections
		s.pad(b0, 4.0, _voicing(ch, 57, 4), vel=0.9, cutoff=1500 if sec in (0, 3) else 2100)
		# arpeggio: 16ths, up-down pattern; an octave up in the last section
		tones = _arp_notes(ch, 64 if sec != 3 else 69)
		pat = [0, 1, 2, 3, 4, 3, 2, 1]
		for i in range(16):
			v = 0.75 if i % 4 == 0 else 0.55
			if sec == 0 and bar < 2:
				v *= (bar * 16 + i) / 32.0 + 0.25  # fade the arp in at the very start
			s.pluck(b0 + i * 0.25, tones[pat[i % 8]], v, pan=0.35 * np.sin(i * 0.8), decay=0.14, cutoff=1800 if sec == 0 else 2600)
		# bass
		root = _bass_root(ch, 2)
		if sec == 0:
			s.bass(b0, 3.9, root, 0.8, bright=0.4)
		else:
			for i in range(8):
				m = root + (12 if i % 2 == 1 and sec == 2 else 0)
				s.bass(b0 + i * 0.5, 0.45, m, 0.9 if i % 2 == 0 else 0.75, bright=0.8)
		# drums
		if sec == 0:
			for i in range(4):
				s.hat(b0 + i + 0.5, 0.6)
		else:
			s.kick(b0, 1.0)
			s.kick(b0 + 2, 0.95)
			if bar % 2 == 1:
				s.kick(b0 + 2.75, 0.6)
			s.snare(b0 + 1, 0.9, rev=0.5)
			s.snare(b0 + 3, 0.9, rev=0.5)
			for i in range(8):
				s.hat(b0 + i * 0.5, 0.8 if i % 2 == 1 else 0.5)
			if bar % 4 == 3:
				s.hat(b0 + 3.5, 0.7, open_=True)
		if bar in (8, 16, 24):
			s.crash(b0, 0.9)
	s.riser(7 * 4, 4, 0.8)
	s.riser(15 * 4, 4, 0.6)
	# last bar fill
	for i in range(8):
		s.snare(31 * 4 + 2 + i * 0.25, 0.35 + 0.08 * i, rev=0.3)
	# lead in the bridge
	A4, B4, C5, D5, E5, F5, G5, Gs4 = 69, 71, 72, 74, 76, 77, 79, 68
	mel = [
		[(A4, 1.5), (C5, 0.5), (E5, 1), (D5, 1)],
		[(D5, 1.5), (B4, 0.5), (D5, 1), (G5, 1)],
		[(E5, 3), (D5, 0.5), (C5, 0.5)],
		[(B4, 1), (C5, 1), (A4, 2)],
		[(A4, 1.5), (C5, 0.5), (F5, 1), (E5, 1)],
		[(D5, 1.5), (G5, 0.5), (F5, 1), (D5, 1)],
		[(E5, 2), (Gs4, 1), (B4, 1)],
		[(E5, 2.5), (None, 1.5)],
	]
	_play_melody(s, 16, mel, 0.85, 0.9)
	return s.render({"bass": 0.35, "pad": 0.45, "arp": 0.3, "lead": 0.15}, delay_beats=0.75, reverb_s=3.0)


# ---------------------------------------------------------------------- race track

def music_race() -> np.ndarray:
	_mk_drums()
	s = Song(128.0, 40, 202)
	main = ["Em", "C", "G", "D"] * 2
	brk = ["C", "D", "Em", "Em", "C", "D", "B", "B"]
	prog = main + main + main + brk + main
	for bar, ch in enumerate(prog):
		sec = bar // 8
		b0 = bar * 4
		root = _bass_root(ch, 2)
		if root > 45:
			root -= 12
		# --- drums
		if sec != 3 or bar % 8 >= 6:
			for i in range(4):
				s.kick(b0 + i, 1.0)
		else:
			s.kick(b0, 1.0)
			s.kick(b0 + 2.5, 0.8)
		if sec >= 1:
			s.clap(b0 + 1, 0.9)
			s.clap(b0 + 3, 0.9)
			s.snare(b0 + 1, 0.5, rev=0.25)
			s.snare(b0 + 3, 0.5, rev=0.25)
		if sec != 3:
			for i in range(16):
				if i % 4 == 2:
					s.hat(b0 + i * 0.25, 0.85, open_=(sec >= 1))
				elif i % 2 == 1 or sec >= 2:
					s.hat(b0 + i * 0.25, 0.45 if i % 2 else 0.3)
		if bar in (8, 16, 24, 32):
			s.crash(b0, 1.0)
		# --- bass: rolling 16ths with octave jumps (half-time in the break)
		if sec == 3:
			s.bass(b0, 1.9, root, 0.9, bright=0.6)
			s.bass(b0 + 2, 1.9, root, 0.8, bright=0.6)
		else:
			for i in range(16):
				if i % 4 == 0:
					continue  # leave room for the kick
				m = root + (12 if i % 4 == 3 else 0)
				s.bass(b0 + i * 0.25, 0.22, m, 0.95 if i % 4 == 3 else 0.8, bright=0.9 + 0.3 * (sec >= 2))
		# --- arp: 16ths, chord tones, rising across the section
		tones = _arp_notes(ch, 64)
		pat = [0, 2, 1, 3, 2, 4, 3, 1]
		for i in range(16):
			v = 0.7 if i % 2 == 0 else 0.5
			if sec == 0:
				v *= 0.8
			s.pluck(b0 + i * 0.25, tones[pat[(i + bar) % 8]] + (12 if sec == 3 and i % 4 == 2 else 0), v, pan=0.4 * np.sin(i * 1.1 + bar), decay=0.11, cutoff=2200 + 300 * sec)
		# --- pads from section 2 on
		if sec >= 1:
			s.pad(b0, 4.0, _voicing(ch, 59, 4), vel=0.75 if sec != 3 else 1.0, cutoff=1700 if sec != 3 else 2600)
	s.riser(15 * 4, 4, 0.9)
	s.riser(31 * 4, 4, 1.0)
	for i in range(8):  # final fill into the loop start
		s.snare(39 * 4 + 2 + i * 0.25, 0.4 + 0.08 * i, rev=0.2)
	B4, D5, E5, Fs5, G5, A5, B5, D6, E6 = 71, 74, 76, 78, 79, 81, 83, 86, 88
	hook = [
		[(E5, 0.75), (G5, 0.75), (B5, 0.5), (A5, 1), (G5, 0.5), (Fs5, 0.5)],
		[(G5, 1.5), (E5, 0.5), (E5, 1), (D5, 1)],
		[(D5, 0.75), (G5, 0.75), (B5, 0.5), (D6, 1), (B5, 0.5), (A5, 0.5)],
		[(A5, 1.5), (Fs5, 0.5), (A5, 1), (Fs5, 1)],
		[(E5, 0.75), (G5, 0.75), (B5, 0.5), (A5, 1), (G5, 0.5), (Fs5, 0.5)],
		[(G5, 1.5), (E5, 0.5), (E5, 1), (D5, 1)],
		[(D5, 0.75), (G5, 0.75), (B5, 0.5), (D6, 1), (E6, 0.5), (D6, 0.5)],
		[(B5, 2), (None, 2)],
	]
	_play_melody(s, 16, hook, 0.9, 1.0)
	_play_melody(s, 32, hook, 0.95, 1.1)
	brk_mel = [
		[(E6, 2), (D6, 2)],
		[(Fs5 + 12, 2), (D6, 2)],
		[(B5, 3), (None, 1)],
		[(G5, 2), (B5, 2)],
		[(E6, 2), (G5 + 12, 2)],
		[(Fs5 + 12, 2), (A5 + 12, 2)],
		[(B5 + 12, 4)],
		[(None, 4)],
	]
	_play_melody(s, 24, brk_mel, 0.6, 0.8, octave=-1)
	return s.render({"bass": 0.45, "pad": 0.55, "arp": 0.35, "lead": 0.12}, delay_beats=0.75, reverb_s=2.2)


ALL = {"music_menu": music_menu, "music_race": music_race}
