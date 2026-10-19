extends Node
## The track editor: roads join their neighbours (dead end, straight, corner, T, cross), the
## editor's rules (cells taken, the map's edge, one start, erase, undo, redo, what a track lacks),
## the .sftrack file (save, load, list, names), the track as a TmChallenge (ground variants,
## pillars under raised road, laps, a uid per layout), validation (a test drive's finish sets the
## medals; an edit clears them); then a straight track driven to the finish in the race scene
## from the editor validates its file, and the editor scene loads it, shows its blocks, places,
## undoes and saves. Tracks and records go to test folders.

const DIR := "user://test_tracks"
const ROAD := "StadiumRoadMain"


func _ready() -> void:
	TestHooks.args["tracks_dir"] = DIR
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["replays"] = "user://test_replays"
	TmRecords.clear()
	TmReplay.clear()
	_clear_tracks()
	_roads()
	_rules()
	var path := _files()
	_challenge()
	if not path.is_empty():
		await _drive(path)
		await _editor(path)
		await _menu(path)
	_clear_tracks()
	TmRecords.clear()
	TmReplay.clear()
	TestHooks.finish()


func _clear_tracks() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


## The variant a road block takes among the blocks at cells (all roads): {flags, dir}.
static func _variant(at: Vector3i, roads: Array) -> Dictionary:
	var occ := {}
	for c: Vector3i in roads:
		occ[c] = {"id": ROAD, "dir": 0, "coord": c}
	return TmUserTracks.road_variant(ROAD, at, func(c: Vector3i) -> Dictionary: return occ.get(c, {}))


func _roads() -> void:
	var o := Vector3i(10, 1, 10)
	var x := Vector3i(1, 0, 0)
	var z := Vector3i(0, 0, 1)
	var alone := _variant(o, [o])
	var end := _variant(o, [o, o + z])
	var straight_z := _variant(o, [o - z, o, o + z])
	var straight_x := _variant(o, [o - x, o, o + x])
	var corner := _variant(o, [o, o + z, o + x])
	var tee := _variant(o, [o, o + z, o - z, o + x])
	var cross := _variant(o, [o, o + z, o - z, o + x, o - x])
	TestHooks.check(alone["flags"] == 0 and end["flags"] == 1 and end["dir"] == 0 and straight_z["flags"] == 3
		and straight_z["dir"] % 2 == 0 and straight_x["flags"] == 3 and straight_x["dir"] % 2 == 1 and corner["flags"] == 2
		and tee["flags"] == 4 and cross["flags"] == 5, "editor_roads_join",
		"%s %s %s %s %s %s %s" % [alone, end, straight_z, straight_x, corner, tee, cross])
	# a checkpoint along z opens a road's side towards it; one across doesn't (its clips face z)
	var occ := {o + z: {"id": "StadiumRoadMainCheckpoint", "dir": 0, "coord": o + z}, o: {"id": ROAD, "dir": 0, "coord": o}}
	var v := TmUserTracks.road_variant(ROAD, o, func(c: Vector3i) -> Dictionary: return occ.get(c, {}))
	occ[o + z] = {"id": "StadiumRoadMainCheckpoint", "dir": 1, "coord": o + z}
	var w := TmUserTracks.road_variant(ROAD, o, func(c: Vector3i) -> Dictionary: return occ.get(c, {}))
	TestHooks.check(v["flags"] == 1 and w["flags"] == 0, "editor_roads_meet_clips", "%s %s" % [v, w])


