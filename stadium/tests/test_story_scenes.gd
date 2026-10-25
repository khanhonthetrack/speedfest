extends Node
## Story mode's cutscenes (story/scenes/*.json; PLAN M20-3), every one of them:
## - it loads, its id is its file's name, it has shots, every line has an id (unique across all
##   scenes: the key a voice or a translation pass swaps by), a known kind, text, and a speaker
##   when it is spoken;
## - nothing is missing: every track a shot stands on exists, every car is one of ours, every
##   person's clip is in the animation library and its cast member ("who") built, every sound and
##   ambience is one of StorySounds' (an ambience one that loops), and every flag a condition reads
##   is set somewhere
##   (a decision's exit, a night's fact, a scene, a line);
## - it plays headless from start to end at the fixed frame rate (logic only: no tracks built), and
##   skipping it at any point ends it at once with its flags set, as if it had played;
## - a line's conditions pick its variant: a cold, warm or hot save hears different lines;
## - with its track built, a shot puts the camera and its cars where the scene says; "bare", the
##   track is left out (no blocks, road decals or neon along it) and the shot stands on the ground;
## - a story map in the race (race.gd --story), a time-attack session (short here: 4 s): the bot's
##   run on G06's second finish, still under way when time is up, counts; the session settles on it,
##   it beats the time to beat on that finish, the panel names the decision, no new run starts, and
##   CONTINUE writes the decision into the save.

const SPECIAL := ["tier=", "facts", "done:", "way:", "count:"]


func _ready() -> void:
	var ids := StoryScene.ids()
	TestHooks.check(not ids.is_empty(), "story_scenes_found", "%d" % ids.size())
	var g := StoryGraph.load_file()
	var set_somewhere := _flags_set(g, ids)
	var line_ids := {}
	var clips := StoryPerson.clip_names()
	for id in ids:
		var d := StoryScene.load_data(id)
		var bad: Array[String] = []
		if d.is_empty():
			bad.append("does not load")
		elif String(d.get("id", "")) != id:
			bad.append("its id is %s" % d.get("id", ""))
		if (d.get("shots", []) as Array).is_empty():
			bad.append("no shots")
		for s: Dictionary in d.get("shots", []):
			for f in _flags_read(s.get("if", null)):
				if not set_somewhere.has(f):
					bad.append("shot %s reads %s, which nothing sets" % [s.get("id", "?"), f])
			var track := String(s.get("track", d.get("track", "")))
			if not track.is_empty() and not TmTracks.has(track):
				bad.append("shot %s: no track %s" % [s.get("id", "?"), track])
			for c: Dictionary in s.get("cars", []):
				var m := String(c.get("model", "hyper"))
				if not (m in ["", "hyper"] or TmRoadCars.is_road(m)):
					bad.append("shot %s: no car %s" % [s.get("id", "?"), m])
			for which in ["camera", "mirror"]:
				var cam: Dictionary = s.get(which, {})
				for k: Dictionary in cam.get("keys", [cam]):
					if k.get("pos") is String and (not String(k["pos"]) in ["driver_head", "mirror"] or not cam.has("follow")):
						bad.append("shot %s: %s at %s, not a place in a followed car" % [s.get("id", "?"), which, k["pos"]])
			for c: Dictionary in s.get("cars", []):
				var box := _in_container(c, s.get("props", []))
				if not box.is_empty():
					bad.append("shot %s: car %s inside the container at %s" % [s.get("id", "?"), c.get("id", "?"), box])
			for p: Dictionary in s.get("people", []):
				if not String(p.get("clip", "Idle")) in clips:
					bad.append("shot %s: no clip %s" % [s.get("id", "?"), p.get("clip", "")])
				# a cast member who isn't built would be the Mannequin, with only a warning
				if p.has("who") and not StoryCast.has(String(p["who"])):
					bad.append("shot %s: no cast member %s" % [s.get("id", "?"), p["who"]])
			# a sound that isn't one of ours would be silence, without a word
			for snd: Dictionary in s.get("sounds", []):
				if StorySounds.get_stream(String(snd.get("cue", ""))) == null:
					bad.append("shot %s: no sound %s" % [s.get("id", "?"), snd.get("cue", "")])
			for cue: String in StoryScene.ambience(s):
				if StorySounds.get_stream(cue) == null or not StorySounds.loops(cue):
					bad.append("shot %s: no looping sound %s" % [s.get("id", "?"), cue])
			for l: Dictionary in s.get("lines", []):
				var lid := String(l.get("id", ""))
				var kind := String(l.get("kind", "say"))
				if lid.is_empty():
					bad.append("shot %s: a line without an id" % s.get("id", "?"))
				elif line_ids.has(lid):
					bad.append("line %s also in %s" % [lid, line_ids[lid]])
				line_ids[lid] = id
				if not kind in ["say", "text", "phone"]:
					bad.append("line %s: kind %s" % [lid, kind])
				if kind == "say" and String(l.get("speaker", "")).is_empty():
					bad.append("line %s: no speaker" % lid)
				if kind != "phone" and String(l.get("text", "")).strip_edges().is_empty():
					bad.append("line %s: no text" % lid)
				for f in _flags_read(l.get("if", null)):
					if not set_somewhere.has(f):
						bad.append("line %s reads %s, which nothing sets" % [lid, f])
		TestHooks.check(bad.is_empty(), "story_scene_sound_" + id, "; ".join(bad))
		if not d.is_empty():
			await _plays(id, d)
	_cabins()
	_layers()
	await _variants()
	await _staged()
	await _story_race()
	TestHooks.finish()


