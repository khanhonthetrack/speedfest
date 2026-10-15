"""Original dark-trap beats for SpeedFest (owner, session 4: "menu is dark trap, Future / Southside /
808 Mafia type beat. For the rest make it similar"). Everything is synthesized here from scratch
(no samples, no third-party material), so the music is fully original and royalty-free.

Tracks (all seamless loops, rendered circularly like gen_music.py):
  music_menu      140 BPM, C# minor  dark bell + choir, sliding 808s, hat rolls
  music_arena     150 BPM, F minor   hype: brass stabs + bell, heavier drums
  music_downtown  142 BPM, A minor   rainy night: felt piano + choir, phrygian b2
  music_coast     136 BPM, E minor   melodic: breathy flute + pluck
  music_race      144 BPM, G minor   generic race beat (fallback for any other track)

Form per loop (32 bars): intro (4, filtered, no drums) -> beat A (12) -> break (4, sparse) ->
beat B (12, melody up / counter line). Half-time feel: clap on beat 3, 808 follows the kick.
"""
from __future__ import annotations

import numpy as np

import synth as S

SR = S.SR


# --------------------------------------------------------------------------- instruments (mono)

def layer(*parts: np.ndarray) -> np.ndarray:
	"""Sum mono sounds of different lengths (zero-padded)."""
	n = max(p.shape[0] for p in parts)
	out = np.zeros(n)
	for p in parts:
		out[:p.shape[0]] += p
	return out


def i808(midi: float, dur: float, glide_to: float | None = None, glide_t: float = 0.09, drive: float = 2.2) -> np.ndarray:
	"""Trap 808: sine with a pitch punch, long decay, optional glide at the end, saturated."""
	n = int((dur + 0.06) * SR)
	t = S.t_axis(n)
	f0 = S.midi_hz(midi)
	f = f0 * (1.0 + 1.1 * np.exp(-t / 0.018))           # punch: starts ~an octave up
	if glide_to is not None:
		g0 = max(dur - glide_t, 0.0)
		u = np.clip((t - g0) / glide_t, 0.0, 1.0)
		f = f * (2.0 ** ((glide_to - midi) / 12.0)) ** (u * u * (3 - 2 * u))
	x = S.sine(f, n)
	env = np.clip(t / 0.003, 0, 1) * np.exp(-t / 1.4)
	rel = np.clip((dur + 0.06 - t) / 0.06, 0, 1)
	x = x * env * rel
	x = np.tanh(drive * x) / np.tanh(drive)              # harmonics so it reads on laptop speakers
	return S.lowpass(x, 3200, 1.0)


def kick() -> np.ndarray:
	n = int(0.32 * SR)
	t = S.t_axis(n)
	f = 52 + 140 * np.exp(-t / 0.028)
	k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.13)
	k += S.bandpass(S.noise(n, 21), 4200, 1.0) * np.exp(-t / 0.002) * 0.35
	return S.normalize_peak(np.tanh(1.8 * k), -1) * 0.8


def clap(seed: int = 31) -> np.ndarray:
	n = int(0.6 * SR)
	t = S.t_axis(n)
	x = np.zeros(n)
	for i, off in enumerate((0.0, 0.009, 0.019, 0.03)):
		o = int(off * SR)
		tt = S.t_axis(n - o)
		x[o:] += S.bandpass(S.noise(n - o, seed + i), 1500, 1.1) * np.exp(-tt / (0.007 if i < 3 else 0.16))
	body = np.sin(2 * np.pi * 210 * t) * np.exp(-t / 0.05) * 0.4
	snare = S.highpass(S.noise(n, seed + 9), 2500, 1.5) * np.exp(-t / 0.09) * 0.5
	return S.normalize_peak(x + body + snare, -1) * 0.62


