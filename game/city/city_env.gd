class_name CityEnv
extends Node3D
## The night sky over the city: the WorldEnvironment (Settings' house look, tuned to the current
## quality), a low moon as the key light, and the sodium-orange glow the city throws into the haze.
##
## The city is lit by its own neon and lamps, so the directional light is only a cold rim that
## separates the towers from the sky; everything warm comes from the emissive facades, the signs
## and the real lights the city kit places.

const MOON_ENERGY := 0.22

var env: Environment
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial


static func create() -> CityEnv:
	var n := CityEnv.new()
	n.name = "CityEnv"
	return n


func _ready() -> void:
	env = Settings.night_environment()
	_city_sky()
	Settings.tune_environment(env)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-34.0, 128.0, 0.0)
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = MOON_ENERGY
	moon.light_specular = 0.4
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	Settings.tune_sun(moon)
	add_child(moon)

	# a very soft fill from below: the city's own light bouncing back off the overcast
	var fill := DirectionalLight3D.new()
	fill.name = "CityBounce"
	fill.rotation_degrees = Vector3(62.0, -40.0, 0.0)
	fill.light_color = Color(1.0, 0.62, 0.34)
	fill.light_energy = 0.10
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)

	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	if env == null:
		return
	env = Settings.night_environment()
	_city_sky()
	Settings.tune_environment(env)
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		we.environment = env
	if moon:
		Settings.tune_sun(moon)


## Swap the procedural sky for the city one: light pollution on the horizon, stars overhead,
## and a thin band of cloud catching the glow of the district.
func _city_sky() -> void:
	var sh := load("res://shaders/env_sky.gdshader")
	if sh == null:
		return
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_REALTIME if Settings.quality >= 2 else Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	var params := {
		"zenith_color": Color(0.010, 0.012, 0.038),
		"sky_color": Color(0.028, 0.030, 0.075),
		"horizon_color": Color(0.145, 0.085, 0.130),
		"ground_color": Color(0.012, 0.012, 0.018),
		"horizon_falloff": 4.2,
		"zenith_falloff": 1.4,
		"glow_color": Color(1.0, 0.44, 0.18),       # sodium light pollution off the district
		"glow_strength": 0.85,
		"glow_height": 0.22,
		"glow_dir_amount": 0.0,
		"cloud_cover": 0.45,
		"cloud_sharpness": 2.6,
		"cloud_scale": 0.5,
		"cloud_dark": Color(0.030, 0.026, 0.055),
		"cloud_lit": Color(0.42, 0.20, 0.30),
		"cloud_lit_from_below": 1.0,
		"cloud_streak": 1.6,
		"star_amount": 0.55,
		"sun_strength": 0.0,
		"energy": 1.0,
	}
	for key in params:
		sky_mat.set_shader_parameter(key, params[key])


