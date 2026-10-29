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
##   track is hidden and its collision off (blocks, road decals, the neon along it), the shot standing
##   on the ground, and switched back on for a shot on the track, without a rebuild;
## - every road car's cabin lining stops at its windows' outlines (no corner of it under the glass:
##   its edge used to come out in saw teeth across the windows), and on a pane whose share is known
##   the cut keeps exactly the part off the glass, turned as the face was;
## - a rear-view mirror on the cabin's glass reflects the driver's eyes truly, its camera runs only in
##   shots with a mirror, lights ride in a car, eyes glance at the mirror on cue, water falls with it;
## - Arch 9's viaduct stands with its lit arch and number, and its train crosses at the shot's time;
## - a cut resets physics interpolation through the scene, so its first frame draws the camera where
##   the new shot puts it (it showed it between the two shots), and a seek within a shot doesn't;
## - a container terminal's block has a stack for every row and bay but those skipped, each as high
##   as its seed says, all of it one MultiMesh; a high mast lights straight down; the scene's own
##   props stand in every shot without any ("props": [] for none); a story car's "finish" is its
##   paint's; "rear" turns the driver's eyes to the back seat; a shot's "env" sets the night air and
##   the next shot without one gets the map's own back;
## - the film finish (StorySubtitles' "grade"): every scene's presets and keys are known ones; the
##   shot's grade goes over the scene's, a preset's name replaces what came before it; "film" when
##   none is named; its picture shows only when it does something (or rain is on the glass) and never
##   over a security camera's;
## - "bare": "set" hides the field's towers and stands the shot on a level deck; the scene's props stay
##   standing over a cut (not rebuilt), a shot's lights go with it, softboxes never reach the camera;
## - a person's "lift" stands them that much over the ground;
## - the camera engine: a "spline" path passes through its keys, "handheld" wanders a little and
##   gives the same frame however it is reached, "dof_near" blurs before the focus and pulls it;
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
				var box := _in_container(c, s.get("props", d.get("props", [])))   # the scene's own props stand in shots without any
				if not box.is_empty():
					bad.append("shot %s: car %s inside the container at %s" % [s.get("id", "?"), c.get("id", "?"), box])
			for p: Dictionary in s.get("people", []):
				if not String(p.get("clip", "Idle")) in clips:
					bad.append("shot %s: no clip %s" % [s.get("id", "?"), p.get("clip", "")])
				# a cast member who isn't built would be the Mannequin, with only a warning
				if p.has("who") and not StoryCast.has(String(p["who"])):
					bad.append("shot %s: no cast member %s" % [s.get("id", "?"), p["who"]])
			for gk: Variant in [d.get("grade"), s.get("grade")]:
				for why in _grade_bad(gk):
					bad.append("shot %s: grade %s" % [s.get("id", "?"), why])
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
	_linings()
	_lining_cut()
	_layers()
	await _variants()
	await _staged()
	await _mirror_glass()
	_viaduct()
	_terminal()
	_scene_props()
	await _cut_snaps()
	await _grade()
	await _camera_engine()
	await _props_kept()
	await _lifted()
	await _reached()
	await _windows()
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


## Every road car's lining (StoryCabin.fit_car) stops at its glass: no corner of it lies under a
## window (StoryCabin.GlassMask, as the lining was cut), so the windows' edges seen from the seats are
## the glass's outline, not the paint's triangles kept whole as teeth across it.
func _linings() -> void:
	var bad: Array[String] = []
	var slowest := 0
	for c: Array in TmRoadCars.CARS:
		var car := TmCarVisual.new()
		car.model = String(c[0])
		add_child(car)
		var t0 := Time.get_ticks_msec()
		StoryCabin.fit_car(car)
		slowest = maxi(slowest, Time.get_ticks_msec() - t0)
		var corners := 0
		var under := 0
		var blind := 0                     # a lined mesh whose glass the test didn't find (it would pass blind)
		for mi: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
			var lining := mi.get_node_or_null("Lining") as MeshInstance3D
			if lining == null:
				continue
			var glass := StoryCabin.GlassMask.new()
			for k in mi.mesh.get_surface_count():
				if mi.get_active_material(k) == StoryCabin._clear_glass:
					var t: PackedVector3Array = StoryCabin._triangles(mi.mesh, k)[0]
					for i in range(0, t.size(), 3):
						glass.add(t[i], t[i + 1], t[i + 2])
			blind += int(glass.a.is_empty())
			for k in lining.mesh.get_surface_count():
				for v: Vector3 in lining.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]:
					corners += 1
					under += int(glass.under(v))
		if corners == 0 or under > 0 or blind > 0:
			bad.append("%s: %d of %d corners under the glass, %d lined meshes without glass" % [c[0], under, corners, blind])
		car.free()
	print("LINING slowest build %d ms" % slowest)
	TestHooks.check(bad.is_empty(), "story_cabin_linings_stop_at_the_glass", "; ".join(bad))


