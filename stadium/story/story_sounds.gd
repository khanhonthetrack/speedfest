class_name StorySounds
extends RefCounted
## The cutscenes' own sounds (PLAN M20-3, the horror layer): synthesized here, like the race's
## stand-in cues (audio/tm_sounds.gd), so no recording is needed: "sting" (a low hit under a
## dissonant scrape, for the face in the mirror), "rain" (a loop: hiss on the roof), "heartbeat"
## (a loop), "chime" (the satnav's two notes), "thump" (a door, a hand on glass), "drip" (a loop:
## water dripping off someone soaked into water on the floor), "drone" (a loop: dread, a low beating
## tone and a thin high one swelling for four seconds, then held).

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
		"drip":
			s = _drip()
		"drone":
			s = _drone()
	_cache[name] = s
	return s


static func loops(name: String) -> bool:
	return name in ["rain", "heartbeat", "drip", "drone"]


## loop_from: the sample a loop goes back to (a swell played once, then its held part looping).
static func _wav(x: PackedFloat32Array, loop := false, loop_from := 0) -> AudioStreamWAV:
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
		w.loop_begin = loop_from
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


static func _drip() -> AudioStreamWAV:
	# drops at uneven gaps, each a short tone rising as it rings (a drop into water) and the tick of
	# it landing; whole seconds, so the loop's seam falls between drops
	var n := RATE * 4
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var at := 0.08
	while at < 3.8:
		var a := rng.randf_range(0.2, 0.55)
		var f := rng.randf_range(650.0, 1150.0)
		var i0 := int(at * RATE)
		for k in mini(int(RATE * 0.09), n - i0):
			var t := float(k) / RATE
			var tone := sin(TAU * f * (t + 3.5 * t * t)) * exp(-t * 60.0)
			x[i0 + k] += a * (tone + rng.randf_range(-1.0, 1.0) * exp(-t * 500.0) * 0.4)
		at += rng.randf_range(0.16, 0.7)
	return _wav(x, true)


static func _drone() -> AudioStreamWAV:
	# 49 and 51.5 Hz beating, their octave wavering, a minor second high and thin; every tone a whole
	# number of cycles over the held two seconds (4 to 6 s), which loop seamlessly
	var n := RATE * 6
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 4.0, 1.0)
		env *= env
		var low := (sin(TAU * 49.0 * t) + sin(TAU * 51.5 * t)) * 0.3
		var mid := sin(TAU * 98.0 * t + 0.4 * sin(TAU * 0.5 * t)) * 0.18
		var high := sin(TAU * 2093.0 * t) * 0.035 + sin(TAU * 2217.5 * t) * 0.03
		x[i] = (low + mid + high) * env
	return _wav(x, true, RATE * 4)
