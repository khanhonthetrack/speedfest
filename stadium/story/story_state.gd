class_name StoryState
extends RefCounted
## A story save (PLAN M20): the difficulty chosen when it was made, the night being played and how
## far into it, the nights done and in what order, every decision (the finish crossed and its
## exit), the flags they set (what the player knows and did), the best time on each map's ways,
## the endings seen. One file, user://story.json (tests: --story_save=<path>), so a test never
## touches the player's own progress.
##
## Conditions (scene lines, endings; holds()): null or "" always; "flag" set; "!flag" not set;
## "done:c03" / "!done:c03" a night played or not; "way:c03=2" the finish taken on c03;
## "tier=cold|warm|hot" how much the player knows (facts(), StoryGraph's "tiers");
## "facts>=3", "facts<3" the count itself; "count:dark_>=5" how many flags start with a prefix
## (>=, <=, >, <, =); an Array: all of them; {"any": [...]}, {"all": [...]},
## {"not": condition}.

const PATH := "user://story.json"
const VERSION := 1

var difficulty := ""
var current := ""                 ## the night being played ("": between nights, on the board)
var step := 0                     ## in it: 0 before map 1, 1 / 2 maps done, 3 decided (its close scene next)
var done: Array[String] = []      ## nights finished, in the order played
var decisions := {}               ## night -> {way, exit (its id)}
var flags := {}                   ## flag -> true
var times := {}                   ## track id -> {"<way>": best ms}
var endings: Array[String] = []   ## endings seen (in this save)
var seen_scenes := {}             ## scene id -> true (the journal replays them)
var car := {}                     ## the car this save drives ({model, livery, tuning}; {}: the player's own)
var started := ""                 ## when the save was made (local time, as the caller gives it)
var warm := 3                     ## facts for the warm and hot tiers (StoryGraph's "tiers")
var hot := 7


## Where the save lives.
static func path() -> String:
	return String(TestHooks.arg("story_save", PATH))


static func exists() -> bool:
	return FileAccess.file_exists(path())


## A new save at a difficulty (its tiers from the graph).
static func create(graph: StoryGraph, difficulty_id: String, when := "") -> StoryState:
	var s := StoryState.new()
	s.difficulty = difficulty_id
	s.started = when
	var t: Dictionary = graph.data.get("tiers", {})
	s.warm = int(t.get("warm", 3))
	s.hot = int(t.get("hot", 7))
	return s


static func load_file(from := "") -> StoryState:
	var p := from if not from.is_empty() else path()
	var text := FileAccess.get_file_as_string(p)
	var d: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not d is Dictionary:
		return null
	return from_dict(d)


static func from_dict(d: Dictionary) -> StoryState:
	var s := StoryState.new()
	s.difficulty = String(d.get("difficulty", ""))
	s.current = String(d.get("current", ""))
	s.step = int(d.get("step", 0))
	for id: Variant in d.get("done", []):
		s.done.append(String(id))
	s.decisions = _ints(d.get("decisions", {}))
	for k: Variant in d.get("flags", {}):
		s.flags[String(k)] = true
	s.times = _ints(d.get("times", {}))
	for e: Variant in d.get("endings", []):
		s.endings.append(String(e))
	for k: Variant in d.get("seen_scenes", {}):
		s.seen_scenes[String(k)] = true
	s.car = _ints(d.get("car", {}))
	s.started = String(d.get("started", ""))
	s.warm = int(d.get("warm", 3))
	s.hot = int(d.get("hot", 7))
	return s


## JSON reads every number as a float: whole ones back to ints (times, ways, liveries).
static func _ints(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)) and absf(v) < 9.0e15:
		return int(v)
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _ints(x))
	return v


func to_dict() -> Dictionary:
	return {"version": VERSION, "difficulty": difficulty, "current": current, "step": step, "done": done,
		"decisions": decisions, "flags": flags, "times": times, "endings": endings, "seen_scenes": seen_scenes,
		"car": car, "started": started, "warm": warm, "hot": hot}


