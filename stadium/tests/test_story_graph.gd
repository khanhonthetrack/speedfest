extends Node
## Story mode's chapter graph (story/story.json; PLAN M20-2), proved over every ordering:
## - the data is sound (StoryGraph.validate: every exit goes to a night that exists and isn't its
##   own, 3-5 exits per map 3, the finale's exits all end somewhere, the start a real night; with
##   the tracks made, every track exists and its third has a finish per exit);
## - exhaustively, over every state a player can reach (the nights done x the night being played,
##   every finish taken, every choice on the board): every night is reachable, no state is a dead
##   end, no night is ever offered twice, the finale is offered only once enough nights are done, a
##   decision whose own night is unplayed goes exactly there, and every path ends with the finale;
## - 10,000 random playthroughs on real saves (StoryState) all finish within the nights there are,
##   and between them reach every ending.

const WALKS := 10000


func _ready() -> void:
	var g := StoryGraph.load_file()
	TestHooks.check(g.ok(), "story_json_loads", "; ".join(g.errors))
	if not g.ok():
		TestHooks.finish()
		return
	var bad := g.validate(true)
	TestHooks.check(bad.is_empty(), "story_graph_valid", "; ".join(bad))
	TestHooks.check(g.ids().size() == 10 and g.regular().size() == 9, "story_has_ten_nights", "%d" % g.ids().size())
	_targets(g)
	_exhaustive(g)
	_walks(g)
	_hand_made()
	TestHooks.finish()


## The time to beat: the bot's author time x the difficulty, up to the clock's 10 ms.
func _targets(g: StoryGraph) -> void:
	TestHooks.check(StoryGraph.target_ms(20000, 1.18) == 23600 and StoryGraph.target_ms(15670, 1.08) == 16930
		and StoryGraph.target_ms(15670, 1.0) == 15670 and StoryGraph.target_ms(-1, 1.3) == -1, "story_target_rounds_up",
		"%d %d %d" % [StoryGraph.target_ms(20000, 1.18), StoryGraph.target_ms(15670, 1.08), StoryGraph.target_ms(15670, 1.0)])
	var mults: Array = g.difficulties().map(func(d: Dictionary) -> float: return float(d["gold"]))
	var sorted := mults.duplicate()
	sorted.sort()
	sorted.reverse()
	TestHooks.check(mults.size() >= 3 and mults == sorted and float(mults[-1]) >= 1.0, "story_difficulties_ordered", str(mults))
	# a track with two ways: each way's target from its own author time
	var ch := TmChallenge.new()
	ch.author_ms = 15000
	ch.gold_ms = 15900
	ch.alt_paths = [[]]
	ch.way_medals = [{"author": 18000, "gold": 19100, "silver": -1, "bronze": -1}, {"author": 15000, "gold": 15900, "silver": -1, "bronze": -1}]
	var id := String(g.difficulties()[0]["id"])
	var m := float(g.difficulties()[0]["gold"])
	TestHooks.check(g.target_for(ch, 0, id) == StoryGraph.target_ms(18000, m) and g.target_for(ch, 1, id) == StoryGraph.target_ms(15000, m),
		"story_target_per_way", "%d %d" % [g.target_for(ch, 0, id), g.target_for(ch, 1, id)])


