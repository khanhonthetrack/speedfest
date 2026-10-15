class_name WeatherFX
extends Node
## Race-scene weather presentation: rain streaks around the camera, darker/foggier light for wet
## rounds on dry-themed stages, storm lightning + thunder, and the rain ambience loop.
## Gameplay (grip) lives in Track.apply_weather / TrackSurface; this is only looks and sound.

var mode := "dry"
var track: Track
var camera: Camera3D
var rain: SceneryRain
var _env: Environment
var _sun: DirectionalLight3D
var _sun_energy := 1.0
var _bg_energy := 1.0
var _ambient := 1.0
var _flash := 0.0
var _next_strike := 0.0
var _thunder_at := -1.0
var _rng := RandomNumberGenerator.new()


static func create(p_track: Track, p_mode: String, p_camera: Camera3D) -> WeatherFX:
	var fx := WeatherFX.new()
	fx.name = "WeatherFX"
	fx.track = p_track
	fx.camera = p_camera
	fx.mode = Weather.sanitize(p_mode)
	return fx


func _ready() -> void:
	_rng.seed = hash(track.track_id if track else "x") ^ 0x5eed
	_env = _find_env(track)
	_sun = _find_sun(track)
	if _sun:
		_sun_energy = _sun.light_energy
	if _env:
		_bg_energy = _env.background_energy_multiplier
		_ambient = _env.ambient_light_energy
	if Weather.is_wet(mode):
		if camera:
			rain = SceneryRain.create(Weather.rain_density(mode))
			camera.add_child(rain)
		_apply_wet_light()
		Audio.play_ambience("rain", 0.0 if mode == "rain" else 3.0)
	if mode == "storm":
		_next_strike = _rng.randf_range(3.0, 7.0)


func _exit_tree() -> void:
	Audio.stop_ambience()


## Rain on a dry-themed stage (arena, coast): dimmer sun, more fog. The city is already a rainy
## night; a storm darkens every stage a bit more.
func _apply_wet_light() -> void:
	var city := track != null and track.theme == "city"
	var dim := 1.0
	if not city:
		dim = 0.6 if mode == "rain" else 0.45
	elif mode == "storm":
		dim = 0.8
	if _sun:
		_sun_energy *= dim
		_sun.light_energy = _sun_energy
	if _env:
		_env.background_energy_multiplier = _bg_energy * lerpf(1.0, dim, 0.7)
		_bg_energy = _env.background_energy_multiplier
		if not city:
			_env.fog_enabled = true
			_env.fog_density = maxf(_env.fog_density, 0.0) * 1.8 + (0.004 if mode == "rain" else 0.007)


func _process(delta: float) -> void:
	if mode != "storm":
		return
	_next_strike -= delta
	if _next_strike <= 0.0:
		_strike()
		_next_strike = _rng.randf_range(7.0, 15.0)
	if _thunder_at >= 0.0:
		_thunder_at -= delta
		if _thunder_at < 0.0:
			Audio.play_sfx("thunder", _rng.randf_range(-6.0, 0.0), _rng.randf_range(0.85, 1.1))
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.5, 0.0)
		# double flicker: bright, dip, bright, fade
		var k := _flash * (0.6 + 0.4 * sin(_flash * 40.0))
		if _sun:
			_sun.light_energy = _sun_energy + k * 3.0
		if _env:
			_env.background_energy_multiplier = _bg_energy + k * 2.5
			_env.ambient_light_energy = _ambient + k * 1.5


## A lightning strike: flash now, thunder 0.3-2 s later (as if a few hundred meters away).
func _strike() -> void:
	_flash = 1.0
	_thunder_at = _rng.randf_range(0.3, 2.0)


func is_flashing() -> bool:
	return _flash > 0.0


static func _find_env(n: Node) -> Environment:
	if n == null:
		return null
	if n is WorldEnvironment:
		return (n as WorldEnvironment).environment
	for c in n.get_children():
		var e := _find_env(c)
		if e:
			return e
	return null


static func _find_sun(n: Node) -> DirectionalLight3D:
	if n == null:
		return null
	if n is DirectionalLight3D:
		return n
	for c in n.get_children():
		var s := _find_sun(c)
		if s:
			return s
	return null
