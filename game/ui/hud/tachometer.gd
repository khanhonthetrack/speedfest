class_name HudTachometer
extends Control
## Bottom-right gauge cluster: LED-segment rpm arc with a redline, needle, digital speed,
## unit, gear, and a segmented nitro bar that glows while active.
## Setters only store values and request a redraw when the visible value changes.

const SIZE := Vector2(320, 330)
const SEGMENTS := 40
const ARC_START := deg_to_rad(135.0)
const ARC_SWEEP := deg_to_rad(270.0)
const REDLINE := 0.84
const RADIUS := 122.0
const SEG_IN := 104.0
const NITRO_CELLS := 16

var speed_kmh: float = 0.0
var rpm: float = 0.0
var gear: int = 0
var nitro: float = 1.0
var nitro_active: bool = false
var mph: bool = false

var _center := Vector2(160, 150)
var _speed_shown: int = -1
var _rpm_q: int = -1
var _nitro_q: int = -1
var _speed_codes := PackedInt32Array()
var _seg_points := PackedVector2Array()
var _seg_colors := PackedColorArray()
var _tick_points := PackedVector2Array()
var _quad := PackedVector2Array()
var _font_num: Font
var _font_heavy: Font
var _font_head: Font
var _font_body: Font
var _time: float = 0.0
var _shift_flash: float = 0.0


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_num = UITheme.font("num")
	_font_heavy = UITheme.font("heavy")
	_font_head = UITheme.font("head")
	_font_body = UITheme.font("body_bold")
	_seg_points.resize(SEGMENTS * 2)
	_seg_colors.resize(SEGMENTS)
	for i in SEGMENTS:
		var a := ARC_START + ARC_SWEEP * (i + 0.5) / SEGMENTS
		var d := Vector2.from_angle(a)
		_seg_points[i * 2] = _center + d * SEG_IN
		_seg_points[i * 2 + 1] = _center + d * RADIUS
	# Minor ticks just outside the segments.
	for i in 37:
		var a := ARC_START + ARC_SWEEP * i / 36.0
		var d := Vector2.from_angle(a)
		var inner := RADIUS + 5.0 if i % 4 == 0 else RADIUS + 6.0
		var outer := RADIUS + 14.0 if i % 4 == 0 else RADIUS + 9.0
		_tick_points.append(_center + d * inner)
		_tick_points.append(_center + d * outer)
	set_process(false)
	_update_segment_colors()


func set_speed(kmh: float, use_mph: bool) -> void:
	speed_kmh = kmh
	var v := absf(kmh) * (0.621371 if use_mph else 1.0)
	var shown := int(v + 0.5)
	if shown != _speed_shown or use_mph != mph:
		_speed_shown = shown
		mph = use_mph
		HudText.int_codes(shown, _speed_codes)
		queue_redraw()


func set_rpm(ratio: float, p_gear: int) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var q := int(ratio * 400.0)
	if p_gear != gear:
		if p_gear > gear and gear > 0:
			_shift_flash = 1.0
			set_process(true)
		gear = p_gear
		queue_redraw()
	rpm = ratio
	if q != _rpm_q:
		_rpm_q = q
		_update_segment_colors()
		queue_redraw()


func set_nitro(amount: float, active: bool) -> void:
	amount = clampf(amount, 0.0, 1.0)
	var q := int(amount * 200.0)
	nitro = amount
	if active != nitro_active:
		nitro_active = active
		set_process(active or _shift_flash > 0.0)
		queue_redraw()
	if q != _nitro_q:
		_nitro_q = q
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _shift_flash > 0.0:
		_shift_flash = maxf(0.0, _shift_flash - delta * 3.0)
	if not nitro_active and _shift_flash <= 0.0:
		set_process(false)
	queue_redraw()


func _update_segment_colors() -> void:
	var lit := rpm * SEGMENTS
	var red := Color(1.0, 0.16, 0.2)
	for i in SEGMENTS:
		var t := (i + 0.5) / SEGMENTS
		var in_red := t >= REDLINE
		if float(i) < lit:
			var c: Color
			if in_red:
				c = red
			else:
				c = UITheme.CYAN.lerp(UITheme.MAGENTA, clampf((t - 0.45) / (REDLINE - 0.45), 0.0, 1.0))
			# The leading segment is brightest.
			if float(i) >= lit - 1.0:
				c = c.lightened(0.45)
			_seg_colors[i] = c
		else:
			_seg_colors[i] = Color(red, 0.22) if in_red else Color(0.55, 0.75, 1.0, 0.09)


