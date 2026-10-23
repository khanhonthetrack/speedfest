extends Node
## Our own tracks (tracks/*.json; no TMNF install needed): each lays out without errors, builds
## from recreated blocks only (no placeholders), has a start, its checkpoints and a finish, and the
## driving bot (TmBot) finishes it in the race scene, crossing every checkpoint, within the
## track's gold time, at the track's bot_grip. The bot drives (about real time, so the gate keeps
## it short) each series' first track by default; --tracks=all every campaign track,
## --series=White one series, --tracks=A01,A02 those; --grip=40 tries another cornering grip; --write_medals: the bot drives each track at several grips and the
## best finish sets its medals (author = the bot's time, gold +6%, silver +20%, bronze +50%,
## rounded up to 10 ms / 0.1 s / 1 s) and bot_grip, written back to the track's file; a track with
## several finishes also gets each way's own set ("way_medals", each with its own bot_grip: story
## mode's decisions are timed per finish) while the fastest way sets "medals".

const LIMIT_MS := 240000


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records_tracks"   # never the player's own records (nor another test's)
	TestHooks.args.erase("map")
	TmRecords.clear()
	var ids := TmTracks.ids()
	TestHooks.check(ids.size() >= 1, "tracks_found", "%d" % ids.size())
	var only := String(TestHooks.arg("tracks", ""))
	var drive := {}                  # the tracks the bot drives (every one lays out and builds)
	if only == "all":
		for id in ids:
			drive[id] = true
	elif not only.is_empty():
		ids.assign(Array(only.split(",")))
		for id in ids:
			drive[id] = true
	elif TestHooks.has_arg("series"):
		ids.clear()
		for s: Dictionary in TmTracks.series():
			if String(s["name"]).to_lower() == String(TestHooks.arg("series", "")).to_lower():
				for id: String in s["tracks"]:
					ids.append(id)
					drive[id] = true
	else:
		for s: Dictionary in TmTracks.series():
			drive[String(s["tracks"][0])] = true
	var report := []
	for id in ids:
		var ms := await _track(id, drive.has(id))
		if drive.has(id):
			report.append("%s %s" % [id, TmRace.time_text(ms) if ms > 0 else "DNF"])
	print("TRACK_TIMES ", ", ".join(report))
	if not ids.is_empty() and not TestHooks.has_arg("write_medals"):
		# on a road track (its gates have the crown screens): SF01 when it's there
		var road := "SF01" if TmTracks.has("SF01") else ids[0]
		await _respawn_check(road)
		await _input_script_check(road)
		await _steer_check(road)
		if TmTracks.has("G06"):
			await _finish_way_check("G06")
	TestHooks.finish()


## Respawning after a checkpoint puts the car back there with the speed it crossed it at (TMNF).
func _respawn_check(id: String) -> void:
	TestHooks.args["track"] = id
	TestHooks.args["bot"] = true
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var race: TmRace = scene.race
	while race.taken.is_empty() and race.time_ms < LIMIT_MS and scene.bot.failed.is_empty():
		await get_tree().physics_frame
	var crossed: float = scene.car.speed_kmh()
	var at: Vector3 = scene.car.global_position
	_gate_screens(id, scene, race, at)
	var occ := scene.get_node_or_null("Occlusion") as TmOcclusion
	var over := occ.height_at(at.x, at.z) - at.y if occ else -1.0
	var beside := occ.height_at(at.x + 40.0, at.z + 40.0) if occ else 0.0
	TestHooks.check(occ != null and occ.texture != null and over > 5.0 and over < 12.0, "occlusion_sees_the_gate_arch",
		"%.1f m over the crossing (the arch's top), %.1f beside" % [over, beside])
	for i in 60:
		await get_tree().physics_frame
	scene.respawn()
	var back: float = scene.car.speed_kmh()
	TestHooks.check(not race.taken.is_empty() and crossed > 50.0 and absf(back - crossed) < 3.0
		and scene.car.global_position.distance_to(at) < 3.0, "respawn_keeps_checkpoint_speed",
		"crossed %.0f km/h, back at %.0f km/h, %.1f m from the crossing" % [crossed, back, scene.car.global_position.distance_to(at)])
	scene.restart()
	var words := TmGateScreen.near(get_tree(), at).map(func(g: TmGateScreen) -> String: return g._main.text)
	TestHooks.check(not words.is_empty() and words.all(func(w: String) -> bool: return w == "CHECKPOINT"),
		"gate_screen_word_after_restart", str(words))
	scene.queue_free()
	await get_tree().physics_frame
	TestHooks.args.erase("bot")


