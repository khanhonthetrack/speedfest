class_name TmRaceHud
extends CanvasLayer
## Race HUD in TMNF's layout: the clock at the bottom centre, speed at the bottom right, the map
## and its medal times at the top left, checkpoints and laps at the top right, the countdown and
## checkpoint times in the middle, the result with its medal at the finish.

var race: TmRace
var car: TmCar
var challenge: TmChallenge

var _clock: Label
var _speed: Label
var _info: Label
var _count: Label
var _centre: Label
var _flash_left := 0.0

const MEDAL_COLOURS := {"author": Color(0.3, 0.85, 0.45), "gold": Color(1.0, 0.82, 0.25),
	"silver": Color(0.82, 0.85, 0.9), "bronze": Color(0.85, 0.55, 0.3), "": Color.WHITE}


func _ready() -> void:
	_clock = _label(56, Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, -40))
	_speed = _label(40, Control.PRESET_BOTTOM_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(-40, -40))
	_info = _label(22, Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT, Vector2(28, 22))
	_count = _label(30, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(-40, 22))
	_centre = _label(64, Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER, Vector2(0, -120))
	if challenge:
		_info.text = "%s\nby %s\n\nAuthor  %s\nGold    %s\nSilver  %s\nBronze  %s" % [challenge.name,
			challenge.author, TmRace.time_text(challenge.author_ms), TmRace.time_text(challenge.gold_ms),
			TmRace.time_text(challenge.silver_ms), TmRace.time_text(challenge.bronze_ms)]
	if race:
		race.checkpoint_taken.connect(_on_checkpoint)
		race.lap_done.connect(_on_lap)
		race.finished.connect(_on_finished)


func _label(size: int, preset: Control.LayoutPreset, align: HorizontalAlignment, offset: Vector2) -> Label:
	var l := Label.new()
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


func _flash(text: String, colour: Color, secs: float) -> void:
	_centre.text = text
	_centre.add_theme_color_override("font_color", colour)
	_flash_left = secs


func _on_checkpoint(count: int, time_ms: int) -> void:
	_flash("%s\n%d / %d" % [TmRace.time_text(time_ms), count, race.checkpoint_count], Color.WHITE, 2.5)


func _on_lap(lap: int, time_ms: int) -> void:
	_flash("%s\nLap %d / %d" % [TmRace.time_text(time_ms), lap + 1, race.laps], Color.WHITE, 2.5)


func _on_finished(time_ms: int) -> void:
	var m := TmRace.medal(time_ms, challenge) if challenge else ""
	var line := ("%s medal" % m.capitalize()) if not m.is_empty() else "Finished"
	_flash("%s\n%s" % [TmRace.time_text(time_ms), line], MEDAL_COLOURS[m], 1e9)


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
	elif race.state == TmRace.State.RACING and race.time_ms < 800:
		_centre.add_theme_color_override("font_color", Color.WHITE)
		_centre.text = "Go!"
	elif race.state == TmRace.State.RACING:
		_centre.text = ""
