class_name SfHeader
extends Control
## The menus' header (PLAN M16; tabs across the top as in RaceRoom's menus, which the owner pointed
## to, in our own look): our wordmark at the left, a back arrow, the tabs (Home, Solo, Multiplayer,
## Garage, Story, Community, Editor) with a red-to-violet line under the current one, and at the
## right you (your nickname and zone: the profile), options and quit. Story is locked (the owner:
## "building a story mode is one of the next steps"): its tab shows a padlock and only says so.

signal page_pressed(page: String)    ## a tab's page (TmMenu.show_page), "profile" or "options"
signal back_pressed
signal quit_pressed
signal locked_pressed(page: String)

const HEIGHT := 76.0
const TABS := [["main", "Home"], ["solo", "Solo"], ["online", "Multiplayer"], ["garage", "Garage"], ["story", "Story"],
	["community", "Community"], ["editors", "Editor"]]
const LOCKED := ["story"]
const UNDER := {"replays": "solo", "campaign": "solo", "tuning": "garage"}     ## pages that light their parent's tab

var tabs := {}                       ## page -> its tab (also "profile": you, "options": the gear)
var current := ""
var _underline: TextureRect
var _back: Glyph
var _nick: RichTextLabel
var _zone: Label


func _ready() -> void:
	theme = SfUi.theme()
	anchor_right = 1.0
	offset_bottom = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", SfUi.box("header"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 36
	line.offset_right = -24
	line.add_theme_constant_override("separation", 0)
	add_child(line)
	line.add_child(Wordmark.new())
	_pad(line, 30)
	_back = Glyph.new("back", "Back (Esc)")
	_back.pressed.connect(func() -> void: back_pressed.emit())
	line.add_child(_back)
	_pad(line, 12)
	for t: Array in TABS:
		line.add_child(_tab(String(t[0]), String(t[1])))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(fill)
	line.add_child(_you())
	_pad(line, 8)
	var gear := Glyph.new("gear", "Options")
	gear.pressed.connect(func() -> void: page_pressed.emit("options"))
	tabs["options"] = gear
	line.add_child(gear)
	var power := Glyph.new("power", "Quit")
	power.pressed.connect(func() -> void: quit_pressed.emit())
	line.add_child(power)
	_underline = SfUi.accent_line(3.0)
	_underline.position.y = HEIGHT - 3.0
	_underline.size = Vector2(0, 3)
	add_child(_underline)
	resized.connect(func() -> void: _place_underline(false))


func _pad(box: HBoxContainer, w: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.x = w
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)


func _tab(page: String, text: String) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_vertical = Control.SIZE_FILL
	var locked := LOCKED.has(page)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 18
	pad.content_margin_right = 36 if locked else 18
	var hover := SfUi.box("row_hover").duplicate() as StyleBoxFlat
	hover.content_margin_left = pad.content_margin_left
	hover.content_margin_right = pad.content_margin_right
	hover.set_corner_radius_all(0)
	for s in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, pad)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	var focus := SfUi.box("focus").duplicate() as StyleBoxFlat
	focus.set_corner_radius_all(0)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_font_override("font", TmUi.font(SfUi.BOLD, 2))
	b.add_theme_font_size_override("font_size", 14)
	_tab_colours(b, false, locked)
	if locked:
		b.tooltip_text = "Story mode is on its way"
		var lock := Glyph.new("lock", "")
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.focus_mode = Control.FOCUS_NONE
		lock.custom_minimum_size = Vector2(16, 16)
		lock.size = Vector2(16, 16)
		lock.colour = SfUi.FAINT
		b.add_child(lock)
		b.resized.connect(func() -> void: lock.position = Vector2(b.size.x - 30, (b.size.y - 16) * 0.5 - 1))
		b.pressed.connect(func() -> void: locked_pressed.emit(page))
	else:
		b.pressed.connect(func() -> void: page_pressed.emit(page))
	b.pressed.connect(TmUi.play.bind("click"))
	b.mouse_entered.connect(TmUi.play.bind("move"))
	tabs[page] = b
	return b


static func _tab_colours(b: Button, chosen: bool, locked := false) -> void:
	var c := SfUi.FAINT if locked else (SfUi.TEXT if chosen else SfUi.DIM)
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_focus_color", c)
	for s in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(s, SfUi.DIM if locked else SfUi.TEXT)


## You, at the right: a ring with your initial, your nickname ($-codes) and zone; opens the profile.
func _you() -> Button:
	var b := Button.new()
	b.flat = true
	b.tooltip_text = "Profile"
	b.size_flags_vertical = Control.SIZE_FILL
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 14
	pad.content_margin_right = 14
	for s in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(s, pad)
	var focus := SfUi.box("focus").duplicate() as StyleBoxFlat
	focus.set_corner_radius_all(0)
	b.add_theme_stylebox_override("focus", focus)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	b.add_child(row)
	var ring := Glyph.new("user", "")
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.focus_mode = Control.FOCUS_NONE
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ring)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	_nick = TmUi.nick_label("", 16, SfUi.TEXT)
	names.add_child(_nick)
	_zone = SfUi.caption("", 10)
	names.add_child(_zone)
	b.mouse_entered.connect(func() -> void: ring.colour = SfUi.TEXT)
	b.mouse_exited.connect(func() -> void: ring.colour = Color(0, 0, 0, 0))
	b.pressed.connect(func() -> void: page_pressed.emit("profile"))
	b.pressed.connect(TmUi.play.bind("click"))
	tabs["profile"] = b
	refresh()
	b.custom_minimum_size.x = 0
	row.resized.connect(func() -> void: b.custom_minimum_size.x = row.get_combined_minimum_size().x + 28)
	return b


