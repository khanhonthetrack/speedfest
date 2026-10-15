class_name StatBar
extends Control
## Skewed neon stat bar (0..1) with a tick marking the stock value. Animates toward new values.

var value := 0.5:
	set(v):
		_target = clampf(v, 0.0, 1.0)
		set_process(true)
var stock := -1.0:
	set(v):
		stock = v
		queue_redraw()
var color: Color = UITheme.CYAN
var _shown := 0.0
var _target := 0.5


func _init() -> void:
	custom_minimum_size = Vector2(120, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_shown = move_toward(_shown, _target, delta * 2.5)
	queue_redraw()
	if is_equal_approx(_shown, _target):
		set_process(false)


func _para(x0: float, x1: float, h: float, col: Color) -> void:
	var sk := h * 0.6
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + sk, 0), Vector2(x1 + sk, 0), Vector2(x1, h), Vector2(x0, h)]), col)


func _draw() -> void:
	var w := size.x - size.y * 0.6
	var h := size.y
	_para(0, w, h, Color(1, 1, 1, 0.08))
	# segmented fill
	var segs := 20
	var seg_w := w / segs
	var filled := _shown * segs
	for i in segs:
		var f := clampf(filled - i, 0.0, 1.0)
		if f <= 0.0:
			break
		var c := color.lerp(UITheme.MAGENTA, float(i) / segs * 0.5)
		_para(i * seg_w + 1, i * seg_w + seg_w * f - 1, h, c)
	if stock >= 0.0:
		var x := stock * w
		draw_line(Vector2(x + h * 0.6, -2), Vector2(x, h + 2), UITheme.TEXT, 2.0)