## The cut on one face whose share under a pane is known (the check above sees only corners under
## the glass, not a lining stopping short of it or turned the wrong way): the pane x 0..1 (y -1..1,
## z 0), the face's corners at x -0.5, 0.5, -0.5 just behind it; off the glass is the face (0.5 m^2)
## less its corner past x = 0 (0.125), less the 2 mm GlassMask.under allows past an edge and the
## halvings' fifth of a millimetre. Kept or dropped whole (the old rule), the last triangles' teeth
## miss it by a few hundredths.
func _lining_cut() -> void:
	var glass := StoryCabin.GlassMask.new()
	glass.add(Vector3(0, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0))
	glass.add(Vector3(0, -1, 0), Vector3(1, 1, 0), Vector3(0, 1, 0))
	var a := Vector3(-0.5, -0.5, 0.005)
	var b := Vector3(0.5, -0.5, 0.005)
	var c := Vector3(-0.5, 0.5, 0.005)
	var n := (b - a).cross(c - a).normalized()
	var v := PackedVector3Array()
	var vn := PackedVector3Array()
	StoryCabin._clip(a, b, c, n, n, n, 3, glass, v, vn)
	var area := 0.0
	var turned := 0
	var under := 0
	for i in range(0, v.size(), 3):
		var cr := (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		area += cr.length() * 0.5
		turned += int(cr.dot(n) < -1.0e-9)
		for j in 3:
			under += int(glass.under(v[i + j]))
	TestHooks.check(v.size() > 0 and absf(area - 0.374) < 0.003 and turned == 0 and under == 0,
		"story_cabin_lining_cut_exact", "area %.4f m^2 (0.374 off the glass), %d turned over, %d corners under the glass" % [area, turned, under])


## The container (its "pos") a car starts inside, if any: a stack or a terminal's block (its whole
## footprint), both in the shot's anchor frame (x left, z ahead; a car's "left" / "ahead" on a straight
## line), a car taken as 2 m round (Tibor's rally car once stood inside a stack of them).
static func _in_container(car: Dictionary, props: Array) -> Array:
	var at := Vector2(float(car.get("left", 0.0)), float(car.get("ahead", 0.0)))
	for p: Dictionary in props:
		var half := Vector2(StoryProps.CONTAINER.x, StoryProps.CONTAINER.z) * 0.5          # a stack
		match String(p.get("kind", "")):
			"container":
				pass
			"containers":                  # a terminal's block: its whole footprint (skipped stacks or not)
				var gaps: Array = p.get("gaps", [0.3, 0.6])
				half = Vector2(int(p.get("rows", 4)) * (StoryProps.CONTAINER.x + float(gaps[0])) - float(gaps[0]),
					int(p.get("bays", 2)) * (StoryProps.CONTAINER.z + float(gaps[1])) - float(gaps[1])) * 0.5
			_:
				continue
		var pos: Array = p.get("pos", [0, 0, 0])
		var local := (at - Vector2(float(pos[0]), float(pos[2]))).rotated(deg_to_rad(float(p.get("yaw", 0.0))))
		if absf(local.x) < half.x + 1.0 and absf(local.y) < half.y + 2.0:
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
	# the track's parts hidden, their collision off; the ground and the city stay
	var shown := []
	var solid := 0
	var parts := 0
	for n in bs._stage.find_children("*", "", true, false):
		if String(n.name) in ["Blocks", "RoadDecals", "NeonLights"]:
			parts += 1
			if (n as Node3D).visible:
				shown.append(String(n.name))
			for b in n.find_children("*", "CollisionObject3D", true, false):
				if (b as CollisionObject3D).collision_layer != 0:
					solid += 1
	var bcar := bs._cars.get("hero", {}).get("node", null) as Node3D
	var terrain := bs._stage.find_child("Terrain", true, false) as Node3D
	var hidden_ok := parts >= 2 and shown.is_empty() and solid == 0 and terrain != null and terrain.visible
	TestHooks.check(hidden_ok and bs._stage_track == "F04" and bcar != null
		and absf(bs._anchor.origin.y - TmMapBuilder.GROUND_Y) < 0.3, "story_shot_bare",
		"stage %s, track parts %d, still shown %s, still solid %d, terrain %s; anchor at %s (ground %.1f)" % [bs._stage_track,
		parts, shown, solid, terrain != null and terrain.visible, bs._anchor.origin, TmMapBuilder.GROUND_Y])
	# and back on the track: shown and solid again, the same stage (no rebuild)
	var stage := bs._stage
	bs._set_bare(false)
	var back := 0
	for n in bs._stage.find_children("Blocks", "", true, false):
		if (n as Node3D).visible:
			for b in n.find_children("*", "CollisionObject3D", true, false):
				if (b as CollisionObject3D).collision_layer != 0:
					back += 1
	TestHooks.check(back > 0 and bs._stage == stage, "story_shot_bare_switches_back", "solid track bodies again %d, same stage %s" % [back, bs._stage == stage])
	# "bare": "set": the field's towers hidden and not solid too, the shot on a level deck SET_DECK up
	bs._set_bare("set")
	var towers := bs._stage.find_child("FieldCity", true, false) as Node3D
	var tower_solid := 0
	if towers != null:
		for b in towers.find_children("*", "CollisionObject3D", true, false):
			tower_solid += int((b as CollisionObject3D).collision_layer != 0)
	var deck := bs._road_xf(0.5, 3.0, 10.0).origin.y
	bs._set_bare(false)
	var towers_back := towers != null and towers.visible
	TestHooks.check(towers != null and tower_solid == 0 and towers_back and is_equal_approx(deck, TmMapBuilder.GROUND_Y + StoryScene.SET_DECK),
		"story_shot_set", "the field's towers %s, solid %d (0), back after %s; a place on the line at %.2f (deck %.2f)" % [
		"found" if towers != null else "missing", tower_solid, towers_back, deck, TmMapBuilder.GROUND_Y + StoryScene.SET_DECK])
	# "env": a shot's night air over the map's own, and the map's own back on a shot without it
	var env := (bs._stage.find_child("Environment", true, false) as WorldEnvironment).environment
	var base := [env.fog_density, env.fog_light_color, env.fog_sky_affect, env.fog_height, env.fog_height_density]
	bs._set_env({"fog": 0.0009, "fog_colour": "#1c1020", "fog_sky": 0.4, "height_fog": [40.0, 0.01], "exposure": 1.3})
	var set_ok := is_equal_approx(env.fog_density, 0.0009) and env.fog_light_color.is_equal_approx(Color("#1c1020")) \
		and is_equal_approx(env.fog_sky_affect, 0.4) and is_equal_approx(env.fog_height, 40.0) and is_equal_approx(bs._attrs.exposure_multiplier, 1.3)
	bs._set_env({})
	var back_ok := [env.fog_density, env.fog_light_color, env.fog_sky_affect, env.fog_height, env.fog_height_density] == base \
		and is_equal_approx(bs._attrs.exposure_multiplier, 1.0)
	TestHooks.check(set_ok and back_ok, "story_shot_env", "set %s (fog %.4f), the map's own back %s (fog %.5f)" % [set_ok, env.fog_density, back_ok, base[0]])
	bs.queue_free()
	await get_tree().process_frame


## A rear-view mirror on the cabin's glass: the reflection camera is the driver's eyes mirrored in
## the glass's plane, looking out towards the back; a shot with a glass mirror puts that camera's
## picture on the glass (no flat picture on the screen) and the next shot without a mirror stops
## the camera; a light with "car" rides in it; "looks" turns the eyes to the mirror only then, and
## "mirror" finds the cabin's glass in a shot without a mirror too; the soaked passenger's water
## falls with the car.
func _mirror_glass() -> void:
	var cab := StoryCabin.make("nemesis")
	var r := cab.reflection()
	var e := cab.driver_head
	var m := cab.mirror_point
	var n := cab.mirror_normal
	var pos: Vector3 = r["pos"]
	var out := (m - e) - 2.0 * (m - e).dot(n) * n                 # the eyes' ray off the glass
	TestHooks.check(absf(pos.distance_to(m) - e.distance_to(m)) < 0.001 and absf(((pos + e) * 0.5 - m).dot(n)) < 0.001
		and (m - pos).normalized().dot(out.normalized()) > 0.9999 and out.z < 0.0 and float(r["fov"]) > 5.0 and float(r["fov"]) < 20.0,
		"story_mirror_reflection", "eyes %s, camera %s, ray out %s, fov %.1f" % [e, pos, out.normalized(), float(r["fov"])])
	cab.free()
	var car := {"id": "c", "model": "nemesis", "cabin": true, "speed": 20.0}
	var drv := {"id": "drv", "car": "c", "seat": "driver", "clip": "Driving", "who": "kit", "looks": [[1.0, 2.0, "mirror"]]}
	var d := {"id": "glass_test", "shots": [
		{"id": "g", "dur": 3.0, "cars": [car.duplicate()], "people": [drv.duplicate(true),
			{"id": "pas", "car": "c", "seat": "rear", "clip": "Sitting_Idle", "who": "passenger", "look": "drowned"}],
			"lights": [{"car": "c", "kind": "omni", "pos": [0.05, 1.0, 0.75], "energy": 0.5, "range": 1.6, "shadow": false}],
			"camera": {"keys": [{"u": 0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]}]},
			"mirror": {"glass": true, "follow": "c"}},
		{"id": "h", "dur": 3.0, "cars": [car.duplicate()], "people": [{"id": "drv", "car": "c", "seat": "driver", "clip": "Driving", "who": "kit", "gaze": "mirror"}],
			"camera": {"keys": [{"u": 0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]}]}}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.5)
	var cabin := sc._cars["c"]["cabin"] as StoryCabin
	var gm := cabin.mirror_glass.material_override as StandardMaterial3D
	var want := cabin.global_transform * (cabin.reflection()["pos"] as Vector3)
	var on_glass := gm != null and gm.albedo_texture == sc._mirror_vp.get_texture()
	var cam_ok := sc._mirror_cam.global_position.distance_to(want) < 0.001 and sc._mirror_vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS
	var hidden := (sc._mirror_cam.cull_mask & (1 << (StoryCabin.MIRROR_LAYER - 1))) == 0 and cabin.mirror_glass.layers == 1 << (StoryCabin.MIRROR_LAYER - 1)
	var overlay := sc.subtitles == null or sc.subtitles._mirror_frame == null or not sc.subtitles._mirror_frame.visible
	TestHooks.check(on_glass and cam_ok and hidden and overlay, "story_mirror_on_the_glass",
		"on the glass %s, camera at the reflected eyes %s (%s vs %s), mirror out of its own picture %s, no flat mirror %s" % [
		on_glass, cam_ok, sc._mirror_cam.global_position, want, hidden, overlay])
	# the riding light: in the cabin, where it was put, however far the car has driven
	var light: OmniLight3D = null
	for l in cabin.find_children("*", "OmniLight3D", true, false):
		if (l as Node3D).position.is_equal_approx(Vector3(0.05, 1.0, 0.75)):
			light = l
	var p1 := cabin.global_position
	sc.seek(2.5)
	var rides := light != null and cabin.global_position.distance_to(p1) > 30.0 \
		and light.global_position.distance_to(cabin.global_transform * Vector3(0.05, 1.0, 0.75)) < 0.001
	TestHooks.check(rides, "story_light_rides_in_the_car", "a light in the cabin %s; the car drove %.1f m" % [light != null, cabin.global_position.distance_to(p1)])
	# looks: the eyes on the glass from 1 s to 2 s only; no drips off someone seated in a car (in a dark
	# cabin they read as rain falling inside it), and the roof's shield keeps the scene's rain out
	var drv_p := _find(sc, "drv")
	var pas := _find(sc, "pas")
	sc.seek(1.5)
	var during: Variant = sc._gaze_of(drv_p, sc.shots[0])
	var glass_then := cabin.mirror_glass.global_position
	sc.seek(2.5)
	var after: Variant = sc._gaze_of(drv_p, sc.shots[0])
	var drips := pas.find_children("*", "GPUParticles3D", true, false)
	var shield := cabin.get_node_or_null("RainShield") as GPUParticlesCollisionBox3D
	TestHooks.check(during is Vector3 and (during as Vector3).distance_to(glass_then) < 0.001 and after == null
		and drips.is_empty() and shield != null, "story_looks_and_drips",
		"eyes during the look %s, after %s; drips off the seated figure %d; the cabin's rain shield %s" % [
		during, after, drips.size(), shield != null])
	# the next shot has no mirror: its camera stops; "mirror" still finds the cabin's glass
	sc.seek(4.0)
	var cabin2 := sc._cars["c"]["cabin"] as StoryCabin
	var g2: Variant = sc._gaze_of(_find(sc, "drv"), sc.shots[1])
	TestHooks.check(sc._mirror_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED and g2 is Vector3
		and (g2 as Vector3).distance_to(cabin2.mirror_glass.global_position) < 0.001, "story_mirror_off_without_one",
		"mirror camera %d (disabled %d); eyes on %s" % [sc._mirror_vp.render_target_update_mode, SubViewport.UPDATE_DISABLED, g2])
	sc.queue_free()
	await get_tree().process_frame


