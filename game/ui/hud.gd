extends CanvasLayer
## In-race HUD (NFSU2-inspired). API fixed by docs/ARCHITECTURE.md "HUD".
## Setters are called every physics tick: they only store values and redraw the
## affected gauge when its visible value changes (no node or string churn per tick).
##
## Layout (1280x720 base, canvas_items stretch scales it up):
##   top-center   run time, CP counter, best, round clock, split pop-ups
##   top-right    live leaderboard (hold `leaderboard` to expand)
##   center       countdown, FINISH / NEW PB! banners, toasts (checkpoints only show the
##                compact split pop-up under the timer: owner found the big banner too loud)
##   bottom-right tachometer, speed, gear, nitro (scaled down to TACHO_SCALE)
##   overlay      speed lines above ~200 km/h (Settings.quality >= 2)

const SPEED_LINES_FROM := 200.0
const TACHO_SCALE := 0.7
const SPEED_LINES_FULL := 330.0

var _root: Control
var _tacho: HudTachometer
var _timer: HudTimerPanel
var _split: HudSplitPopup
var _board: HudLeaderboard
var _speed_lines: ColorRect
var _speed_mat: ShaderMaterial
var _fps: Label

# Center stack.
var _count_box: Control
var _count_label: Label
var _band: HudBannerBand
var _banner_box: Control
var _banner_label: Label
var _sub_label: Label
var _delta_label: Label
var _pb_box: Control
var _pb_label: Label
var _toast_box: PanelContainer
var _toast_label: Label

var _count_tween: Tween
var _banner_tween: Tween
var _pb_tween: Tween
var _toast_tween: Tween

var _lines_intensity: float = 0.0
var _lines_target: float = 0.0
var _speed_kmh: float = 0.0
var _nitro_active: bool = false
var _fps_accum: float = 0.0
var _cp_total: int = 0


func _ready() -> void:
	layer = 5
	_build()
	if Settings.has_signal("changed"):
		Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


# --- contract API -----------------------------------------------------------

func set_speed(kmh: float) -> void:
	_speed_kmh = kmh
	_tacho.set_speed(kmh, Settings.units_mph)
	_update_speed_lines_target()


func set_rpm(ratio: float, gear: int) -> void:
	_tacho.set_rpm(ratio, gear)


func set_nitro(amount: float, active: bool) -> void:
	_tacho.set_nitro(amount, active)
	if active != _nitro_active:
		_nitro_active = active
		if _speed_mat:
			_speed_mat.set_shader_parameter("tint", Color(1.0, 0.55, 0.95) if active else Color(0.75, 0.95, 1.0))
		_update_speed_lines_target()


func set_run_time(ms: int) -> void:
	_timer.set_run_time(ms)


func set_best(ms: int) -> void:
	_timer.set_best(ms)


func set_checkpoints(passed: int, total: int) -> void:
	_cp_total = total
	_timer.set_checkpoints(passed, total)
	_split.set_cp_number(passed)


func show_split(ms: int, delta_ms: int, has_delta: bool) -> void:
	var col := UITheme.CYAN
	if has_delta:
		col = UITheme.GOOD if delta_ms < 0 else (UITheme.BAD if delta_ms > 0 else UITheme.TEXT)
	_split.popup("", ms, delta_ms, has_delta)
	_timer.flash(col)


func show_finish(ms: int, is_pb: bool, delta_ms: int, has_delta: bool) -> void:
	var delta_text := ""
	var delta_col := UITheme.TEXT
	if has_delta:
		delta_text = UITheme.format_delta(delta_ms)
		delta_col = UITheme.GOOD.lightened(0.25) if delta_ms < 0 else (UITheme.BAD.lightened(0.15) if delta_ms > 0 else UITheme.TEXT)
	_split.clear()
	_timer.set_run_time(ms)
	_timer.flash(UITheme.MAGENTA if is_pb else UITheme.CYAN)
	_show_banner("FINISH", 84, UITheme.MAGENTA if is_pb else UITheme.CYAN, UITheme.format_time(ms), delta_text, delta_col, 2.6)
	if is_pb:
		_show_pb()


