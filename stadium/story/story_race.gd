class_name StoryRace
extends RefCounted
## A story night's map in the race scene (PLAN M20-5; race.gd with --story=<night> --story_map=0..2):
## the time to beat is the bot's author time on the finish crossed x the save's difficulty
## (StoryGraph.target_for), shown where the medals are; at the finish the panel says whether the run
## beat it, and on the third map which decision that finish makes (its exit's label). CONTINUE
## records the run in the save (StoryFlow.map_done: on map 3 it is the decision) and goes back to
## the story (story/story_play.tscn). Nothing here touches the race's simulation.

const PLAY := "res://story/story_play.tscn"

var graph: StoryGraph
var state: StoryState
var night := ""
var map := 0
var targets: Array[int] = []       ## per way
var track := ""
var _passed := {}                  ## the last finish: {ms, way} when it beat its target


static func make(ch: TmChallenge, track_id: String) -> StoryRace:
	var s := StoryRace.new()
	s.graph = StoryGraph.load_file()
	s.state = StoryState.load_file()
	if s.state == null:
		s.state = StoryState.create(s.graph, String(TestHooks.arg("story_difficulty", "street")))
	s.night = String(TestHooks.arg("story", ""))
	s.map = int(TestHooks.arg("story_map", 0))
	s.track = track_id
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


## Adds the story's side to the finish panel's result.
func finish(result: Dictionary, ms: int, way: int) -> void:
	var t := target(way)
	var ok := t > 0 and ms <= t
	result["medals"] = {"gold": t}
	result["story"] = {"pass": ok, "target": t, "map": map}
	if map == 2:
		var exit := graph.exit_of(night, way)
		result["way_label"] = "Decision: %s" % String(exit.get("label", "finish %d" % (way + 1)))
	_passed = {"ms": ms, "way": way} if ok else {}


func can_go_on() -> bool:
	return not _passed.is_empty()


## CONTINUE: the run goes into the save, then back to the story.
func go_on(tree: SceneTree) -> void:
	if _passed.is_empty():
		return
	var flow := StoryFlow.new(graph, state)
	flow.map_done(map, track, int(_passed["ms"]), int(_passed["way"]))
	state.save()
	for k in ["story", "story_map", "track"]:
		TestHooks.args.erase(k)
	if tree != null:
		tree.change_scene_to_file(PLAY)