## Arch 9's viaduct: built with Dee's arch at its origin (its bulb, its number), and a train that
## crosses the deck at the shot's time, out of sight before it sets off.
func _viaduct() -> void:
	var root := Node3D.new()
	add_child(root)
	StoryProps.build(root, [{"kind": "viaduct", "pos": [0.0, 0.0, 0.0], "arches": 2, "train": [1.0, 24.0]}], Transform3D())
	var train: Node3D = root.find_child("Train", true, false)
	var label: Label3D = root.find_children("*", "Label3D", true, false)[0] if not root.find_children("*", "Label3D", true, false).is_empty() else null
	StoryProps.pose(root, 0.5)
	var before := train != null and not train.visible
	StoryProps.pose(root, 7.0)
	var half := StoryProps.SPAN * 2.5          # arches 2: five spans, the deck from -22.5 to +22.5
	# the train runs from x - 71.5 (the last car's tail) to x + 10 (the first car's nose): over the deck
	var crossing := train != null and train.visible and train.position.x + 10.0 > -half and train.position.x - 71.5 < half
	TestHooks.check(before and crossing and label != null and label.text == "ARCH 9" and not root.find_children("*", "OmniLight3D", true, false).is_empty(),
		"story_viaduct_and_train", "train hidden before it sets off %s, over the deck at 7 s %s (x %s), sign %s" % [before, crossing,
		train.position.x if train else 0.0, label.text if label else "none"])
	root.free()


