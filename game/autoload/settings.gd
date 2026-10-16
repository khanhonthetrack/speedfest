extends Node
## Global user settings: graphics quality, audio, units, server URL and the input map.
## Persisted in user://settings.cfg (IndexedDB on web).

signal changed

const SAVE_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
# PC display options (M7). Indexes are what settings.cfg stores.
const WINDOW_NAMES := ["Window", "Borderless", "Fullscreen"]       # Fullscreen = exclusive
const VSYNC_NAMES := ["Off", "On", "Adaptive", "Mailbox"]          # = DisplayServer.VSYNC_*
const FPS_CAP_NAMES := ["Unlimited", "VRR", "30", "60", "120", "144", "165", "240"]
const AA_NAMES := ["Auto", "Off", "FXAA", "SMAA", "TAA", "FSR 2"]
enum AA { AUTO, OFF, FXAA, SMAA, TAA, FSR2 }
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var quality: int = 2
var render_scale: float = 1.0
var vsync_mode: int = DisplayServer.VSYNC_ENABLED
var window_mode: int = 2
var fps_cap: int = 0
var aa_mode: int = AA.AUTO
var show_fps: bool = false
var show_pb_ghost: bool = true
var units_mph: bool = false
var camera_mode: int = 0
var master_volume: float = 0.8
var music_volume: float = 0.55
var sfx_volume: float = 0.9
var server_url: String = ""

# Optional NVIDIA RTX: only does anything in a build of NVIDIA's Godot fork (docs/RTX.md).
const DLSS_NAMES := ["Off", "DLAA", "Quality", "Balanced", "Performance"]
const DLSS_SCALES := [1.0, 1.0, 0.67, 0.58, 0.5]
const REFLEX_NAMES := ["Off", "On", "Boost"]
var rtx_path_tracing: bool = false
var rtx_bounces: int = 2
var dlss_mode: int = 0                  # 0 = mainline AA/upscaling; path tracing uses at least Quality
var dlss_frame_gen: bool = false
var reflex_mode: int = 1
var rtx_allow_noisy := false            # --rtx in tests: path trace without the DLSS denoiser (Linux fork)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Physics interpolation (project setting on, M7): physics runs at 60 Hz, screens at 120-240 Hz,
	# so physics-driven bodies must be drawn between ticks or they judder. Only the Car opts in
	# (Car.create); everything moved per frame (cameras, remote cars, ghosts, menus, UI, props)
	# stays as it is, so the whole tree defaults to OFF.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_setup_audio_buses()
	_setup_input_map()
	if is_web():
		quality = 1
	load_settings()
	if TestHooks.has_arg("quality"):
		quality = clampi(int(TestHooks.arg("quality", 2)), 0, 3)
	if TestHooks.has_arg("rtx"):                     # force path tracing on a fork build (tests/screenshots)
		rtx_path_tracing = true
		rtx_allow_noisy = true
	if TestHooks.has_arg("dlss"):
		dlss_mode = maxi(0, DLSS_NAMES.find(String(TestHooks.arg("dlss", "Quality"))))
	if TestHooks.has_arg("aa"):                      # --aa=FSR2 / TAA / SMAA / FXAA / Off / Auto
		aa_mode = maxi(0, AA_NAMES.find(String(TestHooks.arg("aa", "Auto")).replace("FSR2", "FSR 2")))
	apply()


# --- platform -----------------------------------------------------------------

func is_web() -> bool:
	return OS.has_feature("web")


func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## How many dynamic (non-shadowed) omni/spot lights a scene should use at most.
## Compatibility renders each light per object in extra passes, so keep it small there.
func light_budget() -> int:
	if is_compat():
		return [4, 8, 12, 16][quality]
	return [16, 48, 96, 160][quality]


## Whether secondary lights (lamps, neon) may cast shadows.
func local_shadows() -> bool:
	return not is_compat() and quality >= 2


## Scenery authors environments at max quality; this strips what the current
## renderer/quality can't afford. Call after configuring an Environment.
## path_trace = false for environments drawn in a SubViewport: the RTX fork's denoiser runs only in
## a viewport's DLSS pass, and SubViewports don't get one.
func tune_environment(env: Environment, path_trace := true) -> void:
	if env == null:
		return
	if is_compat():
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = false
		env.glow_enabled = env.glow_enabled and quality >= 1
		return
	# PC presets (M7, docs/research/m7_pc_rtx.md 1.7). Their resolution/quality is global:
	# _apply_render_globals() (SSR half size on Medium, SSAO/SSIL quality, fog grid size).
	env.ssr_enabled = env.ssr_enabled and quality >= 1
	if env.ssr_enabled:
		env.ssr_max_steps = [0, 48, 96, 160][quality]
	env.ssao_enabled = env.ssao_enabled and quality >= 1
	env.ssil_enabled = env.ssil_enabled and quality >= 3
	env.sdfgi_enabled = env.sdfgi_enabled and quality >= 3
	env.volumetric_fog_enabled = env.volumetric_fog_enabled and quality >= 2
	env.glow_enabled = env.glow_enabled and quality >= 1
	_apply_path_tracing(env, path_trace)