func _draw() -> void:
	var c := _center
	# Backplate: dark disc with a neon rim and a soft outer halo.
	draw_circle(c, RADIUS + 26.0, Color(0.0, 0.9, 1.0, 0.05))
	draw_circle(c, RADIUS + 20.0, Color(0.02, 0.035, 0.09, 0.78))
	draw_arc(c, RADIUS + 20.0, ARC_START - 0.12, ARC_START + ARC_SWEEP + 0.12, 72, Color(UITheme.CYAN, 0.75), 2.0, true)
	draw_arc(c, RADIUS + 26.0, ARC_START + 0.3, ARC_START + ARC_SWEEP - 0.3, 64, Color(UITheme.CYAN, 0.18), 1.0, true)
	# Redline band behind the segments.
	draw_arc(c, RADIUS + 3.0, ARC_START + ARC_SWEEP * REDLINE, ARC_START + ARC_SWEEP, 24, Color(1, 0.15, 0.2, 0.9), 3.0, true)
	draw_multiline(_tick_points, Color(UITheme.TEXT, 0.45), 1.5)
	# LED segments: one batched call.
	var seg_w := TAU * ((SEG_IN + RADIUS) * 0.5) * (ARC_SWEEP / TAU) / SEGMENTS * 0.62
	draw_multiline_colors(_seg_points, _seg_colors, seg_w)
	# Tick numbers 0..9 (x1000 rpm).
	for i in 10:
		var a := ARC_START + ARC_SWEEP * i / 9.0
		var p := c + Vector2.from_angle(a) * (SEG_IN - 15.0)
		var col := Color(1, 0.35, 0.38) if float(i) / 9.0 >= REDLINE else UITheme.TEXT_DIM
		var code := HudText.C_0 + i
		var w := _font_num.get_char_size(code, 13).x
		_font_num.draw_char(get_canvas_item(), p + Vector2(-w * 0.5, 5.0), code, 13, col)
	# Needle.
	var na := ARC_START + ARC_SWEEP * rpm
	var nd := Vector2.from_angle(na)
	var needle_col := Color(1, 0.3, 0.35) if rpm >= REDLINE else Color(1, 1, 1)
	draw_line(c + nd * 40.0, c + nd * (RADIUS + 4.0), Color(needle_col, 0.25), 7.0, true)
	draw_line(c + nd * 40.0, c + nd * (RADIUS + 4.0), needle_col, 2.5, true)
	# Speed readout.
	var glow := Color(UITheme.CYAN, 0.35)
	if nitro_active:
		glow = Color(UITheme.MAGENTA, 0.45 + 0.2 * sin(_time * 18.0))
	HudText.draw_codes_centered(self, _font_heavy, 58, c.x, c.y + 18.0, _speed_codes, 42.0, UITheme.TEXT, glow, 8)
	var unit := "MPH" if mph else "KM/H"
	var uw := _font_head.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(_font_head, Vector2(c.x - uw * 0.5, c.y + 40.0), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UITheme.CYAN, 0.9))
	# Gear box in the gauge's open bottom.
	var gr := Rect2(c.x - 26.0, c.y + 62.0, 52.0, 46.0)
	HudText.skew_quad(gr, 6.0, _quad)
	var gear_border := UITheme.CYAN
	if rpm >= REDLINE and gear > 0:
		gear_border = Color(1, 0.25, 0.3) if fmod(Time.get_ticks_msec() / 90.0, 2.0) < 1.0 else UITheme.AMBER
	draw_colored_polygon(_quad, Color(0.03, 0.05, 0.12, 0.92).lerp(Color(UITheme.LIME, 0.5), _shift_flash))
	_quad.append(_quad[0])
	draw_polyline(_quad, gear_border, 2.0, true)
	_quad.resize(4)
	var gcode := 82 if gear < 0 else (78 if gear == 0 else HudText.C_0 + clampi(gear, 1, 9))
	var gw := _font_heavy.get_char_size(gcode, 34).x
	var gcol := UITheme.AMBER if gear <= 0 else UITheme.TEXT
	_font_heavy.draw_char(get_canvas_item(), Vector2(c.x - gw * 0.5, gr.position.y + 38.0), gcode, 34, gcol)
	_draw_nitro()


func _draw_nitro() -> void:
	var top := 296.0
	var left := 38.0
	var cell_w := 14.0
	var gap := 2.5
	var h := 16.0
	var label_col := UITheme.MAGENTA if nitro_active else Color(UITheme.TEXT_DIM, 0.9)
	draw_string(_font_head, Vector2(left - 2.0, top - 6.0), "NOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_col)
	var pct := int(nitro * 100.0 + 0.5)
	var pulse := 0.5 + 0.5 * sin(_time * 22.0)
	var lit := nitro * NITRO_CELLS
	for i in NITRO_CELLS:
		var x := left + i * (cell_w + gap)
		var r := Rect2(x, top, cell_w, h)
		HudText.skew_quad(r, 3.0, _quad)
		var col: Color
		if float(i) < lit:
			var frac := clampf(lit - i, 0.0, 1.0)
			col = UITheme.CYAN.lerp(UITheme.MAGENTA, float(i) / NITRO_CELLS)
			if nitro_active:
				col = col.lightened(0.25 + 0.25 * pulse)
			col.a = 0.35 + 0.65 * frac
		else:
			col = Color(1, 1, 1, 0.08)
		draw_colored_polygon(_quad, col)
	if nitro_active:
		var frame := Rect2(left - 6.0, top - 4.0, NITRO_CELLS * (cell_w + gap) + 8.0, h + 8.0)
		HudText.skew_quad(frame, 3.0, _quad)
		_quad.append(_quad[0])
		draw_polyline(_quad, Color(UITheme.MAGENTA, 0.55 + 0.45 * pulse), 2.0, true)
		_quad.resize(4)
	if pct <= 0 and not nitro_active:
		draw_string(_font_head, Vector2(left + 190.0, top - 6.0), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UITheme.BAD, 0.9))
