class_name StoryRace
extends RefCounted
## A story night's map in the race scene (PLAN M20-5; race.gd with --story=<night> --story_map=0..2),
## played the owner's way: a **7-minute time attack** (TRANSCRIPT, session 21: "time attack of 7
## minutes, the best time with a finish decides"). Restart as often as you like; the clock runs while
## you are on the track (the countdown and the run; not the menus, not the pause); when it runs out,
## a run already under way may still finish, and then the session settles on its best run. That run
## must beat the time to beat on the finish it crossed (the bot's author time there x the save's
## difficulty, StoryGraph.target_for); on map 3 its finish is the night's decision (its exit's label).
## The cruel line is the fast one, so it pulls the best time towards it. CONTINUE writes the best run
## into the save (StoryFlow.map_done) and goes back to the story (story/story_play.tscn); TRY AGAIN
## starts a new 7 minutes. Nothing here touches the race's simulation.

const PLAY := "res://story/story_play.tscn"
const SESSION_MS := 7 * 60 * 1000
const LAST_RUN_MS := 60000         ## a run under way when time is up may go on this long

var graph: StoryGraph
var state: StoryState
var night := ""
var map := 0
var targets: Array[int] = []       ## per way
var track := ""
var session_ms := SESSION_MS
var left_ms := SESSION_MS          ## time left on the session's clock
var best := {}                     ## the session's best run: {ms, way}
var settled := false               ## the session is over (time up, or ended early)
var _label: Label
var _tick := 0


static func make(ch: TmChallenge, track_id: String) -> StoryRace:
	var s := StoryRace.new()
	s.graph = StoryGraph.load_file()
	s.state = StoryState.load_file()
	if s.state == null:
		s.state = StoryState.create(s.graph, String(TestHooks.arg("story_difficulty", "street")))
	s.night = String(TestHooks.arg("story", ""))
	s.map = int(TestHooks.arg("story_map", 0))
	s.track = track_id
	s.session_ms = int(TestHooks.arg("story_session_ms", int(s.graph.data.get("session_ms", SESSION_MS))))
	s.left_ms = s.session_ms
	for w in ch.ways():
		s.targets.append(s.graph.target_for(ch, w, s.state.difficulty))
	# the HUD's medal table shows the time to beat (the main way's) instead of the medals
	ch.gold_ms = s.targets[0] if not s.targets.is_empty() else -1
	ch.author_ms = -1
	ch.silver_ms = -1
	ch.bronze_ms = -1
	return s


func target(way: int) -> int:
	return targets[way] if way >= 0 and way < targets.size() else (targets[0] if not targets.is_empty() else -1)


func passed() -> bool:
	return not best.is_empty() and int(best["ms"]) <= target(int(best["way"]))


func expired() -> bool:
	return left_ms <= 0


## The session's clock, a race tick at a time (race.gd's _physics_process): it runs on the track;
## when it is out, a countdown is cut and a run under way gets LAST_RUN_MS more.
func tick(scene: Node) -> void:
	if settled:
		return
	var race: TmRace = scene.race
	if race.state == TmRace.State.FINISHED:
		return
	left_ms -= TmRace.TICK_MS
	if left_ms <= 0 and (race.state == TmRace.State.COUNTDOWN or left_ms <= -LAST_RUN_MS):
		settle(scene)
	_tick += 1
	if _tick % 10 == 0:
		_show(scene)


## A finished run: the session's best if it is faster; the panel's result gets the story's side.
func finish(scene: Node, result: Dictionary, ms: int, way: int) -> void:
	if not settled and (best.is_empty() or ms < int(best["ms"])):
		best = {"ms": ms, "way": way}
	_describe(result, ms, way)
	if expired() and not settled:
		settled = true
		_describe(result, int(best["ms"]), int(best["way"]))
	_show(scene)


## The session is over: the panel shows its best run (or that there was none).
func settle(scene: Node) -> void:
	if settled:
		return
	settled = true
	left_ms = mini(left_ms, 0)
	var r := {"name": scene.challenge.name, "time_ms": int(best.get("ms", -1)), "prev_ms": -1, "record": false,
		"ways": scene.challenge.ways(), "way": int(best.get("way", 0))}
	_describe(r, int(best.get("ms", -1)), int(best.get("way", 0)))
	scene.race.state = TmRace.State.FINISHED
	scene.car.controls_enabled = false
	scene.car.auto_brake = true
	scene._result = r
	scene.menu.story_state = "pass" if passed() else "fail"
	scene.menu.show_finish(r)
	_show(scene)


## Ends the session now (the finish panel's END SESSION): its best run counts.
func end_now(scene: Node) -> void:
	settle(scene)


## A new 7 minutes (TRY AGAIN): the best forgotten, the run restarted.
func new_session(scene: Node) -> void:
	settled = false
	best = {}
	left_ms = session_ms
	scene.menu.story_state = "open"
	scene.restart()


func _describe(result: Dictionary, ms: int, way: int) -> void:
	var t := target(way)
	result["medals"] = {"gold": t}
	result["story"] = {"pass": t > 0 and ms > 0 and ms <= t, "target": t, "map": map, "settled": settled,
		"best_ms": int(best.get("ms", -1)), "best_way": int(best.get("way", 0)), "left_ms": maxi(left_ms, 0)}
	if map == 2 and ms > 0:
		var exit := graph.exit_of(night, way)
		result["way_label"] = "Decision: %s" % String(exit.get("label", "finish %d" % (way + 1)))


## The clock and the best so far, over the race.
func _show(scene: Node) -> void:
	if _label == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		scene.add_child(layer)
		_label = SfUi.label("", 22, SfUi.TEXT, SfUi.BOLD, 2, true)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_label.add_theme_constant_override("shadow_outline_size", 6)
		_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_label.position = Vector2(-300, 14)
		_label.custom_minimum_size = Vector2(600, 0)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(_label)
	var clock := "time's up · last run" if expired() and not settled else ("session over" if settled else TmRace.time_text(left_ms).left(-3))
	var b := "best %s" % TmRace.time_text(int(best["ms"])) if not best.is_empty() else "no time yet"
	if not best.is_empty() and map == 2:
		b += " · " + String(graph.exit_of(night, int(best["way"])).get("label", "finish %d" % (int(best["way"]) + 1)))
	_label.text = "%s   ·   %s" % [clock, b]


## CONTINUE: the session's best run goes into the save, then back to the story.
func go_on(tree: SceneTree) -> void:
	if not settled or not passed():
		return
	var flow := StoryFlow.new(graph, state)
	flow.map_done(map, track, int(best["ms"]), int(best["way"]))
	state.save()
	for k in ["story", "story_map", "track"]:
		TestHooks.args.erase(k)
	if tree != null:
		tree.change_scene_to_file(PLAY)