## Configure a key light's shadow according to quality.
func tune_sun(light: DirectionalLight3D) -> void:
	if light == null:
		return
	light.shadow_enabled = quality >= 1
	if is_compat():
		light.directional_shadow_max_distance = [80.0, 140.0, 220.0, 320.0][quality]
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	else:
		light.directional_shadow_max_distance = [80.0, 150.0, 250.0, 350.0][quality]
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		light.directional_shadow_blend_splits = quality >= 2
		light.light_angular_distance = 0.5 if quality >= 3 else 0.0      # soft (PCSS) shadows on Ultra


# --- persistence --------------------------------------------------------------

func load_settings(path: String = SAVE_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	quality = clampi(cfg.get_value("video", "quality", quality), 0, 3)
	render_scale = clampf(cfg.get_value("video", "render_scale", render_scale), 0.5, 1.0)
	# before M7 these were the booleans "vsync" and "fullscreen"
	var old_vsync := 1 if bool(cfg.get_value("video", "vsync", true)) else 0
	vsync_mode = clampi(int(cfg.get_value("video", "vsync_mode", old_vsync)), 0, VSYNC_NAMES.size() - 1)
	var old_window := 2 if bool(cfg.get_value("video", "fullscreen", window_mode != 0)) else 0
	window_mode = clampi(int(cfg.get_value("video", "window_mode", old_window)), 0, WINDOW_NAMES.size() - 1)
	fps_cap = clampi(int(cfg.get_value("video", "fps_cap", fps_cap)), 0, FPS_CAP_NAMES.size() - 1)
	aa_mode = clampi(int(cfg.get_value("video", "aa_mode", aa_mode)), 0, AA_NAMES.size() - 1)
	rtx_path_tracing = bool(cfg.get_value("video", "rtx_path_tracing", rtx_path_tracing))
	rtx_bounces = clampi(int(cfg.get_value("video", "rtx_bounces", rtx_bounces)), 1, 3)
	dlss_mode = clampi(int(cfg.get_value("video", "dlss_mode", dlss_mode)), 0, DLSS_NAMES.size() - 1)
	dlss_frame_gen = bool(cfg.get_value("video", "dlss_frame_gen", dlss_frame_gen))
	reflex_mode = clampi(int(cfg.get_value("video", "reflex_mode", reflex_mode)), 0, REFLEX_NAMES.size() - 1)
	show_fps = cfg.get_value("video", "show_fps", show_fps)
	show_pb_ghost = cfg.get_value("game", "show_pb_ghost", show_pb_ghost)
	units_mph = cfg.get_value("game", "units_mph", units_mph)
	camera_mode = cfg.get_value("game", "camera_mode", camera_mode)
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	server_url = cfg.get_value("net", "server_url", server_url)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "vsync_mode", vsync_mode)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "fps_cap", fps_cap)
	cfg.set_value("video", "aa_mode", aa_mode)
	cfg.set_value("video", "rtx_path_tracing", rtx_path_tracing)
	cfg.set_value("video", "rtx_bounces", rtx_bounces)
	cfg.set_value("video", "dlss_mode", dlss_mode)
	cfg.set_value("video", "dlss_frame_gen", dlss_frame_gen)
	cfg.set_value("video", "reflex_mode", reflex_mode)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("game", "show_pb_ghost", show_pb_ghost)
	cfg.set_value("game", "units_mph", units_mph)
	cfg.set_value("game", "camera_mode", camera_mode)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("net", "server_url", server_url)
	cfg.save(SAVE_PATH)


## Apply everything to the engine and emit `changed` (scenes re-tune environments on it).
func apply() -> void:
	var vp := get_viewport()
	if vp:
		apply_viewport(vp)
	_apply_render_globals()
	if not is_web():
		DisplayServer.window_set_vsync_mode(vsync_mode as DisplayServer.VSyncMode)
		Engine.max_fps = max_fps()
		if not TestHooks.is_testing():
			var want: DisplayServer.WindowMode = [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][window_mode]
			if DisplayServer.window_get_mode() != want:
				DisplayServer.window_set_mode(want)
	_set_bus_volume("Master", master_volume)
	_set_bus_volume(BUS_MUSIC, music_volume)
	_set_bus_volume(BUS_SFX, sfx_volume)
	changed.emit()


