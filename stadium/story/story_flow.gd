class_name StoryFlow
extends RefCounted
## What comes next in a story save (PLAN M20-5): a night is its opening scene, map 1, a scene, map 2,
## a scene, map 3 (the decision: the finish crossed), the decision's scene, the closing scene, then
## the choice of the next night. Pure rules over StoryGraph and StoryState, so the menu, the race and
## the cutscene player only ask next() and report back (scene_done, map_done, decided, begin).
##
## Before the first night, the story's prologue scene (once).
## A step: {"kind": "choose", "options": [night ids], "after": night, "way": finish} (the board, or
## the routed night alone) | {"kind": "scene", "id": scene id, "night"} | {"kind": "race", "night",
## "map": 0..2, "track": id} | {"kind": "end", "ending": id} (the story is over).
## A scene id the night lacks (no file yet) is passed over, so a night plays with what exists.

const SCENES := ["open", "after1", "after2", "decision", "close"]
## The scene before each map, and the step it needs.
const BEFORE_MAP := ["open", "after1", "after2"]

var graph: StoryGraph
var state: StoryState
var exists := func(id: String) -> bool: return FileAccess.file_exists(StoryScene.path_of(id))


func _init(g: StoryGraph, s: StoryState) -> void:
	graph = g
	state = s


## The next step. When the night's last scene has played, it closes the night (StoryState.close_night)
## and goes on to the choice of the next one, or the end.
func next() -> Dictionary:
	var night := state.current
	if night.is_empty() and state.complete():
		return {"kind": "end", "ending": state.endings[-1]}
	var prologue := String(graph.data.get("prologue", ""))
	if night.is_empty() and state.done.is_empty() and _pending(prologue):
		return {"kind": "scene", "id": prologue, "night": ""}
	if night.is_empty():
		var last := state.done[-1] if not state.done.is_empty() else ""
		var way := int((state.decisions.get(last, {}) as Dictionary).get("way", 0))
		return {"kind": "choose", "options": graph.choices(state, last, way), "after": last, "way": way}
	var scenes: Dictionary = graph.chapter(night).get("scenes", {})
	if state.step < 3:
		var before := String(scenes.get(BEFORE_MAP[state.step], ""))
		if _pending(before):
			return {"kind": "scene", "id": before, "night": night}
		var tracks: Array = graph.chapter(night).get("tracks", [])
		return {"kind": "race", "night": night, "map": state.step, "track": String(tracks[state.step]) if state.step < tracks.size() else ""}
	for key in ["decision", "close"]:
		var id := String(scenes.get(key, ""))
		if _pending(id):
			return {"kind": "scene", "id": id, "night": night}
	if night == graph.finale():
		var e := state.endings[-1] if not state.endings.is_empty() else ""
		var scene := String(graph.ending_info(e).get("scene", ""))
		if _pending(scene):
			return {"kind": "scene", "id": scene, "night": night}
	# the night is over
	state.close_night()
	return next()


func _pending(id: String) -> bool:
	return not id.is_empty() and not state.seen_scenes.has(id) and exists.call(id)


## The player picked a night (from a "choose" step).
func begin(night: String) -> void:
	state.begin(night)


## A scene played (or was skipped): its flags are already set by StoryScene; marked seen here too.
func scene_done(id: String) -> void:
	state.seen_scenes[id] = true


## A map of the current night beaten (within the target for the finish it crossed): maps 1 and 2
## move on; map 3 is the decision (way: the finish crossed).
func map_done(map: int, track: String, ms: int, way := 0) -> void:
	state.record_time(track, way, ms)
	if map < 2:
		state.map_done(map)
	else:
		state.decide(graph, way)
