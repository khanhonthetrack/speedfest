class_name TmTopBar
extends CanvasLayer
## TMNF's bar at the top (M10-6, drawn after TMNF's; the window's full width, the owner's choice: TMNF's
## covers its right half): the sound volume (a wedge with its
## knob, then a speaker), the music volume (a wedge, then a note), display settings, the clock and
## a window button (fullscreen or windowed). In the menus it stays up (`popup` false) with your
## nickname and zone at its left (`profile`); in races and replays it slides down when the mouse
## reaches the top edge and goes again a moment after the mouse leaves it. A press on the speaker or
## the note mutes the sound or the music; the display button opens a small panel (graphics quality,
## shadows, HD), or emits display_pressed where a page shows the options (the menus).
## Not copied: TMNF's 3D glasses (anaglyph) button; the remake has no stereo mode.
## --top_bar=show holds it down in a race (screenshots), --top_bar=display with its panel open.

signal display_pressed

const HEIGHT := 38.0
const TRIGGER := 8.0               ## the mouse this close to the top edge brings it down (races)
const HIDE_AFTER_S := 0.6          ## it goes this long after the mouse left it
const SLIDE := 420.0               ## px/s

var popup := true                  ## races: hidden until the mouse reaches the top edge
var profile := false               ## menus: your nickname and zone at its left
var mouse_override := Vector2(-1, -1)   ## tests: the mouse here (canvas px) instead of the real one

var _root: Control
var _bar: PanelContainer
var _panel: PanelContainer         ## the display settings (races)
var _clock: TmSegText
var _nick: RichTextLabel
var _zone: Label
var _sound: Wedge
var _music: Wedge
var _sound_icon: Glyph
var _music_icon: Glyph
var _window_icon: Glyph
var _y := -HEIGHT - 6.0
var _away_s := 99.0
var _moved := false                ## the mouse has moved since the scene started (its first position means nothing)
var _shown_nick := ""


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = TmUi.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", TmUi.glass("tm_bar"))
	_bar.anchor_left = 0.0
	_bar.anchor_right = 1.0
	_bar.offset_bottom = HEIGHT
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bar)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	_bar.add_child(line)
	if profile:
		var pad := Control.new()
		pad.custom_minimum_size.x = 14
		line.add_child(pad)
		_nick = TmUi.nick_label(String(TmUi.setting("name")), 20)
		_nick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(_nick)
		_zone = TmUi.label("", 15, TmUi.DIM, TmUi.SANS)
		_zone.add_theme_constant_override("outline_size", 0)
		line.add_child(_zone)
		refresh()
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(fill)
	_sound = Wedge.new()
	_sound.value = float(TmUi.setting("sound_volume"))
	_sound.tooltip_text = "Sound volume"
	_sound.changed.connect(func(v: float) -> void: TmUi.set_setting("sound_volume", v))
	line.add_child(_sound)
	_sound_icon = _glyph(line, "sound", "Sound on / off", func() -> void:
		TmUi.set_setting("sound", not bool(TmUi.setting("sound"))))
	_gap(line, 10)
	_music = Wedge.new()
	_music.value = float(TmUi.setting("music_volume"))
	_music.tooltip_text = "Music volume"
	_music.changed.connect(func(v: float) -> void: TmUi.set_setting("music_volume", v))
	line.add_child(_music)
	_music_icon = _glyph(line, "music", "Music on / off", func() -> void:
		TmUi.set_setting("music", not bool(TmUi.setting("music"))))
	_gap(line, 8)
	_glyph(line, "display", "Display settings", _display)
	_gap(line, 4)
	_clock = TmSegText.new()
	_clock.digit_height = 16.0
	_clock.custom_minimum_size = Vector2(118, 30)
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_clock.text = clock_text()
	line.add_child(_clock)
	_window_icon = _glyph(line, "window", "Fullscreen / windowed", func() -> void:
		TmUi.set_setting("fullscreen", not bool(TmUi.setting("fullscreen"))))
	_gap(line, 4)
	_make_panel()
	if not popup:
		_y = 0.0
	var hook := String(TestHooks.arg("top_bar", ""))
	if popup and hook in ["show", "display"]:
		mouse_override = Vector2(_root.size.x - 300.0 if _root.size.x > 0.0 else 1300.0, 2.0)
		_panel.visible = hook == "display"
	_place()


## Your nickname and zone again (after the profile changed them).
func refresh() -> void:
	if not profile or _nick == null:
		return
	_shown_nick = String(TmUi.setting("name"))
	_nick.text = TmNick.to_bbcode(_shown_nick, TmUi.TEXT)
	var zone := String(TmUi.setting("zone"))
	_zone.text = (zone.replace("|", "  ·  ") if not zone.is_empty() else "World").to_upper()