def hat(open_: bool = False, pitch: float = 1.0, seed: int = 41) -> np.ndarray:
	"""808-style metallic hat: six detuned square waves, band-passed, plus a little noise."""
	n = int((0.38 if open_ else 0.07) * SR)
	t = S.t_axis(n)
	x = np.zeros(n)
	for k, f in enumerate((205.3, 304.4, 369.6, 522.7, 540.0, 800.0)):
		ph = (np.arange(n) * f * 1.62 * pitch / SR + 0.13 * k) % 1.0
		x += np.where(ph < 0.5, 1.0, -1.0)
	x = S.bandpass(x, 9500 * pitch, 1.2) + S.highpass(S.noise(n, seed), 9000, 2) * 0.4
	x = S.highpass(x, 7000, 2)
	x *= np.exp(-t / (0.11 if open_ else 0.016))
	return S.normalize_peak(x, -1) * (0.16 if open_ else 0.2)


def bell(midi: float, dur: float = 1.6, bright: float = 1.0) -> np.ndarray:
	"""Dark FM bell (carrier:modulator 1:3.5), slightly detuned double for width."""
	n = int((dur + 0.6) * SR)
	t = S.t_axis(n)
	f = S.midi_hz(midi)
	out = np.zeros(n)
	for det in (0.0, 0.0035):
		fc = f * (1 + det)
		idx = (2.4 * bright) * np.exp(-t / 0.35) + 0.25
		mod = np.sin(2 * np.pi * fc * 3.5 * t) * idx
		out += np.sin(2 * np.pi * fc * t + mod)
	out += 0.35 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / 0.25)
	return out * np.clip(t / 0.002, 0, 1) * np.exp(-t / (dur * 0.45)) * 0.32


def piano(midi: float, dur: float = 1.8) -> np.ndarray:
	"""Felt piano: inharmonic partials with per-partial decay, soft attack, low-passed."""
	n = int((dur + 0.5) * SR)
	t = S.t_axis(n)
	f = S.midi_hz(midi)
	x = np.zeros(n)
	for k in range(1, 9):
		fk = f * k * np.sqrt(1 + 0.0004 * k * k)
		x += np.sin(2 * np.pi * fk * t + 0.3 * k) * (0.9 ** k) / k * np.exp(-t * (0.8 + 0.55 * k) / dur * 1.6)
	x *= np.clip(t / 0.006, 0, 1)
	return S.lowpass(x, 2400, 1.0) * 0.55


def flute(midi: float, dur: float) -> np.ndarray:
	"""Breathy flute (trap 'Mask Off' colour): sine + 2nd/3rd partials, vibrato, breath noise."""
	n = int((dur + 0.25) * SR)
	t = S.t_axis(n)
	vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.25, 0, 1)
	f = S.midi_hz(midi) * vib
	x = S.sine(f, n) + 0.22 * S.sine(f * 2, n) + 0.06 * S.sine(f * 3, n)
	x += S.bandpass(S.noise(n, int(midi * 7)), S.midi_hz(midi) * 2.0, 2.0) * 0.18
	env = S.env_adsr(n, 0.05, 0.15, 0.8, 0.2, dur)
	return x * env * 0.3


def pluck(midi: float, decay: float = 0.5, seed: int = 0) -> np.ndarray:
	"""Karplus-Strong string, dark (averaging + low-pass)."""
	n = int((decay * 4 + 0.05) * SR)
	p = max(2, int(SR / S.midi_hz(midi)))
	buf = S.lowpass(S.noise(p * 2, 500 + seed), 3000, 1)[:p]
	out = np.zeros(n)
	fb = np.exp(-1.0 / (decay * S.midi_hz(midi)))
	ring = buf.copy()
	for i in range(0, n, p):
		m = min(p, n - i)
		out[i:i + m] = ring[:m]
		ring = 0.5 * (ring + np.roll(ring, 1)) * fb
	return S.lowpass(out, 2200, 1) * 0.6