## A run's inputs written as a script (TmInputScript) and driven again without the bot give the
## same splits and finish: the harness for comparing a TMNF run's inputs with the game's times.
func _input_script_check(id: String) -> void:
	var path := OS.get_user_data_dir().path_join("test_inputs_%s.txt" % id)
	TestHooks.args["track"] = id
	TestHooks.args["bot"] = true
	TestHooks.args["record_inputs"] = path
	var a := await _race_to_finish()
	TestHooks.args.erase("bot")
	TestHooks.args.erase("record_inputs")
	TestHooks.args["inputs"] = path
	var b := await _race_to_finish()
	TestHooks.args.erase("inputs")
	TestHooks.check(int(a["finish"]) > 0 and a["splits"] == b["splits"] and a["finish"] == b["finish"],
		"input_script_replays_the_run_" + id, "recorded %s %d, replayed %s %d" % [a["splits"], a["finish"], b["splits"], b["finish"]])


## Left steering turns the car to the left (towards its +x, the screen's left from the chase
## camera), as a left key press does (TmCarInput: left = +1).
func _steer_check(id: String) -> void:
	TestHooks.args["track"] = id
	TestHooks.args["auto_gas"] = "1"
	TestHooks.args["auto_steer"] = "1"
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var race: TmRace = scene.race
	while not race.racing():
		await get_tree().physics_frame
	var start: Basis = scene.car.global_transform.basis
	while race.time_ms < 1200:
		await get_tree().physics_frame
	var fwd: Vector3 = scene.car.global_transform.basis.z
	TestHooks.check(fwd.dot(start.x) > 0.05, "steer_left_turns_left", "heading towards +x by %.2f" % fwd.dot(start.x))
	scene.queue_free()
	await get_tree().physics_frame
	for k in ["auto_gas", "auto_steer"]:
		TestHooks.args.erase(k)


## A run along a split's other way finishes on that way's own line, and the race says so (its
## finish_way, the finish menu's result, the record), as story mode's decisions need.
func _finish_way_check(id: String) -> void:
	TestHooks.args["records"] = "user://test_records_ways"
	TmRecords.clear()
	var ch := TmTracks.challenge(id)
	var spec := TmTracks.spec(id)
	var run := await _drive(id, float(spec.get("bot_grip", 40.0)), 0)
	var rec := TmRecords.best(ch)
	TestHooks.check(run["ms"] > 0 and int(run["way"]) == 1 and int(run["result"].get("way", -1)) == 1
		and int(run["result"].get("ways", 0)) == 2 and int(rec.get("way", -1)) == 1, "finish_way_reported_" + id,
		"%s way %d, result %s, record %s" % [TmRace.time_text(run["ms"]), run["way"], run["result"], rec])
	TmRecords.clear()
	TestHooks.args["records"] = "user://test_records_tracks"


## Runs race.tscn (with the current args) until the finish or LIMIT_MS: {splits, finish (-1: none)}.
func _race_to_finish() -> Dictionary:
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var race: TmRace = scene.race
	while race.state != TmRace.State.FINISHED and race.time_ms < LIMIT_MS:
		await get_tree().physics_frame
	var out := {"splits": race.splits.duplicate(), "finish": race.finish_ms if race.state == TmRace.State.FINISHED else -1}
	scene.queue_free()
	await get_tree().physics_frame
	return out


