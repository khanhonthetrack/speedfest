extends Node
## Headless: keyboard navigation works on the main menu, track select and garage.


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _ready() -> void:
	var menu: Control = load("res://ui/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 3:
		await get_tree().process_frame
	TestHooks.check(_focus() == menu.buttons[0], "nav_menu_initial_focus", str(_focus()))
	await _press("ui_down")
	TestHooks.check(_focus() == menu.buttons[1], "nav_menu_down", str(_focus()))
	menu.queue_free()
	await get_tree().process_frame

	var ts: Control = load("res://ui/track_select.tscn").instantiate()
	add_child(ts)
	for i in 3:
		await get_tree().process_frame
	var start: Control = _focus()
	TestHooks.check(start in ts.cards, "nav_tracks_initial_focus")
	await _press("ui_right")
	TestHooks.check(_focus() in ts.cards and _focus() != start, "nav_tracks_right")
	TestHooks.check(Game.track_id == TrackDefs.IDS[ts.cards.find(_focus())], "nav_tracks_sets_track_id")
	ts.queue_free()
	await get_tree().process_frame

	var g: Control = load("res://ui/garage.tscn").instantiate()
	add_child(g)
	for i in 3:
		await get_tree().process_frame
	var f0 := _focus()
	TestHooks.check(f0 != null and g.tabs.get_current_tab_control().is_ancestor_of(f0), "nav_garage_initial_focus", str(f0))
	await _key(KEY_E)
	TestHooks.check(g.tabs.current_tab == 1, "nav_garage_tab_key")
	var car_before: String = g.car_id
	await _key(KEY_X)
	TestHooks.check(g.car_id != car_before, "nav_garage_car_key")
	g.select_car(car_before)
	TestHooks.finish()
