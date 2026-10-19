extends Node
## TMNF's Select Opponent: the medal ghosts (TmMedalGhost: our bot's run on the track, slowed to each
## medal's time) arrive at the finish on the medal's time, along the bot's line; the dialog lists the
## medals and None and picking one sets the race's ghost.


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TmRecords.clear()
	TestHooks.args["track"] = String(TestHooks.arg("track", "A01"))
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	while not scene.ready_to_race:
		await get_tree().physics_frame
	var ch: TmChallenge = scene.challenge
	var t0 := Time.get_ticks_msec()
	var run := TmMedalGhost.bot_run(scene)
	var took := Time.get_ticks_msec() - t0
	TestHooks.check(run != null and run.finish_ms > 0 and run.finish_ms <= ch.gold_ms + 2000, "bot_run_finishes",
		"%s ms (gold %d), driven in %d ms" % [run.finish_ms if run else -1, ch.gold_ms, took])
	print("bot run %d ms, driven in %d ms" % [run.finish_ms if run else -1, took])
	var again := TmMedalGhost.bot_run(scene)
	TestHooks.check(again == run, "bot_run_kept")
	var silver := TmMedalGhost.at_time(run, ch.silver_ms)
	var end_a: Vector3 = (run.sample(run.finish_ms)["xform"] as Transform3D).origin
	var end_b: Vector3 = (silver.sample(silver.finish_ms)["xform"] as Transform3D).origin
	var mid_a: Vector3 = (run.sample(run.finish_ms * 0.5)["xform"] as Transform3D).origin
	var mid_b: Vector3 = (silver.sample(silver.finish_ms * 0.5)["xform"] as Transform3D).origin
	TestHooks.check(silver.finish_ms == ch.silver_ms and end_a.distance_to(end_b) < 0.5 and mid_a.distance_to(mid_b) < 0.5,
		"medal_ghost_on_time", "%d ms, ends %.2f m apart, halfway %.2f m" % [silver.finish_ms, end_a.distance_to(end_b), mid_a.distance_to(mid_b)])
	scene.set_opponent("bronze")
	TestHooks.check(scene.best_ghost != null and scene.best_ghost.finish_ms == ch.bronze_ms, "opponent_bronze")
	scene.set_opponent("none")
	TestHooks.check(scene.best_ghost == null, "opponent_none")
	# the dialog: the medals and None, the race waiting while it is up
	var opts: Array = scene._opponent_options()
	scene.menu.show_opponents(opts, "bronze")
	await get_tree().process_frame
	var names := (scene.menu as TmRaceMenu)._box.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	TestHooks.check(scene.menu.choosing and get_tree().paused and names.has("Gold Medal") and names.has("Silver Medal")
		and names.has("Bronze Medal") and names.has("None"), "opponent_dialog", str(names))
	var rows := (scene.menu as TmRaceMenu)._box.find_children("*", "Button", true, false)
	(rows[0] as Button).pressed.emit()
	TestHooks.check(not scene.menu.choosing and not get_tree().paused and scene.opponent == "gold"
		and scene.best_ghost != null and scene.best_ghost.finish_ms == ch.gold_ms, "opponent_picked", scene.opponent)
	scene.queue_free()
	TmRecords.clear()
	TestHooks.finish()
