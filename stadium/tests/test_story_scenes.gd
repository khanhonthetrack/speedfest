extends Node
## Story mode's cutscenes (story/scenes/*.json; PLAN M20-3), every one of them:
## - it loads, its id is its file's name, it has shots, every line has an id (unique across all
##   scenes: the key a voice or a translation pass swaps by), a known kind, text, and a speaker
##   when it is spoken;
## - nothing is missing: every track a shot stands on exists, every car is one of ours, every
##   person's clip is in the animation library, and every flag a condition reads is set somewhere
##   (a decision's exit, a night's fact, a scene, a line);
## - it plays headless from start to end at the fixed frame rate (logic only: no tracks built), and
##   skipping it at any point ends it at once with its flags set, as if it had played;
## - a line's conditions pick its variant: a cold, warm or hot save hears different lines;
## - with its track built, a shot puts the camera and its cars where the scene says;
## - a story map in the race (race.gd --story): the bot's run on G06's second finish beats the time
##   to beat on that finish, the panel names the decision, CONTINUE is offered and writes the
##   decision into the save.

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
			var track := String(s.get("track", d.get("track", "")))
			if not track.is_empty() and not TmTracks.has(track):
				bad.append("shot %s: no track %s" % [s.get("id", "?"), track])
			for c: Dictionary in s.get("cars", []):
				var m := String(c.get("model", "hyper"))
				if not (m in ["", "hyper"] or TmRoadCars.is_road(m)):
					bad.append("shot %s: no car %s" % [s.get("id", "?"), m])
			for p: Dictionary in s.get("people", []):
				if not String(p.get("clip", "Idle")) in clips:
					bad.append("shot %s: no clip %s" % [s.get("id", "?"), p.get("clip", "")])
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
	await _variants()
	await _staged()
	await _story_race()
	TestHooks.finish()


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
	for k: String in ["track", "story", "story_map", "bot"]:
		TestHooks.args[k] = {"track": "G06", "story": night, "story_map": "2", "bot": true}[k]
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
	TestHooks.check(story != null and int(r.get("way", -1)) == 1 and bool(r.get("story", {}).get("pass", false))
		and String(r.get("way_label", "")) == want and scene.menu.can_continue and int(r["story"]["target"]) == story.target(1),
		"story_race_finish", "%s / %s" % [r, want])
	story.go_on(null)
	var back := StoryState.load_file()
	TestHooks.check(back != null and back.is_done(night) and int(back.decisions[night]["way"]) == 1
		and back.best_time("G06", 1) == race.finish_ms, "story_race_continue_decides", "%s" % [back.to_dict() if back else {}])
	scene.queue_free()
	await get_tree().physics_frame
	for k: String in ["track", "story", "story_map", "bot", "story_save"]:
		TestHooks.args.erase(k)
	TmRecords.clear()

