extends Node
## Looks at a cutscene (PLAN M20-3): --scene=<id> (story/scenes/<id>.json; --file=<abs path> for one
## kept elsewhere) seeked to --t=<s> and held there for the screenshot (--frames=N --shot=/abs.png;
## give SDFGI and the city a few dozen frames), or --play [--t=<s>] plays it on from there to its
## end at the fixed frame rate and quits (headless tests). --flags=a,b,c sets those flags on the save
## the conditions read (--tier=hot: enough facts for it); --no_stage leaves the tracks out (logic
## only). Prints the scene's timeline. Several stills in one run (the city and SDFGI built once):
## --ts=8.5,14,25 --every=60 holds each time for that many frames; give TestHooks
## --shots=/abs/a.png@59,/abs/b.png@119,... to match.

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
	var st := StoryState.new()
	for f in String(TestHooks.arg("flags", "")).split(",", false):
		st.flags[f] = true
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
	var at := float(TestHooks.arg("t", 0.0))
	if TestHooks.has_arg("play"):
		scene.finished.connect(func(skipped: bool) -> void:
			print("SCENE_END %s at %.2f s%s" % [id, scene.t, " (skipped)" if skipped else ""])
			TestHooks.ok("story_scene_plays_" + id)
			TestHooks.finish())
		scene.play(at)
	else:
		scene.seek(at)
		set_process(true)


var _frame := 0


func _process(_delta: float) -> void:
	_frame += 1
	if scene != null and not scene.playing:
		var ts := String(TestHooks.arg("ts", "")).split(",", false)
		if not ts.is_empty():
			var k := mini(_frame / int(TestHooks.arg("every", 60)), ts.size() - 1)
			scene.seek(float(ts[k]))
		else:
			scene.seek(scene.t)        # held on its frame (the road's collision arrives a frame late)
