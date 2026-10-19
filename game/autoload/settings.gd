extends Node
## Global user settings and the one place that owns the look of the renderer.
##
## SpeedFest is Forward+ only (the browser build was removed on 2026-10-19), so there is no
## compatibility branch: quality 0..3 scales a PC preset, and an optional RTX path lights up when the
## game runs on a build of NVIDIA's Godot fork (docs/RTX.md).
##
## Scenes build their Environment at full quality through `night_environment()` and then call
## `tune_environment(env)`, which strips what the current quality level cannot afford.
## Persisted in user://settings.cfg.

signal changed

const SAVE_PATH := "user://settings.cfg"
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
const WINDOW_NAMES: Array[String] = ["Window", "Borderless", "Fullscreen"]
const VSYNC_NAMES: Array[String] = ["Off", "On", "Adaptive", "Mailbox"]
const DLSS_NAMES: Array[String] = ["Off", "DLAA", "Quality", "Balanced", "Performance"]
const DLSS_SCALES: Array[float] = [1.0, 1.0, 0.67, 0.58, 0.5]
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var quality: int = 2
var render_scale: float = 1.0
var vsync_mode: int = DisplayServer.VSYNC_ENABLED
var window_mode: int = 0
var show_fps: bool = false
var units_mph: bool = false
var camera_mode: int = 0
var master_volume: float = 0.8
var music_volume: float = 0.55
var sfx_volume: float = 0.9

# Optional NVIDIA RTX: only does anything in a build of NVIDIA's Godot fork (docs/RTX.md).
var rtx_path_tracing: bool = false
var rtx_bounces: int = 2
var dlss_mode: int = 0
var rtx_allow_noisy: bool = false     ## --rtx in tests: path trace without the DLSS denoiser


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Physics interpolation is on in project.godot: the car runs at 100 Hz and the screen at
	# whatever the monitor does, so physics-driven bodies must be drawn between ticks. Only the car
	# opts in; everything moved per frame (cameras, props, UI) stays off.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_setup_audio_buses()
	_setup_input_map()
	load_settings()
	if TestHooks.has_arg("quality"):
		quality = clampi(int(TestHooks.arg("quality", 2)), 0, 3)
	if TestHooks.has_arg("rtx"):
		rtx_path_tracing = true
		rtx_allow_noisy = true
	_apply_render_globals()
	_apply_audio()


# --- capabilities -------------------------------------------------------------------------------

func quality_name() -> String:
	return QUALITY_NAMES[clampi(quality, 0, 3)]


## How many dynamic omni/spot lights a scene should light up at most. The night city is made of
## light, so this is the budget every generator spends.
func light_budget() -> int:
	return [24, 64, 140, 240][clampi(quality, 0, 3)]


## Whether secondary lights (street lamps, neon tubes, headlights) may cast shadows.
func local_shadows() -> bool:
	return quality >= 2


## Running on NVIDIA's fork (the only build with path tracing, DLSS, Reflex).
func is_rtx_fork() -> bool:
	return ClassDB.class_has_method(&"Environment", &"set_pathtracing_enabled")


func can_path_trace() -> bool:
	if not is_rtx_fork() or RenderingServer.get_current_rendering_driver_name() != "vulkan":
		return false
	var rd := RenderingServer.get_rendering_device()
	return rd != null and rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE)


func _sl() -> Object:
	return Engine.get_singleton(&"Streamline") if Engine.has_singleton(&"Streamline") else null


func _sl_cap(n: StringName) -> bool:
	var sl := _sl()
	if sl == null or not ClassDB.class_has_integer_constant(&"Streamline", n):
		return false
	var c := ClassDB.class_get_integer_constant(&"Streamline", n)
	return sl.has_method(&"is_feature_supported") and bool(sl.call(&"is_feature_supported", c))


func dlss_available() -> bool:
	return is_rtx_fork() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS")


## Ray Reconstruction is the fork's only path-tracing denoiser; without it path tracing is 1-sample
## noise, so the game refuses to turn it on (unless a test passes --rtx).
func dlss_rr_available() -> bool:
	return is_rtx_fork() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS_RR")


func path_tracing_active() -> bool:
	return rtx_path_tracing and can_path_trace() and (dlss_rr_available() or rtx_allow_noisy)


