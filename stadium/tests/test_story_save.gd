extends Node
## A story save (StoryState; PLAN M20-2): it lives where --story_save says (never the player's own
## user://story.json in a test), saves and loads back the same, keeps the difficulty it was made
## with and applies it to the targets, keeps the best time per map and way, and a decision sets its
## exit's flags and the night's fact, marks the night done and (on the finale) the ending.


func _ready() -> void:
	TestHooks.args["story_save"] = "user://test_story/story.json"
	TestHooks.check(StoryState.path() == "user://test_story/story.json", "story_save_path_from_args")
	if FileAccess.file_exists(StoryState.path()):
		DirAccess.remove_absolute(StoryState.path())
	var g := StoryGraph.load_file()
	TestHooks.check(g.ok(), "story_json_loads")
	var diff := String(g.difficulties()[1]["id"])
	var s := StoryState.create(g, diff, "2026-10-23 12:00:00")
	var first := g.choices(s)[0]
	s.begin(first)
	TestHooks.check(s.record_time("H01", 0, 25000) and not s.record_time("H01", 0, 26000) and s.record_time("H01", 0, 24500)
		and s.record_time("H03", 1, 30000) and s.best_time("H01") == 24500 and s.best_time("H03", 1) == 30000
		and s.best_time("H03", 0) == -1, "story_best_time_per_way")
	s.map_done(0)
	s.map_done(1)
	TestHooks.check(s.step == 2, "story_maps_advance", "%d" % s.step)
	var exit := g.exit_of(first, 2)
	s.decide(g, 2)
	var sets: Array = exit.get("set", [])
	TestHooks.check(s.is_done(first) and int(s.decisions[first]["way"]) == 2 and String(s.decisions[first]["exit"]) == String(exit["id"])
		and sets.all(func(f: String) -> bool: return s.flags.has(f)) and s.flags.has(String(g.chapter(first)["fact"])) and s.step == 3,
		"story_decision_sets_flags", "%s %s" % [s.decisions, s.flags])
	s.close_night()
	s.seen_scenes["%s_open" % first] = true
	s.car = {"model": "kobold", "livery": 2}
	TestHooks.check(s.save(), "story_saves")
	TestHooks.check(StoryState.exists(), "story_save_exists")
	var back := StoryState.load_file()
	TestHooks.check(back != null and JSON.stringify(back.to_dict()) == JSON.stringify(s.to_dict()), "story_save_round_trip",
		"%s\nvs %s" % [back.to_dict() if back else {}, s.to_dict()])
	TestHooks.check(back != null and back.difficulty == diff and back.tier() == s.tier() and back.holds("done:" + first),
		"story_save_keeps_difficulty_and_knowledge")
	# the difficulty applies to the time to beat
	var ch := TmChallenge.new()
	ch.author_ms = 20000
	var easy := g.target_for(ch, 0, String(g.difficulties()[0]["id"]))
	var hard := g.target_for(ch, 0, String(g.difficulties()[-1]["id"]))
	TestHooks.check(easy > hard and hard >= 20000 and g.target_for(ch, 0, back.difficulty) == StoryGraph.target_ms(20000,
		float(g.difficulty(back.difficulty)["gold"])), "story_difficulty_sets_target", "%d %d" % [easy, hard])
	# the finale's decision gives an ending
	var f := StoryState.create(g, diff)
	f.begin(g.finale())
	f.decide(g, 0)
	TestHooks.check(f.complete() and f.endings.size() == 1 and not g.ending_info(f.endings[0]).is_empty(), "story_finale_gives_an_ending",
		str(f.endings))
	TestHooks.check(StoryState.load_file("user://test_story/none.json") == null, "story_missing_save_is_null")
	DirAccess.remove_absolute(StoryState.path())
	TestHooks.finish()