## True while the bar is (at least partly) down.
func shown() -> bool:
	return _y > -HEIGHT - 5.0


## The time of day, as TMNF's bar shows it (hh:mm:ss).
static func clock_text() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [int(t["hour"]), int(t["minute"]), int(t["second"])]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_moved = true


func _process(delta: float) -> void:
	_clock.text = clock_text()
	if profile and String(TmUi.setting("name")) != _shown_nick:
		refresh()
	_sound_icon.off = not bool(TmUi.setting("sound"))
	_music_icon.off = not bool(TmUi.setting("music"))
	if popup:
		var m := mouse_override if mouse_override.x >= 0.0 else (_root.get_local_mouse_position() if _moved else Vector2(-1, 999))
		var over := m.y >= 0.0 and m.y <= TRIGGER
		if shown() and m.y >= 0.0 and m.y <= HEIGHT + 12.0:
			over = true                 # on the bar
		if _panel.visible and _panel.get_global_rect().grow(12.0).has_point(m):
			over = true
		if _sound.dragging or _music.dragging:
			over = true
		_away_s = 0.0 if over else _away_s + delta
		if _away_s > HIDE_AFTER_S:
			_panel.visible = false
		var want := 0.0 if _away_s <= HIDE_AFTER_S else -HEIGHT - 6.0
		_y = move_toward(_y, want, SLIDE * delta)
	else:
		_y = 0.0
	_place()


func _place() -> void:
	_bar.offset_top = _y
	_bar.offset_bottom = _y + HEIGHT
	_bar.visible = shown()


func _gap(line: HBoxContainer, w: float) -> void:
	var g := Control.new()
	g.custom_minimum_size.x = w
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(g)


func _glyph(line: HBoxContainer, kind: String, tip: String, action: Callable) -> Glyph:
	var g := Glyph.new()
	g.kind = kind
	g.tooltip_text = tip
	g.pressed.connect(action)
	g.pressed.connect(TmUi.play.bind("click"))
	line.add_child(g)
	return g


## The display button: the options page where there is one (menus), else the small panel.
func _display() -> void:
	if not display_pressed.get_connections().is_empty():
		display_pressed.emit()
		return
	_panel.visible = not _panel.visible


## The display panel under the bar (races): graphics quality, shadows, HD textures.
func _make_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", TmUi.glass("tm_dialog"))
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -420.0
	_panel.offset_right = -8.0
	_panel.offset_top = HEIGHT + 6.0
	_panel.visible = false
	_root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	v.add_child(TmUi.tm_title("Display"))
	var q := TmUi.tm_button("", Callable(), 380)
	var show_q := func() -> void:
		q.text = "Graphics:  %s" % String(TmRtx.QUALITY_NAMES[clampi(int(TmUi.setting("quality")), 0, TmRtx.QUALITY_NAMES.size() - 1)])
	show_q.call()
	q.focus_mode = Control.FOCUS_NONE
	q.pressed.connect(func() -> void:
		TmUi.set_setting("quality", (int(TmUi.setting("quality")) + 1) % TmRtx.QUALITY_NAMES.size())
		show_q.call())
	v.add_child(q)
	for opt: Array in [["shadows", "Shadows"], ["hd", "HD textures and shading"]]:
		var c := CheckButton.new()
		c.text = String(opt[1])
		c.button_pressed = bool(TmUi.setting(opt[0]))
		c.focus_mode = Control.FOCUS_NONE
		var key: String = opt[0]
		c.toggled.connect(func(on: bool) -> void: TmUi.set_setting(key, on))
		v.add_child(c)
	var note := TmUi.label("Shadows and textures change when the next track loads.", 16, TmUi.DIM, TmUi.SANS)
	note.add_theme_constant_override("outline_size", 0)
	v.add_child(note)