## Every gate has its crown screen (start, checkpoints, finish), and the one just passed shows the
## time it was passed at.
func _gate_screens(id: String, scene: Node, race: TmRace, at: Vector3) -> void:
	var all := get_tree().get_nodes_in_group(TmGateScreen.GROUP)
	var gates := 0
	for wp: Dictionary in scene.builder.waypoints:
		gates += 1 if String(wp["block"]).begins_with("StadiumRoadMain") else 0
	TestHooks.check(all.size() == gates, "gate_screens_" + id, "%d screens, %d road gates" % [all.size(), gates])
	var here := TmGateScreen.near(get_tree(), at)
	var want := TmRace.time_text(race.splits[0]) if not race.splits.is_empty() else "?"
	TestHooks.check(here.size() == 1 and here[0]._main.text == want, "gate_screen_shows_time",
		"%d near, %s (want %s)" % [here.size(), here.map(func(g: TmGateScreen) -> String: return g._main.text), want])


func _track(id: String, drive := true) -> int:
	var spec := TmTracks.spec(id)
	var b := TmTrackBuilder.build(spec)
	TestHooks.check(b.errors.is_empty(), "%s_lays_out" % id, "; ".join(b.errors))
	for n: String in b.notes:
		print("TRACK_NOTE %s %s" % [id, n])
	var ch := TmTracks.challenge(id)
	var mb := TmMapBuilder.build(ch)
	var finishes := 0
	for wp: Dictionary in mb.waypoints:
		# the finish: a start/finish line with road after it (or, where that doesn't fit, a finish)
		if int(wp["kind"]) in [TmBlockCatalogue.Waypoint.FINISH, TmBlockCatalogue.Waypoint.START_FINISH]:
			finishes += 1
	# several finishes: each finish line belongs to exactly one way, and every way has its line
	var ways := {}
	for wp: Dictionary in mb.waypoints:
		if int(wp["kind"]) in [TmBlockCatalogue.Waypoint.FINISH, TmBlockCatalogue.Waypoint.START_FINISH]:
			var w := ch.way_of(wp["coord"])
			ways[w] = int(ways.get(w, 0)) + 1
	var want_ways := range(ch.ways())
	TestHooks.check(b.finish_ways.size() == b.finishes and ways.keys().all(func(w: int) -> bool: return w in want_ways)
		and want_ways.all(func(w: int) -> bool: return ways.has(w)), "%s_finish_ways" % id,
		"%d finishes, %d recorded, ways crossed %s, want %s" % [b.finishes, b.finish_ways.size(), ways, want_ways])
	TestHooks.check(int(mb.stats["placeholder"]) == 0 and int(mb.stats["unknown"]) == 0 and mb.has_start
		and mb.checkpoints.size() == b.checkpoints and finishes == b.finishes and b.finishes >= 1, "%s_builds" % id,
		"%s start %s cps %d/%d finishes %d/%d" % [mb.stats, mb.has_start, mb.checkpoints.size(), b.checkpoints, finishes,
		b.finishes])
	mb.root.free()
	if not ch.ok() or not drive:
		return -1
	# the bot races it: with the track's grip (bot_grip), or, writing medals, its best of several
	var grips: Array = [float(TestHooks.arg("grip", spec.get("bot_grip", 40.0)))]
	if (TestHooks.has_arg("write_medals") or TestHooks.has_arg("sweep")) and not TestHooks.has_arg("grip"):
		grips = [30.0, 40.0, 50.0, 60.0, 75.0]
	var best := {}
	for g: float in grips:
		var run := await _drive(id, g)
		print("TRACK %s %s (grip %.0f): %s, %d/%d checkpoints, top %.0f km/h, at point %d/%d %s" % [id, ch.name, g,
			TmRace.time_text(run["ms"]) if run["ms"] > 0 else "DNF", run["taken"], b.checkpoints, run["top"],
			run["index"], ch.path.size(), run["why"]])
		if run["ms"] > 0 and run["taken"] == b.checkpoints and (best.is_empty() or run["ms"] < best["ms"]):
			best = run
			best["grip"] = g
	var ms: int = best.get("ms", -1)
	TestHooks.check(ms > 0, "%s_bot_finishes" % id, "no finish with grip %s" % [grips])
	if ms > 0 and ch.ways() > 1:
		TestHooks.check(int(best["way"]) == 0, "%s_main_way_finish" % id, "crossed way %d's finish" % best["way"])
	# a fork's other ways (multiple finishes): the bot drives each to its own finish too, and the
	# fastest way sets the medals (a risky shortcut is worth the author's time); each way keeps its
	# own set too (way_medals), at its own best grip
	var way_best: Array = [best]
	var spec_ways: Array = spec.get("way_medals", [])
	for k in ch.alt_paths.size():
		var way_grips: Array = [float(best.get("grip", grips[0]))]
		if k + 1 < spec_ways.size() and spec_ways[k + 1] is Dictionary and (spec_ways[k + 1] as Dictionary).has("bot_grip"):
			way_grips = [float(spec_ways[k + 1]["bot_grip"])]
		if TestHooks.has_arg("write_medals") and not TestHooks.has_arg("grip"):
			way_grips = grips
		var alt_best := {}
		for g: float in way_grips:
			var alt := await _drive(id, g, k)
			print("TRACK %s way %d (grip %.0f): %s, %d/%d checkpoints, at point %d/%d %s" % [id, k + 2, g,
				TmRace.time_text(alt["ms"]) if alt["ms"] > 0 else "DNF", alt["taken"], b.checkpoints, alt["index"],
				(ch.alt_paths[k] as Array).size(), alt["why"]])
			if alt["ms"] > 0 and alt["taken"] == b.checkpoints and (alt_best.is_empty() or alt["ms"] < alt_best["ms"]):
				alt_best = alt
				alt_best["grip"] = g
		TestHooks.check(not alt_best.is_empty(), "%s_way%d_finishes" % [id, k + 2], "no finish with grip %s" % [way_grips])
		way_best.append(alt_best)
		if alt_best.is_empty():
			continue
		TestHooks.check(int(alt_best["way"]) == k + 1, "%s_way%d_own_finish" % [id, k + 2], "crossed way %d's finish" % alt_best["way"])
		if alt_best["ms"] < ms:
			ms = alt_best["ms"]
		var wg := int(ch.medals_of(k + 1)["gold"])
		if wg > 0 and not TestHooks.has_arg("write_medals") and k + 1 < ch.way_medals.size():
			TestHooks.check(int(alt_best["ms"]) <= wg, "%s_way%d_within_its_gold" % [id, k + 2], "%d > %d" % [alt_best["ms"], wg])
	if ms > 0 and ch.gold_ms > 0 and not TestHooks.has_arg("write_medals"):
		TestHooks.check(ms <= ch.gold_ms, "%s_bot_within_gold" % id, "%d > %d" % [ms, ch.gold_ms])
	if ms > 0 and TestHooks.has_arg("write_medals"):
		_write_medals(id, ms, best["grip"], way_best if ch.ways() > 1 else [])
	return ms


