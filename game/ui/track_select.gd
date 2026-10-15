extends Control
## Solo track select: one card per track (art, name, theme, blurb, target time, your PB). Five cards
## fit a 1280-wide screen; short maps (target under 15 s) are tagged SPRINT, the rest STUNT RUN.
## Enter/click starts Game.start_solo(id). Esc goes back to the main menu.

const THEME_NAMES := {"city": "NIGHT CITY", "arena": "STADIUM", "coast": "COAST"}
const SPRINT_MAX_S := 15
const THEME_COLORS := {"city": Color("#ff2bd6"), "arena": Color("#00e5ff"), "coast": Color("#ffb300")}

var cards: Array[Button] = []
var car_label: Label
var _starting := false
## "" = each stage's signature weather (Weather.default_for), else "dry"/"rain"/"storm".
var weather_pick := ""
var weather_row: HFlowContainer
var _pb_labels := {}            # track id -> Label


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	MenuKit.wire_focus_sounds(self)
	Audio.play_music("menu")
	var idx := maxi(0, TrackDefs.IDS.find(Game.track_id))
	cards[idx].grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_ui("back")
		Game.to_menu()


func start(track_id: String) -> void:
	if _starting:
		return
	_starting = true
	Audio.play_ui("confirm")
	Game.start_solo(track_id, weather_pick)


func _build() -> void:
	add_child(MenuKit.backdrop(UITheme.MAGENTA))
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 56)
	root.add_theme_constant_override("margin_right", 56)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 26)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	root.add_child(col)
	var top := HBoxContainer.new()
	top.add_child(MenuKit.header("SOLO TIME ATTACK", "Pick a track. No time limit, just you and your ghost.", UITheme.MAGENTA))
	top.add_child(MenuKit.spacer(0, 0, true))
	var carbox := VBoxContainer.new()
	carbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var cl := UITheme.label("YOUR CAR", "head", 13, UITheme.TEXT_DIM)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	carbox.add_child(cl)
	car_label = UITheme.label(CarDefs.display_name(Profile.selected_car).to_upper(), "heavy", 24, UITheme.CYAN)
	car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	carbox.add_child(car_label)
	top.add_child(carbox)
	col.add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	for id in TrackDefs.IDS:
		var c := _card(id)
		row.add_child(c)
		cards.append(c)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	var back := MenuKit.button("BACK", 160, 46)
	back.pressed.connect(func() -> void:
		Audio.play_ui("back")
		Game.to_menu())
	bottom.add_child(back)
	var garage := MenuKit.button("GARAGE", 160, 46)
	garage.pressed.connect(func() -> void: Game.to_garage(Game.SCENE_TRACK_SELECT))
	bottom.add_child(garage)
	bottom.add_child(MenuKit.spacer(0, 0, true))
	var wl := UITheme.label("WEATHER", "head", 13, UITheme.TEXT_DIM)
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(wl)
	weather_row = MenuKit.chip_row(["AUTO", "DRY", "RAIN", "STORM"], _on_pick_weather, 76)
	weather_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weather_row.custom_minimum_size.x = 4 * 96
	bottom.add_child(weather_row)
	MenuKit.select_chip(weather_row, 0)
	bottom.add_child(MenuKit.spacer(24, 0))
	var hints := MenuKit.key_hints([["← →", "Track"], ["ENTER", "Race"], ["ESC", "Back"]])
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hints)
	col.add_child(bottom)
	# focus wiring: cards <-> bottom buttons
	for c in cards:
		c.focus_neighbor_bottom = c.get_path_to(back)
	back.focus_neighbor_top = back.get_path_to(cards[0])
	garage.focus_neighbor_top = garage.get_path_to(cards[1])


func _card(id: String) -> Button:
	var d := TrackDefs.get_def(id)
	var th := String(d["theme"])
	var accent: Color = THEME_COLORS.get(th, UITheme.CYAN)
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(200, 420)
	var normal := UITheme.panel_style(Color(UITheme.PANEL, 0.92), Color(accent, 0.35), 2, 0.0)
	var hot := UITheme.panel_style(Color(UITheme.PANEL_LIGHT, 0.96), accent, 3, 0.0)
	hot.shadow_color = Color(accent, 0.35)
	hot.shadow_size = 18
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", hot)
	MenuKit.wire_button(b)
	b.pressed.connect(start.bind(id))
	b.pivot_offset = Vector2(100, 210)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.focus_entered.connect(func() -> void:
		Game.track_id = id
		create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.12))
	b.focus_exited.connect(func() -> void: create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 3
	v.offset_right = -3
	v.offset_top = 3
	v.offset_bottom = -3
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var art := TrackArt.new()
	art.theme_id = th
	art.sprint = int(d["target_s"]) < SPRINT_MAX_S
	art.custom_minimum_size = Vector2(0, 210)     # fixed, so every card's art lines up
	v.add_child(art)
	var info := MarginContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		info.add_theme_constant_override("margin_" + side, 16)
	info.add_theme_constant_override("margin_top", 10)
	info.add_theme_constant_override("margin_bottom", 16)
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(iv)
	var kind := "SPRINT" if int(d["target_s"]) < SPRINT_MAX_S else "STUNT RUN"
	var tag := UITheme.label("%s  ·  %s" % [kind, THEME_NAMES.get(th, th.to_upper())], "head", 12, accent)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(tag)
	var nm := UITheme.label(String(d["name"]).to_upper(), "heavy", 24, UITheme.TEXT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(nm)
	var bl := UITheme.label(String(d["blurb"]), "body", 16, UITheme.TEXT_DIM)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(bl)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 14)
	stats.add_child(_stat("TARGET", "~%d s" % int(d["target_s"]), UITheme.TEXT))
	var wx := _weather_for(id)
	var pb := Profile.get_pb(Weather.pb_key(id, wx))
	var pbs := _stat("PB · %s" % Weather.display_name(wx).to_upper(), UITheme.format_time(pb), UITheme.LIME if pb >= 0 else UITheme.TEXT_DIM)
	stats.add_child(pbs)
	_pb_labels[id] = pbs
	iv.add_child(stats)
	for c in [art, info, iv, tag, nm, bl, stats]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _weather_for(id: String) -> String:
	return weather_pick if weather_pick != "" else Weather.default_for(id)


func _on_pick_weather(i: int) -> void:
	weather_pick = "" if i == 0 else Weather.MODES[i - 1]
	Audio.play_ui("click")
	for id in _pb_labels:
		var box: VBoxContainer = _pb_labels[id]
		var wx := _weather_for(id)
		var pb := Profile.get_pb(Weather.pb_key(id, wx))
		(box.get_child(0) as Label).text = "PB · %s" % Weather.display_name(wx).to_upper()
		var val := box.get_child(1) as Label
		val.text = UITheme.format_time(pb)
		val.add_theme_color_override("font_color", UITheme.LIME if pb >= 0 else UITheme.TEXT_DIM)


func _stat(key: String, value: String, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := UITheme.label(key, "head", 11, UITheme.TEXT_DIM)
	v.add_child(k)
	var val := UITheme.label(value, "num", 20, color)
	v.add_child(val)
	for c in v.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v
