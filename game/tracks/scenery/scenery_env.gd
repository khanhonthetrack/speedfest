class_name SceneryEnv
extends Node3D
## Root node returned by SceneryKit.build_environment(): WorldEnvironment (sky, fog, glow,
## tonemap, SSR...) plus the key light. Re-applies the authored (max quality) environment and
## re-tunes it with Settings whenever settings change, so quality switches apply live.

var theme: String = "city"
var world_env: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var _authored: Dictionary = {}

const _TUNED_PROPS := ["ssr_enabled", "ssao_enabled", "ssil_enabled", "sdfgi_enabled", "volumetric_fog_enabled", "glow_enabled"]


static func create(p_theme: String) -> SceneryEnv:
	var root := SceneryEnv.new()
	root.name = "Environment"
	root.theme = p_theme
	root._build()
	return root


func _ready() -> void:
	if not Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


func _on_settings_changed() -> void:
	retune()


func retune() -> void:
	for k in _authored:
		env.set(k, _authored[k])
	Settings.tune_environment(env)
	_quality_extras()
	Settings.tune_sun(sun)
	_sun_extras()


func _build() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	env = Environment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "KeyLight"
	add_child(sun)
	sky_material = SceneryMat.shader_mat("sky")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if Settings.is_compat() else Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.adjustment_enabled = true
	match theme:
		"arena":
			_arena()
		"coast":
			_coast()
		_:
			_city()
	for k in _TUNED_PROPS:
		_authored[k] = env.get(k)
	retune()


func _sky(params: Dictionary) -> void:
	for k in params:
		sky_material.set_shader_parameter(k, params[k])


func _glow_levels(levels: Array) -> void:
	for i in levels.size():
		env.set_glow_level(i, levels[i])


func _city() -> void:
	# Rainy night: blue-violet overcast lit from below by the city, magenta/orange light pollution.
	var moon_dir := Vector3(0.35, 0.55, 0.75).normalized()
	_sky({
		"zenith_color": Color(0.01, 0.012, 0.035), "sky_color": Color(0.025, 0.028, 0.08),
		"horizon_color": Color(0.1, 0.06, 0.16), "ground_color": Color(0.02, 0.015, 0.03),
		"horizon_falloff": 7.0, "glow_color": Color(0.75, 0.25, 0.45), "glow_strength": 0.35,
		"glow_height": 0.05, "sun_dir": moon_dir, "sun_color": Color(0.6, 0.65, 0.9),
		"sun_strength": 0.0, "halo_strength": 0.15, "halo_size": 3.0,
		"cloud_cover": 0.72, "cloud_sharpness": 1.6, "cloud_scale": 0.45,
		"cloud_dark": Color(0.02, 0.02, 0.05), "cloud_lit": Color(0.22, 0.1, 0.24),
		"cloud_lit_from_below": 1.1, "star_amount": 0.0, "energy": 1.0,
	})
	sun.light_color = Color(0.55, 0.62, 0.95)
	sun.light_energy = 0.32
	sun.basis = Basis.looking_at(-moon_dir, Vector3.UP)
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.6
	env.background_energy_multiplier = 1.0
	env.fog_light_color = Color(0.07, 0.07, 0.15)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0042
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.25
	env.fog_height = 2.0
	env.fog_height_density = 0.02
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_hdr_scale = 2.0
	_glow_levels([0.0, 0.6, 1.0, 0.9, 0.6, 0.3, 0.0])
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.6, 0.55, 0.75)
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_ambient_inject = 0.4
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0