## One run of the bot in the race scene: {ms (-1: no finish), taken, top, index, why}. way >= 0:
## along a fork's other way (TmChallenge.alt_paths) to its finish.
func _drive(id: String, grip: float, way := -1) -> Dictionary:
	TestHooks.args["track"] = id
	TestHooks.args["bot"] = true
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var bot: TmBot = scene.bot
	bot.grip = grip
	if way >= 0:
		bot.path = scene.challenge.alt_paths[way]
		bot.reset()
	var race: TmRace = scene.race
	var top := 0.0
	# long tracks (endurance, laps) get longer: at least 12 m/s along the whole line
	var length := 0.0
	var line: Array = scene.challenge.path
	for i in range(1, line.size()):
		length += (line[i]["p"] as Vector3).distance_to(line[i - 1]["p"])
	var limit := maxi(LIMIT_MS, int(length / 12.0 * 1000.0))
	while race.state != TmRace.State.FINISHED and bot.failed.is_empty() and race.time_ms < limit:
		await get_tree().physics_frame
		top = maxf(top, scene.car.speed_kmh())
		# --trace (every 500 ms; --trace_ms=50 --trace_from=4000 --trace_to=6000 closer)
		var every := int(TestHooks.arg("trace_ms", 500))
		if TestHooks.has_arg("trace") and race.racing() and race.time_ms % every == 0 \
				and race.time_ms >= int(TestHooks.arg("trace_from", 0)) and race.time_ms <= int(TestHooks.arg("trace_to", 1e9)):
			print("  %6d ms point %3d at %s %.0f km/h gas %.0f brake %.0f steer %.2f wheels %s local %s up %s mag %s" % [race.time_ms,
				bot.index, scene.car.global_position.snapped(Vector3.ONE * 0.1), scene.car.speed_kmh(), scene.car.gas,
				scene.car.brake, scene.car.steer, scene.car.wheel_contact, scene.car.local_velocity().snapped(Vector3.ONE * 0.1),
				scene.car.global_transform.basis.y.snapped(Vector3.ONE * 0.01), scene.car.body.mag_up.snapped(Vector3.ONE * 0.01)])
	var ms := race.finish_ms if race.state == TmRace.State.FINISHED else -1
	var why := bot.failed if not bot.failed.is_empty() else ("over %d s" % (limit / 1000) if ms < 0 else "")
	var out := {"ms": ms, "taken": race.taken.size(), "top": top, "index": bot.index, "why": why,
		"way": scene.finish_way if ms > 0 else -1, "result": (scene._result as Dictionary).duplicate()}
	scene.queue_free()
	await get_tree().physics_frame
	TestHooks.args.erase("bot")
	return out


