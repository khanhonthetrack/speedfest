class_name TrackArt
extends Control
## Procedural poster art for a track theme ("city", "arena", "coast"), drawn with _draw so it
## costs nothing on either renderer. Used by the track select cards. `sprint` swaps the stunt
## props (loop, cliff) for the short maps' ground: stadium lawn with a sand trap, or beach dunes.

var theme_id := "city":
	set(v):
		theme_id = v
		queue_redraw()
var seed_value := 7
var sprint := false:
	set(v):
		sprint = v
		queue_redraw()


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	match theme_id:
		"arena":
			_draw_arena()
		"coast":
			_draw_coast()
		_:
			_draw_city()
	# bottom fade into the card
	var w := size.x
	var h := size.y
	_vgrad(Rect2(0, h * 0.72, w, h * 0.28), Color(0.02, 0.03, 0.08, 0.0), Color(0.02, 0.03, 0.08, 0.85))


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_city() -> void:
	var w := size.x
	var h := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_vgrad(Rect2(0, 0, w, h * 0.62), Color(0.03, 0.03, 0.12), Color(0.28, 0.08, 0.38))
	_vgrad(Rect2(0, h * 0.62, w, h * 0.38), Color(0.08, 0.04, 0.16), Color(0.02, 0.02, 0.06))
	# far skyline
	var x := 0.0
	while x < w:
		var bw := rng.randf_range(18, 40)
		var bh := rng.randf_range(0.18, 0.4) * h
		draw_rect(Rect2(x, h * 0.62 - bh, bw, bh), Color(0.1, 0.07, 0.22))
		x += bw + 2
	# near buildings with windows
	x = -10.0
	while x < w:
		var bw := rng.randf_range(34, 70)
		var bh := rng.randf_range(0.3, 0.62) * h
		var top := h * 0.66 - bh
		draw_rect(Rect2(x, top, bw, bh), Color(0.04, 0.04, 0.1))
		var wy := top + 8
		while wy < h * 0.64:
			var wx := x + 5
			while wx < x + bw - 6:
				if rng.randf() < 0.35:
					var c := Color(1.0, 0.85, 0.5) if rng.randf() < 0.7 else Color(0.6, 0.9, 1.0)
					draw_rect(Rect2(wx, wy, 4, 5), Color(c, rng.randf_range(0.5, 0.95)))
				wx += 8
			wy += 10
		if rng.randf() < 0.45:
			var nc := [UITheme.MAGENTA, UITheme.CYAN, UITheme.AMBER][rng.randi() % 3] as Color
			var ny := top + rng.randf_range(10, bh * 0.5)
			draw_rect(Rect2(x + 4, ny, bw - 8, 5), nc)
			draw_rect(Rect2(x + 2, ny - 3, bw - 4, 11), Color(nc, 0.18))
		x += bw + rng.randf_range(4, 14)
	# wet road with reflections
	var horizon := h * 0.66
	for i in 9:
		var rx := rng.randf_range(0, w)
		var rc := [UITheme.MAGENTA, UITheme.CYAN, Color(1.0, 0.8, 0.4)][i % 3] as Color
		draw_rect(Rect2(rx, horizon + 4, rng.randf_range(2, 5), h * 0.3), Color(rc, 0.18))
	draw_line(Vector2(w * 0.5, horizon), Vector2(w * 0.1, h), Color(1, 1, 1, 0.25), 2.0)
	draw_line(Vector2(w * 0.5, horizon), Vector2(w * 0.9, h), Color(1, 1, 1, 0.25), 2.0)
	# rain
	for i in 70:
		var px := rng.randf_range(0, w)
		var py := rng.randf_range(0, h)
		draw_line(Vector2(px, py), Vector2(px - 3, py + 12), Color(0.7, 0.8, 1.0, 0.18), 1.0)


