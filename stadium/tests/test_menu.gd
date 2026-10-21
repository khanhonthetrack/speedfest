extends Node
## Menus (our own look, PLAN M16): the header's tabs (Home, Solo, Multiplayer, Story locked,
## Community, Editor; you, options, quit), the home page's picture panels (Solo, Multiplayer;
## Story locked: it only says so; Community, Track editor, Replays), Solo (a row per series, a card
## per track with your medal, the focused track's details, a card's press handing the track to the
## race scene), going back, the profile (nickname with $-codes, zone), online and options; TmNick's
## $-codes; the race's pause and finish menus. Also: picks on the profile keep the focus, Clear all
## records asks again on every visit, the race menu's panel takes its new content's size, no NOW
## PLAYING with the music off. Records go to a test folder, settings to a test file.

const NL := char(10)


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["menu_dry"] = "true"
	TestHooks.args["settings"] = "user://test_settings.cfg"     # never the player's own settings
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	TestHooks.args["master"] = "http://127.0.0.1:9"    # no master: the online page offers logging in
	TestHooks.args["community"] = "http://127.0.0.1:9"  # nor TMX / ManiaPark (the Community page opens)
	TestHooks.args["community_dir"] = "user://test_community_menu"
	TmRecords.clear()
	_nick()
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	await _home(menu)
	(menu.home_tiles["solo"] as SfTile).pressed.emit()
	await get_tree().process_frame
	var names := _buttons(menu).map(_name).filter(func(t: String) -> bool: return not t.is_empty())
	var rows: Array = TmTracks.series().map(func(x: Dictionary) -> String: return String(x["name"])) + ["Replays", "Browse", "Back"]
	TestHooks.check(menu.page == "solo" and names == rows, "menu_solo_page", str(names))
	await _ours(menu)
	menu.back()
	await get_tree().process_frame
	TestHooks.check(menu.page == "main", "menu_back_to_main", menu.page)
	await _profile(menu)
	menu.show_page("online")
	await get_tree().process_frame
	names = _buttons(menu).map(_name)
	TestHooks.check(names.has("Log in") and names.has("Register") and names.has("Servers") and names.has("Rankings") and names.has("Connect")
		and names.has("Back"), "menu_online_page", str(names))
	menu.show_page("options")
	await get_tree().process_frame
	TestHooks.check(_all(menu, []).filter(func(c: Node) -> bool: return c is CheckButton).size() >= 6, "menu_options_page")
	# Clear all records: a first press on an earlier visit doesn't arm it
	_press(menu, "Clear all records")
	menu.show_page("main")
	menu.show_page("options")
	await get_tree().process_frame
	_press(menu, "Clear all records")
	var texts := _buttons(menu).map(func(b: Button) -> String: return b.text)
	TestHooks.check(texts.has("Press again to clear all records") and not texts.has("Records cleared"), "menu_clear_records_asks_again",
		str(texts))
	_toast()
	await _loading()
	await _race_menu()
	TmRecords.clear()
	TestHooks.finish()


## The header's tabs and the home page's panels: Story is locked (its panel and tab only say so and
## stay home), the others open their pages.
func _home(menu: TmMenu) -> void:
	var tabs: Array = menu.nav.tabs.keys()
	TestHooks.check(tabs.slice(0, 6) == ["main", "solo", "online", "story", "community", "editors"] and tabs.has("profile")
		and tabs.has("options") and menu.nav.current == "main", "menu_header_tabs", str(tabs))
	var tiles: Array = menu.home_tiles.keys()
	TestHooks.check(menu.page == "main" and tiles == ["solo", "online", "story", "community", "editors", "replays"]
		and (menu.home_tiles["story"] as SfTile).locked and not (menu.home_tiles["solo"] as SfTile).locked, "menu_home_panels", str(tiles))
	(menu.home_tiles["story"] as SfTile).pressed.emit()
	(menu.nav.tabs["story"] as Button).pressed.emit()
	await get_tree().process_frame
	var notes := _all(menu, []).filter(func(c: Node) -> bool: return String(c.name).begins_with("Notice"))
	TestHooks.check(menu.page == "main" and notes.size() == 2 and _labels(notes[0]).has(TmMenu.LOCKED_NOTE), "menu_story_locked",
		"%s, %d notices" % [menu.page, notes.size()])
	for to: String in ["online", "community", "editors", "replays"]:
		(menu.home_tiles[to] as SfTile).pressed.emit()
		await get_tree().process_frame
		TestHooks.check(menu.page == to and menu.nav.current == ("solo" if to == "replays" else to), "menu_home_opens_" + to,
			"%s, tab %s" % [menu.page, menu.nav.current])
		(menu.nav.tabs["main"] as Button).pressed.emit()
		await get_tree().process_frame
	(menu.nav.tabs["options"] as Button).pressed.emit()
	TestHooks.check(menu.page == "options" and menu.nav.current == "options", "menu_header_options", menu.page)
	menu.nav.back_pressed.emit()
	await get_tree().process_frame
	TestHooks.check(menu.page == "main", "menu_header_back", menu.page)


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
		if _name(b) == text:
			b.pressed.emit()
			return
	TestHooks.check(false, "menu_press_" + text, "no button %s" % text)


