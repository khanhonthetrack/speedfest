extends Node
## Online (needs Node.js; skipped without it): the stadium server started with short rounds on
## the game's own tracks, the Online client joins, races the round's track in online mode, sees a
## second player's car from the positions the server relays, reports a finish that the server
## ranks, and follows the server to the next round's track.

const PORT := 18091
var _pid := -1


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	var node := _node()
	var script := ProjectSettings.globalize_path("res://server/server.js")
	if node.is_empty() or not FileAccess.file_exists(script) or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://server/node_modules/ws")):
		TestHooks.ok("online_skipped_no_node_or_ws")
		TestHooks.finish()
		return
	_pid = OS.create_process(node, [script, "--port=%d" % PORT, "--round-ms=6000", "--results-ms=1500", "--name=Test"])
	await _wait(func() -> bool: return _up(), 8000)
	Online.join("127.0.0.1:%d" % PORT, "Tester", Color(0.1, 0.35, 0.9))
	var ok := await _wait(func() -> bool: return Online.is_online(), 8000)
	TestHooks.check(ok and Online.server_name == "Test", "online_joins", "%s" % Online.server_name)
	if ok:
		var trk := String(Online.round.get("track", ""))
		TestHooks.check(TmTracks.has(trk) and Online.players.size() == 1 and int(Online.players[0]["id"]) == Online.my_id,
			"online_round_and_players", "%s %s" % [trk, Online.players])
		TestHooks.check(absf(Online.time_left_ms() - 6000) < 1500, "online_clock", "%d" % Online.time_left_ms())
		await _race(trk)
	Online.leave()
	OS.kill(_pid)
	TestHooks.finish()


func _race(trk: String) -> void:
	TestHooks.args["track"] = trk
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	await _wait(func() -> bool: return scene.ready_to_race, 20000)
	TestHooks.check(scene.online != null and scene.menu.online, "online_race_mode")
	# a second player, by hand: its car shows up where it says it is
	var other := WebSocketPeer.new()
	other.connect_to_url("ws://127.0.0.1:%d/ws" % PORT)
	await _wait(func() -> bool:
		other.poll()
		return other.get_ready_state() == WebSocketPeer.STATE_OPEN, 5000)
	other.send_text(JSON.stringify({"t": "hello", "name": "Other", "version": Online.VERSION}))
	var at: Vector3 = scene.car.global_position + Vector3(0, 0, 6)
	var seen := await _wait(func() -> bool:
		other.poll()
		while other.get_available_packet_count() > 0:
			other.get_packet()
		other.send_text(JSON.stringify({"t": "state", "p": [at.x, at.y, at.z], "q": [0, 0, 0, 1], "v": 0, "s": 0}))
		for c in scene.get_children():
			if String(c.name).begins_with("Player") and (c as Node3D).global_position.distance_to(at) < 0.5:
				return true
		return false, 6000)
	TestHooks.check(seen, "online_sees_other_player")
	# our finish is ranked by the server
	scene.online.on_finish(42000)
	var ranked := await _wait(func() -> bool:
		return Online.players.any(func(p: Dictionary) -> bool: return int(p["id"]) == Online.my_id and int(p["best"]) == 42000), 5000)
	TestHooks.check(ranked, "online_finish_ranked")
	# the round ends: results, then the next round's track is loaded
	var first := int(Online.round.get("id", -1))
	var next := await _wait(func() -> bool: return int(Online.round.get("id", -1)) > first and String(Online.round.get("state", "")) == "race", 12000)
	TestHooks.check(next and Online.ranking.size() >= 1 and int(Online.ranking[0]["time"]) == 42000, "online_results", str(Online.ranking))
	TestHooks.check(next and scene.pending_track == String(Online.round["track"]), "online_next_track", "%s / %s" % [scene.pending_track, Online.round.get("track")])
	other.close()
	scene.queue_free()


func _up() -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", PORT) != OK:
		return false
	for i in 20:
		tcp.poll()
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			tcp.disconnect_from_host()
			return true
		OS.delay_msec(10)
	return false


func _wait(cond: Callable, ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return false


static func _node() -> String:
	for p in ["node", "C:/Program Files/nodejs/node.exe", "/usr/bin/node", "/usr/local/bin/node"]:
		var out := []
		if OS.execute(p, ["--version"], out) == 0:
			return p
	return ""
