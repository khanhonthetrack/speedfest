class_name TmRaceHud
extends CanvasLayer
## Race HUD in TMNF's layout: the clock at the bottom centre, speed at the bottom right, the map
## and its medal times at the top left, checkpoints and laps at the top right, the countdown and
## checkpoint times in the middle, the result with its medal at the finish. Against the track's
## record (best): the record under the medal times, and at each checkpoint and the finish the
## difference to the record's split, blue when ahead, red when behind (as TMNF shows it).

var race: TmRace
var car: TmCar
var challenge: TmChallenge
var best := {}:                    ## the track's record {time_ms, splits}, set by the race scene
	set(v):
		best = v
		_update_info()

var _clock: Label
var _speed: Label
var _info: Label
var _times: GridContainer           ## medal and record times, two aligned columns
var _count: Label
var _centre: Label
var _delta: Label
var _flash_left := 0.0
var _centre_y := 0.0
var _delta_y := 0.0
const FINISH_LIFT := 190.0

const AHEAD := Color(0.35, 0.6, 1.0)
const BEHIND := Color(1.0, 0.3, 0.25)
const MEDAL_COLOURS := {"author": Color(0.3, 0.85, 0.45), "gold": Color(1.0, 0.82, 0.25),
	"silver": Color(0.82, 0.85, 0.9), "bronze": Color(0.85, 0.55, 0.3), "": Color.WHITE}


func _ready() -> void:
	_clock = _label(52, Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, -40), TmUi.HEAD)
	_speed = _label(40, Control.PRESET_BOTTOM_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(-40, -40), TmUi.HEAD)
	_info = _label(22, Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT, Vector2(28, 22))
	_times = GridContainer.new()
	_times.columns = 2
	_times.add_theme_constant_override("h_separation", 18)
	_times.add_theme_constant_override("v_separation", 0)
	_times.position = Vector2(28, 100)
	add_child(_times)
	_count = _label(30, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(-40, 22))
	_centre = _label(60, Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, -120), TmUi.HEAD)
	_delta = _label(40, Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, 40), TmUi.HEAD)
	_centre_y = _centre.position.y
	_delta_y = _delta.position.y
	_update_info()
	if race:
		race.checkpoint_taken.connect(_on_checkpoint)
		race.lap_done.connect(_on_lap)


func _update_info() -> void:
	if _info == null or challenge == null:
		return
	_info.text = "%s\nby %s" % [challenge.name, challenge.author]
	if _times == null:
		return
	for c in _times.get_children():
		c.queue_free()
	var rows := [["Author", challenge.author_ms, "author"], ["Gold", challenge.gold_ms, "gold"],
		["Silver", challenge.silver_ms, "silver"], ["Bronze", challenge.bronze_ms, "bronze"],
		["", -2, ""], ["Best", int(best.get("time_ms", -1)), ""]]
	for r: Array in rows:
		for col in 2:
			var l := Label.new()
			l.add_theme_font_override("font", TmUi.font(TmUi.BOLD))
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			l.add_theme_constant_override("outline_size", 4)
			l.add_theme_color_override("font_color", MEDAL_COLOURS[r[2]])
			if int(r[1]) == -2:
				l.text = " "
			else:
				l.text = String(r[0]) if col == 0 else TmRace.time_text(int(r[1]))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if col == 1 else HORIZONTAL_ALIGNMENT_LEFT
			_times.add_child(l)


func _label(size: int, preset: Control.LayoutPreset, align: HorizontalAlignment, offset: Vector2, font_key := TmUi.BOLD) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", TmUi.font(font_key))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	l.horizontal_alignment = align
	add_child(l)
	l.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH if align == HORIZONTAL_ALIGNMENT_CENTER else (
		Control.GROW_DIRECTION_BEGIN if align == HORIZONTAL_ALIGNMENT_RIGHT else Control.GROW_DIRECTION_END)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END
	l.position += offset
	return l


## Back to the start state (on restart).
func reset() -> void:
	_flash_left = 0.0
	_centre.text = ""
	_delta.text = ""
	_centre.position.y = _centre_y
	_delta.position.y = _delta_y


func _flash(text: String, colour: Color, secs: float, delta_ms := 0, has_delta := false) -> void:
	_centre.text = text
	_centre.add_theme_color_override("font_color", colour)
	_flash_left = secs
	_delta.text = delta_text(delta_ms) if has_delta else ""
	_delta.add_theme_color_override("font_color", AHEAD if delta_ms <= 0 else BEHIND)


## A difference to the record as TMNF shows it: -0.12 (ahead) or +1.05 (behind).
static func delta_text(ms: int) -> String:
	return "%s%d.%02d" % ["-" if ms <= 0 else "+", absi(ms) / 1000, (absi(ms) % 1000) / 10]


## The record's split at the split just taken (the n-th of the run), if it has one.
func _best_split(n: int) -> int:
	var s: Array = best.get("splits", [])
	return int(s[n - 1]) if n >= 1 and n <= s.size() else -1


func _on_checkpoint(count: int, time_ms: int) -> void:
	var b := _best_split(race.splits.size())
	_flash("%s\n%d / %d" % [TmRace.time_text(time_ms), count, race.checkpoint_count], Color.WHITE, 2.5, time_ms - b, b >= 0)


func _on_lap(lap: int, time_ms: int) -> void:
	var b := _best_split(race.splits.size())
	_flash("%s\nLap %d / %d" % [TmRace.time_text(time_ms), lap + 1, race.laps], Color.WHITE, 2.5, time_ms - b, b >= 0)


## The finish: the time, its medal, the difference to the record before this run (prev) and
## whether it is a new record.
func show_finish(time_ms: int, prev: Dictionary, record: bool) -> void:
	var m := TmRace.medal(time_ms, challenge) if challenge else ""
	var line := ("%s medal" % m.capitalize()) if not m.is_empty() else "Finished"
	if record:
		line += "\nNew record!"
	var b := int(prev.get("time_ms", -1))
	_flash("%s\n%s" % [TmRace.time_text(time_ms), line], MEDAL_COLOURS[m], 1e9, time_ms - b, b >= 0)
	# the result high up, clear of the car and of the finish menu below it
	_centre.position.y = _centre_y - FINISH_LIFT
	_delta.position.y = _delta_y - FINISH_LIFT + 40.0


func _process(delta: float) -> void:
	if race == null:
		return
	_clock.text = TmRace.time_text(race.time_ms)
	if car:
		_speed.text = "%d" % roundi(absf(car.speed_kmh()))
	var lines := []
	if race.checkpoint_count > 0:
		lines.append("%d / %d" % [race.taken.size(), race.checkpoint_count])
	if race.laps > 1:
		lines.append("Lap %d / %d" % [mini(race.lap + 1, race.laps), race.laps])
	_count.text = "\n".join(lines)
	if race.state == TmRace.State.COUNTDOWN:
		_centre.add_theme_color_override("font_color", Color.WHITE)
		_centre.text = str(ceili(race.countdown_ms / 500.0))
		_flash_left = 0.0
	elif _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_centre.text = ""
			_delta.text = ""
	elif race.state == TmRace.State.RACING and race.time_ms < 800:
		_centre.add_theme_color_override("font_color", Color.WHITE)
		_centre.text = "Go!"
	elif race.state == TmRace.State.RACING:
		_centre.text = ""
