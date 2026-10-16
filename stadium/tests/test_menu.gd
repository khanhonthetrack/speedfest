extends Node
## Menus: the main page, the campaign page (needs a TMNF install, --tmnf=), a track's details
## from its header alone, Race handing the track to the race scene, the race's pause and finish
## menus. Records go to a test folder.


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["menu_dry"] = "true"
	TmRecords.clear()
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var buttons := _buttons(menu)
	TestHooks.check(buttons.size() == 4 and buttons[0].text == "PLAY", "menu_main_page", str(buttons.map(func(b: Button) -> String: return b.text)))
	if menu.tracks.is_empty():
		menu.show_page("campaign")
		await get_tree().process_frame
		TestHooks.check(menu.page == "campaign" and _buttons(menu).any(func(b: Button) -> bool: return b.text == "OPEN A TRACK FILE"),
			"menu_without_tmnf_offers_a_file")
	else:
		await _campaign(menu)
	await _race_menu()
	TmRecords.clear()
	TestHooks.finish()


func _campaign(menu: TmMenu) -> void:
	TestHooks.check(menu.tracks.size() == 65, "menu_campaign_tracks", "%d" % menu.tracks.size())
	menu.series = 1
	menu.selected = "B05"
	menu.show_page("campaign")
	await get_tree().process_frame
	var tiles := _buttons(menu).filter(func(b: Button) -> bool: return b.text.begins_with("B") and b.text.contains("\n"))
	TestHooks.check(tiles.size() == 15, "menu_series_tiles", "%d" % tiles.size())
	var full := TmChallenge.load_file(TmStage.campaign_file(menu.tmnf, "B05"))
	var head := menu.header("B05")
	TestHooks.check(head.ok() and head.name == full.name and head.uid == full.uid and head.author_ms == full.author_ms
		and head.gold_ms == full.gold_ms and head.bronze_ms == full.bronze_ms and head.blocks.is_empty(), "menu_header_only_load",
		"%s %d / %s %d" % [head.name, head.author_ms, full.name, full.author_ms])
	var shown := _labels(menu)
	TestHooks.check(shown.has(full.name) and shown.any(func(t: String) -> bool: return t.contains(TmRace.time_text(full.gold_ms))),
		"menu_track_details")
	# a record shows on its tile and in the details
	var g := TmGhost.new()
	g.finish_ms = full.gold_ms - 10
	TmRecords.submit(full, full.gold_ms - 10, [], g)
	menu.show_page("campaign")
	await get_tree().process_frame
	TestHooks.check(_buttons(menu).any(func(b: Button) -> bool: return b.text == "B05\n" + TmRace.time_text(full.gold_ms - 10)),
		"menu_tile_shows_record")
	TestHooks.check(_labels(menu).has("Gold medal"), "menu_details_show_medal")
	var got := []
	menu.raced.connect(func(t: String, m: String) -> void: got.append([t, m]))
	menu.race("B05")
	TestHooks.check(got.size() == 1 and got[0][0] == "B05" and String(TestHooks.arg("track", "")) == "B05" and not TestHooks.has_arg("map"),
		"menu_race_hands_over_the_track")


func _race_menu() -> void:
	var rm := TmRaceMenu.new()
	add_child(rm)
	var restarts := [0]
	rm.restarted.connect(func() -> void: restarts[0] += 1)
	rm.toggle_pause()
	TestHooks.check(get_tree().paused and rm.paused and _buttons(rm).size() == 3, "race_menu_pauses")
	rm.toggle_pause()
	TestHooks.check(not get_tree().paused and not rm.paused, "race_menu_resumes")
	rm.has_next = true
	rm.show_finish()
	await get_tree().process_frame
	var names := _buttons(rm).map(func(b: Button) -> String: return b.text)
	TestHooks.check(names == ["RETRY", "NEXT TRACK", "MENU"], "race_menu_finish", str(names))
	(_buttons(rm)[0] as Button).pressed.emit()
	TestHooks.check(restarts[0] == 1 and not rm.finished, "race_menu_retry")
	rm.queue_free()


static func _all(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
			_all(c, out)
	return out


static func _buttons(n: Node) -> Array:
	return _all(n, []).filter(func(c: Node) -> bool: return c is Button and not (c is CheckButton) and (c as Button).is_visible_in_tree())


static func _labels(n: Node) -> Array:
	return _all(n, []).filter(func(c: Node) -> bool: return c is Label).map(func(l: Label) -> String: return l.text)
