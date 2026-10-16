class_name TmSounds
extends RefCounted
## The remake's sounds, synthesized at start (our own; no sound files): engine loops on and off
## the throttle (a harmonic stack with a firing buzz), tyre skid and wind (filtered noise), and
## the race's cues (countdown, checkpoint, finish, record, respawn, wall hit, turbo, menu). Each
## stream is made once and cached.

const RATE := 22050
const ENGINE_F0 := 110.25            ## Hz; 200 samples a period, so the loop wraps seamlessly
const ENGINE_RPM := 4000.0           ## the rpm at which a loop plays at its own pitch (9800 rpm: 270 Hz)

static var _cache := {}


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _noise(n: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## One-pole low-pass (k: 0..1, smaller = darker), run twice round the loop so it wraps smoothly.
static func _lowpass(x: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var s := 0.0
	for _pass in 2:
		for i in x.size():
			s += (x[i] - s) * k
			y[i] = s
	return y


const NAMES := ["engine_load", "engine_coast", "skid", "wind", "beep", "go", "checkpoint", "finish", "record",
	"respawn", "hit", "turbo", "click", "move"]


static func get_stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		var s: AudioStreamWAV
		match name:
			"engine_load": s = _make_engine_load()
			"engine_coast": s = _make_engine_coast()
			"skid": s = _make_skid()
			"wind": s = _make_wind()
			"beep": s = _make_beep()
			"go": s = _make_go()
			"checkpoint": s = _make_checkpoint()
			"finish": s = _make_finish()
			"record": s = _make_record()
			"respawn": s = _make_respawn()
			"hit": s = _make_hit()
			"turbo": s = _make_turbo()
			"click": s = _make_click()
			"move": s = _make_move()
			_: push_error("TmSounds: no sound %s" % name)
		_cache[name] = s
	return _cache[name]


## The engine under load: harmonics of ENGINE_F0 falling off, the odd ones stronger (a buzzy
## four-cylinder-like note), a firing pulse and a little noise.
static func _make_engine_load() -> AudioStreamWAV:
	return _engine([1.0, 0.55, 0.75, 0.3, 0.45, 0.18, 0.25, 0.1, 0.12], 0.10, 0.9)


## Off the throttle: the low harmonics only, softer.
static func _make_engine_coast() -> AudioStreamWAV:
	return _engine([1.0, 0.35, 0.3, 0.08, 0.06], 0.04, 0.6)


static func _engine(harmonics: Array, noise: float, gain: float) -> AudioStreamWAV:
	var n := 200 * 110   # one second, a whole number of periods
	var nz := _lowpass(_noise(n, 7), 0.25)
	var out := PackedFloat32Array()
	out.resize(n)
	var total := 0.0
	for h: float in harmonics:
		total += h
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in harmonics.size():
			v += float(harmonics[k]) * sin(TAU * ENGINE_F0 * (k + 1) * t + k * 0.7)
		var pulse := 0.6 + 0.4 * pow(absf(sin(PI * ENGINE_F0 * 2.0 * t)), 8.0)
		out[i] = (v / total * pulse + nz[i] * noise) * gain
	return _wav(out, true)


static func _make_skid() -> AudioStreamWAV:
	var n := RATE
	var x := _noise(n, 11)
	var lo := _lowpass(x, 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		# a band of noise with a squeal near 1.4 kHz riding on it
		out[i] = (x[i] - lo[i]) * 0.6 + sin(TAU * 1400.0 * i / RATE + 3.0 * sin(TAU * 7.0 * i / RATE)) * 0.18
	return _wav(out, true)


static func _make_wind() -> AudioStreamWAV:
	var out := _lowpass(_noise(RATE * 2, 23), 0.06)
	for i in out.size():
		out[i] *= 3.5
	return _wav(out, true)


## A tone with an attack/decay envelope; notes: [[frequency, start s, length s, level], ...].
static func _tones(notes: Array, length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for note: Array in notes:
		var f := float(note[0])
		var s0 := int(float(note[1]) * RATE)
		var len_n := int(float(note[2]) * RATE)
		for i in len_n:
			if s0 + i >= n:
				break
			var t := float(i) / RATE
			var env := minf(1.0, t * 200.0) * exp(-3.5 * t / float(note[2]))
			out[s0 + i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) + 0.12 * sin(TAU * f * 3.0 * t)) * env * float(note[3])
	return _wav(out)


static func _make_beep() -> AudioStreamWAV:
	return _tones([[660.0, 0.0, 0.18, 0.5]], 0.2)


static func _make_go() -> AudioStreamWAV:
	return _tones([[990.0, 0.0, 0.45, 0.55]], 0.5)


static func _make_checkpoint() -> AudioStreamWAV:
	return _tones([[880.0, 0.0, 0.12, 0.45], [1320.0, 0.09, 0.25, 0.45]], 0.36)


static func _make_finish() -> AudioStreamWAV:
	return _tones([[523.3, 0.0, 0.3, 0.4], [659.3, 0.1, 0.3, 0.4], [784.0, 0.2, 0.3, 0.4], [1046.5, 0.3, 0.7, 0.45]], 1.05)


static func _make_record() -> AudioStreamWAV:
	return _tones([[784.0, 0.0, 0.2, 0.35], [988.0, 0.12, 0.2, 0.35], [1175.0, 0.24, 0.2, 0.35], [1568.0, 0.36, 0.8, 0.4],
		[1175.0, 0.36, 0.8, 0.25]], 1.2)


static func _make_respawn() -> AudioStreamWAV:
	var n := int(0.35 * RATE)
	var x := _lowpass(_noise(n, 31), 0.2)
	for i in n:
		var t := float(i) / n
		x[i] *= 2.5 * sin(PI * t)
	return _wav(x)


static func _make_hit() -> AudioStreamWAV:
	var n := int(0.25 * RATE)
	var x := _lowpass(_noise(n, 41), 0.08)
	for i in n:
		var t := float(i) / RATE
		x[i] = (x[i] * 4.0 + sin(TAU * 70.0 * t) * 0.6) * exp(-t * 18.0)
	return _wav(x)


static func _make_turbo() -> AudioStreamWAV:
	var n := int(0.6 * RATE)
	var x := _noise(n, 53)
	var out := PackedFloat32Array()
	out.resize(n)
	var s := 0.0
	for i in n:
		var t := float(i) / n
		s += (x[i] - s) * lerpf(0.05, 0.5, t)   # the noise opens up: a rising whoosh
		out[i] = s * 1.6 * sin(PI * t)
	return _wav(out)


static func _make_click() -> AudioStreamWAV:
	return _tones([[1800.0, 0.0, 0.04, 0.35]], 0.05)


static func _make_move() -> AudioStreamWAV:
	return _tones([[1200.0, 0.0, 0.03, 0.18]], 0.04)


## The engine's rpm at a speed: virtual gears (km/h bands) each sweeping the rev range, so the
## note climbs and drops at every shift like TMNF's.
const GEARS := [0.0, 55.0, 105.0, 160.0, 220.0, 290.0, 1e9]
const RPM_IDLE := 2400.0
const RPM_SHIFT_DOWN := 5200.0
const RPM_MAX := 9800.0


static func rpm(kmh: float) -> float:
	var v := absf(kmh)
	for g in GEARS.size() - 1:
		if v < float(GEARS[g + 1]):
			var lo := float(GEARS[g])
			var hi := float(GEARS[g + 1])
			var t := (v - lo) / (hi - lo) if hi < 1e8 else minf((v - lo) / 120.0, 1.0)
			return lerpf(RPM_IDLE if g == 0 else RPM_SHIFT_DOWN, RPM_MAX, t)
	return RPM_MAX