def choir(midis: list[int], dur: float, cutoff: float = 1.0) -> np.ndarray:
	"""'Aah' pad: detuned saws through two vowel formants, slow attack."""
	n = int((dur + 1.4) * SR)
	t = S.t_axis(n)
	x = np.zeros(n)
	for m in midis:
		for det in (-0.08, 0.0, 0.09):
			x += S.bank("saw").render(np.full(n, S.midi_hz(m + det)), 3000.0 * cutoff, phase0=(m * 0.37 + det) % 1)
	x = S.bandpass(x, 750, 3.0) + 0.7 * S.bandpass(x, 1150, 3.5) + 0.25 * S.bandpass(x, 2600, 4.0)
	env = S.env_adsr(n, 0.6, 0.8, 0.85, 1.2, dur)
	return x * env * 0.5 / max(1, len(midis)) ** 0.5


def brass(midi: float, dur: float) -> np.ndarray:
	"""Synth brass stab for the hype track."""
	n = int((dur + 0.2) * SR)
	t = S.t_axis(n)
	f = np.full(n, S.midi_hz(midi))
	cut = 600 + 2600 * np.exp(-t / 0.12)
	x = S.bank("saw").render(f, cut) + 0.8 * S.bank("saw").render(f * 1.007, cut, phase0=0.4) + 0.5 * S.bank("saw").render(f * 0.5, cut)
	return x * S.env_adsr(n, 0.01, 0.12, 0.6, 0.12, dur) * 0.22


def rev_cymbal(seconds: float) -> np.ndarray:
	n = int(seconds * SR)
	t = S.t_axis(n)
	x = S.highpass(S.noise(n, 77), 5000, 1.5) * np.exp(-t / 0.9)
	return x[::-1] * 0.25


# --------------------------------------------------------------------------- song