## Your nickname and zone again (after the profile changed them).
func refresh() -> void:
	if _nick == null:
		return
	_nick.text = TmNick.to_bbcode(String(TmUi.setting("name")), SfUi.TEXT)
	var z := String(TmUi.setting("zone"))
	_zone.text = ("WORLD" if z.is_empty() else z.split("|")[-1]).to_upper()


## Lights the tab of a page (and moves the line under it).
func set_page(page: String) -> void:
	var was := current
	current = String(UNDER.get(page, page))
	for p: String in tabs:
		if tabs[p] is Glyph:
			(tabs[p] as Glyph).lit = p == current
		elif p != "profile":
			_tab_colours(tabs[p], p == current, LOCKED.has(p))
	_back.disabled = current == "main"
	_place_underline.call_deferred(not was.is_empty())


func _place_underline(animate: bool) -> void:
	var b: Control = tabs.get(current)
	if b == null or not is_instance_valid(_underline):
		return
	var x := b.global_position.x - global_position.x
	var w := b.size.x
	if b is Glyph:
		x += 6.0
		w -= 12.0
	if animate:
		var tw := _underline.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_underline, "position:x", x, 0.25)
		tw.parallel().tween_property(_underline, "size:x", w, 0.25)
	else:
		_underline.position.x = x
		_underline.size.x = w


## Our wordmark: two slashes, red and violet, and SPEEDFEST in a heavy italic.
class Wordmark:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(226, 40)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y0 := 8.0
		var y1 := 32.0
		for i in 2:
			var x := 2.0 + i * 11.0
			var c := SfUi.RED if i == 0 else SfUi.VIOLET
			draw_colored_polygon(PackedVector2Array([Vector2(x, y1), Vector2(x + 7, y1), Vector2(x + 17, y0), Vector2(x + 10, y0)]), c)
		draw_string(TmUi.font(SfUi.WORDMARK, 1), Vector2(36, 31), "SPEEDFEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, SfUi.TEXT)


## A line icon as a button: back, next, gear, power, lock, play, user. Dim, white when hovered, focused or lit.
class Glyph:
	extends Button

	var kind := ""
	var lit := false:
		set(v):
			lit = v
			queue_redraw()
	var colour := Color(0, 0, 0, 0):       ## a fixed colour (the padlock, your ring), else by state
		set(v):
			colour = v
			queue_redraw()

	func _init(k: String, tip: String) -> void:
		kind = k
		tooltip_text = tip
		flat = true
		custom_minimum_size = Vector2(48, 48) if k != "user" else Vector2(36, 36)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER if k == "user" else Control.SIZE_FILL
		var none := StyleBoxEmpty.new()
		for s in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(s, none)
		var focus := SfUi.box("focus").duplicate() as StyleBoxFlat
		focus.set_corner_radius_all(0)
		add_theme_stylebox_override("focus", focus)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		if k != "lock" and k != "user":
			pressed.connect(TmUi.play.bind("click"))
			mouse_entered.connect(TmUi.play.bind("move"))

	func _draw() -> void:
		var c := colour
		if c.a == 0.0:
			c = SfUi.FAINT if disabled else (SfUi.TEXT if lit or is_hovered() or has_focus() else SfUi.DIM)
		var m := size * 0.5
		var w := 2.0
		match kind:
			"back":
				draw_polyline(PackedVector2Array([m + Vector2(4, -9), m + Vector2(-5, 0), m + Vector2(4, 9)]), c, w, true)
			"next":
				draw_polyline(PackedVector2Array([m + Vector2(-4, -9), m + Vector2(5, 0), m + Vector2(-4, 9)]), c, w, true)
			"gear":
				var r := 7.5
				draw_arc(m, r, 0.0, TAU, 32, c, w, true)
				draw_arc(m, 2.8, 0.0, TAU, 16, c, w, true)
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(m + Vector2.from_angle(a) * (r + 0.5), m + Vector2.from_angle(a) * (r + 3.5), c, 3.2, true)
			"power":
				draw_arc(m + Vector2(0, 1), 8.5, -PI * 0.5 + 0.75, PI * 1.5 - 0.75, 28, c, w, true)
				draw_line(m + Vector2(0, -10), m + Vector2(0, -1), c, w, true)
			"lock":
				draw_arc(m + Vector2(0, -2), 4.0, PI, TAU, 12, c, 1.8, true)
				draw_line(m + Vector2(-4, -2), m + Vector2(-4, 1), c, 1.8, true)
				draw_line(m + Vector2(4, -2), m + Vector2(4, 1), c, 1.8, true)
				draw_rect(Rect2(m + Vector2(-6, 1), Vector2(12, 8)), c)
			"play":
				draw_arc(m, minf(m.x, m.y) - 2.0, 0.0, TAU, 40, Color(c, 0.9), 2.0, true)
				var k := minf(m.x, m.y) * 0.36
				draw_colored_polygon(PackedVector2Array([m + Vector2(-k * 0.7, -k), m + Vector2(k * 1.1, 0), m + Vector2(-k * 0.7, k)]), c)
			"user":
				for i in 48:
					var a0 := TAU * i / 48.0
					var a1 := TAU * (i + 1) / 48.0
					var t := 0.5 + 0.5 * sin(a0 + 0.8)
					draw_arc(m, m.x - 1.5, a0, a1 + 0.01, 2, SfUi.RED.lerp(SfUi.VIOLET, t), 2.0, true)
				var ink := c if c.a > 0.0 else SfUi.DIM
				draw_circle(m + Vector2(0, -3.5), 4.2, ink)
				draw_arc(m + Vector2(0, 9.5), 8.0, PI + 0.35, TAU - 0.35, 16, ink, 2.4, true)
