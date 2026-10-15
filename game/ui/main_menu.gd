extends Control
## Main menu: SPEEDFEST logo, a slowly turning 3D showroom of the selected car, and the
## Solo / Online / Garage / Settings / Quit buttons. Asks for the player name on first run.

var showroom: Showroom
var buttons: Array[Button] = []
var name_label: Label
var car_name_label: Label
var car_info_label: Label
var name_dialog: Control
var name_dialog_edit: LineEdit
var _menu_box: VBoxContainer


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MenuKit.wire_focus_sounds(self)
	Audio.play_music("menu")
	Profile.changed.connect(_refresh_profile)
	_refresh_profile()
	var first_run := not FileAccess.file_exists(Profile.SAVE_PATH)
	if (first_run and not TestHooks.is_testing()) or TestHooks.has_arg("name_prompt"):
		_open_name_dialog()
	else:
		buttons[0].grab_focus.call_deferred()
	_animate_in()


func _unhandled_input(event: InputEvent) -> void:
	if name_dialog.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_name_dialog(false)
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		showroom.orbit_drag((event as InputEventMouseMotion).relative)


func _refresh_profile() -> void:
	name_label.text = Profile.player_name
	var cfg := Profile.get_config()
	var cid := String(cfg["car"])
	var d := CarDefs.get_def(cid)
	car_name_label.text = String(d["name"]).to_upper()
	car_info_label.text = "%s  ·  %s" % [String(d["archetype"]), String(d["drive"]).to_upper()]
	showroom.show_car(cid, cfg["style"])


# --- actions --------------------------------------------------------------------------------------

func _on_solo() -> void:
	Game.goto(Game.SCENE_TRACK_SELECT)


func _on_online() -> void:
	Game.online_intent = "live"
	Game.goto(Game.SCENE_LOBBY)


func _on_rooms() -> void:
	Game.online_intent = ""
	Game.goto(Game.SCENE_LOBBY)


func _on_garage() -> void:
	Game.to_garage(Game.SCENE_MENU)


func _on_settings() -> void:
	Game.goto(Game.SCENE_SETTINGS)


func _on_quit() -> void:
	Profile.save()
	Settings.save()
	get_tree().quit()


func _open_name_dialog() -> void:
	name_dialog.visible = true
	name_dialog_edit.text = Profile.player_name
	name_dialog_edit.grab_focus.call_deferred()
	name_dialog_edit.select_all.call_deferred()


func _close_name_dialog(apply: bool) -> void:
	if apply:
		Profile.set_player_name(name_dialog_edit.text)
		Audio.play_ui("confirm")
	else:
		Audio.play_ui("back")
	Profile.save() # also marks the first run as done
	name_dialog.visible = false
	buttons[0].grab_focus()


# --- building -------------------------------------------------------------------------------------

func _build() -> void:
	showroom = Showroom.new()
	showroom.screen_offset = -2.0
	showroom.distance = 8.6
	showroom.pitch = 0.2
	showroom.yaw = 0.9
	showroom.auto_rotate = 0.0   # static hero shot (owner, session 4)
	add_child(showroom)
	showroom.turntable.rotation.y = PI - 0.5

	# Left-side shade so the menu reads well over the 3D scene.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.015, 0.04, 0.92))
	grad.set_color(1, Color(0.01, 0.015, 0.04, 0.0))
	grad.set_offset(1, 1.0)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.anchor_right = 0.62
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 72)
	root.add_theme_constant_override("margin_right", 56)
	root.add_theme_constant_override("margin_top", 48)
	root.add_theme_constant_override("margin_bottom", 36)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(430, 0)
	h.add_child(left)
	left.add_child(_logo())
	left.add_child(MenuKit.spacer(0, 26))

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	left.add_child(_menu_box)
	_add_menu_button("SOLO TIME ATTACK", "Beat your best on any track", _on_solo)
	_add_menu_button("ONLINE · LIVE", "Jump into the non-stop map rotation", _on_online)
	_add_menu_button("PRIVATE ROOM", "Race your friends with your own rules", _on_rooms)
	_add_menu_button("GARAGE", "Style your ride", _on_garage)
	_add_menu_button("SETTINGS", "Graphics, sound, controls", _on_settings)
	if not Settings.is_web():
		_add_menu_button("QUIT", "", _on_quit)
	left.add_child(MenuKit.spacer(0, 0, true))

	var driver := HBoxContainer.new()
	driver.add_theme_constant_override("separation", 12)
	var dl := UITheme.label("DRIVER", "head", 13, UITheme.TEXT_DIM)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	driver.add_child(dl)
	name_label = UITheme.label("", "heavy", 22, UITheme.LIME)
	driver.add_child(name_label)
	var change := MenuKit.button("CHANGE", 0, 36)
	change.add_theme_font_size_override("font_size", 17)
	change.pressed.connect(_open_name_dialog)
	driver.add_child(change)
	left.add_child(driver)

	h.add_child(MenuKit.spacer(0, 0, true))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	car_name_label = UITheme.label("", "heavy", 34, UITheme.TEXT)
	car_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	car_name_label.add_theme_color_override("font_shadow_color", Color(UITheme.MAGENTA, 0.5))
	right.add_child(car_name_label)
	car_info_label = UITheme.label("", "body_bold", 20, UITheme.CYAN)
	car_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(car_info_label)
	right.add_child(MenuKit.spacer(0, 8))
	var hints := MenuKit.key_hints([["ENTER", "Select"], ["DRAG", "Spin car"]])
	hints.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(hints)

	var ver := UITheme.label("v0.1  ·  M1", "body", 15, Color(UITheme.TEXT_DIM, 0.6))
	ver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ver.position = Vector2(-120, 14)
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)

	name_dialog = _build_name_dialog()
	add_child(name_dialog)
	name_dialog.visible = false