class Trap:
	def __init__(self, bpm: float, bars: int = 32, seed: int = 1):
		self.bpm = bpm
		self.spb = 60.0 / bpm
		self.bars = bars
		self.n = int(round(bars * 4 * self.spb * SR))
		self.r = np.random.default_rng(seed)
		self.bus = {k: np.zeros((self.n, 2)) for k in ("kick", "808", "drums", "hats", "mel", "pad", "fx")}
		self.rev = np.zeros((self.n, 2))
		self.dly = np.zeros((self.n, 2))
		self.kicks: list[int] = []
		self.K = kick()
		self.C = clap()
		self.HC = [hat(False, p, 41 + i) for i, p in enumerate((1.0, 1.06, 0.94, 1.12))]
		self.HO = hat(True, 1.0, 49)

	def i(self, beat: float) -> int:
		return int(round(beat * self.spb * SR))

	def put(self, bus: str, beat: float, x: np.ndarray, pan: float = 0.0, rev: float = 0.0, dly: float = 0.0, gain: float = 1.0) -> None:
		st = S.pan(x * gain, pan)
		k = self.i(beat)
		S.add_wrap(self.bus[bus], st, k)
		if rev:
			S.add_wrap(self.rev, st * rev, k)
		if dly:
			S.add_wrap(self.dly, st * dly, k)

	# drums
	def kick(self, beat: float, vel: float = 1.0) -> None:
		self.put("kick", beat, self.K * vel)
		self.kicks.append(self.i(beat))

	def clap(self, beat: float, vel: float = 1.0) -> None:
		self.put("drums", beat, self.C * vel, 0.0, rev=0.22)

	def hat(self, beat: float, vel: float = 0.8, pitch_i: int = 0, pan: float = -0.15) -> None:
		self.put("hats", beat, self.HC[pitch_i % len(self.HC)] * vel * (0.85 + 0.3 * self.r.random()), pan, rev=0.03)

	def ohat(self, beat: float, vel: float = 0.8) -> None:
		self.put("hats", beat, self.HO * vel, 0.2, rev=0.06)

	def hats_bar(self, bar: int, style: int) -> None:
		"""One bar of trap hats: 8ths with 16th, triplet and 1/32 rolls depending on `style`."""
		b0 = bar * 4
		pattern = {
			0: [(x * 0.5, 1) for x in range(8)],
			1: [(x * 0.5, 1) for x in range(6)] + [(3.0 + x * 0.25, 1) for x in range(4)],
			2: [(x * 0.5, 1) for x in range(4)] + [(2.0 + x / 3.0, 1) for x in range(3)] + [(3.0 + x * 0.125, 2) for x in range(8)],
			3: [(x * 0.25, 1) for x in range(12)] + [(3.0 + x / 6.0, 3) for x in range(6)],
			4: [(x * 0.5, 1) for x in range(5)] + [(2.5 + x * 0.125, 2) for x in range(4)] + [(3.0 + x * 0.25, 1) for x in range(4)],
		}[style]
		for k, (off, pi) in enumerate(pattern):
			acc = 1.0 if (off * 2) % 2 == 0 else 0.72
			ramp = 0.7 + 0.3 * ((k % 4) / 3.0) if pi > 1 else acc
			self.hat(b0 + off, 0.8 * ramp, pitch_i=(k if pi == 3 else pi - 1))

	def drop_808(self, beat: float, beats: float, midi: float, glide_to: float | None = None, vel: float = 1.0) -> None:
		self.put("808", beat, i808(midi, beats * self.spb * 0.98, glide_to) * vel * 0.62)

	def riser(self, beat: float, beats: float) -> None:
		n = self.i(beats)
		u = np.linspace(0, 1, n)
		x = S.filtered_sweep(S.noise(n, int(self.r.integers(1 << 30))), lambda v: 400 + 7000 * v ** 2, q=1.6) * u ** 2 * 0.22
		self.put("fx", beat, x, 0.0, rev=0.3)

	def revcym(self, beat_end: float, beats: float = 2.0) -> None:
		x = rev_cymbal(beats * self.spb)
		self.put("fx", beat_end - beats, x, 0.1, rev=0.2)

	def render(self, filt_bars: tuple[int, int] = (0, 4)) -> np.ndarray:
		# sidechain: the 808/kick ducks the melodic buses a little (pump)
		pulse = np.zeros(self.n)
		for k in self.kicks:
			pulse[k % self.n] = 1.0
		ln = int(0.25 * SR)
		tt = S.t_axis(ln)
		kern = np.zeros(self.n)
		kern[:ln] = np.clip(tt / 0.005, 0, 1) * np.exp(-tt / 0.09)
		duck = np.clip(np.fft.irfft(np.fft.rfft(pulse) * np.fft.rfft(kern), n=self.n), 0, 1)
		mix = np.zeros((self.n, 2))
		for name, b in self.bus.items():
			d = {"mel": 0.25, "pad": 0.35, "hats": 0.1}.get(name, 0.0)
			if d:
				b = b * (1.0 - d * duck)[:, None]
			if name in ("mel", "pad"):
				# intro: the melody comes in through a closing low-pass (dark, muffled)
				b0, b1 = filt_bars
				i0, i1 = self.i(b0 * 4), self.i(b1 * 4)
				if i1 > i0:
					seg = b[i0:i1]
					lp = S.lowpass(seg, 900, 1.5)
					w = np.linspace(1, 0, i1 - i0)[:, None] ** 2
					b = b.copy()
					b[i0:i1] = lp * w + seg * (1 - w)
			mix += b * {"kick": 1.0, "808": 1.0, "drums": 1.0, "hats": 0.9, "mel": 1.0, "pad": 0.8, "fx": 1.0}[name]
		wet_d = S.pingpong_circular(self.dly, 0.75 * self.spb, 0.42, taps=5, damp_hz=3800)
		ir = S.reverb_ir(2.8, 13, damp_hz=4500)
		wet_r = S.highpass(S.convolve_circular(self.rev + wet_d * 0.3, ir), 220, 1.0)
		mix += wet_d * 0.5 + wet_r * 0.32
		mix = S.highpass(mix, 30, 2.0)
		mix = S.normalize_peak(mix, -1.0)
		mix = np.tanh(mix * 1.5) / np.tanh(1.5)               # glue / loudness
		return S.normalize_peak(mix, -1.0)


# --------------------------------------------------------------------------- arrangement helpers

