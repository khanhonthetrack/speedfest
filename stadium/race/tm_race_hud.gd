class_name TmRaceHud
extends CanvasLayer
## Race HUD as TMNF draws it (compared side by side with TMNF itself, M10-5): the clock in
## 7-segment digits in a faint blue pill on the bottom edge (negative before the start), the speed
## and the distance driven in a dark pill in the bottom-right corner, the map's name and author in
## a grey pill at the top right, the countdown's blue figures 3, 2, 1, Go! just above the middle
## (TmRace.figure_at), "Press Return to respawn / Press Delete to restart" when the car stands
## still, and at each checkpoint and the finish the time with the difference to the record's split,
## blue when ahead, red when behind (then the race menu's result panel).

var race: TmRace
var car: TmCar
var challenge: TmChallenge
var best := {}:                    ## the track's record {time_ms, splits}, set by the race scene
	set(v):
		best = v
		_update_info()

var _clock: TmSegText
var _speed: TmSegText
var _dist: TmSegText
var _info: Label                    ## map name, author (and checkpoints / laps)
var _centre: TmSegText              ## a checkpoint's or the finish's time
var _delta: TmSegText               ## its difference to the record
var _hint: Label
var _fig: TextureRect               ## the countdown's figure (3, 2, 1, Go!: assets/ui/count_*)
var _fig_name := ""
var _flash_left := 0.0
var _distance := 0.0                ## metres driven since the start
var _still := 0.0                   ## seconds the car has stood (nearly) still while racing
var _moving := 0.0                  ## seconds it has moved again since
var _screen: Control
const FINISH_FLASH := 1.5           ## seconds: then the race menu shows the result panel
const PILL := preload("res://ui/tm_pill.gdshader")

const AHEAD := Color(0.35, 0.6, 1.0)
const BEHIND := Color(1.0, 0.3, 0.25)
const MEDAL_COLOURS := {"author": Color(0.3, 0.85, 0.45), "gold": Color(1.0, 0.82, 0.25),
	"silver": Color(0.82, 0.85, 0.9), "bronze": Color(0.85, 0.55, 0.3), "": Color.WHITE}
## The pills' fills, measured against TMNF's frames: the clock's a blue tint growing toward the
## bottom edge, the speed's a plain darkening (x0.76), the map's a light grey.
const CLOCK_TOP := Color(0.1, 0.12, 0.3, 0.14)
const CLOCK_BOTTOM := Color(0.05, 0.18, 0.95, 0.4)
const SPEED_FILL := Color(0.0, 0.0, 0.0, 0.24)
const INFO_FILL := Color(0.6, 0.64, 0.7, 0.5)


