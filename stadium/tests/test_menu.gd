extends Node
## Menus: the main page (TMNF's order: Solo, Online, Profile, Options, Quit), Solo, the campaign
## page (a tab per series, a card per track with its record, the selected track's details, Race
## handing the track to the race scene), going back, the profile (nickname with $-codes, zone),
## online and options; TmNick's $-codes; the race's pause and finish menus. Also: picks on the
## profile keep the focus, CLEAR ALL RECORDS asks again on every visit, the race menu's panel takes
## its new content's size, no NOW PLAYING with the music off. Records go to a test folder,
## settings to a test file.

const NL := char(10)


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["menu_dry"] = "true"
	TestHooks.args["settings"] = "user://test_settings.cfg"     # never the player's own settings
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	TestHooks.args["master"] = "http://127.0.0.1:9"    # no master: the online page offers logging in
	TmRecords.clear()
	_nick()
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var names := _buttons(menu).map(func(b: Button) -> String: return b.text)
	TestHooks.check(names == ["SOLO", "ONLINE", "EDITORS", "PROFILE", "OPTIONS", "QUIT"], "menu_main_page", str(names))
	_press(menu, "SOLO")
	await get_tree().process_frame
	names = _buttons(menu).map(func(b: Button) -> String: return b.text)
	TestHooks.check(menu.page == "solo" and names == ["CAMPAIGN", "REPLAYS", "OPEN A TRACK FILE", "BACK"], "menu_solo_page", str(names))
	await _ours(menu)
	menu.back()
	await get_tree().process_frame
	TestHooks.check(menu.page == "solo", "menu_back_to_solo", menu.page)
	menu.back()
	await get_tree().process_frame
	TestHooks.check(menu.page == "main", "menu_back_to_main", menu.page)
	await _profile(menu)
	menu.show_page("online")
	await get_tree().process_frame
	names = _buttons(menu).map(func(b: Button) -> String: return b.text)
	TestHooks.check(names.has("LOG IN") and names.has("REGISTER") and names.has("SERVERS") and names.has("RANKINGS") and names.has("CONNECT")
		and names.has("BACK"), "menu_online_page", str(names))
	menu.show_page("options")
	await get_tree().process_frame
	TestHooks.check(_all(menu, []).filter(func(c: Node) -> bool: return c is CheckButton).size() >= 6, "menu_options_page")
	# CLEAR ALL RECORDS: a first press on an earlier visit doesn't arm it
	_press(menu, "CLEAR ALL RECORDS")
	menu.show_page("main")
	menu.show_page("options")
	await get_tree().process_frame
	_press(menu, "CLEAR ALL RECORDS")
	var texts := _buttons(menu).map(func(b: Button) -> String: return b.text)
	TestHooks.check(texts.has("PRESS AGAIN TO CLEAR ALL RECORDS") and not texts.has("RECORDS CLEARED"), "menu_clear_records_asks_again",
		str(texts))
	_toast()
	await _race_menu()
	TmRecords.clear()
	TestHooks.finish()


## TMNF's $-codes.
func _nick() -> void:
	TestHooks.check(TmNick.strip("$f00Red$zPlain$$") == "RedPlain$" and TmNick.strip("$oBo$iLd$l[http://x.y]link$l") == "BoLdlink"
		and TmNick.strip("$tup") == "UP" and TmNick.strip("$<$f00a$>b$") == "ab", "nick_strip",
		"%s / %s" % [TmNick.strip("$f00Red$zPlain$$"), TmNick.strip("$oBo$iLd$l[http://x.y]link$l")])
	var r := TmNick.runs("$f00R$0f0$oG$zW")
	TestHooks.check(r.size() == 3 and r[0]["colour"] == Color(1, 0, 0) and r[1]["colour"] == Color(0, 1, 0) and r[1]["bold"]
		and r[2]["colour"] == null and not r[2]["bold"], "nick_runs", str(r))
	var bb := TmNick.to_bbcode("$f00R$iI[x]")
	TestHooks.check(bb.contains("[color=#ff0000]R") and bb.contains("[i]I[lb]x]"), "nick_bbcode", bb)