## One line for the settings menu / HUD: what the renderer is actually doing.
func render_status() -> String:
	if path_tracing_active():
		return "RTX path tracing, %d bounces%s" % [rtx_bounces,
			", DLSS Ray Reconstruction" if dlss_rr_available() else " (undenoised)"]
	if not is_rtx_fork():
		return "Forward+ %s (SDFGI %s, SSR %s)" % [quality_name(),
			"on" if quality >= 3 else "off", "on" if quality >= 1 else "off"]
	return "Forward+ %s on the RTX fork; path tracing off" % quality_name()


# --- the night look -----------------------------------------------------------------------------

## The house environment: a city night. Scenes take this, tweak what they own (fog colour, sky
## tint) and then call tune_environment(). Authored at Ultra; tune_environment strips it down.
func night_environment() -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# A sodium-orange haze over the rooftops fading to deep blue overhead: the classic NFSU2 sky.
	sm.sky_top_color = Color(0.016, 0.020, 0.047)
	sm.sky_horizon_color = Color(0.090, 0.075, 0.125)
	sm.sky_curve = 0.14
	sm.sky_energy_multiplier = 1.0
	sm.ground_bottom_color = Color(0.008, 0.009, 0.014)
	sm.ground_horizon_color = Color(0.075, 0.062, 0.098)
	sm.ground_curve = 0.08
	sm.sun_angle_max = 24.0
	sm.sun_curve = 0.08
	sm.energy_multiplier = 1.0
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0

	# Neon is the key light of this game: glow is tuned to bite only on real emitters.
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 1.05
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.set_glow_level(1, 0.25)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.45)

	env.ssr_enabled = true
	env.ssr_max_steps = 160
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 8.0
	env.ssr_depth_tolerance = 0.3
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_light_affect = 0.1
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.2
	env.ssil_normal_rejection = 1.0

	# SDFGI carries the neon bounce down the street walls.
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 6
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.sdfgi_energy = 1.4
	env.sdfgi_bounce_feedback = 0.6

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.055, 0.058, 0.085)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.35
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 1400.0
	env.fog_depth_curve = 0.9

	# Volumetric fog is what makes neon tubes throw shafts down a wet street.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.62, 0.66, 0.78)
	env.volumetric_fog_emission = Color(0.012, 0.013, 0.022)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_anisotropy = 0.25
	env.volumetric_fog_length = 220.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.35

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	return env


## Strip an Ultra-authored Environment down to what `quality` (and the RTX path) can afford.
func tune_environment(env: Environment, path_trace: bool = true) -> void:
	if env == null:
		return
	var q := clampi(quality, 0, 3)
	env.ssr_enabled = env.ssr_enabled and q >= 1
	if env.ssr_enabled:
		env.ssr_max_steps = [0, 48, 96, 160][q]
	env.ssao_enabled = env.ssao_enabled and q >= 1
	env.ssil_enabled = env.ssil_enabled and q >= 3
	env.sdfgi_enabled = env.sdfgi_enabled and q >= 3
	env.volumetric_fog_enabled = env.volumetric_fog_enabled and q >= 2
	env.glow_enabled = env.glow_enabled and q >= 1
	_apply_path_tracing(env, path_trace)


func _apply_path_tracing(env: Environment, allowed: bool = true) -> void:
	if not is_rtx_fork():
		return
	var pt := allowed and path_tracing_active()
	env.set(&"pathtracing_enabled", pt)
	if not pt:
		return
	env.set(&"pathtracing_samples_per_pixel", 1)
	env.set(&"pathtracing_max_bounces", rtx_bounces)
	env.set(&"pathtracing_denoiser", 1 if dlss_rr_available() else 0)
	# The path tracer replaces every screen-space approximation.
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false


## Configure the moon/key light's shadow for the current quality.
func tune_sun(light: DirectionalLight3D) -> void:
	if light == null:
		return
	var q := clampi(quality, 0, 3)
	light.shadow_enabled = q >= 1
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_max_distance = [120.0, 220.0, 400.0, 600.0][q]
	light.directional_shadow_split_1 = 0.06
	light.directional_shadow_split_2 = 0.16
	light.directional_shadow_split_3 = 0.42
	light.directional_shadow_blend_splits = q >= 2
	light.shadow_blur = 1.0 if q >= 2 else 0.6
	light.light_angular_distance = 0.6