func _arena() -> void:
	# Night stadium: deep purple sky, cyan/magenta haze, strong bloom from floodlights.
	var key_dir := Vector3(-0.4, 0.75, 0.5).normalized()
	_sky({
		"zenith_color": Color(0.01, 0.006, 0.03), "sky_color": Color(0.035, 0.015, 0.07),
		"horizon_color": Color(0.12, 0.04, 0.2), "ground_color": Color(0.02, 0.01, 0.04),
		"horizon_falloff": 5.0, "glow_color": Color(0.2, 0.45, 1.0), "glow_strength": 0.4,
		"glow_height": 0.06, "sun_dir": key_dir, "sun_color": Color(0.7, 0.8, 1.0),
		"sun_strength": 0.0, "halo_strength": 0.0,
		"cloud_cover": 0.35, "cloud_sharpness": 2.0, "cloud_scale": 0.5,
		"cloud_dark": Color(0.02, 0.01, 0.05), "cloud_lit": Color(0.25, 0.08, 0.35),
		"cloud_lit_from_below": 1.0, "star_amount": 1.0, "energy": 1.0,
	})
	sun.light_color = Color(0.8, 0.85, 1.0)
	sun.light_energy = 0.75
	sun.basis = Basis.looking_at(-key_dir, Vector3.UP)
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color(0.25, 0.12, 0.4)
	env.ambient_light_energy = 1.4
	env.fog_light_color = Color(0.16, 0.07, 0.26)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.fog_height = 3.0
	env.fog_height_density = 0.015
	env.glow_intensity = 1.1
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_hdr_scale = 2.0
	_glow_levels([0.0, 0.5, 1.0, 1.0, 0.8, 0.4, 0.1])
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_out = 2.0
	env.ssao_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.7, 0.6, 0.9)
	env.volumetric_fog_length = 200.0
	env.volumetric_fog_ambient_inject = 0.3
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.2
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0


func _coast() -> void:
	# Dusk: low warm sun over the sea, pink-orange clouds, deep blue zenith.
	var sun_dir := Vector3(-0.62, 0.075, -0.78).normalized()
	_sky({
		"zenith_color": Color(0.05, 0.09, 0.28), "sky_color": Color(0.28, 0.26, 0.5),
		"horizon_color": Color(1.0, 0.5, 0.28), "ground_color": Color(0.12, 0.08, 0.12),
		"horizon_falloff": 4.0, "zenith_falloff": 0.8,
		"glow_color": Color(1.0, 0.35, 0.12), "glow_strength": 1.1, "glow_height": 0.1,
		"glow_dir": sun_dir, "glow_dir_amount": 0.85,
		"sun_dir": sun_dir, "sun_color": Color(1.0, 0.62, 0.3), "sun_size": 0.035,
		"sun_strength": 14.0, "halo_strength": 1.6, "halo_size": 3.0,
		"cloud_cover": 0.5, "cloud_sharpness": 2.2, "cloud_scale": 0.35, "cloud_streak": 3.0,
		"cloud_offset": Vector2(3.0, 1.0),
		"cloud_dark": Color(0.28, 0.18, 0.32), "cloud_lit": Color(1.0, 0.55, 0.45),
		"cloud_lit_from_below": 0.5, "cloud_sun_lit": 1.4, "star_amount": 0.25, "energy": 1.0,
	})
	sun.light_color = Color(1.0, 0.62, 0.36)
	sun.light_energy = 1.7
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP)
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.fog_light_color = Color(0.75, 0.48, 0.42)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.5
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	_glow_levels([0.0, 0.4, 1.0, 0.8, 0.5, 0.2, 0.0])
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(1.0, 0.8, 0.7)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 300.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.1
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0


func _quality_extras() -> void:
	if env.ssr_enabled:
		# Settings' 48 steps only reach a few metres: the wet-road neon reflections need more.
		env.ssr_max_steps = 192 if Settings.quality <= 2 else 256
	if Settings.is_compat():
		# No SSR/volumetrics on the web: lean on fog and glow; keep glow cheaper.
		env.glow_bloom = 0.0 if theme == "coast" else env.glow_bloom
		if theme == "city":
			env.fog_density = 0.005


func _sun_extras() -> void:
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.shadow_blur = 1.5
	if theme != "coast":
		# Night: the moon/key light is weak, shadows are a luxury.
		sun.shadow_enabled = sun.shadow_enabled and Settings.quality >= 2
	sun.directional_shadow_fade_start = 0.8