## A cut resets physics interpolation through the scene (the project interpolates physics: without it a
## cut's first frame drew the camera between the two shots), and a seek within a shot doesn't: a probe
## node in the scene counts the resets it is told of (headless, nothing is drawn to compare).
func _cut_snaps() -> void:
	var d := {"id": "cut_test", "shots": [
		{"id": "a", "dur": 1.0, "camera": {"keys": [{"u": 0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]}]}},
		{"id": "b", "dur": 1.0, "camera": {"keys": [{"u": 0, "pos": [40.0, 10.0, -30.0], "look": [0.0, 1.0, 0.0]}]}}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	var gd := GDScript.new()
	gd.source_code = "extends Node\nvar resets := 0\nfunc _notification(what: int) -> void:\n\tif what == NOTIFICATION_RESET_PHYSICS_INTERPOLATION:\n\t\tresets += 1\n"
	gd.reload()
	var probe := Node.new()
	probe.set_script(gd)
	sc.add_child(probe)
	sc.seek(0.5)
	var at_a := int(probe.get("resets"))
	sc.seek(0.7)                          # within the shot
	var within := int(probe.get("resets")) - at_a
	sc.seek(1.5)                          # the cut
	var at_cut := int(probe.get("resets")) - at_a - within
	TestHooks.check(within == 0 and at_cut >= 1, "story_cut_resets_interpolation",
		"resets within a shot %d (0), at the cut %d (1)" % [within, at_cut])
	sc.queue_free()
	await get_tree().process_frame


## A terminal's block and a mast (StoryProps): the block's stacks (one MultiMesh), the same again from
## the same seed; the mast's spot pointing down.
func _terminal() -> void:
	# through JSON, as a scene file reads it (its numbers floats: a skip list of ints never matched them)
	var spec: Dictionary = JSON.parse_string('{"kind": "containers", "rows": 3, "bays": 2, "stack": [2, 2], "seed": 5, "skip": [[0, 0]]}')
	var root := Node3D.new()
	add_child(root)
	StoryProps.build(root, [spec, {"kind": "mast", "pos": [10.0, 0.0, 0.0], "height": 28}], Transform3D())
	var mmis := root.find_children("*", "MultiMeshInstance3D", true, false)
	var mm: MultiMesh = (mmis[0] as MultiMeshInstance3D).multimesh if mmis.size() == 1 else null
	var again := Node3D.new()
	add_child(again)
	StoryProps.build(again, [spec], Transform3D())
	var mm2: MultiMesh = (again.find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D).multimesh
	var same := mm != null and mm2.instance_count == mm.instance_count
	for i in (mm.instance_count if mm != null else 0):
		same = same and mm.get_instance_transform(i) == mm2.get_instance_transform(i) and mm.get_instance_custom_data(i) == mm2.get_instance_custom_data(i)
	# a gap punched in the block leaves every other stack as it was (each stack its own seed)
	var whole := Node3D.new()
	add_child(whole)
	var full := spec.duplicate(true)
	full.erase("skip")
	StoryProps.build(whole, [full], Transform3D())
	var mm3: MultiMesh = (whole.find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D).multimesh
	var kept := {}
	for i in mm3.instance_count:
		kept[str(mm3.get_instance_transform(i).origin) + str(mm3.get_instance_custom_data(i))] = true
	var stays := mm != null and mm3.instance_count == mm.instance_count + 2
	for i in (mm.instance_count if mm != null else 0):
		stays = stays and kept.has(str(mm.get_instance_transform(i).origin) + str(mm.get_instance_custom_data(i)))
	whole.free()
	var spots := root.find_children("*", "SpotLight3D", true, false)
	var down := spots.size() == 1 and (spots[0] as Node3D).global_basis.z.dot(Vector3.UP) > 0.99   # a spot shines along its -z
	TestHooks.check(mm != null and mm.instance_count == 10 and same and stays and down, "story_terminal_and_mast",
		"%d boxes (10: five stacks of two, one skipped), same from the same seed %s, the rest as without the gap %s, the mast's light down %s" % [
		mm.instance_count if mm != null else -1, same, stays, down])
	root.free()
	again.free()


## The scene's own props in a shot without any, none where a shot says "props": []; a car's "finish";
## the "rear" gaze behind the driver.
func _scene_props() -> void:
	var d := {"id": "props_test", "props": [{"kind": "container", "pos": [6.0, 0.0, 0.0], "stack": 2}], "shots": [
		{"id": "a", "dur": 1.0, "cars": [{"id": "c", "model": "nemesis", "cabin": true, "finish": "gloss"}],
			"people": [{"id": "drv", "car": "c", "seat": "driver", "clip": "Driving", "who": "kit", "gaze": "rear"}],
			"camera": {"keys": [{"u": 0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]}]}},
		{"id": "b", "dur": 1.0, "props": [], "camera": {"keys": [{"u": 0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]}]}}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.5)
	var boxes_a := sc._props.find_children("*", "MultiMeshInstance3D", true, false).size()
	var paint: Variant = (sc._cars["c"]["node"] as TmCarVisual)._mats.get("road_paint", null)
	var finish_ok: bool = not (paint is ShaderMaterial) or (paint as ShaderMaterial).get_shader_parameter("finish") == TmCarVisual.FINISHES["gloss"]
	var cabin := sc._cars["c"]["cabin"] as StoryCabin
	var g: Variant = sc._gaze_of(_find(sc, "drv"), sc.shots[0])
	var local: Vector3 = cabin.global_transform.affine_inverse() * (g as Vector3) if g is Vector3 else Vector3.INF
	var rear_ok := g is Vector3 and local.z < cabin.driver_head.z - 0.3 and absf(local.x) < 0.2
	sc.seek(1.5)
	var boxes_b := 0
	for n in sc._props.find_children("*", "MultiMeshInstance3D", true, false):
		boxes_b += int(not n.is_queued_for_deletion() and not n.get_parent().is_queued_for_deletion())
	TestHooks.check(boxes_a == 1 and boxes_b == 0 and finish_ok and rear_ok, "story_scene_props_finish_rear",
		"the scene's props in a shot without any %d (1), in one with [] %d (0); the paint's finish gloss %s (%s); the rear gaze at %s (behind the eyes at z %.2f)" % [
		boxes_a, boxes_b, finish_ok, "HD" if paint is ShaderMaterial else "plain paint", local, cabin.driver_head.z])
	sc.queue_free()


