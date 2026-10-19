class_name MainMenu
extends Control
## The front screen: the title over a slow pan of the city, the track list, and the way into the
## garage or straight onto the circuit.

signal drive_requested(track_id: String)
signal garage_requested
signal quit_requested

var track_index := 0

var _track_name: Label
var _track_blurb: Label
var _track_record: Label
var _car_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.backdrop())
	track_index = maxi(0, TrackDefs.IDS.find(Game.track))

	var left := VBoxContainer.new()
	left.position = Vector2(84, 96)
	left.add_theme_constant_override("separation", 2)
	add_child(left)
	var title := UiTheme.label("SPEEDFEST", 96, UiTheme.WHITE, true)
	left.add_child(title)
	var sub := UiTheme.label("NIGHT CITY TIME ATTACK", 24, UiTheme.MAGENTA)
	left.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 54)
	left.add_child(gap)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	left.add_child(buttons)
	var drive := UiTheme.button("DRIVE", UiTheme.LIME)
	drive.pressed.connect(func() -> void: drive_requested.emit(TrackDefs.IDS[track_index]))
	buttons.add_child(drive)
	var garage := UiTheme.button("GARAGE", UiTheme.CYAN)
	garage.pressed.connect(func() -> void: garage_requested.emit())
	buttons.add_child(garage)
	var quit := UiTheme.button("QUIT", UiTheme.DIM)
	quit.pressed.connect(func() -> void: quit_requested.emit())
	buttons.add_child(quit)

	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-520, 110)
	right.custom_minimum_size = Vector2(440, 0)
	right.add_theme_constant_override("separation", 6)
	add_child(right)
	right.add_child(UiTheme.label("CIRCUIT   [←→]", 18, UiTheme.CYAN))
	_track_name = UiTheme.label("", 44, UiTheme.WHITE, true)
	right.add_child(_track_name)
	_track_blurb = UiTheme.label("", 18, UiTheme.DIM)
	_track_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_track_blurb.custom_minimum_size = Vector2(440, 80)
	right.add_child(_track_blurb)
	_track_record = UiTheme.label("", 20, UiTheme.AMBER)
	right.add_child(_track_record)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 26)
	right.add_child(gap2)
	right.add_child(UiTheme.label("CAR", 18, UiTheme.CYAN))
	_car_label = UiTheme.label("", 30, UiTheme.WHITE, true)
	right.add_child(_car_label)

	var hint := UiTheme.label("[ENTER] drive    [G] garage    [←→] circuit    [ESC] quit", 17, UiTheme.DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(84, -48)
	add_child(hint)
	_refresh()
	drive.grab_focus()


func _refresh() -> void:
	var id := String(TrackDefs.IDS[track_index])
	var d := TrackDefs.get_def(id)
	_track_name.text = String(d["name"]).to_upper()
	_track_blurb.text = String(d["blurb"])
	var best := Game.best_lap(id)
	_track_record.text = "BEST LAP   %s" % Game.format_time(best)
	var car := Garage.selected
	_car_label.text = "%s   %s" % [CarDefs.name_of(car).to_upper(), CarDefs.get_def(car)["archetype"]]
	Game.select_track(id)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT, KEY_A:
			track_index = posmod(track_index - 1, TrackDefs.IDS.size())
			_refresh()
		KEY_RIGHT, KEY_D:
			track_index = posmod(track_index + 1, TrackDefs.IDS.size())
			_refresh()
		KEY_G:
			garage_requested.emit()
		KEY_ENTER, KEY_KP_ENTER:
			drive_requested.emit(TrackDefs.IDS[track_index])
		KEY_ESCAPE:
			quit_requested.emit()
