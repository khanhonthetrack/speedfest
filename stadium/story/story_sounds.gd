class_name StorySounds
extends RefCounted
## The cutscenes' own sounds (PLAN M20-3, the horror layer): synthesized here, like the race's
## stand-in cues (audio/tm_sounds.gd), so no recording is needed: "sting" (a low hit under a
## dissonant scrape, for the face in the mirror), "rain" (a loop: hiss on the roof), "heartbeat"
## (a loop), "chime" (the satnav's two notes), "thump" (a door, a hand on glass), "drip" (a loop:
## water dripping off someone soaked into water on the floor), "drone" (a loop: dread, a low beating
## tone and a thin high one swelling for four seconds, then held), "breath" (a breath let out) and
## "gasp" (a sharp breath in: waking from a nightmare), "train" (a loop: a train over the viaduct,
## a rumble and its wheels over the rail joints), "engine" (a loop: a straight six cruising under tyre
## hiss), "wipers" (a loop: the blades' thunk and squeak), "ring" (the whine in the ears after a
## flash), "creak" (leather taking a weight), "sub" (a deep boom under a hit).

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
		"breath":
			s = _breath()
		"gasp":
			s = _gasp()
		"train":
			s = _train()
		"engine":
			s = _engine()
		"wipers":
			s = _wipers()
		"ring":
			s = _ring()
		"creak":
			s = _creak()
		"sub":
			s = _sub()
	_cache[name] = s
	return s


static func loops(name: String) -> bool:
	return name in ["rain", "heartbeat", "drip", "drone", "train", "engine", "wipers"]


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
		var env := clampf(t * 60.0, 0.0, 1.0) * exp(-t * 1.6)          # at full on the first frame
		var scrape := (sin(TAU * 1480.0 * t) + sin(TAU * 1555.0 * t + sin(TAU * 7.0 * t))) * 0.18 * env
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.8       # a broadband transient, 6 ms
		x[i] = hit + scrape + rng.randf_range(-1.0, 1.0) * 0.12 * env + crack
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


static func _breath() -> AudioStreamWAV:
	# air let out through the mouth: soft noise through a low, then a little lower, filter, up in a
	# fifth of a second and slowly gone
	var n := int(RATE * 1.1)
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := clampf(t / 0.18, 0.0, 1.0) * exp(-maxf(t - 0.18, 0.0) * 3.2)
		var a := lerpf(0.16, 0.08, clampf(t / 1.1, 0.0, 1.0))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		lp2 += (lp - lp2) * 0.3
		x[i] = (lp - lp2 * 0.6) * env * 1.6
	return _wav(x)


static func _gasp() -> AudioStreamWAV:
	# a sharp breath in: noise rising in level and brightness for 0.35 s, then caught (cut short)
	var n := int(RATE * 0.42)
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := pow(clampf(t / 0.35, 0.0, 1.0), 1.6) * (1.0 - clampf((t - 0.36) / 0.04, 0.0, 1.0))
		var a := lerpf(0.12, 0.45, clampf(t / 0.35, 0.0, 1.0))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		hp += (lp - hp) * 0.05
		x[i] = (lp - hp) * env * 1.4
	return _wav(x)


static func _train() -> AudioStreamWAV:
	# low rumble (noise through a very low filter, and the brick's hum) and the wheels' double clack
	# over the joints, every 0.75 s; whole seconds, so the loop's seam falls between clacks
	var n := RATE * 3
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		var hum := sin(TAU * 38.0 * t) * 0.12 + sin(TAU * 57.0 * t) * 0.05
		var clack := 0.0
		for at in [0.1, 0.24]:
			var d := fposmod(t - at, 0.75)
			if d < 0.05:
				clack += sin(TAU * 180.0 * d) * exp(-d * 90.0) * 0.5
		x[i] = lp2 * 2.6 + hum + clack
	return _wav(x, true)


static func _engine() -> AudioStreamWAV:
	# a straight six cruising: about 38 Hz with its second and third harmonics, a slow wobble, under
	# low-passed tyre hiss; four whole seconds, every tone a whole number of cycles, so it loops
	var n := RATE * 4
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var wob := 1.0 + 0.08 * sin(TAU * 0.25 * t)
		var hum := (sin(TAU * 38.0 * t) * 0.5 + sin(TAU * 76.0 * t + 0.6) * 0.3 + sin(TAU * 114.0 * t + 1.1) * 0.15) * wob
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.2
		x[i] = hum * 0.45 + lp2 * 0.9
	return _wav(x, true)


static func _wipers() -> AudioStreamWAV:
	# a wiper's stroke each way: a rubber thunk with a low body and a squeak chirping up at its end
	var n := int(RATE * 1.7)
	var x := PackedFloat32Array()
	x.resize(n)
	for stroke in [0.0, 0.85]:
		var i0 := int(stroke * RATE)
		for k in mini(int(RATE * 0.35), n - i0):
			var t := float(k) / RATE
			var thunk := sin(TAU * 60.0 * t) * exp(-t * 28.0) * 0.6
			var chirp := sin(TAU * (900.0 + 1500.0 * t) * t) * exp(-pow((t - 0.18) / 0.06, 2.0)) * 0.12
			x[i0 + k] += thunk + chirp
	return _wav(x, true)


static func _ring() -> AudioStreamWAV:
	# the whine after a flash: two close high tones beating, dying away
	var n := int(RATE * 2.2)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / RATE
		x[i] = (sin(TAU * 3150.0 * t) + sin(TAU * 3170.0 * t)) * 0.12 * exp(-t * 1.2) * clampf(t * 30.0, 0.0, 1.0)
	return _wav(x)


static func _creak() -> AudioStreamWAV:
	# leather taking a weight: a stick-slip of clicks quickening from 35 to 80 a second through a
	# hollow resonance
	var n := int(RATE * 0.5)
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var phase := 0.0
	var res := 0.0
	var vel := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(35.0, 80.0, t / 0.5) / RATE
		var kick := 0.0
		if phase >= 1.0:
			phase -= 1.0
			kick = rng.randf_range(0.5, 1.0)
		# a resonator about 900 Hz, damped
		var w := TAU * (900.0 + 300.0 * sin(t * 9.0)) / RATE
		vel += kick - w * w * res - 0.012 * vel
		res += vel
		x[i] = clampf(res * 0.1, -1.0, 1.0) * sin(PI * clampf(t / 0.5, 0.0, 1.0))
	return _wav(x)


static func _sub() -> AudioStreamWAV:
	# a deep boom under a hit
	var n := int(RATE * 1.2)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / RATE
		x[i] = sin(TAU * 28.0 * t) * exp(-t * 3.0) * 0.95 * clampf(t * 200.0, 0.0, 1.0)
	return _wav(x)