func _press(menu: Node, text: String) -> void:
	for b: Button in _buttons(menu):
		if b.text == text:
			b.pressed.emit()
			return
	TestHooks.check(false, "menu_press_" + text, "no button %s" % text)


## Our own campaign: a tab per series, a card per track with its name, details, a record, Race.
func _ours(menu: TmMenu) -> void:
	var ids := TmTracks.ids()
	var series := TmTracks.series()
	TestHooks.check(not ids.is_empty() and menu.tracks == ids and menu.selected == ids[0] and not series.is_empty(), "menu_our_tracks",
		"%s" % [menu.tracks.slice(0, 3)])
	_press(menu, "CAMPAIGN")
	await get_tree().process_frame
	TestHooks.check(menu.page == "campaign", "menu_campaign_page", menu.page)
	var tabs := _buttons(menu).filter(func(b: Button) -> bool: return b.toggle_mode)
	TestHooks.check(tabs.size() == series.size() and tabs[0].text == String(series[0]["name"]).to_upper(), "menu_series_tabs",
		str(tabs.map(func(b: Button) -> String: return b.text)))
	var first: Array = series[0]["tracks"]
	var ch := TmTracks.challenge(ids[0])
	TestHooks.check(menu._tiles.size() == first.size() and _labels(menu._tiles[ids[0]]).has(ch.name), "menu_our_cards",
		"%d cards" % menu._tiles.size())
	var shown := _labels(menu)
	TestHooks.check(shown.has(ch.name) and shown.any(func(t: String) -> bool: return t.contains(TmRace.time_text(ch.gold_ms))),
		"menu_our_track_details")
	var g := TmGhost.new()
	g.finish_ms = ch.gold_ms - 10
	TmRecords.submit(ch, ch.gold_ms - 10, [], g)
	menu.show_page("campaign")
	await get_tree().process_frame
	TestHooks.check(_labels(menu._tiles[ids[0]]).has(TmRace.time_text(ch.gold_ms - 10)), "menu_card_shows_record")
	TestHooks.check(_labels(menu).has("Gold medal"), "menu_details_show_medal")
	var counts := menu.medal_counts()
	TestHooks.check(counts["gold"] == 1 and counts["finished"] == 1, "menu_medal_counts", str(counts))
	var got := []
	menu.raced.connect(func(t: String, m: String) -> void: got.append([t, m]), CONNECT_ONE_SHOT)
	menu.race(ids[0])
	TestHooks.check(got.size() == 1 and got[0][0] == ids[0] and String(TestHooks.arg("track", "")) == ids[0] and not TestHooks.has_arg("map"),
		"menu_race_hands_over_the_track")