## Anti-aliasing and upscaling for a 3D viewport (the root one, or a SubViewport such as the garage).
func apply_viewport(vp: Viewport) -> void:
	vp.scaling_3d_scale = render_scale
	if is_compat():
		vp.msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		return
	# Forward+: no MSAA. Switching it at runtime recompiles pipelines (stutter), and post or
	# temporal AA cleans up the thin neon lines and barrier edges better anyway.
	vp.msaa_3d = Viewport.MSAA_DISABLED
	var aa := effective_aa()
	vp.screen_space_aa = [Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED,
		Viewport.SCREEN_SPACE_AA_FXAA, Viewport.SCREEN_SPACE_AA_SMAA, Viewport.SCREEN_SPACE_AA_DISABLED,
		Viewport.SCREEN_SPACE_AA_DISABLED][aa]
	vp.use_taa = aa == AA.TAA
	if aa == AA.FSR2:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2       # at 100 % scale it is a TAA
	elif render_scale < 0.999:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.use_debanding = quality >= 1                                 # night-sky gradients
	vp.anisotropic_filtering_level = [Viewport.ANISOTROPY_4X, Viewport.ANISOTROPY_8X,
		Viewport.ANISOTROPY_16X, Viewport.ANISOTROPY_16X][quality]
	vp.mesh_lod_threshold = [2.0, 1.0, 1.0, 0.75][quality]
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 4096][quality]
	_apply_dlss(vp)


## Renderer-wide quality (Forward+): effect resolutions and shadow filtering, per the PC preset table.
func _apply_render_globals() -> void:
	if is_compat() or DisplayServer.get_name() == "headless":
		return
	var q := quality
	RenderingServer.environment_set_ssr_half_size(q <= 1)
	RenderingServer.environment_set_ssao_quality([RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_LOW,
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_HIGH][q], q <= 1, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(128 if q >= 3 else 64, 128 if q >= 3 else 64)
	RenderingServer.environment_set_volumetric_fog_filter_active(true)
	RenderingServer.directional_shadow_atlas_set_size(4096 if q >= 2 else 2048, true)
	var soft: RenderingServer.ShadowQuality = [RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)


## The AA actually used: "Auto" picks per quality (Low FXAA, Medium TAA, High/Ultra FSR 2 native),
## and SMAA on a software renderer (llvmpipe: FSR 2's compute passes take seconds per frame there).
func effective_aa() -> int:
	if aa_mode != AA.AUTO:
		return aa_mode
	if is_software_gpu():
		return AA.SMAA if quality >= 1 else AA.FXAA
	return [AA.FXAA, AA.TAA, AA.FSR2, AA.FSR2][quality]


## True on a CPU "GPU" (Mesa llvmpipe/lavapipe: CI, containers, VMs without a GPU).
func is_software_gpu() -> bool:
	return RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU


## Engine.max_fps for the FPS limit. "VRR" caps a little under the refresh rate
## (r - r*r/3600: 144 Hz -> 138), which keeps G-Sync/FreeSync engaged with V-Sync on.
func max_fps() -> int:
	if fps_cap == 0:
		return 0
	if fps_cap == 1:
		var r := DisplayServer.screen_get_refresh_rate()     # -1 or NaN when the OS won't say
		if is_nan(r) or r < 30.0:
			r = 60.0
		return int(floor(r - r * r / 3600.0))
	return int(FPS_CAP_NAMES[fps_cap])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not is_web():
		window_mode = 0 if window_mode != 0 else 2
		apply()
		save()
		get_viewport().set_input_as_handled()


# --- optional NVIDIA RTX (NVIDIA's Godot fork, branch nvidia-pt-dlss) ------------------------------
# The fork adds Environment.pathtracing_*, Viewport.SCALING_3D_MODE_DLSS (= 6), Viewport.frame_generation
# and a Streamline singleton. All of it is reached through strings (set/call/ClassDB), so this compiles
# and stays inert on mainline 4.7.2 and on the web. docs/research/m7_pc_rtx.md 3-4 has the details.

func is_rtx_fork() -> bool:
	return ClassDB.class_has_method(&"Environment", &"set_pathtracing_enabled")


func _sl() -> Object:
	return Engine.get_singleton(&"Streamline") if Engine.has_singleton(&"Streamline") else null


func _sl_const(n: StringName) -> int:
	return ClassDB.class_get_integer_constant(&"Streamline", n) if ClassDB.class_has_integer_constant(&"Streamline", n) else -1


func _sl_cap(n: StringName) -> bool:
	var sl := _sl()
	var c := _sl_const(n)
	return sl != null and c >= 0 and bool(sl.call(&"get_capability", c))


## The GPU and driver can path trace (fork, Forward+, Vulkan: the fork's D3D12 driver has no RT).
func can_path_trace() -> bool:
	if not is_rtx_fork() or is_compat() or RenderingServer.get_current_rendering_driver_name() != "vulkan":
		return false
	var rd := RenderingServer.get_rendering_device()
	return rd != null and rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE)