## Every road car's cabin (StoryCabin) fits under its own roof: a seated head's crown
## (StoryCabin.CROWN) and the mirror under the roof's line less its skin, the mirror ahead of the
## driver's eyes (a first cabin, built to the car's box, put the heads through the coupe's falling
## roof and the mirror outside the windscreen).
func _cabins() -> void:
	var bad: Array[String] = []
	for c: Array in TmRoadCars.CARS:
		var id := String(c[0])
		var m := TmRoadCars.manifest(id)
		var pts := StoryCabin.points(id)
		for seat in ["driver", "passenger", "rear"]:
			var p: Vector3 = pts[seat]
			var crown := p.y + StoryCabin.CROWN.x
			var roof := StoryCabin.line(m, "top", p.z + StoryCabin.CROWN.y) - 0.04
			if crown > roof:
				bad.append("%s %s: head to %.2f m, roof %.2f" % [id, seat, crown, roof])
		var mir: Vector3 = pts["mirror"]
		if mir.y + 0.04 > StoryCabin.line(m, "top", mir.z) - 0.03 or mir.z < (pts["driver_head"] as Vector3).z + 0.3:
			bad.append("%s mirror at %s" % [id, mir])
	TestHooks.check(bad.is_empty(), "story_cabins_fit", "; ".join(bad))


## The container (its "pos") a car starts inside, if any: both in the shot's anchor frame (x left,
## z ahead; a car's "left" / "ahead" on a straight line), a car taken as 2 m round (Tibor's rally car
## once stood inside a stack of them).
static func _in_container(car: Dictionary, props: Array) -> Array:
	var at := Vector2(float(car.get("left", 0.0)), float(car.get("ahead", 0.0)))
	for p: Dictionary in props:
		if String(p.get("kind", "")) != "container":
			continue
		var pos: Array = p.get("pos", [0, 0, 0])
		var local := (at - Vector2(float(pos[0]), float(pos[2]))).rotated(deg_to_rad(float(p.get("yaw", 0.0))))
		if absf(local.x) < StoryProps.CONTAINER.x * 0.5 + 1.0 and absf(local.y) < StoryProps.CONTAINER.z * 0.5 + 2.0:
			return pos
	return []


## The 2D layer: a black shot or a fade covers the picture, never the subtitles, the title card or
## the phone's texts (a "black" shot once hid the prologue's radio lines).
func _layers() -> void:
	var sub := StorySubtitles.new()
	add_child(sub)
	var black := sub._black.get_index()
	TestHooks.check(black < sub._sub.get_index() and black < sub._card.get_index() and black < sub._phone.get_index(),
		"story_black_under_the_words", "black %d, subtitles %d, card %d, phone %d" % [black, sub._sub.get_index(), sub._card.get_index(), sub._phone.get_index()])
	sub.queue_free()


## Every flag something sets: exits, facts, scenes, lines.
func _flags_set(g: StoryGraph, ids: Array[String]) -> Dictionary:
	var out := {}
	for cid in g.ids():
		var c := g.chapter(cid)
		out[String(c.get("fact", ""))] = true
		for e: Dictionary in c.get("exits", []):
			for f: Variant in e.get("set", []):
				out[String(f)] = true
	for id in ids:
		var d := StoryScene.load_data(id)
		for f: Variant in d.get("set", []):
			out[String(f)] = true
		for s: Dictionary in d.get("shots", []):
			for l: Dictionary in s.get("lines", []):
				for f: Variant in l.get("set", []):
					out[String(f)] = true
	return out


## The plain flags a condition reads (tiers, counts, nights done and ways taken apart).
static func _flags_read(cond: Variant) -> Array[String]:
	var out: Array[String] = []
	if cond is Array:
		for c: Variant in cond:
			out.append_array(_flags_read(c))
	elif cond is Dictionary:
		for k: String in ["any", "all", "not"]:
			if (cond as Dictionary).has(k):
				out.append_array(_flags_read(cond[k]))
	elif cond is String:
		var s := (cond as String).strip_edges().trim_prefix("!")
		if not s.is_empty() and not SPECIAL.any(func(p: String) -> bool: return s.begins_with(p)):
			out.append(s)
	return out