func _rules() -> void:
	var m := TmEditorModel.new(TmUserTracks.blank("Rules"))
	var ok := m.place("StadiumRoadMainStartLine", 0, Vector3i(16, 1, 2))
	TestHooks.check(ok and m.why_not("StadiumRoadMainStartLine", 0, Vector3i(10, 1, 10)) == "a track has one start", "editor_one_start")
	TestHooks.check(m.why_not(ROAD, 0, Vector3i(16, 1, 2)) == "the space is taken" and m.why_not(ROAD, 0, Vector3i(16, 2, 2)) == "the space is taken",
		"editor_cells_taken")
	TestHooks.check(m.why_not(ROAD, 0, Vector3i(32, 1, 4)) == "outside the stadium" and m.why_not(ROAD, 0, Vector3i(3, 0, 4)) == "outside the stadium"
		and m.why_not("StadiumRoadMainGTCurve2", 0, Vector3i(31, 1, 31)) == "outside the stadium", "editor_map_edge")
	TestHooks.check(m.missing() == "Place a finish", "editor_needs_a_finish", m.missing())
	m.place(ROAD, 0, Vector3i(16, 1, 3))
	m.place("StadiumRoadMainFinishLine", 0, Vector3i(16, 1, 4))
	TestHooks.check(m.missing() == "" and m.track["blocks"].size() == 3, "editor_track_complete")
	m.erase_at(Vector3i(16, 2, 4))   # the finish's arch cell
	TestHooks.check(m.track["blocks"].size() == 2 and m.block_at(Vector3i(16, 1, 4)).is_empty() and m.missing() == "Place a finish", "editor_erase")
	m.undo()
	TestHooks.check(m.track["blocks"].size() == 3 and not m.block_at(Vector3i(16, 1, 4)).is_empty(), "editor_undo")
	m.redo()
	TestHooks.check(m.track["blocks"].size() == 2 and m.block_at(Vector3i(16, 1, 4)).is_empty() and not m.can_redo(), "editor_redo")
	# ground-only blocks spanning several cells turn inside their own box (as the builder places them)
	var box_ok := true
	for d in 4:
		var cs := TmUserTracks.cells("StadiumRoadDirtGTCurve2", d, Vector3i(10, 1, 10))
		var lo := Vector2i(999, 999)
		for c in cs:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.z))
		box_ok = box_ok and cs.size() == 5 and lo == Vector2i(10, 10)
	TestHooks.check(box_ok, "editor_ground_blocks_turn_in_place")
	TestHooks.check(m.why_not("StadiumRoadDirtGTCurve2", 0, Vector3i(10, 3, 10)) == "this block stands on the ground only"
		and m.why_not("StadiumSculptBridgeSuspendSlope2", 0, Vector3i(10, 1, 10)).is_empty(), "editor_ground_only_and_tall_blocks",
		m.why_not("StadiumSculptBridgeSuspendSlope2", 0, Vector3i(10, 1, 10)))
	var lap := TmEditorModel.new(TmUserTracks.blank("Lap"))
	lap.place("StadiumRoadMainStartFinishLine", 0, Vector3i(5, 1, 5))
	var lap_lack := lap.missing()
	lap.place("StadiumRoadMainCheckpoint", 0, Vector3i(5, 1, 7))
	TestHooks.check(lap_lack.begins_with("Place a checkpoint") and lap.missing().is_empty(), "editor_lap_needs_a_checkpoint", lap_lack)
	var t := TmEditorModel.anchor("StadiumRoadMainGTCurve2", 1, Vector3i(5, 1, 5))
	var cells := TmUserTracks.cells("StadiumRoadMainGTCurve2", 1, t)
	TestHooks.check(cells.has(Vector3i(5, 1, 5)) and cells.size() == 4, "editor_anchor_on_cursor", "%s %s" % [t, cells])


## The straight test track: start, road, a checkpoint, road, finish, along +z on the ground.
static func straight_track() -> Dictionary:
	var t := TmUserTracks.blank("Straight Test")
	t["blocks"] = [["StadiumRoadMainStartLine", 0, 16, 1, 2], [ROAD, 0, 16, 1, 3], [ROAD, 0, 16, 1, 4],
		["StadiumRoadMainCheckpoint", 0, 16, 1, 5], [ROAD, 0, 16, 1, 6], ["StadiumRoadMainFinishLine", 0, 16, 1, 7],
		[ROAD, 0, 20, 4, 10], [ROAD, 0, 20, 4, 11]]   # and a raised piece (pillars)
	return t