## What is wrong with a scene's or shot's "grade" (a preset's name, or a dictionary of known keys).
func _grade_bad(g: Variant) -> Array[String]:
	var out: Array[String] = []
	if g == null:
		return out
	var dd: Dictionary = {"preset": g} if g is String else (g as Dictionary if g is Dictionary else {"preset": str(g)})
	for k: String in dd:
		if k == "preset":
			if not StorySubtitles.GRADES.has(String(dd[k])):
				out.append("no preset %s" % dd[k])
		elif not (StorySubtitles.GRADES["none"] as Dictionary).has(k):
			out.append("no key %s" % k)
		elif k in ["shadows", "highlights"] and not Color.html_is_valid(String(dd[k])):
			out.append("%s %s is not a colour" % [k, dd[k]])
	return out


## The film finish: a shot's grade over its scene's, presets, and when the finish's picture shows.
func _grade() -> void:
	var film := StorySubtitles.grade_of(null, null)
	var night := StorySubtitles.grade_of("night", null)
	var over := StorySubtitles.grade_of("night", {"grain": 0.0})
	var none := StorySubtitles.grade_of("night", "none")
	var dawn := StorySubtitles.grade_of({"preset": "dawn", "lift": 0.03}, null)
	var keys_ok := true
	for g: Dictionary in [film, night, over, none, dawn]:
		keys_ok = keys_ok and g.size() == (StorySubtitles.GRADES["none"] as Dictionary).size()
	var maths := is_equal_approx(float(film["grain"]), 0.025) and is_equal_approx(float(night["streak"]), 0.25) \
		and float(over["grain"]) == 0.0 and is_equal_approx(float(over["streak"]), 0.25) \
		and float(none["vignette"]) == 0.0 and float(none["lift"]) == 0.0 and is_equal_approx(float(dawn["lift"]), 0.03) \
		and is_equal_approx(float(dawn["saturation"]), 0.85)
	var sub := StorySubtitles.new()
	add_child(sub)
	await get_tree().process_frame
	sub.set_grade(none)
	var off := not sub._film.visible
	sub.set_glass(0.5, 1.0)
	var rain := sub._film.visible
	sub.set_glass(0.0, 1.0)
	sub.set_grade(film)
	var on := sub._film.visible
	sub.set_cctv({"label": "CAM 2"}, 0.0, 1.0)
	var cctv := not sub._film.visible
	sub.set_cctv({}, 0.0, 1.0)
	var back := sub._film.visible
	sub.queue_free()
	TestHooks.check(keys_ok and maths and off and rain and on and cctv and back, "story_grade",
		"every key in every grade %s; presets and keys over them %s; the picture off with none %s, on for rain %s, on with film %s, off under a security camera %s and back after it %s" % [
		keys_ok, maths, off, rain, on, cctv, back])


