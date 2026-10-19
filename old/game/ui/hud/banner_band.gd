class_name HudBannerBand
extends Control
## A long skewed light band behind center banners (CHECKPOINT / FINISH / GO!).
## Fades out toward both ends; color set per banner.

var color := UITheme.MAGENTA:
	set(v):
		color = v
		queue_redraw()

var _pts := PackedVector2Array()
var _cols := PackedColorArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var sk := h * 0.35
	# Three quads: fade-in, solid, fade-out (vertex colors give the gradient).
	var xs := [0.0, w * 0.3, w * 0.7, w]
	var alphas := [0.0, 1.0, 1.0, 0.0]
	for i in 3:
		_pts.resize(4)
		_cols.resize(4)
		_pts[0] = Vector2(xs[i] + sk, 0)
		_pts[1] = Vector2(xs[i + 1] + sk, 0)
		_pts[2] = Vector2(xs[i + 1] - sk, h)
		_pts[3] = Vector2(xs[i] - sk, h)
		var a0 := Color(0.02, 0.035, 0.09, 0.8 * alphas[i])
		var a1 := Color(0.02, 0.035, 0.09, 0.8 * alphas[i + 1])
		_cols[0] = a0; _cols[1] = a1; _cols[2] = a1; _cols[3] = a0
		draw_polygon(_pts, _cols)
	# Neon edges.
	for i in 3:
		var c0 := Color(color, alphas[i])
		var c1 := Color(color, alphas[i + 1])
		draw_polyline_colors(PackedVector2Array([Vector2(xs[i] + sk, 1), Vector2(xs[i + 1] + sk, 1)]), PackedColorArray([c0, c1]), 2.0)
		draw_polyline_colors(PackedVector2Array([Vector2(xs[i] - sk, h - 1), Vector2(xs[i + 1] - sk, h - 1)]), PackedColorArray([c0, c1]), 2.0)
