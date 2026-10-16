class_name TmCarAudio
extends Node
## The race's sound: the engine (the load and coast loops crossfaded by the throttle, pitched by
## the virtual rpm), tyre skid while wheels slide, wind with speed, and the cues: the countdown's
## beeps and go, checkpoints and laps, wall hits, turbo; the race calls cue() for the finish,
## records and respawns.

var car: TmCar
var race: TmRace

var _load: AudioStreamPlayer
var _coast: AudioStreamPlayer
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
var engine_pitch := 1.0            ## for tests: the engine loops' pitch now
var engine_mix := 0.0              ## for tests: the load loop's share (0 coast .. 1 load)


func _loop(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = TmSounds.get_stream(name)
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _ready() -> void:
	_load = _loop("engine_load")
	_coast = _loop("engine_coast")
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


## Plays a one-shot cue (TmSounds name).
func cue(name: String, db := 0.0) -> void:
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	v.stream = TmSounds.get_stream(name)
	v.volume_db = db
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
	engine_pitch = TmSounds.rpm(kmh) / TmSounds.ENGINE_RPM
	engine_mix = _throttle
	_load.pitch_scale = engine_pitch
	_coast.pitch_scale = engine_pitch
	_load.volume_db = _db(lerpf(0.12, 0.75, _throttle))
	_coast.volume_db = _db(lerpf(0.55, 0.12, _throttle))
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
			cue("go", -2.0)
	if car.model.turbo_until_ms > _turbo_until:
		if car.model.turbo_until_ms > car.now_ms:
			cue("turbo", -3.0)
		_turbo_until = car.model.turbo_until_ms