## The camera engine: a spline through its keys, a hand-held camera's wander (small, the same frame
## whichever way it is reached), the near blur pulled between two keys.
func _camera_engine() -> void:
	var keys := [{"u": 0.0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]},
		{"u": 0.5, "pos": [3.0, 1.5, 4.0], "look": [0.0, 1.0, 0.0]},
		{"u": 1.0, "pos": [6.0, 1.5, 0.0], "look": [0.0, 1.0, 0.0]}]
	var d := {"id": "cam_test", "shots": [
		{"id": "spline", "dur": 2.0, "camera": {"path": "spline", "ease": "linear", "keys": keys}},
		{"id": "held", "dur": 2.0, "camera": {"handheld": 0.5, "keys": [keys[0]]}},
		{"id": "still", "dur": 2.0, "camera": {"keys": [keys[0]]}},
		{"id": "pull", "dur": 2.0, "camera": {"ease": "linear", "keys": [
			{"u": 0.0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0], "dof_near": [1.0, 0.5, 0.2]},
			{"u": 1.0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0], "dof_near": [3.0, 1.0]}]}}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(1.0)
	var mid := sc.camera.global_position.distance_to(sc._anchor * Vector3(3.0, 1.5, 4.0))
	sc.seek(0.5)
	var off_line := absf((sc._anchor.affine_inverse() * sc.camera.global_position).z - lerpf(6.0, 4.0, 0.5)) > 0.01 \
		or absf((sc._anchor.affine_inverse() * sc.camera.global_position).x - 1.5) > 0.01
	sc.seek(4.5)
	var still := sc.camera.global_basis
	sc.seek(2.5)
	var held_a := sc.camera.global_basis
	sc.seek(3.4)
	sc.seek(2.5)
	var held_b := sc.camera.global_basis
	var wander := rad_to_deg(acos(clampf((-held_a.z).dot(-still.z), -1.0, 1.0)))
	var same := held_a.is_equal_approx(held_b)
	sc.seek(7.0)
	var near_ok := sc._attrs.dof_blur_near_enabled and is_equal_approx(sc._attrs.dof_blur_near_distance, 2.0) \
		and is_equal_approx(sc._attrs.dof_blur_near_transition, 0.75) and is_equal_approx(sc._attrs.dof_blur_amount, 0.2)
	sc.seek(4.5)
	var none_ok := not sc._attrs.dof_blur_near_enabled
	TestHooks.check(mid < 0.01 and off_line and wander > 0.01 and wander < 1.0 and same and near_ok and none_ok, "story_camera_engine",
		"the spline through its middle key %.3f m off (0), curved between keys %s; hand-held %.2f deg off the still aim (0-1 for 0.5), the same frame again %s; the near blur pulled %s (%.2f m, 2), off without it %s" % [
		mid, off_line, wander, same, near_ok, sc._attrs.dof_blur_near_distance, none_ok])
	sc.queue_free()
	await get_tree().process_frame


