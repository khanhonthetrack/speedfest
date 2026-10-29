extends Node
## Looks at a cutscene (PLAN M20-3): --scene=<id> (story/scenes/<id>.json; --file=<abs path> for one
## kept elsewhere) seeked to --t=<s> and held there for the screenshot (--frames=N --shot=/abs.png;
## give SDFGI and the city a few dozen frames), or --play [--t=<s>] plays it on from there to its
## end at the fixed frame rate and quits (headless tests; --hold=N holds the first frame N frames
## before it plays, for a clip's light to settle: tools/clip.sh --skip cuts them). --flags=a,b,c sets those flags on the save
## the conditions read (--tier=hot: enough facts for it; --ways=c01=3 the finish taken on a night, for
## a "way:" condition); --no_stage leaves the tracks out (logic
## only); --grade=<StorySubtitles.GRADES name> one film finish over the whole scene (none: the bare
## picture, for a before and after). Prints the scene's timeline. Several stills in one run (the city and SDFGI built once):
## --ts=8.5,14,25 --every=60 holds each time for that many frames; give TestHooks
## --shots=/abs/a.png@59,/abs/b.png@119,... to match, and --frames=180 to quit after the last.
## --probe=t1,t2,... (headless is enough) prints where everyone's eyes, head and hands are at those
## times in a car's road frame (--car=<id>, default kit: a shot's camera keys' frame) and quits.

var scene: StoryScene


func _ready() -> void:
	var id := String(TestHooks.arg("scene", ""))
	var d := StoryScene.load_data(id)
	if TestHooks.has_arg("file"):            # a scene file anywhere (a debug set-up kept out of the story)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(TestHooks.arg("file", ""))))
		d = parsed if parsed is Dictionary else {}
		id = String(d.get("id", "file"))
	if d.is_empty():
		push_error("story_lab: no scene %s" % id)
		TestHooks.fail("story_scene_loads", id)
		TestHooks.finish()
		return
	if TestHooks.has_arg("grade"):           # one look over the whole scene (--grade=none: the bare picture)
		d["grade"] = String(TestHooks.arg("grade", "film"))
		for sh: Dictionary in d.get("shots", []):
			sh.erase("grade")
	var st := StoryState.new()
	for f in String(TestHooks.arg("flags", "")).split(",", false):
		st.flags[f] = true
	for w in String(TestHooks.arg("ways", "")).split(",", false):
		st.decisions[w.get_slice("=", 0)] = {"way": int(w.get_slice("=", 1)), "exit": ""}
	var tier := String(TestHooks.arg("tier", ""))
	for i in (st.hot if tier == "hot" else (st.warm if tier == "warm" else 0)):
		st.flags["fact_lab%d" % i] = true
	scene = StoryScene.new()
	add_child(scene)
	scene.setup(d, st, not TestHooks.has_arg("no_stage"))
	var lines := 0
	for s: Dictionary in scene.shots:
		lines += (s["lines"] as Array).size()
		print("SHOT %s %.2f-%.2f s, %d lines" % [s.get("id", "?"), s["start"], s["end"], (s["lines"] as Array).size()])
	print("SCENE %s %.1f s, %d shots, %d lines" % [id, scene.length, scene.shots.size(), lines])
	await get_tree().physics_frame
	if TestHooks.has_arg("probe"):
		await _probe(String(TestHooks.arg("car", "kit")), String(TestHooks.arg("probe", "")).split(",", false))
		TestHooks.finish()
		return
	var at := float(TestHooks.arg("t", 0.0))
	if TestHooks.has_arg("play"):
		scene.finished.connect(func(skipped: bool) -> void:
			print("SCENE_END %s at %.2f s%s" % [id, scene.t, " (skipped)" if skipped else ""])
			TestHooks.ok("story_scene_plays_" + id)
			TestHooks.finish())
		# a clip's first frames: the city and its light settle on the first frame before it plays
		scene.seek(at)
		for k in int(TestHooks.arg("hold", 0)):
			await get_tree().process_frame
			scene.seek(at)
		scene.play(at)
	else:
		scene.seek(at)
		set_process(true)


var _frame := 0


func _probe(car: String, times: PackedStringArray) -> void:
	for ts in times:
		scene.seek(float(ts))
		await get_tree().physics_frame
		scene.seek(float(ts))
		if not scene._cars.has(car):
			print("PROBE t=%s no car %s: the world's frame" % [ts, car])
		var xf: Transform3D = scene._cars[car].get("xf", Transform3D()) if scene._cars.has(car) else Transform3D()
		var inv := xf.affine_inverse()
		for p: StoryPerson in scene._people:
			if not p.visible:
				continue
			var line := "PROBE t=%s %s eyes %s" % [ts, p.spec.get("id", "?"), _v(inv * p.eyes_point())]
			var sk := StoryCast.skeleton(p)
			if sk != null:
				for b: String in ["Head", "RightHand", "LeftHand"]:
					var i := sk.find_bone(b)
					if i >= 0:
						line += " %s %s" % [b, _v(inv * (sk.global_transform * sk.get_bone_global_pose(i)).origin)]
				var hi := sk.find_bone("Head")
				if hi >= 0:     # where the face points (the head's up and forward, in the car's frame)
					var hb := inv.basis * (sk.global_basis * sk.get_bone_global_pose(hi).basis)
					line += " head_y %s head_z %s" % [_v(hb.y.normalized()), _v(hb.z.normalized())]
			if p.face != null:
				line += " eyes_out_l %.2f in_l %.2f out_r %.2f in_r %.2f up %.2f down %.2f" % [p.face.shape("eyeLookOutLeft"),
					p.face.shape("eyeLookInLeft"), p.face.shape("eyeLookOutRight"), p.face.shape("eyeLookInRight"),
					p.face.shape("eyeLookUpLeft"), p.face.shape("eyeLookDownLeft")]
			if scene._shot >= 0:
				var g: Variant = scene._gaze_of(p, scene.shots[scene._shot])
				if g is Vector3:
					line += " gaze %s" % _v(inv * (g as Vector3))
			print(line)


func _v(p: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [p.x, p.y, p.z]


func _process(_delta: float) -> void:
	_frame += 1
	if scene != null and not scene.playing:
		var ts := String(TestHooks.arg("ts", "")).split(",", false)
		if not ts.is_empty():
			var k := mini(_frame / int(TestHooks.arg("every", 60)), ts.size() - 1)
			scene.seek(float(ts[k]))
		else:
			scene.seek(scene.t)        # held on its frame (the road's collision arrives a frame late)