func _ready() -> void:
	var clock_box := _pill(CLOCK_TOP, CLOCK_BOTTOM, [26, 26, 0, 0])
	clock_box.anchor_left = 0.5
	clock_box.anchor_right = 0.5
	clock_box.anchor_top = 1.0
	clock_box.anchor_bottom = 1.0
	clock_box.offset_left = -150
	clock_box.offset_right = 150
	clock_box.offset_top = -58
	_clock = _digits(clock_box, 35, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_clock.offset_top = 4
	var speed_box := _pill(SPEED_FILL, SPEED_FILL, [26, 0, 0, 0])
	speed_box.anchor_left = 1.0
	speed_box.anchor_right = 1.0
	speed_box.anchor_top = 1.0
	speed_box.anchor_bottom = 1.0
	speed_box.offset_left = -152
	speed_box.offset_top = -78
	_dist = _digits(speed_box, 13, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	_dist.offset_top = 9
	_dist.offset_right = -14
	_speed = _digits(speed_box, 35, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_speed.offset_bottom = -9
	_speed.offset_right = -13
	# the map's name and author: a pill that fits its text, hung from the right edge
	var info_box := PanelContainer.new()
	info_box.add_theme_stylebox_override("panel", _box(INFO_FILL, [22, 0, 0, 22], Vector4(28, 6, 14, 8)))
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.anchor_left = 1.0
	info_box.anchor_right = 1.0
	info_box.offset_top = 8
	info_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(info_box)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.add_theme_font_override("font", TmUi.font(TmUi.SANS))
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_constant_override("line_spacing", -4)
	_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	info_box.add_child(_info)
	_centre = _digits(self_rect(), 40, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_centre.offset_top = 225
	_delta = _digits(self_rect(), 28, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_delta.offset_top = 282
	_hint = _label(22, Vector2(0, -130), TmUi.SANS)
	_hint.text = "Press Return to respawn\nPress Delete to restart"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.visible = false
	_fig = TextureRect.new()
	_fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fig.anchor_left = 0.5
	_fig.anchor_right = 0.5
	_fig.anchor_top = 0.5
	_fig.anchor_bottom = 0.5
	_fig.offset_left = -105
	_fig.offset_right = 105
	_fig.offset_top = -82
	_fig.offset_bottom = 23
	_fig.pivot_offset = Vector2(105, 52)
	_fig.modulate.a = 0.0
	_fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fig)
	_update_info()
	if race:
		race.checkpoint_taken.connect(_on_checkpoint)
		race.lap_done.connect(_on_lap)


func _update_info() -> void:
	if _info == null or challenge == null:
		return
	var lines := [challenge.name, challenge.author]
	if race and race.checkpoint_count > 0:
		lines.append("%d / %d" % [race.taken.size(), race.checkpoint_count])
	if race and race.laps > 1:
		lines.append("Lap %d / %d" % [mini(race.lap + 1, race.laps), race.laps])
	var t := "\n".join(lines)
	if _info.text != t:
		_info.text = t


## A pill (ui/tm_pill.gdshader): a rounded rectangle from `top` to `bottom` colour, corners
## [top left, top right, bottom right, bottom left] in pixels.
func _pill(top: Color, bottom: Color, corners: Array) -> ColorRect:
	var p := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = PILL
	m.set_shader_parameter("top_colour", top)
	m.set_shader_parameter("bottom_colour", bottom)
	m.set_shader_parameter("radii", Vector4(corners[0], corners[1], corners[2], corners[3]))
	p.material = m
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.resized.connect(func() -> void: m.set_shader_parameter("rect_size", p.size))
	add_child(p)
	return p


## A full-screen, input-transparent holder for centred texts.
func self_rect() -> Control:
	if _screen == null:
		_screen = Control.new()
		_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_screen)
		_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _screen


static func _box(fill: Color, corners: Array, margins: Vector4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left = corners[0]
	sb.corner_radius_top_right = corners[1]
	sb.corner_radius_bottom_right = corners[2]
	sb.corner_radius_bottom_left = corners[3]
	sb.corner_detail = 12
	sb.anti_aliasing = true
	sb.content_margin_left = margins.x
	sb.content_margin_top = margins.y
	sb.content_margin_right = margins.z
	sb.content_margin_bottom = margins.w
	return sb


## TMNF's race digits (TmSegText) `height` pixels high, filling `parent`.
func _digits(parent: Control, height: float, h: HorizontalAlignment, v: VerticalAlignment) -> TmSegText:
	var l := TmSegText.new()
	l.digit_height = height
	l.h_align = h
	l.v_align = v
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return l


## A centred label `offset` from the screen's middle.
func _label(size: int, offset: Vector2, font_key: String) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", TmUi.font(font_key))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", maxi(3, size / 9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.position += offset
	return l


## Back to the start state (on restart).
func reset() -> void:
	_flash_left = 0.0
	_centre.text = ""
	_delta.text = ""
	_distance = 0.0
	_still = 0.0
	_moving = 0.0
	_hint.visible = false
	_figure("")


## Shows a countdown figure ("3", "2", "1", "go"; "" hides it), popping in as TMNF's do.
func _figure(fig: String) -> void:
	if fig == _fig_name:
		return
	_fig_name = fig
	if fig.is_empty():
		var out := _fig.create_tween()
		out.tween_property(_fig, "modulate:a", 0.0, 0.08)
		return
	_fig.texture = TmUi.icon("count_" + fig)
	_fig.modulate.a = 1.0
	_fig.scale = Vector2(1.35, 1.35)
	var tw := _fig.create_tween()
	tw.tween_property(_fig, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(text: String, colour: Color, secs: float, delta_ms := 0, has_delta := false) -> void:
	_centre.text = text
	_centre.colour = colour
	_flash_left = secs
	_delta.text = delta_text(delta_ms) if has_delta else ""
	_delta.colour = AHEAD if delta_ms <= 0 else BEHIND


## A difference to the record as TMNF shows it: -0.12 (ahead) or +1.05 (behind).
static func delta_text(ms: int) -> String:
	return "%s%d.%02d" % ["-" if ms <= 0 else "+", absi(ms) / 1000, (absi(ms) % 1000) / 10]


## The clock as TMNF shows it: before the start how long is left, negative (-0:02.60).
static func clock_text(ms: int) -> String:
	return ("-" + TmRace.time_text(-ms)) if ms < 0 else TmRace.time_text(ms)


## The record's split at the split just taken (the n-th of the run), if it has one.
func _best_split(n: int) -> int:
	var s: Array = best.get("splits", [])
	return int(s[n - 1]) if n >= 1 and n <= s.size() else -1


func _on_checkpoint(count: int, time_ms: int) -> void:
	var b := _best_split(race.splits.size())
	_flash(TmRace.time_text(time_ms), Color.WHITE, 2.5, time_ms - b, b >= 0)
	_update_info()


func _on_lap(_lap: int, time_ms: int) -> void:
	var b := _best_split(race.splits.size())
	_flash(TmRace.time_text(time_ms), Color.WHITE, 2.5, time_ms - b, b >= 0)
	_update_info()


## The finish: the time in its medal's colour and the difference to the record before this run
## (prev), for the moment until the race menu's result panel (TmRaceMenu.show_finish) takes over.
func show_finish(time_ms: int, prev: Dictionary, _record: bool) -> void:
	var m := TmRace.medal(time_ms, challenge) if challenge else ""
	var b := int(prev.get("time_ms", -1))
	_flash(TmRace.time_text(time_ms), MEDAL_COLOURS[m], FINISH_FLASH, time_ms - b, b >= 0)


func _process(delta: float) -> void:
	if race == null:
		return
	_clock.text = clock_text(race.clock_ms())
	var kmh := absf(car.speed_kmh()) if car else 0.0
	_speed.text = "%d" % roundi(kmh)
	if race.state == TmRace.State.RACING:
		_distance += kmh / 3.6 * delta
	_dist.text = "%d m" % int(_distance)
	_update_info()
	_figure(TmRace.figure_at(race.clock_ms()))
	# TMNF's hint when the car stands: shown after 2 s still, gone 3 s after it moves again
	if race.state == TmRace.State.RACING and kmh < 20.0:
		_still += delta
		_moving = 0.0
		if _still > 2.0:
			_hint.visible = true
	else:
		_moving += delta
		if _moving > 3.0 or race.state != TmRace.State.RACING:
			_still = 0.0
			_hint.visible = false
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_centre.text = ""
			_delta.text = ""
