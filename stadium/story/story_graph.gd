class_name StoryGraph
extends RefCounted
## Story mode's chapters and how they join (PLAN M20, docs/STORY_MODE_PROMPT.md): ten nights, each
## three maps (tracks/H*.json), the third with 3-5 finishes. The finish a run crosses there is the
## night's decision and picks the next night. Loaded from story/story.json. Pure data and rules, no
## scene and no save (StoryState holds the player's progress), so the whole graph can be proved
## headless over every ordering (tests/test_story_graph).
##
## story.json: {"version", "title",
##   "start": [chapter ids a new save may open with: one is a fixed first night, several a choice],
##   "prologue": a scene played once, before the first night,
##   "finale": id, "finale_after": n (other nights done before the finale opens),
##   "finale_mode": "offer" (once open, offered beside the next night) | "route" (the next decision
##     goes there),
##   "choice": "route" (the finish decides; the board only when a map's exits are all played) |
##     "free" (the board offers every night not yet played as well),
##   "tiers": {"warm": n, "hot": n} (facts known for each tier of dialogue: cold below warm),
##   "difficulties": [{"id", "name", "gold" (target = the bot's author time x this), "note"}],
##   "chapters": [{"id", "title", "place", "fact" (the flag its night gives), "journal" (what Kit
##     writes down once the fact is known: the Story page's journal), "tracks": [3 ids],
##     "ready": true once its tracks are made (validate(true) checks them),
##     "scenes": {"open", "after1", "after2", "decision", "close"} (story/scenes/<id>.json),
##     "exits": [{"way" (the finish: 0 the main way, k + 1 the track's k-th fork or split), "id",
##       "label" (the decision, as the finish menu says it), "to": id | [ids, preferred first],
##       "set": [flags], "dark": bool (the colder choice, whose line is the fast one)}]
##     the finale's exits: {"way", "id", "label", "set", "endings": [{"id", "if": condition}]}],
##   "endings": [{"id", "title", "scene"}]}
## Conditions: StoryState.holds().

const PATH := "res://story/story.json"

var data := {}
var errors: Array[String] = []
var _by_id := {}


static func load_file(path := PATH) -> StoryGraph:
	var g := StoryGraph.new()
	var text := FileAccess.get_file_as_string(path)
	var d: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not d is Dictionary:
		g.errors.append("%s: not a story file" % path)
		return g
	g.setup(d)
	return g


## From a parsed story.json (tests build their own).
func setup(d: Dictionary) -> void:
	data = d
	_by_id.clear()
	for c: Dictionary in d.get("chapters", []):
		_by_id[String(c.get("id", ""))] = c


func ok() -> bool:
	return errors.is_empty()


func ids() -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in data.get("chapters", []):
		out.append(String(c["id"]))
	return out


func chapter(id: String) -> Dictionary:
	return _by_id.get(id, {})


func has(id: String) -> bool:
	return _by_id.has(id)


func finale() -> String:
	return String(data.get("finale", ""))


## The nights that are not the finale.
func regular() -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if id != finale():
			out.append(id)
	return out


func finale_after() -> int:
	return int(data.get("finale_after", regular().size()))


func starts() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in data.get("start", []):
		out.append(String(id))
	return out


## A chapter's exit for the finish `way` ({} if it has none).
func exit_of(id: String, way: int) -> Dictionary:
	for e: Dictionary in chapter(id).get("exits", []):
		if int(e.get("way", -1)) == way:
			return e
	return {}


