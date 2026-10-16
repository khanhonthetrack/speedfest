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
var _authored_levels: Array[float] = []
var _pano_amount := 0.0

const SkyPanoramas := preload("res://tracks/scenery/sky_panoramas.gd")

const _TUNED_PROPS := ["ssr_enabled", "ssao_enabled", "ssil_enabled", "sdfgi_enabled", "volumetric_fog_enabled", "glow_enabled",
	"fog_density", "fog_sky_affect", "volumetric_fog_density", "volumetric_fog_sky_affect",
	"glow_bloom", "glow_hdr_threshold", "glow_intensity", "glow_hdr_luminance_cap"]
## Forward+ bloom (M7 look plan step 2): only real highlights bloom (threshold above 1.0, no
## whole-frame glow_bloom), with a short tail. The web keeps the authored glow.
const PC_GLOW := {
	"city": {"threshold": 1.25, "intensity": 0.75, "levels": [0.0, 0.85, 1.0, 0.6, 0.25, 0.06, 0.0]},
	"arena": {"threshold": 1.2, "intensity": 0.85, "levels": [0.0, 0.75, 1.0, 0.65, 0.3, 0.08, 0.0]},
	"coast": {"threshold": 1.4, "intensity": -1.0, "levels": [0.0, 0.5, 1.0, 0.6, 0.3, 0.1, 0.0]},
}


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
	# start from the authored values every time (settings change often; nothing may compound)
	for k in _authored:
		env.set(k, _authored[k])
	for i in _authored_levels.size():
		env.set_glow_level(i, _authored_levels[i])
	# quality 0 (weak devices) keeps the procedural sky only
	sky_material.set_shader_parameter("pano_amount", _pano_amount if Settings.quality >= 1 else 0.0)
	Settings.tune_environment(env)
	_quality_extras()
	_pc_atmosphere()
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
	for i in 7:
		_authored_levels.append(env.get_glow_level(i))
	retune()


func _sky(params: Dictionary) -> void:
	for k in params:
		sky_material.set_shader_parameter(k, params[k])


## Photographed sky (session 7): a Poly Haven CC0 panorama (tools/textures/fetch_hdri.py) blended
## over the procedural sky. 2K on desktop High/Ultra, 1K elsewhere (web). params: the env_sky
## "pano_*" uniforms; "pano_exposure" is relative to the photo's real brightness; "align_dir" turns
## the panorama so its brightest spot (sun or moon) sits at that direction's azimuth.
func _panorama(params: Dictionary) -> void:
	if not SkyPanoramas.SKIES.has(theme):
		return
	var tex: Texture2D = null
	var paths: Array[String] = ["res://assets/sky/%s_sky.jpg" % theme]
	if not Settings.is_compat() and Settings.quality >= 2:
		paths.push_front("res://assets/hd/sky/%s_sky.jpg" % theme)
	for path in paths:
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	if tex == null:
		return
	var row: Dictionary = SkyPanoramas.SKIES[theme]
	var p := params.duplicate()
	p["panorama"] = tex
	p["pano_exposure"] = float(params.get("pano_exposure", 1.0)) / float(row["scale"])
	if p.has("align_dir"):
		var a: Vector3 = p["align_dir"]
		var want := fposmod(atan2(a.x, -a.z) / TAU, 1.0)
		p["pano_rotation"] = fposmod(float(row["bright_u"]) - want, 1.0)
		p.erase("align_dir")
	_pano_amount = float(p.get("pano_amount", 1.0))
	p.erase("pano_amount")
	_sky(p)


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
	# photo: overcast night with the moon breaking through, graded violet and lit from below by
	# the city glow (kept on top)
	_panorama({"pano_exposure": 0.3, "pano_tint": Color(0.75, 0.6, 1.0), "pano_saturation": 0.6,
		"pano_glow_keep": 1.0, "align_dir": moon_dir})
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
	# volumetric haze lit by the street lights, not by the sky or the moon, and kept off the sky
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.005
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.85)
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_ambient_inject = 0.08
	env.volumetric_fog_sky_affect = 0.1
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_temporal_reprojection_amount = 0.8
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0


