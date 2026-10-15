extends Control
## Garage: 3D preview (drag to orbit, wheel to zoom, auto-rotate), car selection and tabs for
## performance tuning (7 sliders + live stats) and visual style (paint, body, wheels, lights,
## stance & plate). Every change updates the preview and Profile immediately.
## Back -> Game.leave_garage() (saves and returns to where we came from).

const TABS := ["TUNE", "PAINT", "BODY", "WHEELS", "LIGHTS", "PLATE"]
const STAT_KEYS := [["top_speed", "TOP SPEED"], ["accel", "ACCELERATION"], ["handling", "HANDLING"], ["drift", "DRIFT"], ["nitro", "NITRO"]]
const LIVERY_NAMES := {"none": "None", "racing_stripes": "Stripes", "side_stripe": "Side stripe", "two_tone": "Two-tone", "fade": "Fade", "checker": "Checker"}
## Camera presets per tab: [car_yaw, pitch, distance]
const TAB_VIEWS := [
	[PI + 0.65, 0.16, 8.4], [PI + 0.9, 0.22, 8.0], [0.75, 0.2, 8.2],
	[PI / 2 + PI, 0.06, 7.8], [PI + 0.3, 0.12, 8.0], [0.15, 0.12, 7.4],
]

var car_id := "kaze"
var tuning: Dictionary = {}
var style: Dictionary = {}

var showroom: Showroom
var tabs: TabContainer
var car_name_label: Label
var car_arch_label: Label
var car_blurb_label: Label
var car_dots: HBoxContainer
var sliders: Dictionary = {}          # tuning key -> HSlider
var slider_values: Dictionary = {}    # tuning key -> Label
var chip_rows: Dictionary = {}        # style key -> HFlowContainer
var swatch_rows: Dictionary = {}      # style key -> HFlowContainer
var style_sliders: Dictionary = {}    # "tint"/"ride_height" -> HSlider
var style_slider_values: Dictionary = {}
var carbon_check: CheckButton
var plate_edit: LineEdit
var stat_bars: Dictionary = {}
var top_speed_label: Label
var accel_label: Label
var back_btn: Button
var prev_car_btn: Button
var next_car_btn: Button