func _logo() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var t := UITheme.label("SPEEDFEST", "heavy", 64, UITheme.TEXT)
	t.add_theme_color_override("font_shadow_color", Color(UITheme.MAGENTA, 0.85))
	t.add_theme_constant_override("shadow_offset_x", 4)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.add_theme_color_override("font_outline_color", Color(UITheme.CYAN, 0.9))
	t.add_theme_constant_override("outline_size", 2)
	box.add_child(t)
	var bar := MenuKit.NeonBar.new()
	bar.color = UITheme.MAGENTA
	bar.custom_minimum_size = Vector2(420, 7)
	box.add_child(MenuKit.spacer(0, 10))
	box.add_child(bar)
	var sub := UITheme.label("STREET  ·  STUNT  ·  TIME ATTACK", "head", 15, UITheme.CYAN)
	box.add_child(MenuKit.spacer(0, 12))
	box.add_child(sub)
	return box


func _add_menu_button(text: String, sub: String, cb: Callable) -> void:
	var b := MenuKit.button("", 400, 62)
	b.pressed.connect(cb)
	b.add_theme_stylebox_override("normal", UITheme.panel_style(Color(UITheme.PANEL, 0.7), Color(UITheme.CYAN, 0.35), 1))
	b.add_theme_stylebox_override("hover", UITheme.panel_style(Color(UITheme.MAGENTA, 0.22), UITheme.MAGENTA, 2))
	b.add_theme_stylebox_override("focus", UITheme.panel_style(Color(UITheme.MAGENTA, 0.22), UITheme.MAGENTA, 2))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := UITheme.label(text, "head", 24, UITheme.TEXT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if sub != "":
		var s := UITheme.label(sub, "body", 17, UITheme.TEXT_DIM)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
	b.focus_entered.connect(func() -> void:
		t.add_theme_color_override("font_color", UITheme.CYAN)
		create_tween().tween_property(v, "offset_left", 40.0, 0.12))
	b.focus_exited.connect(func() -> void:
		t.add_theme_color_override("font_color", UITheme.TEXT)
		create_tween().tween_property(v, "offset_left", 28.0, 0.12))
	_menu_box.add_child(b)
	buttons.append(b)


func _build_name_dialog() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := MenuKit.panel(Color(UITheme.NAVY, 0.97), UITheme.MAGENTA)
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(MenuKit.header("WELCOME, DRIVER", "", UITheme.MAGENTA))
	var l := UITheme.label("What should your friends call you?", "body_bold", 22, UITheme.TEXT)
	v.add_child(l)
	name_dialog_edit = LineEdit.new()
	name_dialog_edit.max_length = 16
	name_dialog_edit.custom_minimum_size = Vector2(0, 50)
	name_dialog_edit.add_theme_font_size_override("font_size", 26)
	name_dialog_edit.text_submitted.connect(func(_t: String) -> void: _close_name_dialog(true))
	v.add_child(name_dialog_edit)
	var ok := MenuKit.button("LET'S RIDE", 0, 52)
	ok.pressed.connect(func() -> void: _close_name_dialog(true))
	v.add_child(ok)
	return dim


func _animate_in() -> void:
	var i := 0
	for b in buttons:
		b.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.05 + i * 0.06)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)
		i += 1