## A volume as TMNF's: a wedge from thin (quiet) to thick (loud), lit up to the knob.
class Wedge extends Control:
	signal changed(value: float)
	var value := 1.0
	var dragging := false
	const STEP := 0.05

	func _init() -> void:
		custom_minimum_size = Vector2(160, 30)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			dragging = (event as InputEventMouseButton).pressed
			if dragging:
				_set_from((event as InputEventMouseButton).position.x)
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			_set_from((event as InputEventMouseMotion).position.x)
			accept_event()

	func _set_from(x: float) -> void:
		set_value(snappedf(clampf((x - 4.0) / (size.x - 8.0), 0.0, 1.0), STEP))

	func set_value(v: float) -> void:
		if is_equal_approx(v, value):
			return
		value = v
		queue_redraw()
		changed.emit(v)

	func _draw() -> void:
		var mid := size.y * 0.5
		var x0 := 4.0
		var x1 := size.x - 4.0
		var k := lerpf(x0, x1, value)
		var half := func(x: float) -> float: return lerpf(0.6, 4.2, (x - x0) / (x1 - x0))
		# the whole wedge, dark; then lit up to the knob
		draw_colored_polygon(PackedVector2Array([Vector2(x0, mid - 0.6), Vector2(x1, mid - 4.2), Vector2(x1, mid + 4.2),
			Vector2(x0, mid + 0.6)]), Color(0.16, 0.19, 0.24))
		var hk: float = half.call(k)
		draw_polygon(PackedVector2Array([Vector2(x0, mid - 0.6), Vector2(k, mid - hk), Vector2(k, mid + hk), Vector2(x0, mid + 0.6)]),
			PackedColorArray([Color(0.30, 0.40, 0.55), Color(0.62, 0.78, 0.95), Color(0.40, 0.52, 0.68), Color(0.30, 0.40, 0.55)]))
		draw_line(Vector2(x0, mid - 0.5), Vector2(k, mid - hk + 0.6), Color(0.85, 0.92, 1.0, 0.5), 1.0)
		# the knob: a small grey ball, lit from above
		draw_circle(Vector2(k, mid), 7.5, Color(0.22, 0.23, 0.25))
		draw_circle(Vector2(k, mid), 6.5, Color(0.55, 0.57, 0.6))
		draw_circle(Vector2(k - 1.5, mid - 2.0), 3.0, Color(0.88, 0.9, 0.92))


## The bar's buttons, drawn: the speaker, the note, the display and the window.
class Glyph extends Button:
	var kind := ""
	var off := false:
		set(v):
			if v != off:
				off = v
				queue_redraw()

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(36, 34)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var lit := is_hovered()
		var green := Color(0.35, 0.95, 0.35) if not off else Color(0.4, 0.42, 0.45)
		match kind:
			"sound":       # a grey ball with a glowing green eye, as TMNF's speaker
				draw_circle(c, 15.0, Color(0.2, 0.21, 0.23))
				draw_circle(c, 13.5, Color(0.66, 0.68, 0.71) if lit else Color(0.54, 0.56, 0.59))
				draw_circle(c + Vector2(-3, -4), 6.0, Color(1, 1, 1, 0.18))
				draw_arc(c, 8.5, 0.0, TAU, 32, Color(green, 0.55), 2.0, true)
				draw_circle(c, 6.0, Color(green, 0.35))
				draw_circle(c, 4.5, green)
				draw_circle(c + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.8))
			"music":       # a green note
				var col := green.lightened(0.15) if lit else green
				draw_set_transform(c + Vector2(-3.5, 7.0), -0.35, Vector2(1.0, 0.75))
				draw_circle(Vector2.ZERO, 5.0, col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_line(c + Vector2(0.8, 6.5), c + Vector2(0.8, -11.0), col, 2.5)
				draw_polyline(PackedVector2Array([c + Vector2(0.8, -11.0), c + Vector2(6.0, -6.5), c + Vector2(7.5, -1.5)]), col, 2.5)
			"display":     # a monitor on its stand
				var r := Rect2(c + Vector2(-13, -11), Vector2(26, 18))
				var frame := Color(0.92, 0.93, 0.95) if lit else Color(0.78, 0.8, 0.83)
				draw_rect(r, Color(0.12, 0.2, 0.32))
				draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(12, 5)), Color(0.35, 0.6, 0.9))
				draw_rect(Rect2(r.position + Vector2(3, 10), Vector2(20, 5)), Color(0.25, 0.55, 0.3))
				draw_rect(r, frame, false, 2.0)
				draw_rect(Rect2(c + Vector2(-2, 7), Vector2(4, 3)), frame)
				draw_rect(Rect2(c + Vector2(-7, 10), Vector2(14, 2)), frame)
			"window":      # two windows, one over the other
				var col2 := Color.WHITE if lit else Color(0.88, 0.9, 0.92)
				var back := Rect2(c + Vector2(-8, -12), Vector2(20, 15))
				var front := Rect2(c + Vector2(-13, -6), Vector2(20, 15))
				draw_rect(back, Color(0.1, 0.1, 0.11))
				draw_rect(back, col2, false, 2.0)
				draw_rect(Rect2(back.position, Vector2(back.size.x, 3)), col2)
				draw_rect(front, Color(0.1, 0.1, 0.11))
				draw_rect(front, col2, false, 2.0)
				draw_rect(Rect2(front.position, Vector2(front.size.x, 3.5)), col2)
		if off:
			draw_line(c + Vector2(-11, 11), c + Vector2(11, -11), Color(0.9, 0.25, 0.2), 2.5)