## Configure a neon / street light. Returns false when the light budget is spent, so generators
## can fall back to an emissive mesh only.
func tune_point_light(light: Light3D, shadows: bool = false) -> void:
	if light == null:
		return
	light.shadow_enabled = shadows and local_shadows()
	if light is OmniLight3D:
		(light as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.distance_fade_enabled = true
	light.distance_fade_begin = [40.0, 90.0, 180.0, 320.0][clampi(quality, 0, 3)]
	light.distance_fade_length = 24.0
	light.distance_fade_shadow = 24.0


func _apply_render_globals() -> void:
	var q := clampi(quality, 0, 3)
	RenderingServer.screen_space_roughness_limiter_set_active(true, 0.25, 0.18)
	RenderingServer.environment_set_ssao_quality(
		[RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_LOW,
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_HIGH][q],
		true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(
		[RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, RenderingServer.ENV_SSIL_QUALITY_LOW,
		RenderingServer.ENV_SSIL_QUALITY_MEDIUM, RenderingServer.ENV_SSIL_QUALITY_HIGH][q],
		true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_ssr_roughness_quality(
		[RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED, RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW,
		RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_MEDIUM, RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH][q])
	RenderingServer.environment_set_volumetric_fog_filter_active(q >= 2)
	RenderingServer.environment_set_volumetric_fog_volume_size(128 if q >= 3 else 64, 64 if q >= 3 else 32)
	RenderingServer.sub_surface_scattering_set_quality(RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_LOW)
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(vsync_mode as DisplayServer.VSyncMode)
	var vp := get_tree().root
	vp.scaling_3d_scale = render_scale
	vp.use_taa = q >= 2
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if q >= 2 else Viewport.SCREEN_SPACE_AA_FXAA


# --- audio --------------------------------------------------------------------------------------

func _setup_audio_buses() -> void:
	for bus in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus)
			AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, "Master")


func _apply_audio() -> void:
	_set_bus_db("Master", master_volume)
	_set_bus_db(BUS_MUSIC, music_volume)
	_set_bus_db(BUS_SFX, sfx_volume)


func _set_bus_db(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


# --- input --------------------------------------------------------------------------------------

const ACTIONS := {
	"drive": [KEY_UP, KEY_W],
	"brake": [KEY_DOWN, KEY_S],
	"steer_left": [KEY_LEFT, KEY_A],
	"steer_right": [KEY_RIGHT, KEY_D],
	"boost": [KEY_SHIFT, KEY_SPACE],
	"respawn": [KEY_BACKSPACE],
	"restart": [KEY_ENTER],
	"camera": [KEY_C],
	"pause": [KEY_ESCAPE],
	"look_back": [KEY_X],
}


func _setup_input_map() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# --- persistence --------------------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("video", "quality", quality)), 0, 3)
	render_scale = clampf(float(cfg.get_value("video", "render_scale", render_scale)), 0.5, 2.0)
	vsync_mode = int(cfg.get_value("video", "vsync", vsync_mode))
	window_mode = int(cfg.get_value("video", "window", window_mode))
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	rtx_path_tracing = bool(cfg.get_value("rtx", "path_tracing", rtx_path_tracing))
	rtx_bounces = clampi(int(cfg.get_value("rtx", "bounces", rtx_bounces)), 1, 8)
	dlss_mode = clampi(int(cfg.get_value("rtx", "dlss", dlss_mode)), 0, 4)
	units_mph = bool(cfg.get_value("game", "mph", units_mph))
	camera_mode = int(cfg.get_value("game", "camera", camera_mode))
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "vsync", vsync_mode)
	cfg.set_value("video", "window", window_mode)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("rtx", "path_tracing", rtx_path_tracing)
	cfg.set_value("rtx", "bounces", rtx_bounces)
	cfg.set_value("rtx", "dlss", dlss_mode)
	cfg.set_value("game", "mph", units_mph)
	cfg.set_value("game", "camera", camera_mode)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SAVE_PATH)


func apply_and_save() -> void:
	_apply_render_globals()
	_apply_audio()
	save_settings()
	changed.emit()