func _draw_arena() -> void:
	var w := size.x
	var h := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 11
	_vgrad(Rect2(0, 0, w, h * 0.55), Color(0.04, 0.02, 0.12), Color(0.22, 0.05, 0.32))
	_vgrad(Rect2(0, h * 0.55, w, h * 0.45), Color(0.06, 0.03, 0.14), Color(0.02, 0.02, 0.06))
	# floodlight beams
	for i in 4:
		var bx := w * (0.12 + i * 0.25)
		var col := UITheme.CYAN if i % 2 == 0 else UITheme.MAGENTA
		draw_polygon(PackedVector2Array([Vector2(bx - 3, 0), Vector2(bx + 3, 0), Vector2(bx + 70 - i * 30, h * 0.6), Vector2(bx - 40 - i * 10, h * 0.6)]),
			PackedColorArray([Color(col, 0.35), Color(col, 0.35), Color(col, 0.0), Color(col, 0.0)]))
		draw_circle(Vector2(bx, 6), 6, Color(1, 1, 1, 0.9))
	# stands
	for row in 5:
		var y := h * 0.34 + row * 9
		draw_rect(Rect2(0, y, w, 6), Color(0.1, 0.06, 0.2))
		for i in int(w / 6):
			if rng.randf() < 0.5:
				var cc := [UITheme.MAGENTA, UITheme.CYAN, Color.WHITE, UITheme.AMBER][rng.randi() % 4] as Color
				draw_rect(Rect2(i * 6 + 1, y + 1, 2, 3), Color(cc, 0.6))
	if sprint:
		_draw_lawn(w, h)
		return
	# the loop
	var c := Vector2(w * 0.62, h * 0.6)
	var r := h * 0.26
	draw_arc(c, r, 0, TAU, 64, Color(UITheme.CYAN, 0.25), 16.0)
	draw_arc(c, r, 0, TAU, 64, UITheme.CYAN, 4.0)
	draw_arc(c, r - 7, 0, TAU, 64, Color(UITheme.MAGENTA, 0.8), 2.0)
	# ground + track
	draw_rect(Rect2(0, h * 0.6 + r - 2, w, h), Color(0.03, 0.03, 0.08))
	draw_line(Vector2(0, c.y + r), Vector2(w, c.y + r), UITheme.MAGENTA, 3.0)
	# ramp
	var rb := Vector2(w * 0.08, c.y + r)
	draw_colored_polygon(PackedVector2Array([rb, rb + Vector2(70, 0), rb + Vector2(70, -26)]), Color(0.15, 0.1, 0.3))
	draw_line(rb, rb + Vector2(70, -26), UITheme.CYAN, 2.0)
	# boost chevrons
	for i in 3:
		var cx := w * 0.28 + i * 16
		var cy := c.y + r - 6
		draw_polyline(PackedVector2Array([Vector2(cx, cy - 6), Vector2(cx + 8, cy), Vector2(cx, cy + 6)]), UITheme.LIME, 3.0)


func _draw_coast() -> void:
	var w := size.x
	var h := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 23
	var sea_y := h * 0.6
	_vgrad(Rect2(0, 0, w, sea_y * 0.55), Color(0.12, 0.06, 0.3), Color(0.75, 0.2, 0.45))
	_vgrad(Rect2(0, sea_y * 0.55, w, sea_y * 0.45), Color(0.75, 0.2, 0.45), Color(1.0, 0.55, 0.25))
	# sun with stripes
	var sc := Vector2(w * 0.42, sea_y - 6)
	var sr := h * 0.22
	draw_circle(sc, sr * 1.5, Color(1.0, 0.5, 0.3, 0.18))
	draw_circle(sc, sr, Color(1.0, 0.78, 0.35))
	for i in 5:
		var y := sc.y - sr * 0.15 + i * sr * 0.18
		draw_rect(Rect2(sc.x - sr, y, sr * 2, 2.0 + i * 1.2), Color(0.85, 0.3, 0.45))
	# islands
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.62, sea_y), Vector2(w * 0.7, sea_y - 18), Vector2(w * 0.78, sea_y - 10), Vector2(w * 0.86, sea_y)]), Color(0.3, 0.1, 0.3))
	# sea
	_vgrad(Rect2(0, sea_y, w, h - sea_y), Color(0.3, 0.1, 0.32), Color(0.05, 0.04, 0.14))
	for i in 14:
		var y := sea_y + 4 + i * 6
		var len := rng.randf_range(20, 80) * (1.0 - i * 0.05)
		draw_line(Vector2(sc.x - len * 0.5 + rng.randf_range(-10, 10), y), Vector2(sc.x + len * 0.5, y), Color(1.0, 0.7, 0.4, 0.5 - i * 0.03), 2.0)
	if sprint:
		_draw_dunes(w, h, rng)
		return
	# cliff + road
	draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.3), Vector2(w * 0.12, h * 0.36), Vector2(w * 0.22, h * 0.6), Vector2(w * 0.3, h), Vector2(0, h)]), Color(0.08, 0.03, 0.1))
	draw_line(Vector2(w * 0.05, h), Vector2(w * 1.0, h * 0.74), Color(0.1, 0.06, 0.12), 14.0)
	draw_line(Vector2(w * 0.05, h - 7), Vector2(w * 1.0, h * 0.74 - 7), UITheme.AMBER, 2.0)
	# palm
	var pb := Vector2(w * 0.9, h)
	var top := Vector2(w * 0.84, h * 0.3)
	draw_line(pb, top, Color(0.06, 0.02, 0.08), 5.0)
	for a in [-2.6, -2.2, -1.6, -1.0, -0.5]:
		var d := Vector2(cos(a), sin(a) + 0.9) * 46.0
		draw_polyline(PackedVector2Array([top, top + d * 0.5 + Vector2(0, -8), top + d]), Color(0.06, 0.02, 0.08), 4.0)