def beat_section(s: Trap, bar0: int, bars: int, bass: list, kick_pat: list, hat_styles: list, clap_vel: float = 1.0) -> None:
	"""Drums + 808 for `bars` bars. `bass`: per 2-bar cycle list of (beat, beats, midi, glide_to).
	`kick_pat`: beats within 2 bars where the kick lands (the 808 hits are listed separately)."""
	for b in range(bars):
		bar = bar0 + b
		s.clap(bar * 4 + 2, clap_vel)
		s.hats_bar(bar, hat_styles[b % len(hat_styles)])
		if b % 4 == 3:
			s.ohat(bar * 4 + 3.5, 0.6)
	for c in range(0, bars, 2):
		base = (bar0 + c) * 4
		for kb in kick_pat:
			if c + kb / 4.0 < bars:
				s.kick(base + kb)
		for (bb, beats, m, g) in bass:
			if c + bb / 4.0 < bars:
				s.drop_808(base + bb, beats, m, g)


def melody(s: Trap, bar0: int, bars: int, motif: list, inst, octave: int = 0, vel: float = 1.0, pan: float = 0.0, rev: float = 0.35, dly: float = 0.25) -> None:
	"""Repeat a motif (list of (beat_in_cycle, midi, dur_beats)) whose cycle is 2 or 4 bars."""
	cycle = max(4, int(np.ceil(max(b + d for b, m, d in motif) / 4.0)) * 4)
	reps = int(np.ceil(bars * 4 / cycle))
	for r in range(reps):
		for (b, m, d) in motif:
			beat = bar0 * 4 + r * cycle + b
			if beat >= (bar0 + bars) * 4:
				continue
			x = inst(m + 12 * octave, d * s.spb)
			s.put("mel", beat, x * vel, pan, rev=rev, dly=dly)