var _save_timer: Timer
var _dragging := false
var _loading := false


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 1.0
	_save_timer.timeout.connect(Profile.save)
	add_child(_save_timer)
	_build()
	MenuKit.wire_focus_sounds(self)
	Audio.play_music("menu")
	select_car(Profile.selected_car)
	# Online: if the host starts a round while we're tuning, save and go race.
	Net.round_started.connect(_on_round_started)
	var tab := int(TestHooks.arg("tab", 0))
	if tab != 0:
		tabs.current_tab = clampi(tab, 0, TABS.size() - 1)
	var v: Array = TAB_VIEWS[tabs.current_tab]
	showroom.turntable.rotation.y = float(v[0])
	showroom.pitch = float(v[1])
	showroom.distance = float(v[2])
	showroom.yaw = 0.0
	_focus_first_in_tab.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
		return
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit
	if event is InputEventKey and event.pressed and not event.echo and not typing:
		match (event as InputEventKey).physical_keycode:
			KEY_Q, KEY_PAGEUP:
				_cycle_tab(-1)
			KEY_E, KEY_PAGEDOWN:
				_cycle_tab(1)
			KEY_Z:
				_cycle_car(-1)
			KEY_X:
				_cycle_car(1)
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_cycle_tab(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_cycle_tab(1)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			showroom.zoom(-0.08)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			showroom.zoom(0.08)
	elif event is InputEventMouseMotion and _dragging:
		showroom.orbit_drag((event as InputEventMouseMotion).relative)


# --- public API (also used by tests) --------------------------------------------------------------

func select_car(id: String) -> void:
	if not id in CarDefs.IDS:
		id = CarDefs.IDS[0]
	car_id = id
	Profile.set_selected_car(id)
	var cfg := Profile.get_config(id)
	tuning = cfg["tuning"].duplicate()
	style = cfg["style"].duplicate()
	var d := CarDefs.get_def(id)
	car_name_label.text = String(d["name"]).to_upper()
	car_arch_label.text = "%s  ·  %s" % [String(d["archetype"]), "AWD" if String(d["drive"]) == "awd" else "RWD"]
	car_blurb_label.text = String(d["blurb"])
	var i := 0
	for dot in car_dots.get_children():
		(dot as ColorRect).color = UITheme.CYAN if CarDefs.IDS[i] == id else Color(1, 1, 1, 0.2)
		i += 1
	showroom.show_car(id, style)
	_load_controls()
	_update_stats()
	_schedule_save()


func set_tuning_value(key: String, v: float) -> void:
	if _loading or not key in CarDefs.TUNING_KEYS:
		return
	tuning[key] = snappedf(clampf(v, -1.0, 1.0), 0.1)
	Profile.set_tuning(car_id, tuning)
	tuning = Profile.get_config(car_id)["tuning"].duplicate()
	slider_values[key].text = _fmt_signed(float(tuning[key]))
	_update_stats()
	_schedule_save()


func set_style_value(key: String, v: Variant) -> void:
	if _loading:
		return
	style[key] = v
	Profile.set_style(car_id, style)
	style = Profile.get_config(car_id)["style"].duplicate()
	showroom.show_car(car_id, style)
	_reflect_style_key(key)
	_schedule_save()


func reset_tuning() -> void:
	Profile.set_tuning(car_id, CarDefs.default_tuning())
	tuning = Profile.get_config(car_id)["tuning"].duplicate()
	_load_controls()
	_update_stats()
	_schedule_save()


func reset_style() -> void:
	Profile.set_style(car_id, CarDefs.default_style(car_id))
	style = Profile.get_config(car_id)["style"].duplicate()
	showroom.show_car(car_id, style)
	_load_controls()
	_schedule_save()


# --- internals ------------------------------------------------------------------------------------

func _on_back() -> void:
	Audio.play_ui("back")
	_save_timer.stop()
	Game.leave_garage()


func _on_round_started(info: Dictionary) -> void:
	if not Net.in_room():
		return
	_save_timer.stop()
	Profile.save()
	Net.set_profile(Profile.player_name, Profile.get_config())
	Game.start_online_round(info)


func _schedule_save() -> void:
	_save_timer.start()


func _cycle_tab(dir: int) -> void:
	tabs.current_tab = wrapi(tabs.current_tab + dir, 0, TABS.size())
	Audio.play_ui("click")
	_focus_first_in_tab()


func _cycle_car(dir: int) -> void:
	var i := CarDefs.IDS.find(car_id)
	select_car(CarDefs.IDS[wrapi(i + dir, 0, CarDefs.IDS.size())])
	Audio.play_ui("click")


func _on_tab_changed(i: int) -> void:
	var v: Array = TAB_VIEWS[i]
	showroom.focus_view(float(v[0]), float(v[1]), float(v[2]))


func _focus_first_in_tab() -> void:
	var page := tabs.get_current_tab_control()
	if page == null:
		return
	for c in page.find_children("*", "", true, false):
		var ctl := c as Control
		if ctl and ctl.focus_mode == Control.FOCUS_ALL and ctl.is_visible_in_tree():
			ctl.grab_focus()
			(page as ScrollContainer).set_deferred("scroll_vertical", 0)
			return


func _update_stats() -> void:
	var s := Tuning.stats(car_id, tuning)
	var stock := Tuning.stats(car_id, CarDefs.default_tuning())
	for pair in STAT_KEYS:
		var k: String = pair[0]
		var bar: StatBar = stat_bars[k]
		bar.value = float(s.get(k, 0.5))
		bar.stock = float(stock.get(k, -1.0))
	var kmh := float(s.get("top_speed_kmh", 0.0))
	if Settings.units_mph:
		top_speed_label.text = "%d mph" % roundi(kmh * 0.621371)
	else:
		top_speed_label.text = "%d km/h" % roundi(kmh)
	accel_label.text = "%.1f s" % float(s.get("zero_to_100_s", 0.0))


func _load_controls() -> void:
	_loading = true
	for k in CarDefs.TUNING_KEYS:
		(sliders[k] as HSlider).set_value_no_signal(float(tuning.get(k, 0.0)))
		slider_values[k].text = _fmt_signed(float(tuning.get(k, 0.0)))
	for k in style:
		_reflect_style_key(String(k))
	_loading = false


func _reflect_style_key(key: String) -> void:
	var v: Variant = style.get(key)
	if swatch_rows.has(key):
		MenuKit.select_swatch(swatch_rows[key], String(v))
	if chip_rows.has(key):
		var idx := int(v) if typeof(v) != TYPE_STRING else _style_options(key).find(String(v))
		MenuKit.select_chip(chip_rows[key], idx)
	if style_sliders.has(key):
		(style_sliders[key] as HSlider).set_value_no_signal(float(v))
		style_slider_values[key].text = ("%d%%" % roundi(float(v) * 100.0)) if key == "tint" else ("%+.2f" % float(v))
	if key == "hood_carbon" and carbon_check:
		carbon_check.set_pressed_no_signal(bool(v))
	if key == "plate" and plate_edit and plate_edit.text != String(v):
		var caret := plate_edit.caret_column
		plate_edit.text = String(v)
		plate_edit.caret_column = mini(caret, plate_edit.text.length())


func _style_options(key: String) -> Array:
	match key:
		"finish":
			return Array(CarDefs.FINISHES)
		"livery":
			return Array(CarDefs.LIVERIES)
		"underglow_mode":
			return Array(CarDefs.UNDERGLOW_MODES)
	return []


static func _fmt_signed(v: float) -> String:
	if absf(v) < 0.05:
		return "STOCK"
	return "%+.1f" % v


# --- building -------------------------------------------------------------------------------------

func _build() -> void:
	showroom = Showroom.new()
	showroom.screen_offset = -1.9
	showroom.distance = 8.4
	showroom.auto_rotate = 0.15
	showroom.set_accent(UITheme.CYAN)
	add_child(showroom)

	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.015, 0.04, 0.85))
	grad.set_color(1, Color(0.01, 0.015, 0.04, 0.0))
	grad.add_point(0.75, Color(0.01, 0.015, 0.04, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_right = 0.6
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 36)
	root.add_theme_constant_override("margin_right", 36)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 22)
	add_child(root)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 24)
	root.add_child(h)

	# left column: header, car picker, tabs, bottom buttons
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(580, 0)
	left.add_theme_constant_override("separation", 10)
	h.add_child(left)
	left.add_child(MenuKit.header("GARAGE", "", UITheme.CYAN))
	left.add_child(_build_car_picker())
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_focus_mode = Control.FOCUS_ALL
	tabs.add_theme_font_size_override("font_size", 13)
	left.add_child(tabs)
	_add_tab(TABS[0], _build_perf_tab())
	_add_tab(TABS[1], _build_paint_tab())
	_add_tab(TABS[2], _build_body_tab())
	_add_tab(TABS[3], _build_wheels_tab())
	_add_tab(TABS[4], _build_lights_tab())
	_add_tab(TABS[5], _build_plate_tab())
	tabs.tab_changed.connect(_on_tab_changed)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	back_btn = MenuKit.button("DONE", 170, 48)
	back_btn.pressed.connect(_on_back)
	bottom.add_child(back_btn)
	var rs := MenuKit.button("RESET LOOK", 0, 48)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.pressed.connect(reset_style)
	bottom.add_child(rs)
	var rt := MenuKit.button("RESET TUNING", 0, 48)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.pressed.connect(reset_tuning)
	bottom.add_child(rt)
	left.add_child(bottom)

	# right column: hints on top, stats at the bottom
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	var hints := MenuKit.key_hints([["Q/E", "Tab"], ["Z/X", "Car"], ["DRAG", "Orbit"], ["ESC", "Done"]])
	hints.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(hints)
	right.add_child(MenuKit.spacer(0, 0, true))
	var sp := HBoxContainer.new()
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(MenuKit.spacer(0, 0, true))
	sp.add_child(_build_stats_panel())
	right.add_child(sp)