## The chapters an exit prefers, in order.
static func targets(exit: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var to: Variant = exit.get("to", [])
	if to is String:
		out.append(to)
	else:
		for t: Variant in to:
			out.append(String(t))
	return out


# --- difficulty ----------------------------------------------------------------------------

func difficulties() -> Array:
	return data.get("difficulties", [])


func difficulty(id: String) -> Dictionary:
	for d: Dictionary in difficulties():
		if String(d.get("id", "")) == id:
			return d
	return {}


## The time to beat on a map's way: the bot's author time there x the difficulty's multiplier,
## rounded up to 10 ms (the race clock's tick). -1 without an author time.
static func target_ms(author_ms: int, multiplier: float) -> int:
	if author_ms <= 0:
		return -1
	return int(ceil(author_ms * multiplier / 10.0 - 1e-6)) * 10


## The target on a track's way for a save's difficulty (the track's per-way author time,
## TmChallenge.medals_of).
func target_for(ch: TmChallenge, way: int, difficulty_id: String) -> int:
	var d := difficulty(difficulty_id)
	return target_ms(int(ch.medals_of(way)["author"]), float(d.get("gold", 1.06)))


# --- routing -------------------------------------------------------------------------------

func finale_open(state: StoryState) -> bool:
	var n := 0
	for id in regular():
		if state.is_done(id):
			n += 1
	return n >= finale_after()


## Where a decision leads: the exit's own chapter if it isn't played yet, else the next it prefers,
## then the other exits' chapters of the same map, still unplayed. "" when every one of them is
## played: the player picks on the board (choices()). Never a chapter already done, never the
## finale (it opens by count, finale_open()).
func route(state: StoryState, from: String, way: int) -> String:
	var seen := {}
	var order: Array[String] = targets(exit_of(from, way))
	for e: Dictionary in chapter(from).get("exits", []):
		if int(e.get("way", -1)) != way:
			order.append_array(targets(e))
	for id in order:
		if seen.has(id):
			continue
		seen[id] = true
		if id != from and id != finale() and has(id) and not state.is_done(id):
			return id
	return ""


## The nights the player may go to after deciding `way` on `from` (or, from = "", before the first
## night): the routed one first. The board (every night not yet played) when routing runs out or
## the story's choice is "free"; the finale once open ("offer": beside the others, "route": alone).
func choices(state: StoryState, from := "", way := 0) -> Array[String]:
	var out: Array[String] = []
	if from.is_empty():
		for id in starts():
			if has(id) and not state.is_done(id):
				out.append(id)
		if out.is_empty():
			out = _board(state)
		return out
	var fin := finale()
	var open := finale_open(state) and not state.is_done(fin) and has(fin)
	if open and String(data.get("finale_mode", "offer")) == "route":
		out.append(fin)
		return out
	var routed := route(state, from, way)
	if not routed.is_empty():
		out.append(routed)
	if routed.is_empty() or String(data.get("choice", "route")) == "free":
		for id in _board(state):
			if not id in out:
				out.append(id)
	if open:
		out.append(fin)
	return out


## Every night not yet played (the finale apart).
func _board(state: StoryState) -> Array[String]:
	var out: Array[String] = []
	for id in regular():
		if not state.is_done(id):
			out.append(id)
	return out


## The ending a finale decision earns: the first of its exit's endings whose condition holds.
func ending(state: StoryState, way: int) -> String:
	for e: Dictionary in exit_of(finale(), way).get("endings", []):
		if state.holds(e.get("if", null)):
			return String(e.get("id", ""))
	return ""


func ending_info(id: String) -> Dictionary:
	for e: Dictionary in data.get("endings", []):
		if String(e.get("id", "")) == id:
			return e
	return {}


# --- checks --------------------------------------------------------------------------------

## What is wrong with the story's data (tests/test_story_graph): missing chapters, exits that go
## nowhere or back to their own night, a map 3 without 3-5 exits, ways given twice, a finale that
## can never open, unknown endings. tracks: also check that every ready night's tracks exist and its
## third has a finish per exit.
func validate(tracks := false) -> Array[String]:
	var out: Array[String] = []
	var all := ids()
	if all.size() != _by_id.size():
		out.append("chapter ids repeat")
	var fin := finale()
	if not has(fin):
		out.append("the finale %s is not a chapter" % fin)
	if finale_after() > regular().size() or finale_after() < 1:
		out.append("finale_after %d with %d other nights" % [finale_after(), regular().size()])
	if starts().is_empty():
		out.append("no start")
	for s in starts():
		if not has(s) or s == fin:
			out.append("start %s is not a night" % s)
	var ending_ids := {}
	for e: Dictionary in data.get("endings", []):
		ending_ids[String(e.get("id", ""))] = true
	for id in all:
		var c := chapter(id)
		var ex: Array = c.get("exits", [])
		if (c.get("tracks", []) as Array).size() != 3:
			out.append("%s: %d tracks, not 3" % [id, (c.get("tracks", []) as Array).size()])
		if ex.size() < 3 or ex.size() > 5:
			out.append("%s: %d exits, not 3-5" % [id, ex.size()])
		var ways := {}
		for e: Dictionary in ex:
			var w := int(e.get("way", -1))
			if ways.has(w) or w < 0:
				out.append("%s: way %d given twice (or negative)" % [id, w])
			ways[w] = true
			if String(e.get("label", "")).is_empty():
				out.append("%s way %d: no label" % [id, w])
			if id == fin:
				if (e.get("endings", []) as Array).is_empty():
					out.append("%s way %d: a finale exit without endings" % [id, w])
				for en: Dictionary in e.get("endings", []):
					if not ending_ids.has(String(en.get("id", ""))):
						out.append("%s way %d: unknown ending %s" % [id, w, en.get("id", "")])
				continue
			var t := targets(e)
			if t.is_empty():
				out.append("%s way %d: goes nowhere" % [id, w])
			for to in t:
				if not has(to):
					out.append("%s way %d: to %s, not a chapter" % [id, w, to])
				elif to == id:
					out.append("%s way %d: back to its own night" % [id, w])
				elif to == fin:
					out.append("%s way %d: to the finale (it opens by count)" % [id, w])
		for k in ways.size():
			if not ways.has(k):
				out.append("%s: ways not 0..%d" % [id, ways.size() - 1])
				break
		if tracks and bool(c.get("ready", false)):
			for t: Variant in c.get("tracks", []):
				if not TmTracks.has(String(t)):
					out.append("%s: track %s missing" % [id, t])
			var last := String((c.get("tracks", [""]) as Array)[-1]) if not (c.get("tracks", []) as Array).is_empty() else ""
			if TmTracks.has(last):
				var ch := TmTracks.challenge(last)
				if ch.ways() != ex.size():
					out.append("%s: %s has %d finishes, %d exits" % [id, last, ch.ways(), ex.size()])
	return out
