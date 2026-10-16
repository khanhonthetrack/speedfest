extends Node
## Settings (M7 PC): anti-aliasing per quality without MSAA on Forward+ (runtime MSAA switches
## recompile pipelines), FPS limit values, and old settings.cfg keys (vsync/fullscreen booleans)
## migrating to the new modes. Never saves, so the player's settings.cfg is untouched.
## Run: tools/run_scene.sh res://tests/core/test_settings.tscn            (Forward+)
##      tools/run_scene.sh res://tests/core/test_settings.tscn --compat   (web renderer)

const KEYS := ["quality", "render_scale", "vsync_mode", "window_mode", "fps_cap", "aa_mode",
	"rtx_path_tracing", "rtx_bounces", "dlss_mode", "rtx_allow_noisy"]


func _ready() -> void:
	await get_tree().process_frame
	var saved := {}
	for k in KEYS:
		saved[k] = Settings.get(k)
	# the AA checks are about the mainline path: a fork player's saved DLSS/path tracing would override it
	Settings.dlss_mode = 0
	Settings.rtx_path_tracing = false
	var vp := get_viewport()
	if Settings.is_compat():
		Settings.quality = 2
		Settings.apply()
		TestHooks.check(vp.msaa_3d == Viewport.MSAA_2X, "settings_compat_keeps_msaa")
	else:
		TestHooks.check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 1)) == 0, "settings_project_msaa_off")
		var want := [Settings.AA.FXAA, Settings.AA.TAA, Settings.AA.FSR2, Settings.AA.FSR2]
		if Settings.is_software_gpu():
			want = [Settings.AA.FXAA, Settings.AA.SMAA, Settings.AA.SMAA, Settings.AA.SMAA]
		print("adapter %s type %d software %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_type(), Settings.is_software_gpu()])
		var msaa_seen := false
		var mapping_ok := true
		Settings.aa_mode = Settings.AA.AUTO
		Settings.render_scale = 1.0
		for q in 4:
			Settings.quality = q
			Settings.apply()
			msaa_seen = msaa_seen or vp.msaa_3d != Viewport.MSAA_DISABLED
			mapping_ok = mapping_ok and Settings.effective_aa() == want[q]
		TestHooks.check(not msaa_seen, "settings_no_msaa_on_forward_plus")
		TestHooks.check(mapping_ok, "settings_auto_aa_per_quality")
		Settings.aa_mode = Settings.AA.FSR2
		Settings.apply()
		TestHooks.check(vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 and not vp.use_taa
			and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "settings_fsr2")
		Settings.aa_mode = Settings.AA.TAA
		Settings.render_scale = 0.75
		Settings.apply()
		TestHooks.check(vp.use_taa and vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR
			and is_equal_approx(vp.scaling_3d_scale, 0.75), "settings_taa_with_fsr1_upscale")
		Settings.aa_mode = Settings.AA.SMAA
		Settings.render_scale = 1.0
		Settings.apply()
		TestHooks.check(vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_SMAA and not vp.use_taa
			and vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "settings_smaa")
	_rtx_checks()
	Settings.fps_cap = 0
	TestHooks.check(Settings.max_fps() == 0, "settings_fps_unlimited")
	Settings.fps_cap = Settings.FPS_CAP_NAMES.find("144")
	TestHooks.check(Settings.max_fps() == 144, "settings_fps_144")
	Settings.fps_cap = 1
	var r := DisplayServer.screen_get_refresh_rate()
	var vrr := Settings.max_fps()
	TestHooks.check(vrr > 25 and vrr < maxf(r, 60.0), "settings_fps_vrr_under_refresh", "refresh %.1f -> cap %d" % [r, vrr])
	# old settings.cfg: booleans
	var path := "user://test_settings_migration.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("video", "vsync", false)
	cfg.set_value("video", "fullscreen", true)
	cfg.save(path)
	Settings.load_settings(path)
	TestHooks.check(Settings.vsync_mode == DisplayServer.VSYNC_DISABLED and Settings.window_mode == 2, "settings_migrate_old_bools",
		"vsync_mode %d window_mode %d" % [Settings.vsync_mode, Settings.window_mode])
	cfg = ConfigFile.new()
	cfg.set_value("video", "vsync", true)
	cfg.set_value("video", "fullscreen", false)
	cfg.set_value("video", "vsync_mode", 3)
	cfg.save(path)
	Settings.load_settings(path)
	TestHooks.check(Settings.vsync_mode == 3 and Settings.window_mode == 0, "settings_new_keys_win")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for k in KEYS:
		Settings.set(k, saved[k])
	Settings.apply()
	TestHooks.finish()


## Mainline 4.7.2: the RTX layer must do nothing. NVIDIA's fork (Linux build on lavapipe, which
## has Vulkan ray tracing but no Streamline/DLSS): path tracing turns on, without a denoiser.
func _rtx_checks() -> void:
	# DLSS model Auto: the CNN preset on RTX 20/30 (measured on an RTX 2060), the driver's choice later
	var auto_ok := Settings.dlss_preset_for(0, "NVIDIA GeForce RTX 2060") == "F" \
		and Settings.dlss_preset_for(0, "NVIDIA GeForce RTX 3080 Ti Laptop GPU") == "F" \
		and Settings.dlss_preset_for(0, "Quadro RTX 4000") == "F" \
		and Settings.dlss_preset_for(0, "NVIDIA RTX A4000") == "F" \
		and Settings.dlss_preset_for(0, "NVIDIA GeForce RTX 4070") == "?" \
		and Settings.dlss_preset_for(0, "NVIDIA GeForce RTX 5090") == "?" \
		and Settings.dlss_preset_for(2, "NVIDIA GeForce RTX 2060") == "K" \
		and Settings.dlss_preset_for(3, "NVIDIA GeForce RTX 2060") == "M"
	TestHooks.check(auto_ok, "settings_dlss_model_auto")
	var env := Environment.new()
	env.ssr_enabled = true
	env.ssao_enabled = true
	Settings.quality = 2
	Settings.rtx_path_tracing = true
	if not Settings.is_rtx_fork():
		Settings.rtx_allow_noisy = true
		Settings.apply()
		Settings.tune_environment(env)
		TestHooks.check(not Settings.can_path_trace() and not Settings.dlss_active() and not Settings.path_tracing_active()
			and env.get("pathtracing_enabled") == null and env.ssr_enabled == not Settings.is_compat(), "settings_rtx_inert_on_mainline",
			Settings.rtx_status())
		return
	print("RTX fork: %s | driver %s" % [Settings.rtx_status(), RenderingServer.get_current_rendering_driver_name()])
	TestHooks.check(Settings.is_compat() or Settings.can_path_trace(), "settings_rtx_fork_can_path_trace", Settings.rtx_status())
	Settings.rtx_allow_noisy = false
	Settings.tune_environment(env)
	var want_pt := Settings.dlss_rr_available()
	TestHooks.check(bool(env.get("pathtracing_enabled")) == want_pt, "settings_rtx_needs_denoiser",
		"pt %s, ray reconstruction %s" % [env.get("pathtracing_enabled"), want_pt])
	Settings.rtx_allow_noisy = true
	env.ssr_enabled = true
	Settings.tune_environment(env)
	if not Settings.is_compat():
		TestHooks.check(bool(env.get("pathtracing_enabled")) and not env.ssr_enabled and int(env.get("pathtracing_max_bounces")) == Settings.rtx_bounces,
			"settings_rtx_path_tracing_on")