## Plays to the end; then again, skipped halfway.
func _plays(id: String, d: Dictionary) -> void:
	var st := StoryState.new()
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, st, false)
	var ended := [false, false]
	sc.finished.connect(func(skipped: bool) -> void:
		ended[0] = true
		ended[1] = skipped)
	sc.play()
	var frames := 0
	var limit := int(sc.length * Engine.physics_ticks_per_second) + 600
	while not ended[0] and frames < limit:
		await get_tree().process_frame
		frames += 1
	var flags := sc.flags_set()
	TestHooks.check(ended[0] and not ended[1] and absf(sc.t - sc.length) < 0.05 and sc.length > 1.0
		and flags.all(func(f: String) -> bool: return st.flags.has(f)) and st.seen_scenes.has(id), "story_scene_plays_" + id,
		"ended %s (skipped %s) at %.2f of %.2f s after %d frames" % [ended[0], ended[1], sc.t, sc.length, frames])
	sc.queue_free()
	var st2 := StoryState.new()
	var sk := StoryScene.new()
	add_child(sk)
	sk.setup(d, st2, false)
	var got := [false, false]
	sk.finished.connect(func(skipped: bool) -> void:
		got[0] = true
		got[1] = skipped)
	sk.play(sk.length * 0.5)
	await get_tree().process_frame
	sk.skip()
	TestHooks.check(got[0] and got[1] and flags.all(func(f: String) -> bool: return st2.flags.has(f)) and not sk.playing,
		"story_scene_skips_" + id, "ended %s skipped %s" % [got[0], got[1]])
	sk.queue_free()
	await get_tree().process_frame


## A scene made here: its lines differ by how much the save knows; texts arrive on the phone;
## lines flow one after another, each long enough to read.
func _variants() -> void:
	var d := {"id": "variants", "shots": [{"id": "a", "lines": [
		{"id": "v1", "speaker": "A", "text": "Always."},
		{"id": "v2", "speaker": "A", "text": "Cold only.", "if": "tier=cold"},
		{"id": "v3", "speaker": "A", "text": "Hot only, and a little longer to read.", "if": "tier=hot"},
		{"id": "v4", "kind": "phone", "from": "Unknown"},
		{"id": "v5", "kind": "text", "text": "Where are you?"},
		{"id": "v6", "speaker": "B", "text": "Only if met.", "if": "met", "set": ["answered"]}]}]}
	var cold := StoryScene.new()
	add_child(cold)
	cold.setup(d, StoryState.new(), false)
	var hot_state := StoryState.new()
	for i in hot_state.hot:
		hot_state.flags["fact_%d" % i] = true
	hot_state.flags["met"] = true
	var hot := StoryScene.new()
	add_child(hot)
	hot.setup(d, hot_state, false)
	var texts := func(sc: StoryScene) -> Array:
		return (sc.shots[0]["lines"] as Array).map(func(l: Dictionary) -> String: return String(l.get("text", l.get("from", ""))))
	TestHooks.check(texts.call(cold) == ["Always.", "Cold only.", "Unknown", "Where are you?"]
		and texts.call(hot) == ["Always.", "Hot only, and a little longer to read.", "Unknown", "Where are you?", "Only if met."],
		"story_lines_by_knowledge", "%s / %s" % [texts.call(cold), texts.call(hot)])
	var l0: Dictionary = hot.shots[0]["lines"][0]
	var l1: Dictionary = hot.shots[0]["lines"][1]
	TestHooks.check(float(l1["at"]) >= float(l0["at"]) + float(l0["hold"]) and float(l0["hold"]) >= 1.8
		and float(l1["hold"]) > float(l0["hold"]), "story_lines_flow_and_hold")
	var mid := float(l1["at"]) + 0.1
	TestHooks.check(String(hot.line_at(mid).get("id", "")) == "v3" and hot.phone_at(mid).get("messages", []).is_empty()
		and (hot.phone_at(hot.length - 0.01).get("messages", []) as Array).size() == 1 and hot.flags_set() == (["answered"] as Array[String])
		and cold.flags_set().is_empty(), "story_line_and_phone_at_a_time", "%s %s" % [hot.line_at(mid), hot.phone_at(hot.length - 0.01)])
	cold.queue_free()
	hot.queue_free()
	await get_tree().process_frame