func _add_tab(title: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.add_child(content)
	scroll.add_child(m)
	tabs.add_child(scroll)


func _vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	return v


func _build_car_picker() -> Control:
	var p := MenuKit.panel(Color(UITheme.PANEL, 0.8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	prev_car_btn = MenuKit.button("◀", 48, 64)
	prev_car_btn.pressed.connect(_cycle_car.bind(-1))
	h.add_child(prev_car_btn)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", -2)
	car_name_label = UITheme.label("", "heavy", 28, UITheme.TEXT)
	car_name_label.add_theme_color_override("font_shadow_color", Color(UITheme.MAGENTA, 0.5))
	v.add_child(car_name_label)
	car_arch_label = UITheme.label("", "body_bold", 19, UITheme.CYAN)
	v.add_child(car_arch_label)
	car_blurb_label = UITheme.label("", "body", 17, UITheme.TEXT_DIM)
	car_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(car_blurb_label)
	car_dots = HBoxContainer.new()
	car_dots.add_theme_constant_override("separation", 6)
	for _id in CarDefs.IDS:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(26, 4)
		car_dots.add_child(dot)
	v.add_child(car_dots)
	h.add_child(v)
	next_car_btn = MenuKit.button("▶", 48, 64)
	next_car_btn.pressed.connect(_cycle_car.bind(1))
	h.add_child(next_car_btn)
	return p


func _build_perf_tab() -> Control:
	var v := _vbox()
	v.add_theme_constant_override("separation", 14)
	for k in CarDefs.TUNING_KEYS:
		var labels: Array = CarDefs.TUNING_LABELS[k]
		var row := MenuKit.slider_row(String(labels[0]), String(labels[1]), String(labels[2]), -1.0, 1.0, 0.1)
		var s: HSlider = row["slider"]
		s.value_changed.connect(func(val: float) -> void: set_tuning_value(k, val))
		sliders[k] = s
		slider_values[k] = row["value"]
		v.add_child(row["root"])
	var note := UITheme.label("Every setting is a trade-off. The white tick on each stat bar is stock.", "body", 16, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	return v


func _swatches(v: VBoxContainer, title: String, key: String, colors: Array) -> void:
	v.add_child(MenuKit.caption(title))
	var row := MenuKit.swatch_row(colors, func(html: String) -> void: set_style_value(key, html))
	swatch_rows[key] = row
	v.add_child(row)


func _chips(v: VBoxContainer, title: String, key: String, labels: Array, values: Array = []) -> void:
	v.add_child(MenuKit.caption(title))
	var row := MenuKit.chip_row(labels, func(i: int) -> void:
		set_style_value(key, values[i] if not values.is_empty() else i))
	chip_rows[key] = row
	v.add_child(row)


func _build_paint_tab() -> Control:
	var v := _vbox()
	_swatches(v, "Paint color", "paint", MenuKit.PAINT_SWATCHES)
	_chips(v, "Finish", "finish", CarDefs.FINISHES.map(func(f: String) -> String: return f.capitalize()), Array(CarDefs.FINISHES))
	_chips(v, "Livery", "livery", CarDefs.LIVERIES.map(func(l: String) -> String: return String(LIVERY_NAMES.get(l, l))), Array(CarDefs.LIVERIES))
	_swatches(v, "Accent / livery color", "accent", MenuKit.SWATCHES)
	return v


func _build_body_tab() -> Control:
	var v := _vbox()
	_chips(v, "Hood", "hood", CarDefs.PART_NAMES["hood"])
	carbon_check = CheckButton.new()
	carbon_check.text = "Carbon fiber hood"
	carbon_check.focus_mode = Control.FOCUS_ALL
	MenuKit.style_toggle(carbon_check)
	MenuKit.wire_button(carbon_check)
	carbon_check.toggled.connect(func(on: bool) -> void: set_style_value("hood_carbon", on))
	v.add_child(carbon_check)
	_chips(v, "Front bumper", "front", CarDefs.PART_NAMES["front"])
	_chips(v, "Rear bumper", "rear", CarDefs.PART_NAMES["rear"])
	_chips(v, "Side skirts", "skirts", CarDefs.PART_NAMES["skirts"])
	_chips(v, "Spoiler", "spoiler", CarDefs.PART_NAMES["spoiler"])
	return v


func _build_wheels_tab() -> Control:
	var v := _vbox()
	_chips(v, "Rims", "rims", CarDefs.PART_NAMES["rims"])
	_swatches(v, "Rim color", "rim_color", ["#d8d8d8", "#9aa3ad", "#2b2b2b", "#111111", "#c8a24a", "#ffd400", "#ff2bd6", "#00e5ff", "#a6ff00", "#d0101c", "#2b6bff", "#f4f4f4"])
	_swatches(v, "Brake calipers", "caliper", ["#d01010", "#ff1a1a", "#ffb300", "#ffd400", "#2b6bff", "#00e5ff", "#a6ff00", "#ff2bd6", "#f4f4f4", "#111111"])
	return v


func _build_lights_tab() -> Control:
	var v := _vbox()
	_swatches(v, "Underglow color", "underglow", MenuKit.LIGHT_SWATCHES)
	_chips(v, "Underglow mode", "underglow_mode", CarDefs.UNDERGLOW_MODES.map(func(m: String) -> String: return m.capitalize()), Array(CarDefs.UNDERGLOW_MODES))
	_swatches(v, "Headlights", "headlight", MenuKit.HEADLIGHT_SWATCHES)
	var row := MenuKit.slider_row("Window tint", "Clear", "Limo", 0.0, 1.0, 0.05)
	var s: HSlider = row["slider"]
	s.value_changed.connect(func(val: float) -> void:
		row["value"].text = "%d%%" % roundi(val * 100.0)
		set_style_value("tint", val))
	style_sliders["tint"] = s
	style_slider_values["tint"] = row["value"]
	v.add_child(row["root"])
	return v


func _build_plate_tab() -> Control:
	var v := _vbox()
	var row := MenuKit.slider_row("Ride height", "Slammed", "Raised", -1.0, 1.0, 0.05)
	var s: HSlider = row["slider"]
	s.value_changed.connect(func(val: float) -> void:
		row["value"].text = "%+.2f" % val
		set_style_value("ride_height", val))
	style_sliders["ride_height"] = s
	style_slider_values["ride_height"] = row["value"]
	v.add_child(row["root"])
	v.add_child(MenuKit.spacer(0, 8))
	v.add_child(MenuKit.caption("License plate"))
	plate_edit = LineEdit.new()
	plate_edit.max_length = 16  # sanitize_plate trims to 8 valid characters
	plate_edit.custom_minimum_size = Vector2(260, 60)
	plate_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_edit.add_theme_font_override("font", UITheme.font("heavy"))
	plate_edit.add_theme_font_size_override("font_size", 30)
	var psb := UITheme.panel_style(Color(0.92, 0.94, 0.98), UITheme.NAVY, 3, 0.0)
	plate_edit.add_theme_stylebox_override("normal", psb)
	var psf := UITheme.panel_style(Color(0.92, 0.94, 0.98), UITheme.CYAN, 3, 0.0)
	plate_edit.add_theme_stylebox_override("focus", psf)
	plate_edit.add_theme_color_override("font_color", UITheme.NAVY)
	plate_edit.add_theme_color_override("caret_color", UITheme.MAGENTA)
	plate_edit.text_changed.connect(func(t: String) -> void:
		var clean := CarDefs.sanitize_plate(t)
		if clean != t:
			var caret := plate_edit.caret_column
			plate_edit.text = clean
			plate_edit.caret_column = mini(caret, clean.length())
		set_style_value("plate", clean))
	plate_edit.text_submitted.connect(func(_t: String) -> void: back_btn.grab_focus())
	v.add_child(plate_edit)
	v.add_child(UITheme.label("Up to 8 characters: A-Z, 0-9, space and dash.", "body", 16, UITheme.TEXT_DIM))
	return v


func _build_stats_panel() -> Control:
	var p := MenuKit.panel(Color(UITheme.PANEL, 0.85))
	p.custom_minimum_size = Vector2(400, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	var ts := VBoxContainer.new()
	ts.add_theme_constant_override("separation", -4)
	ts.add_child(UITheme.label("TOP SPEED", "head", 11, UITheme.TEXT_DIM))
	top_speed_label = UITheme.label("", "heavy", 26, UITheme.TEXT)
	ts.add_child(top_speed_label)
	top.add_child(ts)
	var ac := VBoxContainer.new()
	ac.add_theme_constant_override("separation", -4)
	ac.add_child(UITheme.label("0-100 KM/H", "head", 11, UITheme.TEXT_DIM))
	accel_label = UITheme.label("", "heavy", 26, UITheme.TEXT)
	ac.add_child(accel_label)
	top.add_child(ac)
	v.add_child(top)
	for pair in STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UITheme.label(String(pair[1]), "head", 12, UITheme.TEXT)
		l.custom_minimum_size = Vector2(124, 0)
		row.add_child(l)
		var bar := StatBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		stat_bars[pair[0]] = bar
		v.add_child(row)
	return p