func _files() -> String:
	var t := straight_track()
	var path := TmUserTracks.path_for(t)
	TestHooks.check(TmUserTracks.save(t, path) and path == DIR.path_join("Straight Test.sftrack"), "editor_save", path)
	var back := TmUserTracks.load_file(path)
	TestHooks.check(back.get("blocks", []).size() == 8 and String(back["id"]) == String(t["id"]) and TmUserTracks.layout(back) == TmUserTracks.layout(t),
		"editor_load")
	var other := TmUserTracks.blank("Straight Test")
	TestHooks.check(TmUserTracks.path_for(other) == DIR.path_join("Straight Test 2.sftrack") and TmUserTracks.path_for(back) == path,
		"editor_names_dont_clash", TmUserTracks.path_for(other))
	var all := TmUserTracks.list()
	TestHooks.check(all.size() == 1 and String(all[0]["path"]) == path, "editor_list")
	var odd := TmUserTracks.blank("#1 Track")
	TestHooks.check(not TmUserTracks.path_for(odd).get_file().begins_with("_"), "editor_names_listed", TmUserTracks.path_for(odd))
	return path


func _challenge() -> void:
	var t := straight_track()
	var ch := TmUserTracks.challenge(t)
	var names := {}
	for b: Dictionary in ch.blocks:
		names[b["name"]] = int(names.get(b["name"], 0)) + 1
	var ground_ok := true
	for b: Dictionary in ch.blocks:
		var c: Vector3i = b["coord"]
		ground_ok = ground_ok and bool(b["ground"]) == (c.y == 1)
	var road: Dictionary = ch.blocks.filter(func(b: Dictionary) -> bool: return b["name"] == ROAD and (b["coord"] as Vector3i) == Vector3i(16, 1, 3))[0]
	TestHooks.check(ch.ok() and ch.uid.begins_with("U-" + String(t["id"])) and ground_ok and int(road["flags"]) & 0x3F == 3
		and names.get("StadiumTube", 0) == 1 and names.get("StadiumTubePillar", 0) == 2 and not ch.lap_race and ch.author_ms < 0,
		"editor_challenge", "%s %s" % [ch.uid, names])
	t["laps"] = 3
	var lap := TmUserTracks.challenge(t)
	TestHooks.check(lap.lap_race and lap.nb_laps == 3 and lap.uid != ch.uid, "editor_laps_new_layout")
	var v := straight_track()
	TestHooks.check(TmUserTracks.validate(v, 8123) and TmUserTracks.is_validated(v) and int(v["medals"]["author"]) == 8130
		and int(v["medals"]["gold"]) == 8700 and not TmUserTracks.validate(v, 9000) and TmUserTracks.validate(v, 8000), "editor_validate",
		str(v["medals"]))
	(v["blocks"] as Array).append([ROAD, 0, 2, 1, 2])
	TestHooks.check(not TmUserTracks.is_validated(v) and TmUserTracks.challenge(v).author_ms < 0, "editor_edit_invalidates")


## The straight track raced from the editor: full gas to the finish validates its file.
func _drive(path: String) -> void:
	TestHooks.args.erase("track")
	TestHooks.args["map"] = path
	TestHooks.args["back"] = "editor"
	TestHooks.args["auto_gas"] = "1"
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	var waited := 0
	while not scene.ready_to_race and waited < 600:
		await get_tree().physics_frame
		waited += 1
	var race: TmRace = scene.race
	while race != null and race.state != TmRace.State.FINISHED and race.time_ms < 30000:
		await get_tree().physics_frame
	var fin := race.finish_ms if race != null else -1
	var t := TmUserTracks.load_file(path)
	TestHooks.check(fin > 0 and race.splits.size() == 2, "editor_track_races", "finish %d, splits %s" % [fin, race.splits if race else []])
	TestHooks.check(TmUserTracks.is_validated(t) and int(t["medals"]["author"]) == TmUserTracks.medals(fin)["author"]
		and scene.challenge.author_ms == int(t["medals"]["author"]) and scene.menu._menu_text() == "Editor", "editor_test_drive_validates",
		str(t.get("medals", {})))
	scene.queue_free()
	await get_tree().physics_frame
	TestHooks.args.erase("auto_gas")
	TestHooks.args.erase("map")
	TestHooks.args.erase("back")