## The profile: the nickname (saved as typed, previewed with its codes) and the zone.
func _profile(menu: TmMenu) -> void:
	_press(menu, "PROFILE")
	await get_tree().process_frame
	var edits := _all(menu, []).filter(func(c: Node) -> bool: return c is LineEdit)
	TestHooks.check(menu.page == "profile" and edits.size() == 1, "menu_profile_page", menu.page)
	if edits.is_empty():
		return
	var edit: LineEdit = edits[0]
	edit.text = "$f00Speed$fffFest"
	edit.text_changed.emit(edit.text)
	var rich := _all(menu, []).filter(func(c: Node) -> bool: return c is RichTextLabel and (c as RichTextLabel).text.contains("[color=#ff0000]Speed"))
	TestHooks.check(String(TmUi.setting("name")) == "$f00Speed$fffFest" and not rich.is_empty(), "menu_profile_nickname")
	var pick: OptionButton = _all(menu, []).filter(func(c: Node) -> bool: return c is OptionButton)[0]
	var uk := -1
	for i in pick.item_count:
		if pick.get_item_metadata(i) is String and pick.get_item_metadata(i) == "Europe|United Kingdom":
			uk = i
	pick.select(uk)
	pick.item_selected.emit(uk)
	await get_tree().process_frame
	TestHooks.check(uk > 0 and String(TmUi.setting("zone")) == "Europe|United Kingdom" and _labels(menu).has("EUROPE  ·  UNITED KINGDOM"),
		"menu_profile_zone", String(TmUi.setting("zone")))
	# a pick rebuilds the page; the focus stays on what was picked (not the nickname)
	await get_tree().process_frame
	var on_zone := get_viewport().gui_get_focus_owner() is OptionButton
	var swatches := _buttons(menu).filter(func(b: Button) -> bool: return b.custom_minimum_size == Vector2(46, 46))
	(swatches[2] as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var f := get_viewport().gui_get_focus_owner()
	TestHooks.check(on_zone and int(TmUi.setting("colour")) == 2 and f is Button and (f as Button).custom_minimum_size == Vector2(46, 46)
		and f.get_index() == 2, "menu_profile_keeps_focus", "%s, %s" % [on_zone, f])
	menu.back()
	await get_tree().process_frame


func _race_menu() -> void:
	var rm := TmRaceMenu.new()
	add_child(rm)
	var restarts := [0]
	rm.restarted.connect(func() -> void: restarts[0] += 1)
	rm.toggle_pause()
	TestHooks.check(get_tree().paused and rm.paused and _buttons(rm).size() == 3, "race_menu_pauses")
	var first_h: float = rm._panel.size.y
	rm.toggle_pause()
	TestHooks.check(not get_tree().paused and not rm.paused, "race_menu_resumes")
	rm.toggle_pause()                 # the panel again: its own size, not the old content's added
	var again_h: float = rm._panel.size.y
	rm.toggle_pause()
	TestHooks.check(absf(again_h - first_h) < 1.0, "race_menu_panel_size", "%.0f then %.0f px" % [first_h, again_h])
	rm.has_next = true
	rm.show_finish()
	await get_tree().process_frame
	var names := _buttons(rm).map(func(b: Button) -> String: return b.text)
	TestHooks.check(names == ["RETRY", "REPLAY", "SAVE REPLAY", "NEXT TRACK", "MENU"], "race_menu_finish", str(names))
	(_buttons(rm)[0] as Button).pressed.emit()
	TestHooks.check(restarts[0] == 1 and not rm.finished, "race_menu_retry")
	# the result panel: the time, the medal it earns, the record, the medal times and what's left
	rm.show_finish({"name": "Kickoff", "time_ms": 55000, "prev_ms": 56230, "record": true,
		"medals": {"author": 54440, "gold": 57800, "silver": 66000, "bronze": 82000}})
	await get_tree().process_frame
	var texts := _labels(rm)
	names = _buttons(rm).map(func(b: Button) -> String: return b.text)
	TestHooks.check(texts.has("0:55.00") and texts.has("GOLD MEDAL") and texts.has("NEW RECORD") and texts.has("-1.23")
		and texts.has("+0.56") and texts.has("0:54.44") and names == ["RETRY", "REPLAY", "SAVE REPLAY", "NEXT TRACK", "MENU"], "race_menu_result",
		"%s %s" % [texts, names])
	rm.toggle_pause()
	rm.toggle_pause()
	await get_tree().process_frame
	TestHooks.check(_labels(rm).has("GOLD MEDAL"), "race_menu_result_after_pause")
	rm.queue_free()


## The NOW PLAYING toast: shown with the music on, not with it off.
func _toast() -> void:
	var holder := Node.new()
	add_child(holder)
	Music.toast(holder)
	var l: Label = _all(holder, []).filter(func(c: Node) -> bool: return c is Label)[0]
	TmUi.set_setting("music", false)
	Music.now_playing.emit("Title", "Artist")
	var off := l.text
	TmUi.set_setting("music", true)
	Music.now_playing.emit("Title", "Artist")
	TestHooks.check(off.is_empty() and l.text.contains("NOW PLAYING"), "menu_toast_follows_music", "%s | %s" % [off, l.text])
	holder.queue_free()


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
