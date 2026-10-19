class_name HudLeaderboard
extends Control
## Top-right live leaderboard. Compact shows the top 5 (or the top 4 plus my row when
## I'm lower); `expanded` shows everyone. Strings are built only when entries change.

const W := 310.0
const ROW_H := 27.0
const HEAD_H := 30.0
const COMPACT := 5
const MAX_ROWS := 16
const MEDALS := [Color("#ffd23f"), Color("#d6e2f0"), Color("#e08a4a")]

var expanded: bool = false:
	set(v):
		if v != expanded:
			expanded = v
			_layout()

var _rows: Array = []      # [{rank:int, rank_s, name, time_s, dnf, me}]
var _shown: Array = []     # subset of _rows currently drawn
var _hidden_count: int = 0
var _last_sig: String = ""
var _font_head: Font
var _font_num: Font
var _font_body: Font
var _quad := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_head = UITheme.font("head")
	_font_num = UITheme.font("num")
	_font_body = UITheme.font("body_bold")
	custom_minimum_size = Vector2(W, HEAD_H)
	size = custom_minimum_size
	visible = false


## entries: [{id, name, car, best_ms, runs}] (sorted by the server; re-sorted defensively).
func set_entries(entries: Array, my_id: int) -> void:
	var sig := "%d|%s" % [my_id, str(entries)]
	if sig == _last_sig:
		return
	_last_sig = sig
	var sorted := entries.duplicate()
	sorted.sort_custom(_compare)
	_rows.clear()
	for i in sorted.size():
		var e: Dictionary = sorted[i] if sorted[i] is Dictionary else {}
		var best := int(e.get("best_ms", -1))
		var name := String(e.get("name", "?"))
		if name.length() > 16:
			name = name.substr(0, 15) + "…"
		_rows.append({
			"rank": i + 1,
			"rank_s": str(i + 1),
			"name": name.to_upper(),
			"time_s": UITheme.format_time(best) if best >= 0 else "NO TIME",
			"dnf": best < 0,
			"me": int(e.get("id", -999)) == my_id,
		})
	visible = not _rows.is_empty()
	_layout()


static func _compare(a: Variant, b: Variant) -> bool:
	var am := int(a.get("best_ms", -1)) if a is Dictionary else -1
	var bm := int(b.get("best_ms", -1)) if b is Dictionary else -1
	if (am < 0) != (bm < 0):
		return bm < 0
	return am < bm


func _layout() -> void:
	_shown.clear()
	var limit := mini(_rows.size(), MAX_ROWS) if expanded else COMPACT
	if _rows.size() <= limit:
		_shown.append_array(_rows)
	else:
		var my_idx := -1
		for i in _rows.size():
			if _rows[i]["me"]:
				my_idx = i
				break
		if my_idx >= limit:
			_shown.append_array(_rows.slice(0, limit - 1))
			_shown.append(_rows[my_idx])
		else:
			_shown.append_array(_rows.slice(0, limit))
	_hidden_count = _rows.size() - _shown.size()
	var h := HEAD_H + _shown.size() * ROW_H + (20.0 if _hidden_count > 0 else 6.0)
	custom_minimum_size = Vector2(W, h)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var h := size.y
	# Panel with a slanted left edge.
	var plate := PackedVector2Array([Vector2(16, 0), Vector2(W, 0), Vector2(W, h), Vector2(0, h)])
	draw_colored_polygon(plate, Color(0.02, 0.035, 0.09, 0.78))
	draw_line(Vector2(16, 0), Vector2(0, h), Color(UITheme.CYAN, 0.8), 2.0, true)
	draw_line(Vector2(16, 1), Vector2(W, 1), Color(UITheme.CYAN, 0.8), 2.0)
	draw_line(Vector2(16, 1), Vector2(90, 1), UITheme.MAGENTA, 4.0)
	draw_string(_font_head, Vector2(26, 21), "LEADERBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.CYAN)
	var hint := "TAB" if not expanded else "ALL %d" % _rows.size()
	draw_string(_font_head, Vector2(W - 70, 21), hint, HORIZONTAL_ALIGNMENT_RIGHT, 60, 10, Color(UITheme.TEXT_DIM, 0.8))
	var y := HEAD_H
	for i in _shown.size():
		var r: Dictionary = _shown[i]
		var x0 := 16.0 - 16.0 * (y + ROW_H * 0.5) / h + 8.0
		if r["me"]:
			HudText.skew_quad(Rect2(x0, y + 1, W - x0 - 4, ROW_H - 2), 4.0, _quad)
			draw_colored_polygon(_quad, Color(UITheme.CYAN, 0.22))
			draw_line(Vector2(W - 4, y + 2), Vector2(W - 4, y + ROW_H - 2), UITheme.CYAN, 3.0)
		elif i > 0 and _shown[i - 1]["rank"] != r["rank"] - 1:
			# Gap between the top rows and my row.
			draw_line(Vector2(x0 + 10, y), Vector2(W - 14, y), Color(UITheme.TEXT_DIM, 0.35), 1.0)
		var rank: int = r["rank"]
		var rcol: Color = MEDALS[rank - 1] if rank <= 3 and not r["dnf"] else UITheme.TEXT_DIM
		HudText.skew_quad(Rect2(x0 + 4, y + 4, 30, ROW_H - 8), 3.0, _quad)
		draw_colored_polygon(_quad, Color(rcol, 0.22 if rank > 3 else 0.9))
		var rank_col := Color(0.03, 0.04, 0.1) if rank <= 3 and not r["dnf"] else UITheme.TEXT
		draw_string(_font_num, Vector2(x0 + 4, y + 19), r["rank_s"], HORIZONTAL_ALIGNMENT_CENTER, 30, 13, rank_col)
		var ncol := UITheme.CYAN if r["me"] else UITheme.TEXT
		draw_string(_font_body, Vector2(x0 + 44, y + 20), r["name"], HORIZONTAL_ALIGNMENT_LEFT, 140, 18, ncol)
		var tcol := Color(UITheme.TEXT_DIM, 0.7) if r["dnf"] else UITheme.TEXT
		draw_string(_font_num, Vector2(W - 120, y + 19), r["time_s"], HORIZONTAL_ALIGNMENT_RIGHT, 106, 13, tcol)
		y += ROW_H
	if _hidden_count > 0:
		draw_string(_font_head, Vector2(26, y + 14), "+%d MORE" % _hidden_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UITheme.TEXT_DIM, 0.8))
