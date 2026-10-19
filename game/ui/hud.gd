class_name Hud
extends CanvasLayer
## The in-race display: speed, boost, lap and split times, position on the lap, and the countdown.
## It reads a Race node every frame and never touches the simulation.

const SPLIT_HOLD := 2.4

var race: Race

var _speed: Label
var _speed_unit: Label
var _gear: Label
var _boost_fill: ColorRect
var _boost_glow: ColorRect
var _boost_label: Label
var _time: Label
var _best: Label
var _lap: Label
var _split: Label
var _split_t := 0.0
var _count: Label
var _map: Control
var _map_pts: PackedVector2Array
var _msg: Label
var _msg_t := 0.0
var _fps: Label


func _init(p_race: Race = null) -> void:
	race = p_race
	layer = 10


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- speed, bottom right ---
	var speed_box := VBoxContainer.new()
	speed_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_box.position = Vector2(-300, -170)
	speed_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(speed_box)
	_speed = UiTheme.label("0", 92, UiTheme.WHITE, true)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed.custom_minimum_size = Vector2(280, 0)
	speed_box.add_child(_speed)
	_speed_unit = UiTheme.label("KM/H", 22, UiTheme.CYAN)
	_speed_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_unit.custom_minimum_size = Vector2(280, 0)
	speed_box.add_child(_speed_unit)

	# --- boost meter, bottom centre-right ---
	var boost := Control.new()
	boost.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	boost.position = Vector2(-300, -56)
	boost.custom_minimum_size = Vector2(280, 22)
	root.add_child(boost)
	var track := ColorRect.new()
	track.size = Vector2(272, 16)
	track.color = Color(0.08, 0.09, 0.12, 0.85)
	boost.add_child(track)
	_boost_glow = ColorRect.new()
	_boost_glow.size = Vector2(0, 16)
	_boost_glow.color = Color(UiTheme.MAGENTA.r, UiTheme.MAGENTA.g, UiTheme.MAGENTA.b, 0.35)
	boost.add_child(_boost_glow)
	_boost_fill = ColorRect.new()
	_boost_fill.position = Vector2(2, 2)
	_boost_fill.size = Vector2(0, 12)
	_boost_fill.color = UiTheme.CYAN
	boost.add_child(_boost_fill)
	_boost_label = UiTheme.label("NOS", 16, UiTheme.DIM)
	_boost_label.position = Vector2(-44, -2)
	boost.add_child(_boost_label)
	_gear = UiTheme.label("", 20, UiTheme.AMBER)
	_gear.position = Vector2(0, 22)
	boost.add_child(_gear)

	# --- timing, top left ---
	var times := VBoxContainer.new()
	times.position = Vector2(34, 26)
	root.add_child(times)
	_time = UiTheme.label("0:00.000", 46, UiTheme.WHITE, true)
	times.add_child(_time)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 18)
	times.add_child(sub)
	_lap = UiTheme.label("LAP 1/3", 20, UiTheme.CYAN)
	sub.add_child(_lap)
	_best = UiTheme.label("BEST --:--.---", 20, UiTheme.DIM)
	sub.add_child(_best)
	_split = UiTheme.label("", 30, UiTheme.LIME)
	_split.position = Vector2(34, 110)
	root.add_child(_split)

	# --- centre messages and the countdown ---
	_count = UiTheme.label("", 150, UiTheme.WHITE, true)
	_count.set_anchors_preset(Control.PRESET_CENTER)
	_count.position = Vector2(-80, -220)
	root.add_child(_count)
	_msg = UiTheme.label("", 40, UiTheme.MAGENTA, true)
	_msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg.position = Vector2(-320, 170)
	_msg.custom_minimum_size = Vector2(640, 0)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_msg)

	# --- lap map, top right ---
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_map.position = Vector2(-230, 28)
	_map.custom_minimum_size = Vector2(200, 160)
	_map.draw.connect(_draw_map)
	root.add_child(_map)

	_fps = UiTheme.label("", 16, UiTheme.DIM)
	_fps.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps.position = Vector2(34, -30)
	root.add_child(_fps)

	if race:
		race.checkpoint_passed.connect(_on_checkpoint)
		race.lap_done.connect(_on_lap)
		race.race_done.connect(_on_race_done)
		_bake_map()