static func _round_up(ms: int, step: int) -> int:
	return int(ceil(float(ms) / step)) * step


## TMNF's medal rule of thumb from the author time: gold +6%, silver +20%, bronze +50%.
static func medals(author_ms: int) -> Dictionary:
	var a := _round_up(author_ms, 10)
	return {"author": a, "gold": _round_up(int(a * 1.06), 100), "silver": _round_up(int(a * 1.2), 1000),
		"bronze": _round_up(int(a * 1.5), 1000)}


## ways: each way's best run ({ms, grip}, [] for a track with one finish): a "way_medals" line too.
func _write_medals(id: String, ms: int, grip: float, ways: Array = []) -> void:
	var path := TmTracks.DIR.path_join(id + ".json")
	var text := FileAccess.get_file_as_string(path)
	var m := medals(ms)
	var lines := "\t\"medals\": {\"author\": %d, \"gold\": %d, \"silver\": %d, \"bronze\": %d},\n\t\"bot_grip\": %d," % [
		m["author"], m["gold"], m["silver"], m["bronze"], int(grip)]
	if not ways.is_empty():
		var sets: Array[String] = []
		for w: Dictionary in ways:
			if w.is_empty():
				sets.append("{}")
				continue
			var wm := medals(int(w["ms"]))
			sets.append("{\"author\": %d, \"gold\": %d, \"silver\": %d, \"bronze\": %d, \"bot_grip\": %d}" % [wm["author"],
				wm["gold"], wm["silver"], wm["bronze"], int(w["grip"])])
		lines += "\n\t\"way_medals\": [%s]," % ", ".join(sets)
	# the old medal and grip lines out, the new ones in before the pieces
	text = RegEx.create_from_string("\\t\"(medals|bot_grip|way_medals)\": [^\\n]*\\n").sub(text, "", true)
	text = text.replace("\n\t\"pieces\"", "\n" + lines + "\n\t\"pieces\"")
	var f :=FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("MEDALS %s %s grip %d" % [id, m, int(grip)])