func show_countdown(n: int) -> void:
	if _count_tween:
		_count_tween.kill()
	if n < 0:
		_count_box.visible = false
		return
	if n == 3 or n > 3:
		# A new run starts: clear leftovers from the previous one.
		_hide_banner()
		_split.clear()
	_count_box.visible = true
	_count_box.modulate.a = 1.0
	_count_box.pivot_offset = _count_box.size * 0.5
	_count_tween = create_tween()
	if n == 0:
		_count_label.text = "GO!"
		_count_label.add_theme_color_override("font_color", UITheme.LIME)
		_count_label.add_theme_color_override("font_outline_color", Color(UITheme.LIME.darkened(0.6), 0.9))
		_count_box.scale = Vector2(0.5, 0.5)
		_count_tween.tween_property(_count_box, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_count_tween.tween_interval(0.45)
		_count_tween.set_parallel(true)
		_count_tween.chain().tween_property(_count_box, "scale", Vector2(2.2, 2.2), 0.35).set_ease(Tween.EASE_IN)
		_count_tween.tween_property(_count_box, "modulate:a", 0.0, 0.35)
		_count_tween.chain().tween_callback(_count_box.hide)
	else:
		_count_label.text = str(n)
		var col: Color = [UITheme.BAD, UITheme.AMBER, UITheme.CYAN][clampi(n, 1, 3) - 1] if n <= 3 else UITheme.CYAN
		_count_label.add_theme_color_override("font_color", Color.WHITE.lerp(col, 0.35))
		_count_label.add_theme_color_override("font_outline_color", Color(col, 0.85))
		_count_box.scale = Vector2(2.4, 2.4)
		_count_box.modulate.a = 0.0
		_count_tween.set_parallel(true)
		_count_tween.tween_property(_count_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_count_tween.tween_property(_count_box, "modulate:a", 1.0, 0.15)
		_count_tween.chain().tween_interval(0.45)
		_count_tween.chain().tween_property(_count_box, "modulate:a", 0.25, 0.2)


func show_message(text: String, seconds: float = 2.0) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.text = text
	_toast_box.visible = true
	_toast_box.modulate.a = 0.0
	# Re-center after the text changed the panel width.
	_toast_box.reset_size()
	_toast_box.position.x = (_root.size.x - _toast_box.size.x) * 0.5
	_toast_box.position.y = _root.size.y * 0.7
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_box, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(maxf(0.1, seconds))
	_toast_tween.tween_property(_toast_box, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_toast_box.hide)


func set_round_time_left(ms: int) -> void:
	_timer.set_round_time_left(ms)


func set_leaderboard(entries: Array, my_id: int) -> void:
	_board.set_entries(entries, my_id)



# --- additions (documented in docs/modules/ui_hud.md) -----------------------

## Clear transient banners/pop-ups (e.g. on restart or respawn).
func clear_banners() -> void:
	_hide_banner()
	_split.clear()
	if _count_tween:
		_count_tween.kill()
	_count_box.visible = false


## Show or hide the whole HUD (e.g. hidden behind the results screen).
func set_hud_visible(v: bool) -> void:
	_root.visible = v


# --- internals --------------------------------------------------------------

func _process(delta: float) -> void:
	if InputMap.has_action("leaderboard"):
		_board.expanded = Input.is_action_pressed("leaderboard")
	# Smooth the speed lines toward their target; only touch the material when it moves.
	if absf(_lines_intensity - _lines_target) > 0.002:
		_lines_intensity = move_toward(_lines_intensity, _lines_target, delta * 1.8)
		_speed_mat.set_shader_parameter("intensity", _lines_intensity)
		_speed_lines.visible = _lines_intensity > 0.003
	if _fps.visible:
		_fps_accum += delta
		if _fps_accum >= 0.5:
			_fps_accum = 0.0
			_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _update_speed_lines_target() -> void:
	var t := 0.0
	if Settings.quality >= 2:
		t = clampf((absf(_speed_kmh) - SPEED_LINES_FROM) / (SPEED_LINES_FULL - SPEED_LINES_FROM), 0.0, 1.0)
		if _nitro_active and absf(_speed_kmh) > 120.0:
			t = minf(1.0, t + 0.35)
	_lines_target = t


func _on_settings_changed() -> void:
	_fps.visible = Settings.show_fps
	_update_speed_lines_target()
	_tacho.set_speed(_speed_kmh, Settings.units_mph)


func _build() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_speed_lines = ColorRect.new()
	_speed_lines.name = "SpeedLines"
	_speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_mat = ShaderMaterial.new()
	_speed_mat.shader = load("res://shaders/ui_speed_lines.gdshader")
	_speed_lines.material = _speed_mat
	_speed_lines.visible = false
	_root.add_child(_speed_lines)
	_root.resized.connect(_on_root_resized)

	_timer = HudTimerPanel.new()
	_timer.name = "Timer"
	_root.add_child(_timer)
	_place(_timer, Control.PRESET_CENTER_TOP, Vector2(0, 0))

	_split = HudSplitPopup.new()
	_split.name = "Split"
	_root.add_child(_split)
	_place(_split, Control.PRESET_CENTER_TOP, Vector2(0, HudTimerPanel.H + 42.0))

	_board = HudLeaderboard.new()
	_board.name = "Leaderboard"
	_root.add_child(_board)
	_place(_board, Control.PRESET_TOP_RIGHT, Vector2(-18, 18))

	_tacho = HudTachometer.new()
	_tacho.name = "Tachometer"
	_root.add_child(_tacho)
	_place(_tacho, Control.PRESET_BOTTOM_RIGHT, Vector2(-10, -6))
	_tacho.pivot_offset = _tacho.size     # shrink toward the bottom-right corner
	_tacho.scale = Vector2(TACHO_SCALE, TACHO_SCALE)

	# Center: countdown.
	_count_box = _center_box(Vector2(600, 260), Vector2(0, -60))
	_count_label = _make_label("heavy", 180, Color.WHITE)
	_count_label.add_theme_constant_override("outline_size", 22)
	_count_box.add_child(_count_label)
	_count_box.visible = false

	# Center: banner band + title + time + delta.
	_banner_box = _center_box(Vector2(1000, 230), Vector2(0, -40))
	_band = HudBannerBand.new()
	_band.set_anchors_preset(Control.PRESET_FULL_RECT)
	_band.offset_top = 22
	_band.offset_bottom = -22
	_banner_box.add_child(_band)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.add_child(vb)
	_banner_label = _make_label("heavy", 84, Color.WHITE)
	_banner_label.add_theme_constant_override("outline_size", 14)
	_banner_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vb.add_child(_banner_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	_sub_label = _make_label("num", 40, UITheme.TEXT)
	_sub_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.add_child(_sub_label)
	_delta_label = _make_label("heavy", 32, UITheme.TEXT)
	_delta_label.add_theme_constant_override("outline_size", 8)
	_delta_label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.08, 0.9))
	_delta_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.add_child(_delta_label)
	_banner_box.visible = false

	_pb_box = _center_box(Vector2(600, 90), Vector2(0, 80))
	_pb_label = _make_label("heavy", 50, UITheme.AMBER)
	_pb_label.text = "NEW PB!"
	_pb_label.add_theme_constant_override("outline_size", 12)
	_pb_label.add_theme_color_override("font_outline_color", Color(UITheme.MAGENTA, 0.9))
	_pb_box.add_child(_pb_label)
	_pb_box.visible = false

	# Toast.
	_toast_box = PanelContainer.new()
	var ts := UITheme.panel_style(Color(0.02, 0.035, 0.09, 0.88), UITheme.CYAN, 2, UITheme.SKEW)
	ts.content_margin_left = 34
	ts.content_margin_right = 34
	ts.border_width_left = 0
	ts.border_width_right = 0
	_toast_box.add_theme_stylebox_override("panel", ts)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UITheme.label("", "body_bold", 26, UITheme.TEXT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_box.add_child(_toast_label)
	_root.add_child(_toast_box)
	_toast_box.visible = false

	_fps = UITheme.label("", "num", 14, UITheme.LIME)
	_fps.position = Vector2(12, 8)
	_root.add_child(_fps)


func _place(c: Control, preset: int, offset: Vector2) -> void:
	var sz := c.size
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	c.offset_left += offset.x
	c.offset_right = c.offset_left + sz.x
	c.offset_top += offset.y
	c.offset_bottom = c.offset_top + sz.y


func _center_box(sz: Vector2, offset: Vector2) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = sz
	_root.add_child(box)
	_place(box, Control.PRESET_CENTER, offset)
	box.pivot_offset = sz * 0.5
	return box


func _make_label(kind: String, size: int, color: Color) -> Label:
	var l := UITheme.label("", kind, size, color)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


func _on_root_resized() -> void:
	if _speed_mat and _root.size.y > 0.0:
		_speed_mat.set_shader_parameter("aspect", _root.size.x / _root.size.y)


func _show_banner(title: String, size: int, color: Color, sub: String, delta_text: String, delta_col: Color, hold: float) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner_label.text = title
	_banner_label.add_theme_font_size_override("font_size", size)
	_banner_label.add_theme_color_override("font_color", Color.WHITE.lerp(color, 0.25))
	_banner_label.add_theme_color_override("font_outline_color", Color(color, 0.8))
	_sub_label.text = sub
	_sub_label.visible = sub != ""
	_delta_label.text = delta_text
	_delta_label.visible = delta_text != ""
	_delta_label.add_theme_color_override("font_color", delta_col)
	_band.color = color
	var big := sub != ""
	_band.offset_top = 10 if big else 66
	_band.offset_bottom = -10 if big else -66
	_banner_box.visible = true
	_banner_box.modulate.a = 0.0
	_banner_box.scale = Vector2(1.6, 0.4)
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.12)
	_banner_tween.tween_property(_banner_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(hold)
	_banner_tween.chain().tween_property(_banner_box, "modulate:a", 0.0, 0.35)
	_banner_tween.chain().tween_callback(_banner_box.hide)


func _hide_banner() -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner_box.visible = false
	if _pb_tween:
		_pb_tween.kill()
	_pb_box.visible = false


func _show_pb() -> void:
	if _pb_tween:
		_pb_tween.kill()
	_pb_box.visible = true
	_pb_box.modulate.a = 1.0
	_pb_box.scale = Vector2(0.2, 0.2)
	_pb_box.modulate.a = 0.0
	_pb_tween = create_tween()
	_pb_tween.tween_interval(0.25)
	_pb_tween.tween_property(_pb_box, "modulate:a", 1.0, 0.05)
	_pb_tween.tween_property(_pb_box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for i in 5:
		_pb_tween.tween_property(_pb_label, "theme_override_colors/font_color", UITheme.MAGENTA.lightened(0.3), 0.14)
		_pb_tween.tween_property(_pb_label, "theme_override_colors/font_color", UITheme.AMBER, 0.14)
	_pb_tween.tween_property(_pb_box, "modulate:a", 0.0, 0.4)
	_pb_tween.tween_callback(_pb_box.hide)