## Short stadium map: striped infield lawn, a curving road, gravel and a sand trap under a jump.
func _draw_lawn(w: float, h: float) -> void:
	var g := h * 0.6
	for i in 6:
		var y0 := g + (h - g) * pow(i / 6.0, 1.6)
		var y1 := g + (h - g) * pow((i + 1) / 6.0, 1.6)
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1), Color(0.09, 0.26, 0.08) if i % 2 == 0 else Color(0.12, 0.31, 0.1))
	# sand trap
	var sc := Vector2(w * 0.7, g + (h - g) * 0.55)
	draw_set_transform(sc, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, w * 0.22, Color(0.72, 0.6, 0.4))
	draw_set_transform(Vector2.ZERO)
	# road sweeping in from the left, gravel run-off on its outside
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(Vector2(lerpf(-10.0, w * 0.55, t), lerpf(h + 6.0, g + 8.0, t) + sin(t * PI) * 16.0))
	draw_polyline(pts, Color(0.45, 0.42, 0.38), 26.0)
	draw_polyline(pts, Color(0.06, 0.06, 0.1), 18.0)
	draw_polyline(pts, Color(UITheme.CYAN, 0.8), 2.0)
	# jump ramp over the trap
	var rb := Vector2(w * 0.5, g + 12.0)
	draw_colored_polygon(PackedVector2Array([rb, rb + Vector2(36, 0), rb + Vector2(36, -16)]), Color(0.15, 0.1, 0.3))
	draw_line(rb, rb + Vector2(36, -16), UITheme.LIME, 2.0)
	draw_arc(Vector2(w * 0.72, g + 4.0), w * 0.2, PI * 1.08, PI * 1.92, 24, Color(1, 1, 1, 0.35), 2.0)


## Short coast map: sand dunes in the foreground with a road over them and a dune jump.
func _draw_dunes(w: float, h: float, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var base := h * (0.66 + k * 0.12)
		var pts := PackedVector2Array([Vector2(0, h)])
		for i in 17:
			var x := w * i / 16.0
			pts.append(Vector2(x, base - (sin(x / w * TAU * (0.8 + k * 0.3) + k * 1.7) * 0.5 + 0.5) * (22.0 - k * 4.0)))
		pts.append(Vector2(w, h))
		var c := Color(0.55, 0.36, 0.3).lerp(Color(0.85, 0.62, 0.4), k / 2.0)
		draw_colored_polygon(pts, c)
		for i in 10:
			var rx := rng.randf_range(0, w)
			draw_line(Vector2(rx, base + 6), Vector2(rx + 18, base + 4), Color(1, 0.9, 0.7, 0.25), 1.0)
	# road over the dunes, kicking up into a jump
	var road := PackedVector2Array()
	for i in 11:
		var t := i / 10.0
		road.append(Vector2(lerpf(-10.0, w * 0.62, t), lerpf(h * 0.98, h * 0.72, t) - sin(t * PI * 1.5) * 10.0))
	draw_polyline(road, Color(0.08, 0.05, 0.1), 12.0)
	draw_polyline(road, UITheme.AMBER, 2.0)
	draw_arc(Vector2(w * 0.8, h * 0.74), w * 0.18, PI * 1.05, PI * 1.95, 24, Color(1, 1, 1, 0.4), 2.0)
	# palm
	var pb := Vector2(w * 0.9, h)
	var top := Vector2(w * 0.86, h * 0.36)
	draw_line(pb, top, Color(0.06, 0.02, 0.08), 5.0)
	for a in [-2.6, -2.2, -1.6, -1.0, -0.5]:
		var d := Vector2(cos(a), sin(a) + 0.9) * 40.0
		draw_polyline(PackedVector2Array([top, top + d * 0.5 + Vector2(0, -8), top + d]), Color(0.06, 0.02, 0.08), 4.0)
