extends CanvasLayer
## Pause menu: Resume, Restart run, Settings (volumes + camera inline), Quit.
## Solo pauses the tree; online it doesn't (the round keeps running, a hint says so).
## Signals per docs/ARCHITECTURE.md: resumed, restart_requested, quit_requested.

signal resumed
signal restart_requested
signal quit_requested

const CAMERA_NAMES := ["Chase near", "Chase far", "Bumper", "Hood"]

var _root: Control
var _dim: ColorRect
var _panel: Control
var _settings_panel: PanelContainer
var _btn_resume: Button
var _btn_restart: Button
var _btn_settings: Button
var _btn_quit: Button
var _hint: Label
var _title: Label
var _sub: Label
var _sliders: Dictionary = {}     # key -> HSlider
var _value_labels: Dictionary = {}
var _camera: OptionButton
var _paused_tree := false
var _opened_frame := -1
var _tween: Tween
var _settings_dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_opened_frame = Engine.get_process_frames()
	var online := _is_online()
	_btn_quit.text = "QUIT TO LOBBY" if online else "QUIT TO MENU"
	_hint.visible = online
	_sub.text = _subtitle()
	_settings_panel.visible = false
	_sync_settings()
	visible = true
	if not online:
		_paused_tree = true
		get_tree().paused = true
	# Entrance: fade the dim, slide the panel in from the left.
	if _tween:
		_tween.kill()
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.position.x = -60.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_panel, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_btn_resume.grab_focus()
	_play_ui("confirm")


func close() -> void:
	if not visible:
		return
	visible = false
	if _tween:
		_tween.kill()
	if _settings_dirty:
		_settings_dirty = false
		Settings.save()
	if _paused_tree:
		_paused_tree = false
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _settings_panel.visible:
			_toggle_settings()
		else:
			_on_resume()


func _is_online() -> bool:
	return Game.mode == "online"


func _subtitle() -> String:
	var mode := "ONLINE TIME ATTACK" if _is_online() else "SOLO TIME ATTACK"
	return "%s  ·  %s" % [mode, String(Game.track_id).to_upper()]


func _on_resume() -> void:
	_play_ui("back")
	close()
	resumed.emit()


func _on_restart() -> void:
	_play_ui("confirm")
	close()
	restart_requested.emit()


func _on_quit() -> void:
	_play_ui("confirm")
	close()
	if quit_requested.get_connections().is_empty():
		# Nobody handles it (e.g. a test scene): leave on our own.
		if _is_online():
			Game.to_lobby()
		else:
			Game.to_menu()
	quit_requested.emit()


func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible
	_play_ui("click")
	if _settings_panel.visible:
		_sync_settings()
		(_sliders["master"] as HSlider).grab_focus()
	else:
		_btn_settings.grab_focus()


func _play_ui(n: String) -> void:
	if Audio.has_method("play_ui"):
		Audio.play_ui(n)


# --- settings ---------------------------------------------------------------

func _sync_settings() -> void:
	_set_slider("master", Settings.master_volume)
	_set_slider("music", Settings.music_volume)
	_set_slider("sfx", Settings.sfx_volume)
	_camera.select(clampi(Settings.camera_mode, 0, CAMERA_NAMES.size() - 1))


func _set_slider(key: String, v: float) -> void:
	var s: HSlider = _sliders[key]
	s.set_value_no_signal(v * 100.0)
	(_value_labels[key] as Label).text = "%d" % roundi(v * 100.0)


func _on_slider(value: float, key: String) -> void:
	var v := value / 100.0
	match key:
		"master": Settings.master_volume = v
		"music": Settings.music_volume = v
		"sfx": Settings.sfx_volume = v
	(_value_labels[key] as Label).text = "%d" % roundi(value)
	_settings_dirty = true
	Settings.apply()


func _on_camera(idx: int) -> void:
	Settings.camera_mode = idx
	_settings_dirty = true
	Settings.apply()
	_play_ui("click")


