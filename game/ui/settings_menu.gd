extends Control
## Settings: graphics, game, audio, online, plus a controls reference. Changes apply live
## (Settings.apply()) and are saved when leaving (Esc / Back).

const CAMERA_NAMES := ["Chase near", "Chase far", "Bumper", "Hood"]
const CONTROLS := [
	["Accelerate", "W / ↑"], ["Brake / reverse", "S / ↓"], ["Steer", "A D / ← →"],
	["Handbrake (drift)", "Space"], ["Nitro", "Shift / N"], ["Respawn at checkpoint", "Backspace / R"],
	["Restart run", "Delete / Enter"], ["Camera", "C"], ["Look back", "Q"],
	["Leaderboard", "Tab (hold)"], ["Pause", "Esc / P"],
]

## Where Back goes (main menu by default).
static var return_scene := ""

var quality_row: HFlowContainer
var units_row: HFlowContainer
var camera_row: HFlowContainer
var scale_slider: HSlider
var chip_rows: Dictionary = {}       # Settings key -> chip row (display / v-sync / fps / AA)
var vol_sliders: Dictionary = {}
var checks: Dictionary = {}
var url_edit: LineEdit
var back_btn: Button
var _sfx_blip_ms := 0


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_load()
	MenuKit.wire_focus_sounds(self)
	Audio.play_music("menu")
	(quality_row.get_child(Settings.quality) as Control).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_back() -> void:
	Audio.play_ui("back")
	_commit_url()
	Settings.save()
	var target := return_scene if return_scene != "" else Game.SCENE_MENU
	return_scene = ""
	Game.goto(target)


func _load() -> void:
	MenuKit.select_chip(quality_row, Settings.quality)
	MenuKit.select_chip(units_row, 1 if Settings.units_mph else 0)
	MenuKit.select_chip(camera_row, clampi(Settings.camera_mode, 0, CAMERA_NAMES.size() - 1))
	scale_slider.set_value_no_signal(Settings.render_scale)
	_scale_label_update(Settings.render_scale)
	for k in vol_sliders:
		(vol_sliders[k]["slider"] as HSlider).set_value_no_signal(float(Settings.get(k)))
		vol_sliders[k]["value"].text = "%d%%" % roundi(float(Settings.get(k)) * 100.0)
	for k in checks:
		(checks[k] as CheckButton).set_pressed_no_signal(bool(Settings.get(k)))
	for k in chip_rows:
		MenuKit.select_chip(chip_rows[k], int(Settings.get(k)))
	url_edit.text = Settings.server_url


func _apply_setting(key: String, value: Variant) -> void:
	Settings.set(key, value)
	Settings.apply()


func _commit_url() -> void:
	var u := url_edit.text.strip_edges()
	if u != Settings.server_url:
		Settings.server_url = u


var _scale_value: Label


func _scale_label_update(v: float) -> void:
	if _scale_value:
		_scale_value.text = "%d%%" % roundi(v * 100.0)


# --- building -------------------------------------------------------------------------------------

