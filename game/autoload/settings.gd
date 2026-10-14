extends Node
## Global user settings: graphics quality, audio, units, server URL and the input map.
## Persisted in user://settings.cfg (IndexedDB on web).

signal changed

const SAVE_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var quality: int = 2
var render_scale: float = 1.0
var vsync: bool = true
var fullscreen: bool = false
var show_fps: bool = false
var show_pb_ghost: bool = true
var units_mph: bool = false
var camera_mode: int = 0
var master_volume: float = 0.8
var music_volume: float = 0.55
var sfx_volume: float = 0.9
var server_url: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_setup_input_map()
	if is_web():
		quality = 1
	load_settings()
	if TestHooks.has_arg("quality"):
		quality = clampi(int(TestHooks.arg("quality", 2)), 0, 3)
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
func tune_environment(env: Environment) -> void:
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
	env.ssr_enabled = env.ssr_enabled and quality >= 2
	if env.ssr_enabled:
		env.ssr_max_steps = 48 if quality == 2 else 96
	env.ssao_enabled = env.ssao_enabled and quality >= 2
	env.ssil_enabled = env.ssil_enabled and quality >= 3
	env.sdfgi_enabled = env.sdfgi_enabled and quality >= 3
	env.volumetric_fog_enabled = env.volumetric_fog_enabled and quality >= 3
	env.glow_enabled = env.glow_enabled and quality >= 1


## Configure a key light's shadow according to quality.
func tune_sun(light: DirectionalLight3D) -> void:
	if light == null:
		return
	light.shadow_enabled = quality >= 1
	light.directional_shadow_max_distance = [80.0, 140.0, 220.0, 320.0][quality]
	if is_compat():
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	else:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


# --- persistence --------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	quality = clampi(cfg.get_value("video", "quality", quality), 0, 3)
	render_scale = clampf(cfg.get_value("video", "render_scale", render_scale), 0.5, 1.0)
	vsync = cfg.get_value("video", "vsync", vsync)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
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
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "fullscreen", fullscreen)
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
		vp.scaling_3d_scale = render_scale
		if is_compat():
			vp.msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		else:
			vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	if not is_web():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		if not TestHooks.is_testing():
			var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.window_get_mode() != want:
				DisplayServer.window_set_mode(want)
	_set_bus_volume("Master", master_volume)
	_set_bus_volume(BUS_MUSIC, music_volume)
	_set_bus_volume(BUS_SFX, sfx_volume)
	changed.emit()


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