## A state: the nights done (a bit each) and the night being played.
func _exhaustive(g: StoryGraph) -> void:
	var all := g.ids()
	var bit := {}
	for i in all.size():
		bit[all[i]] = 1 << i
	var fin := g.finale()
	var reached := {}             # night -> true (played as `current`)
	var positions := {}           # night -> {its place in the order (1 = the first night): true}
	var problems: Array[String] = []
	var seen := {}                # "mask:night" -> true
	var stack: Array = []
	var empty := StoryState.new()
	for s in g.choices(empty):
		stack.append([0, s])
	TestHooks.check(not stack.is_empty(), "story_has_a_first_night")
	var states := 0
	var finale_paths := 0
	var paths := {}               # "mask:night" -> number of ways to finish from here (memo)
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var mask: int = top[0]
		var night: String = top[1]
		var key := "%d:%s" % [mask, night]
		if seen.has(key):
			continue
		seen[key] = true
		states += 1
		reached[night] = true
		var place := 1
		for i in all.size():
			place += 1 if mask & (1 << i) else 0
		if not positions.has(night):
			positions[night] = {}
		positions[night][place] = true
		var st := _state_of(all, mask)
		if st.is_done(night):
			problems.append("%s offered after it was played (done %s)" % [night, st.done])
			continue
		if night == fin:
			if not g.finale_open(st):
				problems.append("the finale played with %d nights done (needs %d)" % [st.done.size(), g.finale_after()])
			continue
		var after := mask | int(bit[night])
		var st2 := _state_of(all, after)
		for e: Dictionary in g.chapter(night).get("exits", []):
			var way := int(e["way"])
			var ch := g.choices(st2, night, way)
			if ch.is_empty():
				problems.append("dead end after %s way %d (done %s)" % [night, way, st2.done])
			var own := StoryGraph.targets(e)
			if not own.is_empty() and not st2.is_done(own[0]) and own[0] != fin and (ch.is_empty() or ch[0] != own[0]) \
					and String(g.data.get("finale_mode", "offer")) != "route":
				problems.append("%s way %d: its own night %s is unplayed but the first choice is %s" % [night, way, own[0], ch])
			for c in ch:
				if st2.is_done(c):
					problems.append("%s way %d offers %s again" % [night, way, c])
				if c == fin and not g.finale_open(st2):
					problems.append("%s way %d offers the finale with %d done" % [night, way, st2.done.size()])
				stack.append([after, c])
		if problems.size() > 20:
			break
	for p in problems.slice(0, 8):
		print("STORY_GRAPH ", p)
	TestHooks.check(problems.is_empty(), "story_graph_every_state_sound", "%d problems (first above)" % problems.size())
	var missing := all.filter(func(id: String) -> bool: return not reached.has(id))
	TestHooks.check(missing.is_empty(), "story_every_night_reachable", "never reached: %s" % [missing])
	finale_paths = _count_orders(g, all, bit, 0, "", paths)
	print("STORY_GRAPH %d states, %d different orders of nights to the finale" % [states, finale_paths])
	var places := []
	var narrow: Array[String] = []
	for id in all:
		var ps: Array = (positions.get(id, {}) as Dictionary).keys()
		ps.sort()
		places.append("%s %s" % [id, ps])
		# any order: a night that isn't the fixed first one (or the finale) turns up in several places
		if id != fin and not (g.starts().size() == 1 and id == g.starts()[0]) and ps.size() < 3:
			narrow.append(id)
	print("STORY_GRAPH places: ", ", ".join(places))
	TestHooks.check(finale_paths >= 50 and narrow.is_empty(), "story_order_really_varies",
		"%d orders; nights in fewer than 3 places: %s" % [finale_paths, narrow])


## How many different orders of nights lead from here to the finale (every finish, every choice).
func _count_orders(g: StoryGraph, all: Array[String], bit: Dictionary, mask: int, night: String, memo: Dictionary) -> int:
	var key := "%d:%s" % [mask, night]
	if memo.has(key):
		return memo[key]
	var n := 0
	if night.is_empty():
		for s in g.choices(_state_of(all, 0)):
			n += _count_orders(g, all, bit, 0, s, memo)
	elif night == g.finale():
		n = 1
	else:
		var after := mask | int(bit[night])
		var st := _state_of(all, after)
		var next := {}
		for e: Dictionary in g.chapter(night).get("exits", []):
			for c in g.choices(st, night, int(e["way"])):
				next[c] = true       # different finishes to the same night: one order
		for c: String in next:
			n += _count_orders(g, all, bit, after, c, memo)
	memo[key] = n
	return n


static func _state_of(all: Array[String], mask: int) -> StoryState:
	var s := StoryState.new()
	for i in all.size():
		if mask & (1 << i):
			s.done.append(all[i])
	return s


## Random playthroughs on real saves: random finishes, random choices.
func _walks(g: StoryGraph) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026_10_23
	var endings := {}
	var bad := 0
	var longest := 0
	var why := ""
	for w in WALKS:
		var s := StoryState.create(g, String(g.difficulties()[1]["id"]))
		var next := g.choices(s)
		var nights := 0
		var finished := false
		while not next.is_empty() and nights <= g.ids().size():
			var night: String = next[rng.randi() % next.size()]
			if s.is_done(night):
				why = "walk %d: %s twice" % [w, night]
				break
			s.begin(night)
			s.map_done(0)
			s.map_done(1)
			var ex: Array = g.chapter(night).get("exits", [])
			var way := int((ex[rng.randi() % ex.size()] as Dictionary)["way"])
			s.decide(g, way)
			s.close_night()
			nights += 1
			if night == g.finale():
				finished = true
				break
			next = g.choices(s, night, way)
		longest = maxi(longest, nights)
		if not finished or s.endings.size() != 1:
			bad += 1
			if why.is_empty():
				why = "walk %d stopped after %s with choices %s, endings %s" % [w, s.done, next, s.endings]
		else:
			endings[s.endings[0]] = int(endings.get(s.endings[0], 0)) + 1
	TestHooks.check(bad == 0, "story_random_walks_finish", "%d of %d: %s" % [bad, WALKS, why])
	TestHooks.check(longest <= g.ids().size(), "story_walks_bounded", "%d nights" % longest)
	var want: Array = g.data.get("endings", []).map(func(e: Dictionary) -> String: return String(e["id"]))
	var missing := want.filter(func(e: String) -> bool: return not endings.has(e))
	print("STORY_ENDINGS %s" % endings)
	TestHooks.check(missing.is_empty(), "story_every_ending_reached", "never: %s (%s)" % [missing, endings])