func _build() -> void:
	add_child(MenuKit.backdrop(UITheme.CYAN))
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 40)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 26)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)
	col.add_child(MenuKit.header("SETTINGS", "Changes apply immediately.", UITheme.CYAN))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(h)

	# column 1: graphics + game
	var c1 := _column(h)
	c1.add_child(MenuKit.caption("Graphics quality", UITheme.MAGENTA))
	quality_row = MenuKit.chip_row(Settings.QUALITY_NAMES, func(i: int) -> void: _apply_setting("quality", i))
	c1.add_child(quality_row)
	var q_hint := UITheme.label("Web builds start on Medium. Lower it if the game stutters.", "body", 16, UITheme.TEXT_DIM)
	q_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c1.add_child(q_hint)
	var sr := MenuKit.slider_row("Render scale", "Faster", "Sharper", 0.5, 1.0, 0.05)
	scale_slider = sr["slider"]
	_scale_value = sr["value"]
	scale_slider.value_changed.connect(func(v: float) -> void:
		_scale_label_update(v)
		_apply_setting("render_scale", v))
	c1.add_child(sr["root"])
	if not Settings.is_compat():
		_chips(c1, "aa_mode", "Anti-aliasing", Settings.AA_NAMES)
	_check(c1, "show_fps", "Show FPS counter")

	# column 2: game + audio
	var c2 := _column(h)
	c2.add_child(MenuKit.caption("Game", UITheme.MAGENTA))
	_check(c2, "show_pb_ghost", "Show my PB ghost")
	c2.add_child(UITheme.label("Speed units", "body_bold", 20, UITheme.TEXT))
	units_row = MenuKit.chip_row(["km/h", "mph"], func(i: int) -> void: _apply_setting("units_mph", i == 1), 80)
	c2.add_child(units_row)
	c2.add_child(UITheme.label("Camera", "body_bold", 20, UITheme.TEXT))
	camera_row = MenuKit.chip_row(CAMERA_NAMES, func(i: int) -> void: _apply_setting("camera_mode", i))
	c2.add_child(camera_row)
	if not Settings.is_web():
		c2.add_child(MenuKit.spacer(0, 10))
		c2.add_child(MenuKit.caption("Display", UITheme.MAGENTA))
		_chips(c2, "window_mode", "Mode (F11)", Settings.WINDOW_NAMES)
		_chips(c2, "vsync_mode", "V-Sync", Settings.VSYNC_NAMES)
		_chips(c2, "fps_cap", "FPS limit", Settings.FPS_CAP_NAMES)
		var f_hint := UITheme.label("G-Sync / FreeSync: V-Sync On with FPS limit VRR. Lowest input lag: V-Sync Off or Mailbox.", "body", 16, UITheme.TEXT_DIM)
		f_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c2.add_child(f_hint)

	# column 3: audio + online
	c2 = _column(h)
	c2.add_child(MenuKit.caption("Audio", UITheme.MAGENTA))
	for pair in [["master_volume", "Master"], ["music_volume", "Music"], ["sfx_volume", "Effects"]]:
		var key: String = pair[0]
		var row := MenuKit.slider_row(String(pair[1]), "", "", 0.0, 1.0, 0.05)
		var s: HSlider = row["slider"]
		var lbl: Label = row["value"]
		s.value_changed.connect(func(v: float) -> void:
			lbl.text = "%d%%" % roundi(v * 100.0)
			_apply_setting(key, v)
			var now := Time.get_ticks_msec()
			if key != "music_volume" and now - _sfx_blip_ms > 150:
				_sfx_blip_ms = now
				Audio.play_ui("hover"))
		vol_sliders[key] = row
		c2.add_child(row["root"])
	c2.add_child(MenuKit.spacer(0, 10))
	c2.add_child(MenuKit.caption("Online server", UITheme.MAGENTA))
	url_edit = LineEdit.new()
	url_edit.placeholder_text = "Automatic"
	url_edit.tooltip_text = "Automatic: %s" % _auto_url()
	url_edit.custom_minimum_size = Vector2(0, 44)
	url_edit.text_submitted.connect(func(_t: String) -> void:
		_commit_url()
		back_btn.grab_focus())
	c2.add_child(url_edit)
	var ur := VBoxContainer.new()
	var uh := UITheme.label("Leave empty to use the server this page came from.", "body", 16, UITheme.TEXT_DIM)
	uh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ur.add_child(uh)
	var auto_btn := MenuKit.button("USE AUTOMATIC", 0, 38)
	auto_btn.pressed.connect(func() -> void: url_edit.text = "")
	ur.add_child(auto_btn)
	c2.add_child(ur)

	# column 4: controls reference
	var c3 := _column(h)
	c3.add_child(MenuKit.caption("Controls (keyboard)", UITheme.MAGENTA))
	for pair in CONTROLS:
		var r := HBoxContainer.new()
		var a := UITheme.label(String(pair[0]), "body", 17, UITheme.TEXT_DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(a)
		r.add_child(UITheme.label(String(pair[1]), "body_bold", 17, UITheme.TEXT))
		c3.add_child(r)
	var gp := UITheme.label("Gamepad: RT/LT drive, A nitro, B handbrake, Y respawn.", "body", 16, UITheme.TEXT_DIM)
	gp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c3.add_child(gp)

	var bottom := HBoxContainer.new()
	back_btn = MenuKit.button("BACK", 180, 48)
	back_btn.pressed.connect(_on_back)
	bottom.add_child(back_btn)
	bottom.add_child(MenuKit.spacer(0, 0, true))
	var hints := MenuKit.key_hints([["ENTER", "Select"], ["ESC", "Save & back"]])
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hints)
	col.add_child(bottom)


func _column(parent: Container) -> VBoxContainer:
	var p := MenuKit.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	return v


func _chips(parent: Container, key: String, title: String, names: Array) -> void:
	parent.add_child(UITheme.label(title, "body_bold", 20, UITheme.TEXT))
	var row := MenuKit.chip_row(names, func(i: int) -> void: _apply_setting(key, i))
	chip_rows[key] = row
	parent.add_child(row)


func _check(parent: Container, key: String, text: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.focus_mode = Control.FOCUS_ALL
	c.add_theme_font_size_override("font_size", 20)
	MenuKit.style_toggle(c)
	MenuKit.wire_button(c)
	c.toggled.connect(func(on: bool) -> void: _apply_setting(key, on))
	checks[key] = c
	parent.add_child(c)


func _auto_url() -> String:
	var saved := Settings.server_url
	Settings.server_url = ""
	var d := Settings.resolve_server_url()
	Settings.server_url = saved
	return d
