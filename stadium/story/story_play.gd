extends Node
## Story mode's player (PLAN M20-5): takes the save (StoryState, user://story.json; --story_new=<
## difficulty> starts a new one) through StoryFlow one step at a time: a cutscene plays here
## (StoryScene), a map goes to the race scene (race.gd with --story: CONTINUE comes back here), the
## next night is chosen here (the routed one by itself, or a board), and the end shows the ending.
## --story_auto (tests): every map taken as beaten at its time to beat on finish --story_way (or the
## main way), every choice the first offered, every scene skipped: a whole save plays headless.

var graph: StoryGraph
var state: StoryState
var flow: StoryFlow
var _layer: CanvasLayer
var steps := 0


func _ready() -> void:
	TmUi.apply()
	graph = StoryGraph.load_file()
	state = StoryState.load_file()
	if state == null or TestHooks.has_arg("story_new"):
		state = StoryState.create(graph, String(TestHooks.arg("story_new", "street")), Time.get_datetime_string_from_system(false, true))
	flow = StoryFlow.new(graph, state)
	_layer = CanvasLayer.new()
	add_child(_layer)
	_step.call_deferred()


func _step() -> void:
	steps += 1
	for c in _layer.get_children():
		c.queue_free()
	var st := flow.next()
	state.save()
	print("STORY_STEP %s" % JSON.stringify(st))
	match String(st["kind"]):
		"scene":
			_scene(String(st["id"]))
		"race":
			_race(st)
		"choose":
			_choose(st)
		_:
			_end(String(st.get("ending", "")))


func _scene(id: String) -> void:
	var sc := StoryScene.new()
	add_child(sc)
	sc.setup(StoryScene.load_data(id), state, not TestHooks.has_arg("story_auto"))
	sc.finished.connect(func(_skipped: bool) -> void:
		flow.scene_done(id)
		sc.queue_free()
		_step.call_deferred())
	await get_tree().physics_frame
	if TestHooks.has_arg("story_auto"):
		sc.skip()
	else:
		sc.play()


func _race(st: Dictionary) -> void:
	var track := String(st["track"])
	var map := int(st["map"])
	if TestHooks.has_arg("story_auto"):
		var ch := TmTracks.challenge(track)
		var way := clampi(int(TestHooks.arg("story_way", 0)), 0, maxi(0, ch.ways() - 1)) if map == 2 else 0
		var ms := graph.target_for(ch, way, state.difficulty) if ch.ok() else 30000
		flow.map_done(map, track, ms if ms > 0 else 30000, way)
		_step.call_deferred()
		return
	TestHooks.args["track"] = track
	TestHooks.args["story"] = String(st["night"])
	TestHooks.args["story_map"] = str(map)
	TestHooks.args["return_page"] = "main"
	TmLoading.change_scene(get_tree(), "res://race/race.tscn")


func _choose(st: Dictionary) -> void:
	var opts: Array = st["options"]
	if opts.size() == 1 or TestHooks.has_arg("story_auto"):
		flow.begin(String(opts[0]))
		_step.call_deferred()
		return
	# the board: a night per row, its title and where it happens
	var root := _panel("Where to tonight?")
	for id: Variant in opts:
		var c := graph.chapter(String(id))
		var label := String(c.get("title", id))
		if not String(c.get("place", "")).is_empty():
			label += "   ·   " + String(c["place"])
		root.add_child(SfUi.button(label, func() -> void:
			flow.begin(String(id))
			_step.call_deferred(), 520, String(id) == String(opts[0])))


func _end(ending: String) -> void:
	var title := String(graph.ending_info(ending).get("title", "The end"))
	var root := _panel(title)
	root.add_child(SfUi.button("Back to the menu", func() -> void: get_tree().change_scene_to_file("res://ui/menu.tscn"), 320, true))
	if TestHooks.has_arg("story_auto"):
		print("STORY_END %s after %d steps, nights %s" % [ending, steps, state.done])
		TestHooks.check(not ending.is_empty(), "story_plays_to_an_ending", "%d steps" % steps)
		TestHooks.finish()


func _panel(title: String) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = SfUi.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)
	box.add_child(SfUi.title(title))
	return box