# --- build ------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.015, 0.05, 0.72)
	_root.add_child(_dim)
	# Diagonal neon slashes for the NFSU2 feel.
	var deco := _PauseDeco.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(deco)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 60)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size = Vector2(380, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(left)

	_title = UITheme.label("PAUSED", "heavy", 64, UITheme.TEXT)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(UITheme.MAGENTA, 0.55))
	left.add_child(_title)
	var bar := ColorRect.new()
	bar.color = UITheme.MAGENTA
	bar.custom_minimum_size = Vector2(170, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(bar)
	_sub = UITheme.label("", "head", 14, UITheme.CYAN)
	left.add_child(_sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	left.add_child(spacer)

	_btn_resume = _make_button("RESUME", _on_resume)
	left.add_child(_btn_resume)
	_btn_restart = _make_button("RESTART RUN", _on_restart)
	left.add_child(_btn_restart)
	_btn_settings = _make_button("SETTINGS", _toggle_settings)
	left.add_child(_btn_settings)
	_btn_quit = _make_button("QUIT TO MENU", _on_quit)
	left.add_child(_btn_quit)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	left.add_child(spacer2)
	_hint = UITheme.label("ONLINE: THE ROUND KEEPS RUNNING WHILE THIS MENU IS OPEN", "body_bold", 18, UITheme.AMBER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(380, 0)
	left.add_child(_hint)
	var keys := UITheme.label("ESC  RESUME", "head", 11, UITheme.TEXT_DIM)
	left.add_child(keys)

	_settings_panel = PanelContainer.new()
	var ps := UITheme.panel_style(UITheme.PANEL, UITheme.CYAN.darkened(0.2), 2, 0.0)
	ps.content_margin_left = 28
	ps.content_margin_right = 28
	ps.content_margin_top = 20
	ps.content_margin_bottom = 24
	ps.border_width_left = 4
	ps.border_color = UITheme.CYAN
	_settings_panel.add_theme_stylebox_override("panel", ps)
	_settings_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_settings_panel.custom_minimum_size = Vector2(440, 0)
	cols.add_child(_settings_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(sv)
	sv.add_child(UITheme.label("SETTINGS", "head", 22, UITheme.CYAN))
	for item in [["master", "MASTER VOLUME"], ["music", "MUSIC"], ["sfx", "EFFECTS"]]:
		sv.add_child(_make_slider_row(item[0], item[1]))
	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 12)
	var cam_l := UITheme.label("CAMERA", "body_bold", 20, UITheme.TEXT_DIM)
	cam_l.custom_minimum_size = Vector2(150, 0)
	cam_row.add_child(cam_l)
	_camera = OptionButton.new()
	for n in CAMERA_NAMES:
		_camera.add_item(n)
	_camera.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera.item_selected.connect(_on_camera)
	cam_row.add_child(_camera)
	sv.add_child(cam_row)
	sv.add_child(UITheme.label("Changes apply immediately.", "body", 16, UITheme.TEXT_DIM))
	_settings_panel.visible = false


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", UITheme.font("head"))
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void: _play_ui("hover"))
	b.focus_entered.connect(func() -> void: _play_ui("hover"))
	return b


func _make_slider_row(key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UITheme.label(text, "body_bold", 20, UITheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(160, 24)
	s.value_changed.connect(_on_slider.bind(key))
	row.add_child(s)
	var v := UITheme.label("0", "num", 16, UITheme.TEXT)
	v.custom_minimum_size = Vector2(44, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	_sliders[key] = s
	_value_labels[key] = v
	return row


class _PauseDeco extends Control:
	func _draw() -> void:
		var h := size.y
		var w := size.x
		# Left vertical slab and a few speed slashes.
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(70, 0), Vector2(40, h), Vector2(0, h)]),
			Color(UITheme.CYAN, 0.08))
		draw_line(Vector2(70, 0), Vector2(40, h), Color(UITheme.CYAN, 0.55), 2.0, true)
		for i in 4:
			var x := w * 0.62 + i * 46.0
			draw_line(Vector2(x + 160, 0), Vector2(x - 40, h), Color(UITheme.MAGENTA, 0.06 + 0.03 * i), 14.0 - i * 3.0, true)
		draw_line(Vector2(0, h - 3), Vector2(w * 0.35, h - 3), Color(UITheme.MAGENTA, 0.8), 3.0)
