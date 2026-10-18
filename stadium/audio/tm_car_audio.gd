class_name TmCarAudio
extends Node
## The race's sound: the engine the way TMNF's works (its six gears drive the rpm; six loops of our
## own, four under load and two coasting, each pitched by rpm / its base rpm and faded in and out
## over its rpm band, the throttle crossfading load and coast; a dip and a clunk at each upshift,
## the rev limiter's flutter, free revs in the air), tyre skid while wheels slide, wind with speed,
## and the cues: the countdown's beeps and go, checkpoints and laps, wall hits, turbo; the race
## calls cue() for the finish, records and respawns.

var car: TmCar
var race: TmRace

## The engine's layers: [stream, base rpm (the loop's own), volume, fade-in rpm from-to,
## fade-out rpm from-to, under load]. The bands and volumes follow TMNF's engine sound; the
## bases are our loops' (stadium/tools/sfxgen/engine.py).
const LAYERS := [
	["engine_idle", 1200.0, 0.85, [0.0, 0.0], [1700.0, 3800.0], true],
	["engine_low", 3600.0, 0.6, [500.0, 1600.0], [5200.0, 8000.0], true],
	["engine_mid", 6600.0, 0.75, [3600.0, 6000.0], [8200.0, 12000.0], true],
	["engine_high", 9600.0, 0.9, [6600.0, 9200.0], [1e9, 1e9], true],
	["engine_coast_low", 3600.0, 0.8, [0.0, 600.0], [6500.0, 12000.0], false],
	["engine_coast_high", 9000.0, 0.55, [5000.0, 7500.0], [1e9, 1e9], false],
]
const RPM_RISE := 26000.0          ## rpm/s the engine can climb (and fall) between ticks
const SHIFT_DIP_MS := 70           ## the load layers dip at an upshift (TMNF cuts drive 25 ms)

var _layers: Array[AudioStreamPlayer] = []
var _skid: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _throttle := 0.0
var _skid_level := 0.0
var _digit := -1
var _was_racing := false
var _turbo_until := -1
var _hit_ready_ms := 0
var engine_rpm := TmSounds.RPM_IDLE   ## the engine's rpm now
var engine_gear := 1                 ## its gear (0: reverse)
var engine_mix := 0.0                ## the load layers' share (0 coast .. 1 load)
var _shift_until := 0


func _loop(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = TmSounds.get_stream(name)
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _ready() -> void:
	for l: Array in LAYERS:
		_layers.append(_loop(String(l[0])))
	_skid = _loop("skid")
	_wind = _loop("wind")
	for i in 4:
		var v := AudioStreamPlayer.new()
		add_child(v)
		_voices.append(v)
	if race:
		race.checkpoint_taken.connect(func(_c: int, _t: int) -> void: cue("checkpoint"))
		race.lap_done.connect(func(_l: int, _t: int) -> void: cue("checkpoint"))
	if car:
		car.wheel_hit_wall.connect(_on_hit)


## Plays a one-shot cue (TmSounds name), optionally pitched.
func cue(name: String, db := 0.0, pitch := 1.0) -> void:
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	v.stream = TmSounds.get_stream(name)
	v.volume_db = db
	v.pitch_scale = pitch
	v.play()


func _on_hit() -> void:
	if car and Time.get_ticks_msec() >= _hit_ready_ms and absf(car.speed_kmh()) > 30.0:
		_hit_ready_ms = Time.get_ticks_msec() + 300
		cue("hit", -4.0)


static func _db(level: float) -> float:
	return linear_to_db(maxf(level, 0.0001))


func _process(delta: float) -> void:
	if car == null:
		return
	var kmh := car.speed_kmh()
	var k := 1.0 - exp(-delta * 8.0)
	_throttle += (clampf(car.gas, 0.0, 1.0) - _throttle) * k
	_engine(kmh, delta)
	var sliding := car.model.any_sliding and car.model.grounded and absf(kmh) > 25.0
	_skid_level += ((0.55 if sliding else 0.0) - _skid_level) * (1.0 - exp(-delta * 12.0))
	_skid.volume_db = _db(_skid_level)
	_skid.pitch_scale = clampf(0.85 + absf(kmh) / 900.0, 0.85, 1.3)
	_wind.volume_db = _db(clampf(absf(kmh) / 450.0, 0.0, 1.0) * 0.45)
	_wind.pitch_scale = 0.8 + clampf(absf(kmh) / 600.0, 0.0, 0.6)
	if race:
		if race.state == TmRace.State.COUNTDOWN:
			var d := ceili(race.countdown_ms / 500.0)
			if d != _digit and d > 0:
				_digit = d
				cue("beep", -3.0)
			_was_racing = false
		elif race.state == TmRace.State.RACING and not _was_racing:
			_was_racing = true
			_digit = -1
			cue("go", -2.0, 1.5)
	if car.model.turbo_until_ms > _turbo_until:
		if car.model.turbo_until_ms > car.now_ms:
			cue("turbo", -3.0)
		_turbo_until = car.model.turbo_until_ms


## The gearbox, the rpm and the layers' mix.
func _engine(kmh: float, delta: float) -> void:
	var v := absf(kmh)
	var target := TmSounds.RPM_IDLE
	if kmh < -3.0:
		engine_gear = 0
		target = clampf(v / TmSounds.REVERSE_TOP * TmSounds.RPM_MAX, TmSounds.RPM_IDLE, TmSounds.RPM_MAX)
	else:
		if engine_gear < 1:
			engine_gear = 1
		var up := false
		while engine_gear < TmSounds.GEAR_TOP.size() and v > float(TmSounds.SHIFT_UP[engine_gear]) * float(TmSounds.GEAR_TOP[engine_gear - 1]):
			engine_gear += 1
			up = true
		while engine_gear > 1 and v < float(TmSounds.SHIFT_DOWN[engine_gear - 1]) * float(TmSounds.GEAR_TOP[engine_gear - 2]):
			engine_gear -= 1
		if up and _throttle > 0.5:
			_shift_until = Time.get_ticks_msec() + SHIFT_DIP_MS
			cue("shift", -14.0, randf_range(0.95, 1.05))
		target = TmSounds.rpm(v, engine_gear)
		if car.model.grounded == false and car.gas > 0.5:
			target = TmSounds.RPM_MAX * 0.97       # wheels spinning free in the air
	if car.gas > 0.5 and target >= TmSounds.RPM_MAX * 0.97:
		target -= 260.0 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.11))   # the limiter's flutter
	var step := RPM_RISE * delta
	engine_rpm = clampf(target, engine_rpm - step * 1.6, engine_rpm + step)
	engine_mix = _throttle
	var dip := 0.45 if Time.get_ticks_msec() < _shift_until else 1.0
	for i in LAYERS.size():
		var l: Array = LAYERS[i]
		var p := _layers[i]
		var fin: Array = l[3]
		var fout: Array = l[4]
		var w := float(l[2])
		if float(fin[1]) > float(fin[0]):
			w *= smoothstep(float(fin[0]), float(fin[1]), engine_rpm)
		if float(fout[1]) > float(fout[0]) and float(fout[0]) < 1e8:
			w *= 1.0 - smoothstep(float(fout[0]), float(fout[1]), engine_rpm)
		w *= (_throttle * dip) if bool(l[5]) else (1.0 - _throttle) * 0.85
		p.volume_db = _db(w * 0.8)
		p.pitch_scale = clampf(engine_rpm / float(l[1]), 0.25, 3.0)
