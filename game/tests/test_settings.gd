extends Node
## The renderer settings: the night look is authored at Ultra and `tune_environment` has to strip
## it back correctly at every quality level, the light budget has to grow with quality, and the RTX
## path has to stay switched off on a stock Godot build.


func _ready() -> void:
	_night_look()
	_quality_gates()
	_lights()
	_rtx()
	_persistence()
	TestHooks.finish()


func _night_look() -> void:
	var env := Settings.night_environment()
	TestHooks.check(env.background_mode == Environment.BG_SKY, "the city has a sky")
	TestHooks.check(env.tonemap_mode == Environment.TONE_MAPPER_AGX, "AgX tonemapping")
	TestHooks.check(env.glow_enabled and env.glow_hdr_threshold >= 1.0,
		"glow only bites on real emitters", str(env.glow_hdr_threshold))
	TestHooks.check(env.fog_enabled and env.volumetric_fog_enabled, "there is haze for the neon")
	TestHooks.check(env.ssr_enabled and env.ssil_enabled and env.sdfgi_enabled,
		"authored at Ultra: SSR, SSIL and SDFGI all on")
	TestHooks.check(env.ambient_light_energy < 1.0, "ambient stays low enough to read as night",
		str(env.ambient_light_energy))
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	TestHooks.check(sky != null and sky.sky_top_color.get_luminance() < 0.1, "the sky is dark",
		str(sky.sky_top_color if sky else "no sky"))


func _quality_gates() -> void:
	var was := Settings.quality
	for q in 4:
		Settings.quality = q
		var env := Settings.night_environment()
		Settings.tune_environment(env)
		TestHooks.check(env.ssr_enabled == (q >= 1), "SSR gated at Medium (q=%d)" % q)
		TestHooks.check(env.ssao_enabled == (q >= 1), "SSAO gated at Medium (q=%d)" % q)
		TestHooks.check(env.ssil_enabled == (q >= 3), "SSIL only on Ultra (q=%d)" % q)
		TestHooks.check(env.sdfgi_enabled == (q >= 3), "SDFGI only on Ultra (q=%d)" % q)
		TestHooks.check(env.volumetric_fog_enabled == (q >= 2), "volumetric fog from High (q=%d)" % q)
		TestHooks.check(env.glow_enabled == (q >= 1), "glow from Medium (q=%d)" % q)
		if q >= 1:
			TestHooks.check(env.ssr_max_steps > 0, "SSR has steps at q=%d" % q, str(env.ssr_max_steps))
	Settings.quality = was


func _lights() -> void:
	var prev := 0
	var was := Settings.quality
	for q in 4:
		Settings.quality = q
		var b := Settings.light_budget()
		TestHooks.check(b > prev, "the light budget grows with quality (q=%d)" % q, str(b))
		prev = b
		var sun := DirectionalLight3D.new()
		Settings.tune_sun(sun)
		TestHooks.check(sun.shadow_enabled == (q >= 1), "the moon casts shadows from Medium (q=%d)" % q)
		TestHooks.check(sun.directional_shadow_max_distance > 50.0, "shadow distance set (q=%d)" % q)
		sun.free()
		var omni := OmniLight3D.new()
		Settings.tune_point_light(omni, true)
		TestHooks.check(omni.shadow_enabled == (q >= 2), "neon shadows from High (q=%d)" % q)
		TestHooks.check(omni.distance_fade_enabled, "point lights fade with distance (q=%d)" % q)
		omni.free()
	Settings.quality = was
	TestHooks.check(Settings.local_shadows() == (Settings.quality >= 2), "local shadows follow quality")


func _rtx() -> void:
	# Stock Godot: everything RTX stays off and nothing crashes when it is asked for.
	var fork := Settings.is_rtx_fork()
	TestHooks.check(not fork, "this is a stock Godot build (no path tracing)")
	TestHooks.check(not Settings.can_path_trace(), "path tracing unavailable off the fork")
	TestHooks.check(not Settings.dlss_available(), "no DLSS off the fork")
	Settings.rtx_path_tracing = true
	TestHooks.check(not Settings.path_tracing_active(), "asking for RTX does not turn it on here")
	var env := Settings.night_environment()
	Settings.tune_environment(env)
	TestHooks.check(env.ssr_enabled == (Settings.quality >= 1),
		"the screen-space path is untouched without the fork")
	Settings.rtx_path_tracing = false
	var status := Settings.render_status()
	TestHooks.check(status.begins_with("Forward+"), "the status line names the renderer", status)


func _persistence() -> void:
	TestHooks.check(Settings.quality_name() in Settings.QUALITY_NAMES, "quality has a name",
		Settings.quality_name())
	for action in Settings.ACTIONS:
		TestHooks.check(InputMap.has_action(action), "input action %s exists" % action)
