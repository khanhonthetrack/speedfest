class_name HudMinimap
extends Control
## Bottom-left minimap. `set_points` fits the XZ centerline into the box, choosing the
## rotation that makes it largest. Car positions come every frame via `set_cars`.

const SIZE := Vector2(260, 190)
const PAD := 18.0

var _xf := Transform2D.IDENTITY
var _line := PackedVector2Array()
var _has_map := false
var _local := Vector2.ZERO
var _has_local := false
var _others: Array = []
var _frame := PackedVector2Array()


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := SIZE
	var k := 18.0
	_frame = PackedVector2Array([Vector2(k, 0), Vector2(s.x, 0), Vector2(s.x, s.y - k), Vector2(s.x - k, s.y),
		Vector2(0, s.y), Vector2(0, k)])
	visible = false


func set_points(points: PackedVector2Array) -> void:
	_line.clear()
	_has_map = points.size() >= 2
	visible = _has_map
	if not _has_map:
		return
	var centroid := Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= points.size()
	# Find the rotation that lets the track fill the box the most.
	var best_a := 0.0
	var best_scale := 0.0
	var best_mid := Vector2.ZERO
	for step in 60:
		var a := PI * step / 60.0
		var cs := cos(a)
		var sn := sin(a)
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for p in points:
			var d := p - centroid
			var r := Vector2(d.x * cs - d.y * sn, d.x * sn + d.y * cs)
			mn = mn.min(r)
			mx = mx.max(r)
		var sc := minf((SIZE.x - PAD * 2.0) / maxf(mx.x - mn.x, 1.0), (SIZE.y - PAD * 2.0) / maxf(mx.y - mn.y, 1.0))
		# Prefer the unrotated view unless rotating gains > 8%.
		if sc > best_scale * (1.08 if step > 0 else 1.0):
			best_scale = sc
			best_a = a
			best_mid = (mn + mx) * 0.5
	var scale_f := best_scale
	# screen = R(a) * (p - centroid) - mid, scaled, then moved to the box center.
	var rot := Transform2D(best_a, Vector2.ZERO)
	_xf = Transform2D(0.0, SIZE * 0.5) * Transform2D(0.0, Vector2(scale_f, scale_f), 0.0, Vector2.ZERO) \
		* Transform2D(0.0, -best_mid) * rot * Transform2D(0.0, -centroid)
	_line.resize(points.size())
	for i in points.size():
		_line[i] = _xf * points[i]
	queue_redraw()


## `others`: Array of Vector2, or Dictionaries with "pos" (Vector2) and optional "color" (Color).
func set_cars(local_pos: Vector2, others: Array) -> void:
	_local = local_pos
	_has_local = true
	_others = others
	if _has_map:
		queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_frame, Color(0.02, 0.035, 0.09, 0.66))
	draw_polyline(_frame, Color(UITheme.CYAN, 0.5), 1.5, true)
	draw_line(_frame[_frame.size() - 1], _frame[0], Color(UITheme.CYAN, 0.5), 1.5, true)
	draw_line(Vector2(0, SIZE.y - 1.0), Vector2(70, SIZE.y - 1.0), UITheme.MAGENTA, 3.0)
	if not _has_map:
		return
	draw_polyline(_line, Color(UITheme.CYAN, 0.16), 9.0, true)
	draw_polyline(_line, Color(0.75, 0.95, 1.0, 0.9), 2.5, true)
	# Start/finish marker.
	var s0 := _line[0]
	var dir := (_line[1] - s0).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	draw_line(s0 - nrm * 8.0, s0 + nrm * 8.0, Color(1, 1, 1), 3.0)
	draw_line(s0 - nrm * 8.0, s0 + nrm * 8.0, Color(0.05, 0.05, 0.05), 1.0)
	for o in _others:
		var p: Vector2
		var col := UITheme.MAGENTA
		if o is Vector2:
			p = o
		elif o is Dictionary:
			p = o.get("pos", Vector2.ZERO)
			col = o.get("color", col)
		else:
			continue
		var sp := _clamp_in(_xf * p)
		draw_circle(sp, 6.0, Color(col, 0.3))
		draw_circle(sp, 3.5, col)
	if _has_local:
		var lp := _clamp_in(_xf * _local)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_circle(lp, 9.0 + 3.0 * pulse, Color(UITheme.LIME, 0.18))
		draw_circle(lp, 5.0, UITheme.LIME)
		draw_arc(lp, 5.5, 0.0, TAU, 16, Color(0, 0, 0, 0.8), 1.5, true)


func _clamp_in(p: Vector2) -> Vector2:
	return p.clamp(Vector2(4, 4), SIZE - Vector2(4, 4))
