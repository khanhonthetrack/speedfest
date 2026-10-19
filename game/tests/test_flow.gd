extends Node
## The screen flow and the wiring between them: the menu lists the circuits, the garage installs
## parts on the selected car and hands it to the race, and the race starts with that car and that
## track. Runs headless: no frames are drawn, only the node graph is exercised.

var main: Node


func _ready() -> void:
	TestHooks.args["nocity"] = "true"
	main = load("res://race/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await _menu()
	await _garage()
	await _race()
	TestHooks.finish()


func _menu() -> void:
	TestHooks.check(main.current is MainMenu, "the game opens on the menu",
		main.current.get_class() if main.current else "nothing")
	var menu: MainMenu = main.current
	TestHooks.check(TrackDefs.IDS.size() >= 2, "there is more than one circuit")
	var first := Game.track
	menu.track_index = (menu.track_index + 1) % TrackDefs.IDS.size()
	menu._refresh()
	TestHooks.check(Game.track != first, "picking a circuit changes the selection",
		"%s -> %s" % [first, Game.track])
	TestHooks.check(TrackDefs.has(Game.track), "and it is a real circuit", Game.track)


func _garage() -> void:
	main.open_garage()
	await get_tree().process_frame
	TestHooks.check(main.current is GarageScreen, "the garage opens")
	var g: GarageScreen = main.current
	TestHooks.check(g.car_id == Garage.selected, "it shows the selected car", g.car_id)
	# walk the lineup
	for id: String in CarDefs.IDS:
		g._select_car(id)
		TestHooks.check(Garage.selected == id, "the garage can switch to %s" % id)
		TestHooks.check(g._visual != null and g._visual.get_triangle_count() > 2000,
			"%s is built on the turntable" % id,
			str(g._visual.get_triangle_count() if g._visual else 0))
	# fit a part and see the specs move
	g._select_car("kaze")
	Garage.reset_all()
	var before := Tuning.resolve("kaze", Garage.setup_of("kaze"))
	g.showing_perf = true
	g.slot_index = Tuning.PERF_SLOTS.find("engine")
	g.level_index = 3
	g._install()
	var after := Tuning.resolve("kaze", Garage.setup_of("kaze"))
	TestHooks.check(float(after["accel"]) > float(before["accel"]),
		"fitting the race engine adds power", "%.2f -> %.2f" % [before["accel"], after["accel"]])
	TestHooks.check(Garage.credits < Garage.START_CREDITS, "and it costs credits", str(Garage.credits))
	# a look slot rebuilds the model
	g.showing_perf = false
	g.slot_index = Tuning.LOOK_SLOTS.find("spoiler")
	g.level_index = 3
	g._install()
	TestHooks.check(int(Garage.setup_of("kaze")["spoiler"]) == 3, "the wing is fitted")
	TestHooks.check(g._visual != null, "the model is still there after a rebuild")
	g._cycle_colour("paint", 1)
	TestHooks.check(Color.html_is_valid(String(Garage.setup_of("kaze")["paint_color"])),
		"the paint can be cycled", String(Garage.setup_of("kaze")["paint_color"]))


func _race() -> void:
	Garage.select("vector")
	Game.select_track("harbour")
	main.start_race("harbour")
	await get_tree().process_frame
	await get_tree().process_frame
	var race: Race = main.current.get_node_or_null("Race") as Race
	TestHooks.check(race != null, "the race starts")
	if race == null:
		return
	TestHooks.check(race.track_id == "harbour", "on the circuit the menu chose", race.track_id)
	TestHooks.check(race.car != null and race.car.car_id == "vector",
		"with the car the garage chose", race.car.car_id if race.car else "none")
	TestHooks.check(race.car.specs["accel"] == Tuning.resolve("vector", Garage.setup_of("vector"))["accel"],
		"and that car's tuning")
	TestHooks.check(race.rig != null and race.rig.visual != null, "the car has its model on")
	TestHooks.check(main.current.get_node_or_null("Hud") != null, "the HUD is up")
	var pause: PauseOverlay = main.current.get_node_or_null("PauseOverlay") as PauseOverlay
	TestHooks.check(pause != null, "the pause overlay is ready")
	if pause:
		pause.show_menu()
		TestHooks.check(get_tree().paused, "escape pauses the game")
		pause.close()
		TestHooks.check(not get_tree().paused, "and lets it go again")
	race.restart()
	TestHooks.check(race.lap == 1 and race.next_cp == 0, "restart puts the lap back to one")
	main.open_menu()
	await get_tree().process_frame
	TestHooks.check(main.current is MainMenu, "and the way back to the menu works")