## Sample the track into screen points once, for the little lap map.
func _bake_map() -> void:
	if race == null or race.path == null:
		return
	var n := 160
	var raw: PackedVector2Array = PackedVector2Array()
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in n + 1:
		var p := race.path.sample_position(race.path.length * float(i) / float(n))
		var q := Vector2(p.x, p.z)
		raw.append(q)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var span := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 1.0)
	var size := 180.0
	_map_pts = PackedVector2Array()
	for q in raw:
		_map_pts.append((q - lo) / span * size + Vector2(10, 10))


func _draw_map() -> void:
	if _map_pts.size() < 2:
		return
	_map.draw_polyline(_map_pts, Color(0.35, 0.40, 0.52, 0.65), 3.0, true)
	if race:
		var idx := int(race.progress_ratio() * float(_map_pts.size() - 1))
		_map.draw_circle(_map_pts[clampi(idx, 0, _map_pts.size() - 1)], 5.0, UiTheme.CYAN)
		_map.draw_circle(_map_pts[0], 4.0, UiTheme.LIME)


func _process(delta: float) -> void:
	if race == null or race.car == null:
		return
	var kmh := absf(race.car.speed_kmh())
	if Settings.units_mph:
		_speed.text = "%d" % roundi(kmh * 0.621371)
		_speed_unit.text = "MPH"
	else:
		_speed.text = "%d" % roundi(kmh)
		_speed_unit.text = "KM/H"
	var top := race.car.top_speed_kmh()
	_speed.add_theme_color_override("font_color", UiTheme.MAGENTA if kmh > top - 12.0 else UiTheme.WHITE)

	var m := race.car.boost_meter
	_boost_fill.size.x = 268.0 * m
	_boost_fill.color = UiTheme.MAGENTA if race.car.boosting else UiTheme.CYAN.lerp(UiTheme.LIME, m)
	_boost_glow.size.x = _boost_fill.size.x + 4.0
	_boost_glow.color.a = 0.5 if race.car.boosting else 0.18
	_boost_label.add_theme_color_override("font_color", UiTheme.MAGENTA if race.car.boosting else UiTheme.DIM)
	_boost_label.text = "NOS" if race.car.boost_tank > 0.0 else "NO NOS"
	_gear.text = "BOOST" if race.car.boosting else ""

	_time.text = Game.format_time(race.elapsed_ms())
	_lap.text = "LAP %d/%d" % [race.lap, race.laps]
	var pb := Game.best_lap(race.track_id, race.car.car_id)
	_best.text = "BEST %s" % Game.format_time(pb)
	if race.countdown_ms > 0 and not race.started:
		var n := race.countdown_number()
		_count.text = str(n) if n > 0 else "GO"
		_count.add_theme_color_override("font_color", UiTheme.LIME if n == 0 else UiTheme.WHITE)
	else:
		_count.text = ""
	if _split_t > 0.0:
		_split_t -= delta
		if _split_t <= 0.0:
			_split.text = ""
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	if Settings.show_fps:
		_fps.text = "%d fps   %s" % [Engine.get_frames_per_second(), Settings.render_status()]
	_map.queue_redraw()


func _on_checkpoint(index: int, time_ms: int) -> void:
	var pb := Game.best_lap(race.track_id, race.car.car_id)
	_split.text = "CP %d   %s" % [index + 1, Game.format_time(time_ms)]
	_split.add_theme_color_override("font_color", UiTheme.LIME if pb == 0 else UiTheme.CYAN)
	_split_t = SPLIT_HOLD


func _on_lap(lap_index: int, time_ms: int, best: bool) -> void:
	_split.text = "LAP %d   %s%s" % [lap_index, Game.format_time(time_ms), "   NEW BEST" if best else ""]
	_split.add_theme_color_override("font_color", UiTheme.MAGENTA if best else UiTheme.WHITE)
	_split_t = SPLIT_HOLD


func _on_race_done(total: int) -> void:
	_msg.text = "FINISH   %s" % Game.format_time(total)
	_msg_t = 8.0