def pads(s: Trap, bar0: int, bars: int, chords: list, inst=choir, vel: float = 1.0, bars_per_chord: int = 2) -> None:
	for k in range(0, bars, bars_per_chord):
		ch = chords[(k // bars_per_chord) % len(chords)]
		s.put("pad", (bar0 + k) * 4, inst(ch, bars_per_chord * 4 * s.spb) * vel, 0.0, rev=0.45)


def song(s: Trap, motif_a: list, motif_b: list, inst, bass: list, kick_pat: list, chords: list, counter=None, counter_inst=None) -> np.ndarray:
	"""Standard 32-bar form."""
	# intro (0-3): melody + pad, filtered; reverse cymbal into the drop
	melody(s, 0, 4, motif_a, inst, vel=0.9)
	pads(s, 0, 4, chords, vel=0.8)
	s.revcym(16, 2)
	# beat A (4-15)
	beat_section(s, 4, 12, bass, kick_pat, [0, 1, 0, 2, 0, 1, 4, 3])
	melody(s, 4, 12, motif_a, inst)
	pads(s, 4, 12, chords, vel=0.6)
	# break (16-19): hats sparse, melody B, a lone 808 on the downbeat, riser into the drop
	for b in range(16, 20):
		for x in range(4):
			s.hat(b * 4 + x, 0.6)
	s.drop_808(16 * 4, 6, bass[0][2], None, 0.8)
	melody(s, 16, 4, motif_b, inst, vel=0.95)
	pads(s, 16, 4, chords, vel=0.9)
	s.riser(18 * 4, 8)
	s.revcym(80, 2)
	# beat B (20-31): melody + counter line an octave up
	beat_section(s, 20, 12, bass, kick_pat, [0, 2, 1, 3, 0, 4, 1, 3])
	melody(s, 20, 12, motif_a, inst)
	if counter:
		melody(s, 20, 12, counter, counter_inst or inst, octave=1, vel=0.5, pan=0.35, rev=0.4, dly=0.35)
	pads(s, 20, 12, chords, vel=0.6)
	return s.render()


# --------------------------------------------------------------------------- tracks
# Motifs: (beat within the cycle, midi, length in beats). Bass: (beat in 2-bar cycle, beats, midi, glide_to).

def music_menu() -> np.ndarray:
	# 140 BPM, C# minor, harmonic-minor B# for the sinister leading tone. Dark bell + choir.
	s = Trap(140, seed=11)
	a = [(0, 73, 0.5), (0.5, 68, 0.5), (1, 76, 0.75), (2, 75, 0.5), (2.5, 73, 0.5), (3, 68, 1.0),
		(4, 69, 0.5), (4.5, 76, 0.5), (5, 73, 0.5), (5.5, 71, 0.5), (6, 72, 0.75), (6.75, 75, 0.25), (7, 73, 1.0)]
	b = [(0, 80, 1.0), (1, 76, 0.5), (1.5, 75, 0.5), (2, 73, 1.5), (4, 81, 1.0), (5, 76, 0.5), (5.5, 75, 0.5), (6, 72, 1.5)]
	counter = [(0.75, 68, 0.25), (2.75, 68, 0.25), (4.75, 69, 0.25), (6.75, 67, 0.25)]
	bass = [(0, 1.5, 37, None), (1.5, 1.0, 37, 44), (2.75, 1.25, 37, None), (4, 1.5, 33, None), (5.5, 1.0, 33, 32), (6.75, 1.25, 32, None)]
	kicks = [0, 1.5, 2.75, 4, 5.5, 6.75]
	chords = [[61, 64, 68], [57, 61, 64], [54, 57, 61], [56, 60, 63]]
	return song(s, a, b, lambda m, d: bell(m, max(d, 0.9)), bass, kicks, chords, counter, lambda m, d: bell(m, 0.6, 0.6))


def music_arena() -> np.ndarray:
	# 150 BPM, F minor, hype: brass stabs on the off-beats + bell lead, busier 808.
	s = Trap(150, seed=12)
	a = [(0, 77, 0.25), (0.5, 77, 0.25), (0.75, 80, 0.5), (1.5, 79, 0.5), (2, 77, 0.5), (3, 72, 0.5), (3.5, 75, 0.5),
		(4, 77, 0.25), (4.5, 77, 0.25), (4.75, 80, 0.5), (5.5, 82, 0.5), (6, 80, 0.5), (6.5, 79, 0.5), (7, 77, 1.0)]
	b = [(0, 84, 0.5), (0.75, 82, 0.5), (1.5, 80, 1.0), (3, 79, 1.0), (4, 84, 0.5), (4.75, 85, 0.5), (5.5, 84, 1.0), (7, 80, 1.0)]
	counter = [(1, 65, 0.25), (3, 65, 0.25), (5, 68, 0.25), (7, 67, 0.25)]
	bass = [(0, 0.75, 29, None), (0.75, 0.75, 29, None), (1.5, 1.0, 29, 36), (2.5, 0.5, 36, None), (3, 1.0, 32, None),
		(4, 0.75, 29, None), (4.75, 0.75, 29, None), (5.5, 1.0, 27, None), (6.5, 1.5, 28, 24)]
	kicks = [0, 0.75, 1.5, 3, 4, 4.75, 5.5, 6.5]
	chords = [[65, 68, 72], [61, 65, 68], [63, 67, 70], [60, 64, 67]]
	return song(s, a, b, lambda m, d: layer(brass(m, d), bell(m, 0.8, 0.8) * 0.5), bass, kicks, chords, counter, lambda m, d: bell(m, 0.5))


def music_downtown() -> np.ndarray:
	# 142 BPM, A minor with the phrygian b2 (Bb): rainy night, felt piano + choir.
	s = Trap(142, seed=13)
	a = [(0, 69, 1.0), (1, 70, 0.5), (1.5, 69, 0.5), (2, 64, 1.0), (3, 72, 1.0),
		(4, 71, 1.0), (5, 72, 0.5), (5.5, 71, 0.5), (6, 64, 1.0), (7, 65, 1.0)]
	b = [(0, 76, 1.5), (1.5, 77, 0.5), (2, 76, 1.0), (3, 72, 1.0), (4, 74, 1.5), (5.5, 72, 0.5), (6, 70, 2.0)]
	counter = [(0.5, 57, 0.5), (2.5, 52, 0.5), (4.5, 59, 0.5), (6.5, 53, 0.5)]
	bass = [(0, 2.0, 33, None), (2.0, 0.75, 33, None), (2.75, 1.25, 33, 34), (4, 2.0, 29, None), (6.0, 1.0, 29, None), (7.0, 1.0, 28, None)]
	kicks = [0, 2.0, 2.75, 4, 6.0, 7.0]
	chords = [[57, 60, 64], [58, 62, 65], [53, 57, 60], [52, 56, 59]]
	return song(s, a, b, lambda m, d: piano(m, max(d, 1.2)), bass, kicks, chords, counter, lambda m, d: piano(m, 0.9))


def music_coast() -> np.ndarray:
	# 136 BPM, E minor: melodic trap, breathy flute lead over a dark pluck.
	s = Trap(136, seed=14)
	a = [(0, 76, 0.75), (0.75, 79, 0.25), (1, 78, 0.5), (1.5, 76, 0.5), (2, 74, 1.0), (3, 71, 1.0),
		(4, 72, 0.75), (4.75, 74, 0.25), (5, 76, 0.5), (5.5, 74, 0.5), (6, 71, 1.5), (7.5, 69, 0.5)]
	b = [(0, 83, 1.0), (1, 81, 0.5), (1.5, 79, 0.5), (2, 78, 1.0), (3, 76, 1.0), (4, 79, 1.0), (5, 78, 0.5), (5.5, 76, 0.5), (6, 74, 2.0)]
	counter = [(0, 64, 0.5), (1, 67, 0.5), (2, 71, 0.5), (3, 67, 0.5), (4, 60, 0.5), (5, 64, 0.5), (6, 67, 0.5), (7, 62, 0.5)]
	bass = [(0, 1.5, 28, None), (1.5, 1.0, 28, 31), (2.5, 1.5, 31, None), (4, 1.5, 24, None), (5.5, 1.0, 24, 26), (6.5, 1.5, 26, None)]
	kicks = [0, 1.5, 2.5, 4, 5.5, 6.5]
	chords = [[64, 67, 71], [60, 64, 67], [55, 59, 62], [62, 66, 69]]
	return song(s, a, b, lambda m, d: flute(m, d), bass, kicks, chords, counter, lambda m, d: pluck(m - 12, 0.45, int(m)))


def music_race() -> np.ndarray:
	# 144 BPM, G minor: generic race beat (bell + pluck), used by any track without its own.
	s = Trap(144, seed=15)
	a = [(0, 79, 0.5), (0.5, 74, 0.5), (1, 82, 0.5), (1.5, 81, 0.5), (2, 79, 1.0), (3, 74, 0.5), (3.5, 77, 0.5),
		(4, 75, 0.5), (4.5, 74, 0.5), (5, 72, 0.5), (5.5, 74, 0.5), (6, 70, 1.0), (7, 74, 1.0)]
	b = [(0, 86, 1.0), (1, 82, 0.5), (1.5, 81, 0.5), (2, 79, 1.5), (4, 84, 1.0), (5, 82, 0.5), (5.5, 81, 0.5), (6, 78, 2.0)]
	bass = [(0, 1.5, 31, None), (1.5, 1.0, 31, 38), (2.5, 1.5, 34, None), (4, 1.5, 27, None), (5.5, 1.0, 27, 26), (6.5, 1.5, 26, None)]
	kicks = [0, 1.5, 2.5, 4, 5.5, 6.5]
	chords = [[67, 70, 74], [63, 67, 70], [65, 69, 72], [62, 66, 69]]
	return song(s, a, b, lambda m, d: bell(m, max(d, 0.8)), bass, kicks, chords, None, None)


ALL = {
	"music_menu": music_menu,
	"music_arena": music_arena,
	"music_downtown": music_downtown,
	"music_coast": music_coast,
	"music_race": music_race,
}
