class_name StorySounds
extends RefCounted
## The cutscenes' own sounds (PLAN M20-3, the horror layer): synthesized here, like the race's
## stand-in cues (audio/tm_sounds.gd), so no recording is needed: "sting" (a low hit under a
## dissonant scrape, for the face in the mirror), "rain" (a loop: hiss on the roof), "heartbeat"
## (a loop), "chime" (the satnav's two notes), "thump" (a door, a hand on glass).

const RATE := 22050
static var _cache := {}


static func get_stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStream = null
	match name:
		"sting":
			s = _sting()
		"rain":
			s = _rain()
		"heartbeat":
			s = _heartbeat()
		"chime":
			s = _chime()
		"thump":
			s = _thump()
	_cache[name] = s
	return s


static func loops(name: String) -> bool:
	return name in ["rain", "heartbeat"]


static func _wav(x: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = x.size()
	return w


static func _sting() -> AudioStreamWAV:
	var n := int(RATE * 2.2)
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in n:
		var t := float(i) / RATE
		var hit := sin(TAU * 42.0 * t) * exp(-t * 2.2) * 0.9
		# the scrape: two close high tones beating, and noise, swelling then gone
		var env := clampf(t * 8.0, 0.0, 1.0) * exp(-t * 1.6)
		var scrape := (sin(TAU * 1480.0 * t) + sin(TAU * 1555.0 * t + sin(TAU * 7.0 * t))) * 0.18 * env
		x[i] = hit + scrape + rng.randf_range(-1.0, 1.0) * 0.12 * env
	return _wav(x)


static func _rain() -> AudioStreamWAV:
	var n := RATE * 3
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var drop := 0.0
		if rng.randf() < 0.002:
			drop = rng.randf_range(0.3, 0.7)
		x[i] = lp * 0.35 + drop * rng.randf_range(-1.0, 1.0)
	return _wav(x, true)


static func _heartbeat() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / RATE
		var a := sin(TAU * 55.0 * t) * exp(-t * 18.0)
		var b := sin(TAU * 50.0 * (t - 0.22)) * exp(-maxf(t - 0.22, 0.0) * 16.0) * (1.0 if t > 0.22 else 0.0) * 0.7
		x[i] = (a + b) * 0.8
	return _wav(x, true)


static func _chime() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 if t < 0.3 else 659.25
		var tt := t if t < 0.3 else t - 0.3
		x[i] = sin(TAU * f * t) * exp(-tt * 5.0) * 0.35
	return _wav(x)


static func _thump() -> AudioStreamWAV:
	var n := int(RATE * 0.4)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / RATE
		x[i] = sin(TAU * 70.0 * t) * exp(-t * 14.0) * 0.9
	return _wav(x)