## The look test's flank shot with F04 built: the camera stands where its first key says, in the
## shot's anchor frame, and the hero car on the road beside it.
func _staged() -> void:
	var d := StoryScene.load_data("look_test")
	if d.is_empty():
		return
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), true)
	var flank := -1
	for i in sc.shots.size():
		if String(sc.shots[i].get("id", "")) == "flank":
			flank = i
	var start := float(sc.shots[flank]["start"]) + 0.001
	sc.seek(start)
	for i in 3:
		await get_tree().physics_frame
		sc.seek(start)
	var key: Array = sc.shots[flank]["camera"]["keys"][0]["pos"]
	var want := sc._anchor * Vector3(float(key[0]), float(key[1]), float(key[2]))
	var car := sc._cars.get("hero", {}).get("node", null) as Node3D
	TestHooks.check(sc.camera.global_position.distance_to(want) < 0.05 and car != null
		and car.global_position.distance_to(sc._anchor.origin) < 1.5 and sc._stage_track == "F04", "story_shot_staged",
		"camera %s want %s, car at %s, anchor %s" % [sc.camera.global_position, want, car.global_position if car else Vector3.INF,
		sc._anchor.origin])
	sc.queue_free()
	await get_tree().process_frame
	# the same shot "bare": F04 without its track (no blocks, decals or neon along the road), the city's
	# paved ground still under the anchor and the car
	var bd := d.duplicate(true)
	bd["bare"] = true
	var bs := StoryScene.new()
	add_child(bs)
	bs.setup(bd, StoryState.new(), true)
	bs.seek(start)
	for i in 3:
		await get_tree().physics_frame
		bs.seek(start)
	var names := {}
	for n in bs._stage.find_children("*", "", true, false):
		names[String(n.name)] = true
	var bcar := bs._cars.get("hero", {}).get("node", null) as Node3D
	TestHooks.check(not names.has("Blocks") and not names.has("RoadDecals") and not names.has("NeonLights")
		and names.has("Terrain") and bs._stage_track == "F04|bare" and bcar != null
		and absf(bs._anchor.origin.y - TmMapBuilder.GROUND_Y) < 0.3, "story_shot_bare",
		"stage %s, nodes: blocks %s decals %s neon %s terrain %s; anchor at %s (ground %.1f)" % [bs._stage_track,
		names.has("Blocks"), names.has("RoadDecals"), names.has("NeonLights"), names.has("Terrain"), bs._anchor.origin,
		TmMapBuilder.GROUND_Y])
	bs.queue_free()
	await get_tree().process_frame


func _story_race() -> void:
	if not TmTracks.has("G06"):
		return
	var g := StoryGraph.load_file()
	var night := g.regular()[0]
	TestHooks.args["story_save"] = "user://test_story/race.json"
	TestHooks.args["records"] = "user://test_records_story"
	TmRecords.clear()
	var st := StoryState.create(g, String(g.difficulties()[0]["id"]))
	st.begin(night)
	st.map_done(0)
	st.map_done(1)
	st.save()
	for k: String in ["track", "story", "story_map", "bot", "story_session_ms"]:
		TestHooks.args[k] = {"track": "G06", "story": night, "story_map": "2", "bot": true, "story_session_ms": "4000"}[k]
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var bot: TmBot = scene.bot
	bot.grip = float(TmTracks.spec("G06").get("bot_grip", 75))
	bot.path = scene.challenge.alt_paths[0]
	bot.reset()
	var race: TmRace = scene.race
	while race.state != TmRace.State.FINISHED and race.time_ms < 60000 and bot.failed.is_empty():
		await get_tree().physics_frame
	var r: Dictionary = scene._result
	var story: StoryRace = scene.story
	var want := "Decision: %s" % String(g.exit_of(night, 1).get("label", ""))
	# the 4 s session ran out during the run: the run still counts, and the session settles on it
	TestHooks.check(story != null and story.settled and story.passed() and int(story.best["way"]) == 1
		and int(r.get("way", -1)) == 1 and bool(r.get("story", {}).get("settled", false))
		and String(r.get("way_label", "")) == want and scene.menu.story_state == "pass" and int(r["story"]["target"]) == story.target(1),
		"story_race_session_settles_on_its_best", "%s / %s" % [r, want])
	scene.restart()
	TestHooks.check(race.state == TmRace.State.FINISHED, "story_race_no_run_after_the_session")
	story.go_on(null)
	var back := StoryState.load_file()
	TestHooks.check(back != null and back.is_done(night) and int(back.decisions[night]["way"]) == 1
		and back.best_time("G06", 1) == race.finish_ms, "story_race_continue_decides", "%s" % [back.to_dict() if back else {}])
	scene.queue_free()
	await get_tree().physics_frame
	for k: String in ["track", "story", "story_map", "bot", "story_save", "story_session_ms"]:
		TestHooks.args.erase(k)
	TmRecords.clear()

