extends Control
## The game's entry point: menu -> garage -> race, and back. Each screen is built in code and
## thrown away when it closes, so nothing from a finished race keeps running in the background.
##
## Test args: --screen=menu|garage|race (default menu), plus everything race.gd and the garage take.

var current: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	match String(TestHooks.arg("screen", "menu")):
		"garage":
			open_garage()
		"race":
			start_race(String(TestHooks.arg("track", Game.track)))
		_:
			open_menu()


func _clear() -> void:
	if current and is_instance_valid(current):
		current.queue_free()
	current = null


func open_menu() -> void:
	_clear()
	var m := MainMenu.new()
	m.drive_requested.connect(start_race)
	m.garage_requested.connect(open_garage)
	m.quit_requested.connect(func() -> void: get_tree().quit())
	add_child(m)
	current = m


func open_garage() -> void:
	_clear()
	var g := GarageScreen.new()
	g.drive_requested.connect(func() -> void: start_race(Game.track))
	g.closed.connect(open_menu)
	add_child(g)
	current = g


func start_race(track_id: String) -> void:
	_clear()
	Game.select_track(track_id)
	var holder := Node.new()
	holder.name = "RaceSession"
	add_child(holder)
	var race := Race.new()
	race.name = "Race"
	holder.add_child(race)
	var hud := Hud.new(race)
	hud.name = "Hud"
	holder.add_child(hud)
	var pause := PauseOverlay.new()
	pause.name = "PauseOverlay"
	pause.resume_requested.connect(func() -> void: pause.close())
	pause.restart_requested.connect(func() -> void:
		pause.close()
		race.restart())
	pause.garage_requested.connect(open_garage)
	pause.menu_requested.connect(open_menu)
	holder.add_child(pause)
	current = holder
