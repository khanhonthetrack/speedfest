class_name HudTimerPanel
extends Control
## Top-center panel: run time (big, tabular), checkpoint counter, best time, and the
## online round clock in a tab underneath (amber in the last 30 s, flashing red in the last 10 s).

const W := 470.0
const H := 92.0
const TAB_W := 190.0
const TAB_H := 28.0

var _run_ms: int = -2
var _best_ms: int = -2
var _cp_passed: int = -1
var _cp_total: int = -1
var _round_ms: int = -1
var _round_shown_s: int = -2

var _run_codes := PackedInt32Array()
var _best_codes := PackedInt32Array()
var _cp_codes := PackedInt32Array()
var _cp_total_codes := PackedInt32Array()
var _round_codes := PackedInt32Array()
var _plate := PackedVector2Array()
var _tab := PackedVector2Array()
var _edge := PackedVector2Array()
var _font_heavy: Font
var _font_num: Font
var _font_head: Font
var _time: float = 0.0
## Briefly tints the run time (e.g. blue/red after a split). Fades out.
var _tint := Color(1, 1, 1, 0)


func _ready() -> void:
	custom_minimum_size = Vector2(W, H + TAB_H + 8.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_heavy = UITheme.font("heavy")
	_font_num = UITheme.font("num")
	_font_head = UITheme.font("head")
	_plate = PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W - 34.0, H), Vector2(34.0, H)])
	_edge = PackedVector2Array([Vector2(W, 0), Vector2(W - 34.0, H), Vector2(34.0, H), Vector2(0, 0)])
	var tx := (W - TAB_W) * 0.5
	_tab = PackedVector2Array([Vector2(tx, H + 4.0), Vector2(tx + TAB_W, H + 4.0),
		Vector2(tx + TAB_W - 14.0, H + 4.0 + TAB_H), Vector2(tx + 14.0, H + 4.0 + TAB_H)])
	set_run_time(-1)
	set_best(-1)
	set_checkpoints(0, 0)
	set_process(false)


func set_run_time(ms: int) -> void:
	if ms == _run_ms:
		return
	_run_ms = ms
	HudText.time_codes(ms, _run_codes)
	queue_redraw()


func set_best(ms: int) -> void:
	if ms == _best_ms:
		return
	_best_ms = ms
	HudText.time_codes(ms, _best_codes)
	queue_redraw()


func set_checkpoints(passed: int, total: int) -> void:
	if passed == _cp_passed and total == _cp_total:
		return
	_cp_passed = passed
	_cp_total = total
	HudText.int_codes(passed, _cp_codes)
	HudText.int_codes(total, _cp_total_codes)
	queue_redraw()


func set_round_time_left(ms: int) -> void:
	_round_ms = ms
	var s := -1 if ms < 0 else (ms + 999) / 1000
	if s == _round_shown_s:
		return
	_round_shown_s = s
	if ms >= 0:
		HudText.clock_codes(ms, _round_codes)
	set_process(ms >= 0 and ms <= 10000 or _tint.a > 0.0)
	queue_redraw()


func flash(color: Color) -> void:
	_tint = color
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if _tint.a > 0.0:
		_tint.a = maxf(0.0, _tint.a - delta * 0.8)
	if _tint.a <= 0.0 and not (_round_ms >= 0 and _round_ms <= 10000):
		set_process(false)
	queue_redraw()


func _draw() -> void:
	# Backplate with a neon underline and magenta corner accents.
	draw_colored_polygon(_plate, Color(0.02, 0.035, 0.09, 0.82))
	draw_polyline(_edge, Color(UITheme.CYAN, 0.18), 6.0, true)
	draw_polyline(_edge, Color(UITheme.CYAN, 0.9), 2.0, true)
	draw_line(Vector2(34.0, H), Vector2(110.0, H), UITheme.MAGENTA, 4.0)
	draw_line(Vector2(W - 110.0, H), Vector2(W - 34.0, H), UITheme.MAGENTA, 4.0)
	var cx := W * 0.5
	# Run time.
	var col := UITheme.TEXT
	if _tint.a > 0.0:
		col = UITheme.TEXT.lerp(Color(_tint, 1.0), _tint.a)
	HudText.draw_codes_centered(self, _font_heavy, 44, cx, 52.0, _run_codes, 33.0, col, Color(UITheme.CYAN, 0.28), 8)
	# Checkpoints (left) and best (right).
	draw_string(_font_head, Vector2(64.0, 79.0), "CP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.CYAN)
	var x := 92.0
	x += HudText.draw_codes(self, _font_num, 17, Vector2(x, 80.0), _cp_codes, 13.0, UITheme.TEXT)
	draw_string(_font_num, Vector2(x + 2.0, 80.0), "/", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.TEXT_DIM)
	HudText.draw_codes(self, _font_num, 15, Vector2(x + 13.0, 80.0), _cp_total_codes, 11.5, UITheme.TEXT_DIM)
	draw_string(_font_head, Vector2(W - 238.0, 79.0), "BEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.MAGENTA)
	HudText.draw_codes_right(self, _font_num, 17, W - 64.0, 80.0, _best_codes, 13.0, UITheme.TEXT if _best_ms >= 0 else UITheme.TEXT_DIM)
	# Round clock tab.
	if _round_ms < 0:
		return
	var tab_bg := Color(0.02, 0.035, 0.09, 0.82)
	var tcol := UITheme.TEXT
	var edge := Color(UITheme.CYAN, 0.6)
	if _round_ms <= 10000:
		var on := fmod(_time * 2.0, 1.0) < 0.5
		tcol = UITheme.BAD if on else UITheme.TEXT
		edge = UITheme.BAD
		tab_bg = Color(0.3, 0.02, 0.05, 0.85) if on else tab_bg
	elif _round_ms <= 30000:
		tcol = UITheme.AMBER
		edge = UITheme.AMBER
	draw_colored_polygon(_tab, tab_bg)
	draw_line(_tab[3], _tab[2], edge, 2.0)
	draw_string(_font_head, Vector2(_tab[0].x + 22.0, H + 24.0), "ROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(tcol, 0.75))
	HudText.draw_codes_right(self, _font_num, 18, _tab[1].x - 24.0, H + 25.0, _round_codes, 13.5, tcol)