## The scene's props stand over a cut to a shot that keeps them on the same spot (not rebuilt), while
## each shot's own lights go with it (they don't pile up under the props kept).
func _props_kept() -> void:
	var cam := {"keys": [{"u": 0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]}]}
	var lights := [{"kind": "omni", "pos": [0.0, 3.0, 0.0]}, {"kind": "softbox", "pos": [0.0, 4.0, 0.0], "look": [0.0, 0.0, 0.0]}]
	var d := {"id": "kept_test", "props": [{"kind": "container", "pos": [6.0, 0.0, 0.0]}], "shots": [
		{"id": "a", "dur": 1.0, "camera": cam, "lights": lights}, {"id": "b", "dur": 1.0, "camera": cam, "lights": lights,
			"probe": {"pos": [0.0, 2.0, 0.0]}}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.5)
	var first := sc._props.get_child(0) if sc._props.get_child_count() > 0 else null
	sc.seek(1.5)
	await get_tree().process_frame
	var live := 0
	for n in sc._lights.get_children():
		live += int(not n.is_queued_for_deletion())
	var hidden := sc.camera.cull_mask & StoryScene.SOFTBOX_LAYER == 0
	TestHooks.check(first != null and sc._props.get_child(0) == first and sc._props.get_child_count() == 1 and live == 3 and hidden,
		"story_props_kept", "the scene's props the same node after the cut %s (%d under them); the second shot's lights %d (3: omni, softbox, probe); softboxes hidden from the camera %s" % [
		first != null and sc._props.get_child(0) == first, sc._props.get_child_count(), live, hidden])
	sc.queue_free()
	await get_tree().process_frame


## A person's "lift": stood that much over the ground they'd be dropped onto (a crouch at a car window).
func _lifted() -> void:
	var d := {"id": "lift_test", "shots": [{"id": "a", "dur": 1.0, "camera": {"keys": [{"u": 0, "pos": [0.0, 1.5, 6.0], "look": [0.0, 1.0, 0.0]}]},
		"people": [{"id": "low", "clip": "Idle", "pos": [1.0, 0.0, 0.0]}, {"id": "up", "clip": "Idle", "pos": [-1.0, 0.0, 0.0], "lift": 0.42}]}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.5)
	var rise := _find(sc, "up").global_position.y - _find(sc, "low").global_position.y
	TestHooks.check(is_equal_approx(snappedf(rise, 0.001), 0.42), "story_person_lift", "lifted %.3f m (0.42)" % rise)
	sc.queue_free()
	await get_tree().process_frame


## A person's "reach": hands put where the keys say, in a car's road frame ("reach_car"), palms facing
## as asked; a hand the next key leaves out eased back to the clip (the knock's Dee, leaning on the door).
func _reached() -> void:
	var roof_l := Vector3(0.82, 0.883, 0.4)        # the coupe's door top under its window, either side of her
	var roof_r := Vector3(0.82, 0.895, -0.2)
	var d := {"id": "reach_test", "shots": [{"id": "a", "dur": 3.0, "bare": true,
		"camera": {"keys": [{"u": 0, "pos": [4.0, 1.5, 3.0], "look": [0.0, 1.0, 0.0]}]},
		"cars": [{"id": "kit", "model": "nemesis"}],
		"people": [{"id": "dee", "who": "dee", "clip": "Stand", "pos": [1.48, 0.0, 0.1], "face": -90, "reach_car": "kit",
			"bend": [{"t": 0.0, "Hips": [46, 0, 0], "LeftUpperLeg": [-46, 0, 0], "RightUpperLeg": [-46, 0, 0], "Spine": [8, 0, 0]}],
			"reach": [{"t": 0.0, "LeftHand": {"at": [roof_l.x, roof_l.y, roof_l.z], "palm": [0, -1, 0], "fingers": [-1, 0, 0]},
				"RightHand": [roof_r.x, roof_r.y, roof_r.z]}, {"t": 1.0, "LeftHand": {"at": [roof_l.x, roof_l.y, roof_l.z],
				"palm": [0, -1, 0], "fingers": [-1, 0, 0]}, "RightHand": [roof_r.x, roof_r.y, roof_r.z]},
				{"t": 2.0, "LeftHand": {"at": [roof_l.x, roof_l.y, roof_l.z], "palm": [0, -1, 0], "fingers": [-1, 0, 0]}}]}]}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.5)
	var xf: Transform3D = sc._cars["kit"]["xf"]
	var dee := _find(sc, "dee")
	var sk := StoryCast.skeleton(dee)
	var skin := func(side: String) -> Vector3:     # the palm's skin: its middle, the hand's half thickness out
		var f := StoryPerson._hand_frame(sk, side)
		return sk.global_transform * ((f["palm"] as Vector3) + (f["normal"] as Vector3) * StoryPerson.PALM_HALF)
	var off_l: float = (skin.call("Left") as Vector3).distance_to(xf * roof_l)
	var off_r: float = (skin.call("Right") as Vector3).distance_to(xf * roof_r)
	var hf := StoryPerson._hand_frame(sk, "Left")
	var down := (sk.global_transform.basis * (hf["normal"] as Vector3)).normalized().dot(-(xf.basis.y.normalized()))
	sc.seek(2.5)                                   # the right hand let go: back where the clip has it, hanging
	var hang := dee.palm_point("Right").distance_to(xf * roof_r)
	TestHooks.check(off_l < 0.015 and off_r < 0.015 and down > 0.9 and hang > 0.3, "story_person_reach",
		"palms' skin %.3f / %.3f m off their marks on the door (under 0.015); the left palm down %.2f (over 0.9); the right hand let go %.2f m from its mark (over 0.3)" % [
		off_l, off_r, down, hang])
	sc.queue_free()
	await get_tree().process_frame


## A cabin car's "windows_down": the driver's door glass (+x, the road frame's left) split out of the
## body, up before its span and wound down into the door after it; the passenger's left alone.
func _windows() -> void:
	var d := {"id": "windows_test", "shots": [{"id": "a", "dur": 2.0, "bare": true,
		"camera": {"keys": [{"u": 0, "pos": [4.0, 1.5, 3.0], "look": [0.0, 1.0, 0.0]}]},
		"cars": [{"id": "kit", "model": "nemesis", "cabin": true, "windows_down": {"driver": [0.5, 1.5]}}]}]}
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(d, StoryState.new(), false)
	sc.seek(0.2)
	var car := sc._cars["kit"]["node"] as Node
	var mine := car.find_children("Window_driver", "MeshInstance3D", true, false)
	var other := car.find_children("Window_passenger", "MeshInstance3D", true, false)
	var piece := mine[0] as MeshInstance3D if not mine.is_empty() else null
	var box := piece.mesh.get_aabb() if piece != null else AABB()
	var up := piece.position.y if piece != null else 1.0
	sc.seek(1.9)
	var down := piece.position.y if piece != null else 0.0
	TestHooks.check(piece != null and other.is_empty() and box.position.x > 0.5 and absf(up) < 0.001 and down < -0.3,
		"story_windows_down", "the driver's glass split out %s (x %.2f-%.2f: over 0.5), none for the passenger %s; %.3f m down before its span, %.3f after (under -0.3)" % [
		piece != null, box.position.x, box.end.x, other.is_empty(), up, down])
	sc.queue_free()
	await get_tree().process_frame


func _find(sc: Node, id: String) -> StoryPerson:
	for n in sc.find_children("*", "", true, false):
		if n is StoryPerson and String((n as StoryPerson).spec.get("id", "")) == id and not n.is_queued_for_deletion():
			return n
	return null


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