func save(to := "") -> bool:
	var p := to if not to.is_empty() else path()
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return true


# --- progress ------------------------------------------------------------------------------

func is_done(id: String) -> bool:
	return id in done


## Starts a night (from the board or a decision).
func begin(id: String) -> void:
	current = id
	step = 0


## A finished run on a map's way: kept if it is that way's best. Returns true for a new best.
func record_time(track: String, way: int, ms: int) -> bool:
	if ms <= 0:
		return false
	var t: Dictionary = times.get(track, {})
	var k := str(way)
	if t.has(k) and int(t[k]) <= ms:
		return false
	t[k] = ms
	times[track] = t
	return true


func best_time(track: String, way := 0) -> int:
	return int((times.get(track, {}) as Dictionary).get(str(way), -1))


## Map 1 or 2 of the current night beaten: on to the next.
func map_done(index: int) -> void:
	step = maxi(step, index + 1)


## The decision on the current night's third map: the finish crossed (its exit's flags set),
## the night done, its fact learnt.
func decide(graph: StoryGraph, way: int) -> void:
	var id := current
	var exit := graph.exit_of(id, way)
	decisions[id] = {"way": way, "exit": String(exit.get("id", ""))}
	for f: Variant in exit.get("set", []):
		flags[String(f)] = true
	var fact := String(graph.chapter(id).get("fact", ""))
	if not fact.is_empty():
		flags[fact] = true
	if not id in done:
		done.append(id)
	step = 3
	if id == graph.finale():
		var e := graph.ending(self, way)
		if not e.is_empty() and not e in endings:
			endings.append(e)


## After the night's close scene: back between nights.
func close_night() -> void:
	current = ""
	step = 0


func complete() -> bool:
	return not endings.is_empty()


# --- what the player knows -----------------------------------------------------------------

## Facts known: flags named fact_*.
func facts() -> int:
	var n := 0
	for k: String in flags:
		if k.begins_with("fact_"):
			n += 1
	return n


func tier() -> String:
	var n := facts()
	return "hot" if n >= hot else ("warm" if n >= warm else "cold")


func holds(cond: Variant) -> bool:
	if cond == null:
		return true
	if cond is Array:
		for c: Variant in cond:
			if not holds(c):
				return false
		return true
	if cond is Dictionary:
		var d := cond as Dictionary
		if d.has("any"):
			for c: Variant in d["any"]:
				if holds(c):
					return true
			return false
		if d.has("all"):
			return holds(d["all"])
		if d.has("not"):
			return not holds(d["not"])
		return true
	var s := String(cond).strip_edges()
	if s.is_empty():
		return true
	if s.begins_with("!"):
		return not holds(s.substr(1))
	if s.begins_with("done:"):
		return is_done(s.substr(5))
	if s.begins_with("way:"):
		var kv := s.substr(4).split("=")
		return kv.size() == 2 and decisions.has(kv[0]) and int(decisions[kv[0]]["way"]) == int(kv[1])
	if s.begins_with("tier="):
		return tier() == s.substr(5)
	if s.begins_with("count:"):
		# "count:dark_>=5": how many flags start with that prefix
		var m := RegEx.create_from_string("^count:([A-Za-z0-9_]+?)(>=|<=|>|<|=)(\\d+)$").search(s)
		if m == null:
			return false
		var n := 0
		for k: String in flags:
			if k.begins_with(m.get_string(1)):
				n += 1
		var want := int(m.get_string(3))
		match m.get_string(2):
			">=": return n >= want
			"<=": return n <= want
			">": return n > want
			"<": return n < want
			_: return n == want
	if s.begins_with("facts>="):
		return facts() >= int(s.substr(7))
	if s.begins_with("facts<"):
		return facts() < int(s.substr(6))
	return flags.has(s)