## Routing rules on a small graph made here: preferences, the other exits, the board, the finale.
func _hand_made() -> void:
	var g := StoryGraph.new()
	g.setup({"start": ["a"], "finale": "z", "finale_after": 2, "finale_mode": "offer", "choice": "route",
		"chapters": [
			{"id": "a", "tracks": ["1", "2", "3"], "exits": [{"way": 0, "label": "x", "to": ["b", "c"]}, {"way": 1, "label": "y", "to": "c"},
				{"way": 2, "label": "w", "to": "b"}]},
			{"id": "b", "tracks": ["1", "2", "3"], "exits": [{"way": 0, "label": "x", "to": "a"}, {"way": 1, "label": "y", "to": "a"},
				{"way": 2, "label": "w", "to": "a"}]},
			{"id": "c", "tracks": ["1", "2", "3"], "exits": [{"way": 0, "label": "x", "to": "a"}, {"way": 1, "label": "y", "to": "b"},
				{"way": 2, "label": "w", "to": "a"}]},
			{"id": "z", "tracks": ["1", "2", "3"], "exits": [{"way": 0, "label": "x", "endings": [{"id": "e1", "if": "fact_a"}, {"id": "e2"}]},
				{"way": 1, "label": "y", "endings": [{"id": "e2"}]}, {"way": 2, "label": "w", "endings": [{"id": "e2"}]}]}],
		"endings": [{"id": "e1"}, {"id": "e2"}]})
	TestHooks.check(g.validate().is_empty(), "story_small_graph_valid", "; ".join(g.validate()))
	var s := StoryState.new()
	s.done.assign(["a"])
	TestHooks.check(g.route(s, "a", 0) == "b" and g.route(s, "a", 1) == "c", "story_route_own_night")
	s.done.assign(["a", "b"])
	TestHooks.check(g.route(s, "a", 0) == "c" and g.route(s, "a", 2) == "c", "story_route_next_preference_then_other_exits",
		"%s %s" % [g.route(s, "a", 0), g.route(s, "a", 2)])
	TestHooks.check(g.choices(s, "a", 0) == (["c", "z"] as Array[String]), "story_finale_offered_once_open", str(g.choices(s, "a", 0)))
	s.done.assign(["b", "c"])
	TestHooks.check(g.route(s, "b", 0) == "a" and g.choices(s, "b", 0).has("z"), "story_finale_beside_the_routed_night",
		str(g.choices(s, "b", 0)))
	s.done.assign(["a", "b", "c"])
	TestHooks.check(g.route(s, "c", 0) == "" and g.choices(s, "c", 0) == (["z"] as Array[String]), "story_board_when_exits_run_out",
		str(g.choices(s, "c", 0)))
	s.flags["fact_a"] = true
	TestHooks.check(g.ending(s, 0) == "e1" and g.ending(s, 1) == "e2", "story_ending_by_flags")
	s.flags.erase("fact_a")
	TestHooks.check(g.ending(s, 0) == "e2", "story_ending_falls_through")
	# conditions
	var c := StoryState.new()
	c.flags = {"fact_a": true, "fact_b": true, "fact_c": true, "dark_a": true, "met": true}
	c.decisions = {"a": {"way": 2, "exit": "a2"}}
	c.done.assign(["a"])
	TestHooks.check(c.holds("met") and not c.holds("!met") and c.holds("done:a") and not c.holds("done:b") and c.holds("way:a=2")
		and not c.holds("way:a=1") and c.holds("tier=warm") and c.holds("facts>=3") and c.holds("facts<4")
		and c.holds("count:dark_=1") and c.holds("count:dark_>=1") and not c.holds("count:dark_>1") and c.holds(["met", "done:a"])
		and not c.holds(["met", "nope"]) and c.holds({"any": ["nope", "met"]}) and c.holds({"not": "nope"}) and c.holds(null)
		and c.holds(""), "story_conditions")
	c.flags.merge({"fact_d": true, "fact_e": true, "fact_f": true, "fact_g": true})
	TestHooks.check(c.tier() == "hot" and StoryState.new().tier() == "cold", "story_tiers", c.tier())