func _editor(path: String) -> void:
	TestHooks.args["edit"] = path
	var ed: TmEditor = (load("res://editor/editor.tscn") as PackedScene).instantiate()
	add_child(ed)
	await get_tree().process_frame
	var want := TmUserTracks.challenge_blocks(ed.model.track).size()
	TestHooks.check(ed.path == path and ed.model.track["blocks"].size() == 8 and ed._built.size() == want, "editor_opens_a_track",
		"%d built of %d" % [ed._built.size(), want])
	TestHooks.check((ed.palette[0] as Array).has(ROAD) and (ed.palette[TmEditor.CATEGORIES.size() - 1] as Array).has("StadiumRoadMainStartLine")
		and (ed.palette[0] as Array).has("StadiumRoadMainGTCurve2") and not (ed.palette[0] as Array).has("StadiumRoadMainClip"), "editor_palette",
		"%d road blocks" % (ed.palette[0] as Array).size())
	# a road beside the first straight: the straight becomes a T, its key changes
	var before := ed._built.keys()
	ed.select_block(ROAD)
	ed.rot = 0
	ed.cursor = Vector3i(15, 1, 3)
	ed.level = 1
	var placed := ed.place()
	var changed := ed._built.keys().filter(func(k: String) -> bool: return not before.has(k))
	TestHooks.check(placed and ed.model.dirty and changed.size() == 2 and changed.any(func(k: String) -> bool: return k.begins_with(ROAD + "|") and k.contains("|16,1,3|%d|" % (4 | TmTrackBuilder.GROUND_FLAG))),
		"editor_place_rejoins", str(changed))
	ed.undo()
	TestHooks.check(ed._built.size() == want and ed.model.track["blocks"].size() == 8, "editor_scene_undo")
	ed.cursor = Vector3i(16, 1, 2)
	TestHooks.check(not ed.place() and ed.message == "the space is taken", "editor_scene_refuses", ed.message)
	ed._name_edit.text = "Renamed"
	TestHooks.check(ed.save() and String(TmUserTracks.load_file(path)["name"]) == "Renamed" and not ed.model.dirty, "editor_scene_saves")
	ed.queue_free()
	await get_tree().process_frame
	TestHooks.args.erase("edit")


## The menu's Editors page lists the track; Edit and New track hand over to the editor, Play races it.
func _menu(path: String) -> void:
	TestHooks.args["menu_dry"] = "true"
	var menu: TmMenu = (load("res://ui/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.show_page("editors")
	await get_tree().process_frame
	var names := _buttons(menu).map(func(b: Button) -> String: return b.text)
	TestHooks.check(menu.track_rows.size() == 1 and menu.track_rows.has(path) and names.has("New Track") and names.has("Edit")
		and names.has("Play"), "editor_menu_lists", str(names))
	var got := []
	menu.edited.connect(func(p: String) -> void: got.append(p))
	menu.edit(path)
	TestHooks.check(got == [path] and String(TestHooks.arg("edit", "")) == path, "editor_menu_edit")
	menu.edit("")
	TestHooks.check(got.size() == 2 and not TestHooks.has_arg("edit"), "editor_menu_new_track")
	menu.race("", path)
	TestHooks.check(String(TestHooks.arg("map", "")) == path and not TestHooks.has_arg("back"), "editor_menu_play")
	menu.queue_free()
	TestHooks.args.erase("menu_dry")
	TestHooks.args.erase("map")


static func _all(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
			_all(c, out)
	return out


static func _buttons(n: Node) -> Array:
	return _all(n, []).filter(func(c: Node) -> bool: return c is Button and not (c is CheckButton) and (c as Button).is_visible_in_tree())
