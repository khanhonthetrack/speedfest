class_name TmRtx
extends RefCounted
## Graphics for strong GPUs. On stock Godot: the quality presets (TmUi setting "quality": 0 Low,
## 1 High, 2 Ultra: global illumination (SDFGI), screen-space reflections and indirect light,
## light volumetric haze, four shadow splits). On NVIDIA's RTX fork of Godot (branch
## nvidia-pt-dlss; see docs/RTX.md on SpeedFest's m7-rtx branch, built on this PC in
## C:\dev\godot-rtx): DLSS upscaling (the Fast model on RTX 20/30 cards, measured on an RTX 2060)
## and optional path tracing with DLSS Ray Reconstruction. Everything of the fork is reached
## through strings (set/call/ClassDB), so this compiles and stays inert on stock Godot.

const DLSS_NAMES := ["Off", "DLAA", "Quality", "Balanced", "Performance"]
const DLSS_SCALES := [1.0, 1.0, 0.67, 0.58, 0.5]
const QUALITY_NAMES := ["Low", "High", "Ultra"]


static func is_fork() -> bool:
	return ClassDB.class_has_method(&"Environment", &"set_pathtracing_enabled")


static func _sl() -> Object:
	return Engine.get_singleton(&"Streamline") if Engine.has_singleton(&"Streamline") else null


static func _sl_const(n: StringName) -> int:
	return ClassDB.class_get_integer_constant(&"Streamline", n) if ClassDB.class_has_integer_constant(&"Streamline", n) else -1


static func _sl_cap(n: StringName) -> bool:
	var sl := _sl()
	var c := _sl_const(n)
	return sl != null and c >= 0 and bool(sl.call(&"get_capability", c))


## The GPU and driver can path trace (fork, Vulkan, a ray-tracing pipeline).
static func can_path_trace() -> bool:
	if not is_fork() or RenderingServer.get_current_rendering_driver_name() != "vulkan":
		return false
	var rd := RenderingServer.get_rendering_device()
	return rd != null and rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE)


static func dlss_available() -> bool:
	return is_fork() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS")


static func rr_available() -> bool:
	return dlss_available() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS_RR")


static func path_tracing_active() -> bool:
	return bool(TmUi.setting("path_tracing")) and can_path_trace() and (rr_available() or TestHooks.has_arg("rtx_noisy"))


static func dlss_mode() -> int:
	return clampi(int(TmUi.setting("dlss")), 0, DLSS_NAMES.size() - 1)


static func dlss_active() -> bool:
	return dlss_available() and (dlss_mode() > 0 or path_tracing_active())


## One line for the options page: what this build can do here, and why not.
static func status() -> String:
	if not is_fork():
		return ""
	if RenderingServer.get_current_rendering_driver_name() != "vulkan":
		return "Path tracing needs Vulkan."
	if not can_path_trace():
		return "This GPU or driver has no Vulkan ray tracing."
	if not dlss_available():
		return "DLSS unavailable: needs an RTX GPU and the Streamline DLLs next to the game."
	if not rr_available():
		return "DLSS Ray Reconstruction unavailable: update the NVIDIA driver."
	return "RTX ready."


## The DLSS model: the CNN (preset F) on RTX 20/30 cards (2-3x cheaper there), else the driver's.
static func dlss_preset(gpu_name: String) -> String:
	var older := RegEx.create_from_string("RTX\\s*(20|30)\\d\\d|Quadro RTX|RTX A\\d{3,4}").search(gpu_name) != null
	return "F" if older else "?"


## The viewport's anti-aliasing and upscaling: DLSS on the fork when on, else the project's
## 4x MSAA and SMAA for shader and thin-line edges (no TAA: it smeared the moving car).
static func apply_viewport(vp: Viewport) -> void:
	if not is_fork():
		return
	if dlss_active():
		vp.set(&"scaling_3d_mode", ClassDB.class_get_integer_constant(&"Viewport", &"SCALING_3D_MODE_DLSS"))
		vp.scaling_3d_scale = float(DLSS_SCALES[dlss_mode() if dlss_mode() > 0 else 2])
		vp.use_taa = false
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_sl().call(&"set_parameter", _sl_const(&"STREAMLINE_PARAM_DLSS_PRESET"), dlss_preset(RenderingServer.get_video_adapter_name()))
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.use_taa = false
		vp.msaa_3d = Viewport.MSAA_4X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA


## The environment's effects for the quality preset, and path tracing on the fork.
static func apply_environment(env: Environment, sun: DirectionalLight3D) -> void:
	var q := clampi(int(TmUi.setting("quality")), 0, 2)
	if q == 0:
		env.ssao_enabled = false
		env.glow_enabled = false
		sun.directional_shadow_max_distance = 300.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	elif q == 2:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 6
		env.sdfgi_min_cell_size = 0.4
		env.sdfgi_energy = 0.9
		env.ssr_enabled = true
		env.ssr_max_steps = 96
		env.ssr_fade_in = 0.1
		env.ssr_fade_out = 3.0
		env.ssil_enabled = true
		env.ssil_intensity = 0.8
		env.ssao_intensity = 1.6
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0006
		env.volumetric_fog_albedo = Color(0.85, 0.9, 1.0)
		env.volumetric_fog_anisotropy = 0.6
		env.volumetric_fog_length = 400.0
		env.volumetric_fog_sky_affect = 0.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 900.0
		sun.light_volumetric_fog_energy = 0.6
	if not is_fork():
		return
	var pt := path_tracing_active()
	env.set(&"pathtracing_enabled", pt)
	if pt:
		env.set(&"pathtracing_samples_per_pixel", 1)
		env.set(&"pathtracing_max_bounces", clampi(int(TmUi.setting("rtx_bounces")), 1, 3))
		env.set(&"pathtracing_denoiser", 1 if rr_available() else 0)
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = false
