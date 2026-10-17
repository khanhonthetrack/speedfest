extends Node
## Menus: the main page; the campaign page with our own tracks (always) and, with a TMNF install
## (--tmnf=), its series as more tabs (a track's details from its header alone); without one, the
## way to add TMNF's tracks; Race handing the track to the race scene; the race's pause and finish
## menus. Records go to a test folder.

const NL := char(10)


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["menu_dry"] = "true"
	TmRecords.clear()
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var buttons := _buttons(menu)
	TestHooks.check(buttons.size() == 5 and buttons[0].text == "PLAY" and buttons[1].text == "ONLINE", "menu_main_page", str(buttons.map(func(b: Button) -> String: return b.text)))
	await _ours(menu)
	if menu.tmnf.is_empty():
		menu.show_page("campaign")
		await get_tree().process_frame
		var add := _buttons(menu).filter(func(b: Button) -> bool: return b.text == "+ TMNF TRACKS")
		TestHooks.check(add.size() == 1, "menu_offers_tmnf_tracks")
		(add[0] as Button).pressed.emit()
		await get_tree().process_frame
		TestHooks.check(menu.page == "notmnf" and _buttons(menu).any(func(b: Button) -> bool: return b.text == "OPEN A TRACK FILE"),
			"menu_without_tmnf_offers_a_file")
	else:
		await _tmnf(menu)
	await _race_menu()
	TmRecords.clear()
	TestHooks.finish()


## Our own campaign: the first tab, a tile per track with its name, details, a record, Race.
func _ours(menu: TmMenu) -> void:
	var ids := TmTracks.ids()
	TestHooks.check(not ids.is_empty() and menu.tracks.slice(0, ids.size()) == ids and menu.selected == ids[0], "menu_our_tracks_first",
		"%s" % [menu.tracks.slice(0, 3)])
	menu.series = 0
	menu.selected = ids[0]
	menu.show_page("campaign")
	await get_tree().process_frame
	var ch := TmTracks.challenge(ids[0])
	var tiles := _buttons(menu).filter(func(b: Button) -> bool: return b.text.contains(NL))
	TestHooks.check(tiles.size() == ids.size() and tiles[0].text.begins_with(ch.name.to_upper()), "menu_our_tiles",
		"%d tiles, %s" % [tiles.size(), tiles[0].text if not tiles.is_empty() else ""])
	var shown := _labels(menu)
	TestHooks.check(shown.has(ch.name) and shown.any(func(t: String) -> bool: return t.contains(TmRace.time_text(ch.gold_ms))),
		"menu_our_track_details")
	var g := TmGhost.new()
	g.finish_ms = ch.gold_ms - 10
	TmRecords.submit(ch, ch.gold_ms - 10, [], g)
	menu.show_page("campaign")
	await get_tree().process_frame
	TestHooks.check(_buttons(menu).any(func(b: Button) -> bool: return b.text == ch.name.to_upper() + NL + TmRace.time_text(ch.gold_ms - 10)),
		"menu_tile_shows_record")
	TestHooks.check(_labels(menu).has("Gold medal"), "menu_details_show_medal")
	var got := []
	menu.raced.connect(func(t: String, m: String) -> void: got.append([t, m]), CONNECT_ONE_SHOT)
	menu.race(ids[0])
	TestHooks.check(got.size() == 1 and got[0][0] == ids[0] and String(TestHooks.arg("track", "")) == ids[0] and not TestHooks.has_arg("map"),
		"menu_race_hands_over_the_track")


## TMNF's campaign from an install: five more tabs, read from the tracks' headers.
func _tmnf(menu: TmMenu) -> void:
	TestHooks.check(menu.tracks.size() == TmTracks.ids().size() + 65, "menu_campaign_tracks", "%d" % menu.tracks.size())
	menu.series = 2
	menu.selected = "B05"
	menu.show_page("campaign")
	await get_tree().process_frame
	var tiles := _buttons(menu).filter(func(b: Button) -> bool: return b.text.begins_with("B") and b.text.contains(NL))
	TestHooks.check(tiles.size() == 15, "menu_series_tiles", "%d" % tiles.size())
	var full := TmChallenge.load_file(TmStage.campaign_file(menu.tmnf, "B05"))
	var head := menu.header("B05")
	TestHooks.check(head.ok() and head.name == full.name and head.uid == full.uid and head.author_ms == full.author_ms
		and head.gold_ms == full.gold_ms and head.bronze_ms == full.bronze_ms and head.blocks.is_empty(), "menu_header_only_load",
		"%s %d / %s %d" % [head.name, head.author_ms, full.name, full.author_ms])
	TestHooks.check(_labels(menu).has(full.name), "menu_tmnf_track_details")


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
	# the result panel: the time, the medal it earns, the record, the medal times and what's left
	rm.show_finish({"name": "Kickoff", "time_ms": 55000, "prev_ms": 56230, "record": true,
		"medals": {"author": 54440, "gold": 57800, "silver": 66000, "bronze": 82000}})
	await get_tree().process_frame
	var texts := _labels(rm)
	names = _buttons(rm).map(func(b: Button) -> String: return b.text)
	TestHooks.check(texts.has("0:55.00") and texts.has("GOLD MEDAL") and texts.has("NEW RECORD") and texts.has("-1.23")
		and texts.has("+0.56") and texts.has("0:54.44") and names == ["RETRY", "NEXT TRACK", "MENU"], "race_menu_result",
		"%s %s" % [texts, names])
	rm.toggle_pause()
	rm.toggle_pause()
	await get_tree().process_frame
	TestHooks.check(_labels(rm).has("GOLD MEDAL"), "race_menu_result_after_pause")
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
