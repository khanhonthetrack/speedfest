class_name TmSounds
extends RefCounted
## The remake's sounds: our own synthesized engine (six loops, one per layer, and the gear
## change's clunk: stadium/tools/sfxgen/engine.py), our own cues made to sound like TMNF's (the
## countdown's beeps, the crowd at the start and at a medal, the checkpoint's swoosh, a wall's crash,
## a landing's thump, the menus' whum and click, the wind: stadium/tools/sfxgen/cues.py), open-licensed recordings in audio/sfx
## (tyre squeal, Kenney's respawn sound; audio/sfx/CREDITS.md), and, for any of those
## missing, our synthesized stand-ins below (filtered noise, tone cues). Each stream is loaded or
## made once and cached. Also TMNF's engine model: its six gears and rev range (rpm()).

const RATE := 22050
const FILES := {"engine_idle": "engine_idle.wav", "engine_low": "engine_low.wav", "engine_mid": "engine_mid.wav",
	"engine_high": "engine_high.wav", "engine_coast_low": "engine_coast_low.wav", "engine_coast_high": "engine_coast_high.wav",
	"shift": "shift.wav", "skid": "skid.wav",
	"wind": "wind.ogg", "beep": "beep.ogg", "go": "go.ogg", "checkpoint": "checkpoint.ogg", "cheer": "cheer.ogg",
	"cheer_big": "cheer_big.ogg", "respawn": "respawn.ogg", "hit": "hit.ogg", "land": "land.ogg", "turbo": "turbo.wav", "click": "ui_click.ogg",
	"move": "ui_move.ogg"}
const ENGINE_LAYERS := ["engine_idle", "engine_low", "engine_mid", "engine_high", "engine_coast_low", "engine_coast_high"]
const LOOPS := ["engine_idle", "engine_low", "engine_mid", "engine_high", "engine_coast_low", "engine_coast_high", "skid", "wind"]

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


## A recorded sound from audio/sfx, looping where it should; null if there is none.
static func _recorded(name: String) -> AudioStream:
	var path := "res://audio/sfx/" + String(FILES.get(name, ""))
	if not FILES.has(name) or not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if name in LOOPS:
		if s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
		elif s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
	return s


const NAMES := ["engine_idle", "engine_low", "engine_mid", "engine_high", "engine_coast_low", "engine_coast_high",
	"shift", "skid", "wind", "beep", "go", "checkpoint", "cheer", "cheer_big", "respawn", "hit", "land", "turbo", "click", "move"]


static func get_stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var s: AudioStream = _recorded(name)
		if s:
			_cache[name] = s
			return s
		match name:
			"skid": s = _make_skid()
			"wind": s = _make_wind()
			"beep": s = _make_beep()
			"go": s = _make_go()
			"checkpoint": s = _make_checkpoint()
			"cheer": s = _make_cheer()
			"cheer_big": s = _make_cheer_big()
			"respawn": s = _make_respawn()
			"hit", "land": s = _make_hit()
			"turbo": s = _make_turbo()
			"click": s = _make_click()
			"move": s = _make_move()
			_: push_error("TmSounds: no sound %s" % name)
		_cache[name] = s
	return _cache[name]


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


static func _make_cheer() -> AudioStreamWAV:
	return _tones([[523.3, 0.0, 0.3, 0.4], [659.3, 0.1, 0.3, 0.4], [784.0, 0.2, 0.3, 0.4], [1046.5, 0.3, 0.7, 0.45]], 1.05)


static func _make_cheer_big() -> AudioStreamWAV:
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


## TMNF's engine model (its car tuning, read locally: the rev limit and the gear buffers): six
## gears, each reaching the rev limit at its top speed (km/h); a gear is engaged at SHIFT_UP of
## the gear below's top speed and dropped under SHIFT_DOWN of it. The sound follows it (the drive
## doesn't: TMNF's acceleration is a function of speed).
const GEAR_TOP := [85.0, 110.0, 160.0, 220.0, 370.0, 400.0]
const SHIFT_UP := [0.0, 0.95, 0.9, 0.95, 0.95, 1.0]
const SHIFT_DOWN := [0.0, 0.0, 0.5, 0.57, 0.55, 0.6]
const RPM_IDLE := 1200.0
const RPM_MAX := 11000.0
const REVERSE_TOP := 85.0


## The gear at a speed while accelerating (1..6; the shift-up points).
static func gear_for(kmh: float) -> int:
	var v := absf(kmh)
	var g := 1
	while g < GEAR_TOP.size() and v > float(SHIFT_UP[g]) * float(GEAR_TOP[g - 1]):
		g += 1
	return g


## The engine's rpm at a speed in a gear (the gear for the speed if none is given).
static func rpm(kmh: float, gear := 0) -> float:
	var v := absf(kmh)
	var g := gear if gear > 0 else gear_for(v)
	return clampf(v / float(GEAR_TOP[g - 1]) * RPM_MAX, RPM_IDLE, RPM_MAX)
