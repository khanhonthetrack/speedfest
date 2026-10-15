class_name HudSplitPopup
extends Control
## Split pop-up under the run timer: "CP 2   0:23.456   -0.123".
## Blue (GOOD) when faster than the PB split, red (BAD) when slower, neutral without a PB.

const W := 360.0
const H := 40.0

var _cp_text: String = ""
var _time_text: String = ""
var _delta_text: String = ""
var _color := UITheme.CYAN
var _font_head: Font
var _font_num: Font
var _font_heavy: Font
var _quad := PackedVector2Array()
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_head = UITheme.font("head")
	_font_num = UITheme.font("num")
	_font_heavy = UITheme.font("heavy")
	modulate.a = 0.0
	visible = false


func popup(cp_label: String, ms: int, delta_ms: int, has_delta: bool, hold: float = 2.6) -> void:
	_cp_text = cp_label
	_time_text = UITheme.format_time(ms)
	if has_delta:
		_delta_text = UITheme.format_delta(delta_ms)
		_color = UITheme.GOOD if delta_ms < 0 else (UITheme.BAD if delta_ms > 0 else UITheme.TEXT_DIM)
	else:
		_delta_text = ""
		_color = UITheme.CYAN
	queue_redraw()
	if _tween:
		_tween.kill()
	visible = true
	modulate.a = 0.0
	scale = Vector2(1.25, 0.6)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(hold)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.chain().tween_callback(hide)


func clear() -> void:
	if _tween:
		_tween.kill()
	visible = false
	modulate.a = 0.0


func _draw() -> void:
	HudText.skew_quad(Rect2(10, 0, W - 20, H), 8.0, _quad)
	draw_colored_polygon(_quad, Color(0.02, 0.035, 0.09, 0.85))
	if _delta_text != "":
		# Colored delta block on the right.
		HudText.skew_quad(Rect2(W - 138, 0, 128, H), 8.0, _quad)
		draw_colored_polygon(_quad, Color(_color, 0.85))
	draw_line(Vector2(2, H), Vector2(W - 18, H), _color, 2.0)
	draw_string(_font_head, Vector2(26, 26), _cp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _color.lightened(0.3))
	var time_x := 92.0 if _delta_text != "" else 0.0
	var time_w := 130.0 if _delta_text != "" else W
	draw_string(_font_num, Vector2(time_x, 27), _time_text, HORIZONTAL_ALIGNMENT_CENTER, time_w, 18, UITheme.TEXT)
	if _delta_text != "":
		draw_string(_font_heavy, Vector2(W - 138, 28), _delta_text, HORIZONTAL_ALIGNMENT_CENTER, 128, 20, Color(1, 1, 1))
