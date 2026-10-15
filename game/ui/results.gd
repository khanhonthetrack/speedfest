extends CanvasLayer
## Round results overlay: ranked table (medal colors for the top 3, DNF last, my row
## highlighted, best time, runs, car), animated entrance, and a back-to-lobby countdown.
## API: show_results(results: Array, my_id: int) per docs/ARCHITECTURE.md.

const MEDALS := [Color("#ffd23f"), Color("#d6e2f0"), Color("#e08a4a")]
const TABLE_W := 860.0
const ROW_H := 46.0
const MAX_ROWS := 10

## Seconds until the room returns to the lobby (server: ~12 s). The footer counts down.
var return_seconds: float = 12.0

var _root: Control
var _dim: ColorRect
var _title: Label
var _sub: Label
var _header_row: Control
var _rows_box: VBoxContainer
var _footer: Label
var _left: float = 0.0
var _shown_left: int = -1
var _tween: Tween


func _ready() -> void:
	layer = 9
	_build()
	visible = false
	set_process(false)


func show_results(results: Array, my_id: int) -> void:
	var rows := results.duplicate()
	rows.sort_custom(_compare)
	for c in _rows_box.get_children():
		c.queue_free()
	var n := mini(rows.size(), MAX_ROWS)
	var my_index := -1
	for i in rows.size():
		if rows[i] is Dictionary and int(rows[i].get("id", -999)) == my_id:
			my_index = i
	for i in n:
		_rows_box.add_child(_make_row(rows[i], i, i == my_index))
	if my_index >= n:
		# Always show my own row, even past the cap.
		_rows_box.get_child(n - 1).queue_free()
		_rows_box.add_child(_make_row(rows[my_index], my_index, true))
	if rows.is_empty():
		var empty := UITheme.label("NO DRIVERS", "head", 22, UITheme.TEXT_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows_box.add_child(empty)
	_sub.text = _subtitle(rows, my_index)
	_left = return_seconds
	_shown_left = -1
	_update_footer()
	visible = true
	set_process(true)
	_set_sibling_hud_visible(false)
	_animate_in()


func hide_results() -> void:
	visible = false
	set_process(false)
	_set_sibling_hud_visible(true)


## The race adds the HUD next to us; hide it under the results so they read cleanly.
func _set_sibling_hud_visible(v: bool) -> void:
	var p := get_parent()
	if p == null:
		return
	for c in p.get_children():
		if c != self and c.has_method("set_hud_visible"):
			c.call("set_hud_visible", v)


static func _compare(a: Variant, b: Variant) -> bool:
	var am := int(a.get("best_ms", -1)) if a is Dictionary else -1
	var bm := int(b.get("best_ms", -1)) if b is Dictionary else -1
	if (am < 0) != (bm < 0):
		return bm < 0
	return am < bm


func _subtitle(rows: Array, my_index: int) -> String:
	var track := String(Game.track_id).to_upper()
	if my_index < 0:
		return "TIME ATTACK  ·  %s" % track
	var me: Dictionary = rows[my_index]
	if int(me.get("best_ms", -1)) < 0:
		return "TIME ATTACK  ·  %s  ·  NO FINISH THIS ROUND" % track
	return "TIME ATTACK  ·  %s  ·  YOU FINISHED P%d OF %d" % [track, my_index + 1, rows.size()]


func _process(delta: float) -> void:
	_left = maxf(0.0, _left - delta)
	_update_footer()


func _update_footer() -> void:
	var s := ceili(_left)
	if s == _shown_left:
		return
	_shown_left = s
	_footer.text = "RETURNING TO LOBBY IN %d" % s if s > 0 else "RETURNING TO LOBBY…"


func _car_name(car: Variant) -> String:
	var id := ""
	if car is Dictionary:
		id = String(car.get("car", ""))
	else:
		id = String(car)
	if id in CarDefs.IDS:
		return CarDefs.display_name(id).to_upper()
	return id.to_upper() if id != "" else "—"


func _make_row(e: Variant, index: int, me: bool) -> Control:
	var d: Dictionary = e if e is Dictionary else {}
	var best := int(d.get("best_ms", -1))
	var dnf := best < 0
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(TABLE_W, ROW_H)
	var bg := Color(0.03, 0.05, 0.12, 0.88) if index % 2 == 0 else Color(0.05, 0.07, 0.16, 0.88)
	var border := Color(UITheme.CYAN, 0.15)
	if me:
		bg = Color(0.0, 0.32, 0.42, 0.9)
		border = UITheme.CYAN
	var st := UITheme.panel_style(bg, border, 2 if me else 1, UITheme.SKEW * 0.5)
	st.content_margin_left = 12
	st.content_margin_right = 26
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	if index < 3 and not dnf:
		st.border_width_left = 8
		st.border_color = MEDALS[index] if not me else UITheme.CYAN
	row.add_theme_stylebox_override("panel", st)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	row.add_child(hb)

	var rank_text := "DNF" if dnf else str(index + 1)
	var rank_col: Color = MEDALS[index] if index < 3 and not dnf else (UITheme.TEXT_DIM if dnf else UITheme.TEXT)
	var rank := UITheme.label(rank_text, "heavy", 26 if not dnf else 18, rank_col)
	rank.custom_minimum_size = Vector2(70, 0)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(rank)

	var name_text := String(d.get("name", "?")).to_upper()
	if me:
		name_text += "  (YOU)"
	var name_l := UITheme.label(name_text, "body_bold", 24, UITheme.CYAN if me else UITheme.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(name_l)

	var car_l := UITheme.label(_car_name(d.get("car", "")), "head", 14, UITheme.TEXT_DIM)
	car_l.custom_minimum_size = Vector2(170, 0)
	car_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(car_l)

	var time_l := UITheme.label("NO TIME" if dnf else UITheme.format_time(best), "num", 22,
		UITheme.TEXT_DIM if dnf else (MEDALS[0] if index == 0 else UITheme.TEXT))
	time_l.custom_minimum_size = Vector2(170, 0)
	time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(time_l)

	var runs_l := UITheme.label(str(int(d.get("runs", 0))), "num", 18, UITheme.TEXT_DIM)
	runs_l.custom_minimum_size = Vector2(70, 0)
	runs_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	runs_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(runs_l)
	return row


func _animate_in() -> void:
	if _tween:
		_tween.kill()
	_dim.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.position.x = -80.0
	_header_row.modulate.a = 0.0
	_footer.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.35)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.3).set_delay(0.1)
	_tween.tween_property(_title, "position:x", 0.0, 0.45).set_delay(0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_header_row, "modulate:a", 1.0, 0.3).set_delay(0.3)
	var i := 0
	for row in _rows_box.get_children():
		var c := row as Control
		if c == null or c.is_queued_for_deletion():
			continue
		c.modulate.a = 0.0
		var d := 0.35 + 0.08 * i
		_tween.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(d)
		# Slide via a transient horizontal offset on the theme margin would relayout; use scale instead.
		c.pivot_offset = Vector2(0, ROW_H * 0.5)
		c.scale = Vector2(1.08, 1.0)
		_tween.tween_property(c, "scale", Vector2.ONE, 0.35).set_delay(d).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		i += 1
	_tween.tween_property(_footer, "modulate:a", 1.0, 0.4).set_delay(0.5 + 0.08 * i)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.015, 0.05, 0.84)
	_root.add_child(_dim)
	var deco := _ResultsDeco.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(deco)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(TABLE_W, 0)
	center.add_child(vb)

	var title_holder := Control.new()
	title_holder.custom_minimum_size = Vector2(TABLE_W, 70)
	vb.add_child(title_holder)
	_title = UITheme.label("ROUND RESULTS", "heavy", 56, UITheme.TEXT)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(UITheme.MAGENTA, 0.5))
	title_holder.add_child(_title)
	var bar := ColorRect.new()
	bar.color = UITheme.MAGENTA
	bar.custom_minimum_size = Vector2(200, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vb.add_child(bar)
	_sub = UITheme.label("", "head", 14, UITheme.CYAN)
	vb.add_child(_sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	vb.add_child(gap)

	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 14)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 12)
	hm.add_theme_constant_override("margin_right", 26)
	hm.add_child(_header_row)
	vb.add_child(hm)
	for spec in [["POS", 70, HORIZONTAL_ALIGNMENT_CENTER], ["DRIVER", -1, HORIZONTAL_ALIGNMENT_LEFT],
			["CAR", 170, HORIZONTAL_ALIGNMENT_LEFT], ["BEST", 170, HORIZONTAL_ALIGNMENT_RIGHT],
			["RUNS", 70, HORIZONTAL_ALIGNMENT_RIGHT]]:
		var l := UITheme.label(spec[0], "head", 12, UITheme.TEXT_DIM)
		l.horizontal_alignment = spec[2]
		if spec[1] > 0:
			l.custom_minimum_size = Vector2(spec[1], 0)
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_header_row.add_child(l)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	vb.add_child(_rows_box)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	vb.add_child(gap2)
	_footer = UITheme.label("", "head", 16, UITheme.AMBER)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_footer)


class _ResultsDeco extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Big diagonal light slabs behind the table.
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.08, 0), Vector2(w * 0.3, 0), Vector2(w * 0.12, h), Vector2(-w * 0.1, h)]),
			Color(UITheme.CYAN, 0.04))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.78, 0), Vector2(w * 0.86, 0), Vector2(w * 0.68, h), Vector2(w * 0.6, h)]),
			Color(UITheme.MAGENTA, 0.06))
		draw_line(Vector2(0, 2), Vector2(w, 2), Color(UITheme.CYAN, 0.5), 2.0)
		draw_line(Vector2(0, h - 3), Vector2(w * 0.4, h - 3), Color(UITheme.MAGENTA, 0.8), 3.0)