## DLSS works: Windows fork build, Streamline DLLs next to the exe, an RTX GPU.
func dlss_available() -> bool:
	return is_rtx_fork() and not is_compat() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS")


## Ray Reconstruction is the fork's only path-tracing denoiser, and it runs inside the DLSS pass.
func dlss_rr_available() -> bool:
	return dlss_available() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS_RR")


func frame_gen_available() -> bool:
	return dlss_available() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS_G")


func reflex_available() -> bool:
	return is_rtx_fork() and _sl_cap(&"STREAMLINE_CAPABILITY_REFLEX")


func path_tracing_active() -> bool:
	return rtx_path_tracing and can_path_trace() and (dlss_rr_available() or rtx_allow_noisy)


func dlss_active() -> bool:
	return dlss_available() and (dlss_mode > 0 or path_tracing_active())


## One line for the settings screen: what the RTX build can do on this PC, and why not.
func rtx_status() -> String:
	if not is_rtx_fork():
		return "Needs the RTX build of SpeedFest."
	if is_compat():
		return "Needs the Forward+ renderer."
	if RenderingServer.get_current_rendering_driver_name() != "vulkan":
		return "Path tracing needs Vulkan (start without --rendering-driver d3d12)."
	if not can_path_trace():
		return "This GPU or driver has no Vulkan ray tracing."
	if not dlss_available():
		return "DLSS unavailable: needs an RTX GPU, Windows and the Streamline DLLs next to SpeedFest.exe."
	if not dlss_rr_available():
		return "DLSS Ray Reconstruction unavailable: update the NVIDIA driver."
	return "RTX ready."


func _apply_dlss(vp: Viewport) -> void:
	if not is_rtx_fork():
		return
	var on := dlss_active()
	vp.set(&"frame_generation", on and dlss_frame_gen and frame_gen_available())
	if reflex_available():               # Reflex works with or without DLSS
		_sl().call(&"set_parameter", _sl_const(&"STREAMLINE_PARAM_REFLEX_MODE"), reflex_mode)
	if not on:
		return
	vp.scaling_3d_mode = ClassDB.class_get_integer_constant(&"Viewport", &"SCALING_3D_MODE_DLSS") as Viewport.Scaling3DMode
	vp.scaling_3d_scale = float(DLSS_SCALES[dlss_mode if dlss_mode > 0 else 2])
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.fsr_sharpness = 0.0                       # under DLSS this is NIS sharpening


## Path tracing replaces SSR, SSAO, SSIL, SDFGI, VoxelGI and shadow maps; volumetric fog isn't traced.
func _apply_path_tracing(env: Environment, allowed := true) -> void:
	if not is_rtx_fork():
		return
	var pt := allowed and path_tracing_active()
	env.set(&"pathtracing_enabled", pt)
	if not pt:
		return
	env.set(&"pathtracing_samples_per_pixel", 1)
	env.set(&"pathtracing_max_bounces", rtx_bounces)
	env.set(&"pathtracing_denoiser", 1 if dlss_rr_available() else 0)   # 1 = DLSS Ray Reconstruction
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false


## Default server URL: same origin as the page on web, localhost on desktop.
func resolve_server_url() -> String:
	if server_url != "":
		return server_url
	if is_web():
		var proto: Variant = JavaScriptBridge.eval("window.location.protocol", true)
		var host: Variant = JavaScriptBridge.eval("window.location.host", true)
		if typeof(host) == TYPE_STRING and String(host) != "":
			var ws := "wss" if String(proto) == "https:" else "ws"
			return "%s://%s/ws" % [ws, host]
	return "ws://localhost:8080/ws"


# --- audio buses --------------------------------------------------------------

func _setup_audio_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


# --- input map ----------------------------------------------------------------

func _setup_input_map() -> void:
	_bind("accelerate", [KEY_W, KEY_UP], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("brake", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("steer_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("steer_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("handbrake", [KEY_SPACE], [JOY_BUTTON_B], [])
	_bind("nitro", [KEY_SHIFT, KEY_N], [JOY_BUTTON_A], [])
	_bind("respawn", [KEY_BACKSPACE, KEY_R], [JOY_BUTTON_Y], [])
	_bind("restart", [KEY_DELETE, KEY_ENTER], [JOY_BUTTON_BACK], [])
	_bind("camera_cycle", [KEY_C], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_bind("look_back", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER], [])
	_bind("leaderboard", [KEY_TAB], [], [])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_bind("toggle_fullscreen", [KEY_F11], [], [])


func _bind(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(action, jm)