## Our own campaign on the Solo page: a row per series, a card per track with its name and your
## medal, the focused track's details with your record, a race handed over.
func _ours(menu: TmMenu) -> void:
	var ids := TmTracks.ids()
	var series := TmTracks.series()
	TestHooks.check(not ids.is_empty() and menu.tracks == ids and menu.selected == ids[0] and not series.is_empty(), "menu_our_tracks",
		"%s" % [menu.tracks.slice(0, 3)])
	menu.show_page("campaign")       # TMNF's campaign is the Solo page
	await get_tree().process_frame
	TestHooks.check(menu.page == "solo", "menu_campaign_page", menu.page)
	var names: Array = series.map(func(x: Dictionary) -> String: return String(x["name"]))
	var tabs := _buttons(menu).filter(func(b: Button) -> bool: return names.has(_name(b)))
	TestHooks.check(tabs.size() == series.size() and _name(tabs[0]) == String(series[0]["name"]), "menu_series_rows",
		str(tabs.map(_name)))
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
	var gold := TmUi.icon("medal_gold")
	TestHooks.check(_all(menu._tiles[ids[0]], []).any(func(c: Node) -> bool: return c is TextureRect and (c as TextureRect).texture == gold)
		and _labels(menu).has(TmRace.time_text(ch.gold_ms - 10)), "menu_card_shows_record")
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
	(menu.nav.tabs["profile"] as Button).pressed.emit()     # you, at the header's right
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
	TestHooks.check(uk > 0 and String(TmUi.setting("zone")) == "Europe|United Kingdom" and _labels(menu.nav).has("UNITED KINGDOM"),
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
	TestHooks.check(names == ["Retry", "Replay", "Save replay", "Next track", "Quit"], "race_menu_finish", str(names))
	(_buttons(rm)[0] as Button).pressed.emit()
	TestHooks.check(restarts[0] == 1 and not rm.finished, "race_menu_retry")
	# the result panel: the time, the medal it earns, the record, the medal times and what's left
	rm.show_finish({"name": "Kickoff", "time_ms": 55000, "prev_ms": 56230, "record": true,
		"medals": {"author": 54440, "gold": 57800, "silver": 66000, "bronze": 82000}})
	await get_tree().process_frame
	var texts := _labels(rm)
	names = _buttons(rm).map(func(b: Button) -> String: return b.text)
	TestHooks.check(texts.has("0:55.00") and texts.has("Gold medal") and texts.has("New record") and texts.has("-1.23")
		and texts.has("+0.56") and texts.has("0:54.44") and names == ["Retry", "Replay", "Save replay", "Next track", "Quit"], "race_menu_result",
		"%s %s" % [texts, names])
	rm.toggle_pause()
	rm.toggle_pause()
	await get_tree().process_frame
	TestHooks.check(_labels(rm).has("Gold medal"), "race_menu_result_after_pause")
	rm.queue_free()


## The loading screen: TMNF's keyboard with the race's keys lit, each label pointing at a lit key;
## it covers the screen (the race holds its countdown) until it has faded out.
func _loading() -> void:
	var lit := TmLoading.keys().filter(func(k: Array) -> bool: return k[1]).map(func(k: Array) -> String: return String(k[2]))
	lit.sort()
	var want := ["1", "2", "3", "Back", "Del", "Down", "Enter", "Esc", "Left", "Right", "Up"]
	TestHooks.check(lit == want and TmLoading._labels().all(func(l: Array) -> bool: return lit.has(String(l[2]))), "loading_keys", str(lit))
	TestHooks.check(not TmLoading.covering(), "loading_none")
	var l := TmLoading.new()
	add_child(l)
	TestHooks.check(TmLoading.covering() and _labels(l).has("RESPAWN") and _labels(l).has("CHANGE VIEW"), "loading_covers")
	l.queue_free()
	await get_tree().process_frame
	TestHooks.check(not TmLoading.covering(), "loading_gone")


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


## A page's buttons (not the header's), visible.
static func _buttons(n: Node) -> Array:
	return _all(n, []).filter(func(c: Node) -> bool: return c is Button and not (c is CheckButton) and (c as Button).is_visible_in_tree()).filter(
		func(c: Node) -> bool: return not _in_header(c))


static func _in_header(c: Node) -> bool:
	while c != null:
		if c is SfHeader:
			return true
		c = c.get_parent()
	return false


## A button's name: a column row's as written (its text is in capitals), else its text.
static func _name(b: Button) -> String:
	return String(b.get_meta("name", b.text))


static func _labels(n: Node) -> Array:
	return _all(n, []).filter(func(c: Node) -> bool: return c is Label or c is TmSegText).map(func(l: Control) -> String: return String(l.get("text")))