func _arena() -> void:
	# Night stadium (session 4: a real stadium with a lawn, not synthwave): navy sky with a warm
	# floodlight halo, neutral haze, white floodlights so the grass reads green.
	var key_dir := Vector3(-0.4, 0.75, 0.5).normalized()
	_sky({
		"zenith_color": Color(0.006, 0.01, 0.025), "sky_color": Color(0.02, 0.03, 0.06),
		"horizon_color": Color(0.07, 0.075, 0.1), "ground_color": Color(0.02, 0.02, 0.025),
		"horizon_falloff": 5.0, "glow_color": Color(0.95, 0.85, 0.65), "glow_strength": 0.3,
		"glow_height": 0.06, "sun_dir": key_dir, "sun_color": Color(0.7, 0.8, 1.0),
		"sun_strength": 0.0, "halo_strength": 0.0,
		"cloud_cover": 0.35, "cloud_sharpness": 2.0, "cloud_scale": 0.5,
		"cloud_dark": Color(0.02, 0.02, 0.03), "cloud_lit": Color(0.16, 0.16, 0.19),
		"cloud_lit_from_below": 1.0, "star_amount": 1.0, "energy": 1.0,
	})
	# photo: clear moonlit night (the moon sits behind the key light); sharp procedural stars on top
	_panorama({"pano_exposure": 0.32, "pano_tint": Color(0.8, 0.88, 1.0), "pano_saturation": 0.8,
		"pano_glow_keep": 0.6, "pano_star_keep": 0.5, "align_dir": key_dir})
	sun.light_color = Color(0.95, 0.96, 1.0)
	sun.light_energy = 0.9
	sun.basis = Basis.looking_at(-key_dir, Vector3.UP)
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color(0.22, 0.24, 0.28)
	env.ambient_light_energy = 1.25
	env.fog_light_color = Color(0.1, 0.11, 0.14)
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
	env.volumetric_fog_density = 0.0022
	env.volumetric_fog_albedo = Color(0.65, 0.67, 0.72)
	env.volumetric_fog_length = 200.0
	env.volumetric_fog_ambient_inject = 0.05
	env.volumetric_fog_sky_affect = 0.1
	env.volumetric_fog_anisotropy = 0.5
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.08
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0


func _coast() -> void:
	# Dusk: low warm sun over the sea, pink-orange clouds, deep blue zenith.
	var sun_dir := Vector3(-0.62, 0.075, -0.78).normalized()
	if SkyPanoramas.SKIES.has("coast") and Settings.quality >= 1:
		# the photographed sun sits lower than the procedural one: light from where it is seen
		var el := (0.5 - float(SkyPanoramas.SKIES["coast"]["bright_v"])) * PI
		var flat := Vector3(sun_dir.x, 0.0, sun_dir.z).normalized()
		sun_dir = (flat * cos(el) + Vector3.UP * sin(el)).normalized()
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
	# photo: low sun under a cloud deck over open water; the procedural sun disk and a little of
	# the warm glow band stay on top
	_panorama({"pano_exposure": 0.08, "pano_tint": Color(1.05, 0.93, 0.92), "pano_saturation": 1.3,
		"pano_top_tint": Color(0.45, 0.4, 0.9), "pano_glow_keep": 0.35, "align_dir": sun_dir})
	sun.light_color = Color(1.0, 0.62, 0.36)
	sun.light_energy = 1.7
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP)
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.fog_light_color = Color(0.75, 0.48, 0.42)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.0006
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
	env.volumetric_fog_sky_affect = 0.3
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.1
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0


## Forward+ only (M7 look plan steps 1-2): with volumetric fog on, the exponential fog is thinned
## (the two stacked and flattened the skyline), and bloom keeps to real highlights.
## Look-dev: --vfog=<density x> --vsky=<sky affect> --glow=old (authored bloom, for A/B shots).
func _pc_atmosphere() -> void:
	if Settings.is_compat():
		return
	if env.volumetric_fog_enabled:
		env.fog_density = float(_authored["fog_density"]) * 0.6
		env.fog_sky_affect = float(_authored["fog_sky_affect"]) * 0.5
		env.volumetric_fog_density = float(_authored["volumetric_fog_density"]) * float(TestHooks.arg("vfog", 1.0))
		if TestHooks.has_arg("vsky"):
			env.volumetric_fog_sky_affect = float(TestHooks.arg("vsky", 0.1))
	if env.glow_enabled and String(TestHooks.arg("glow", "")) != "old":
		var g: Dictionary = PC_GLOW.get(theme, PC_GLOW["city"])
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = float(g["threshold"])
		env.glow_hdr_luminance_cap = 8.0
		if float(g["intensity"]) > 0.0:
			env.glow_intensity = float(g["intensity"])
		_glow_levels(g["levels"])


func _quality_extras() -> void:
	if TestHooks.has_arg("tonemap") and not Settings.is_compat():      # look-dev: --tonemap=agx
		if String(TestHooks.arg("tonemap", "")) == "agx":
			env.tonemap_mode = Environment.TONE_MAPPER_AGX
			env.tonemap_agx_white = float(TestHooks.arg("agx_white", 10.0))
			env.tonemap_agx_contrast = float(TestHooks.arg("agx_contrast", 1.25))
	if env.ssr_enabled:
		# Settings' 48 steps only reach a few metres: the wet-road neon reflections need more.
		env.ssr_max_steps = 192 if Settings.quality <= 2 else 256
	if Settings.is_compat():
		# No SSR/volumetrics on the web: lean on fog and glow; keep glow cheaper.
		env.glow_bloom = 0.0 if theme == "coast" else env.glow_bloom
		if theme == "city":
			env.fog_density = 0.005


func _sun_extras() -> void:
	sun.shadow_bias = 0.1 if theme == "coast" else 0.04
	sun.shadow_normal_bias = 3.0 if theme == "coast" else 1.5
	sun.shadow_blur = 1.5
	if theme != "coast":
		# Night: the moon/key light is weak, shadows are a luxury.
		sun.shadow_enabled = sun.shadow_enabled and Settings.quality >= 2
	sun.directional_shadow_fade_start = 0.8
	# the moon/key light no longer lights the whole fog volume (the dusk sun's rays are wanted)
	sun.light_volumetric_fog_energy = 1.0 if theme == "coast" else 0.15
