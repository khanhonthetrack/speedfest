extends Node
## Online (needs Node.js; skipped without it): the stadium server started with short rounds on
## the game's own tracks, the Online client joins, races the round's track in online mode, sees a
## second player's car from the positions the server relays, reports a finish that the server
## ranks, and follows the server to the next round's track. A server's admin uploads a community
## track (a .Challenge.Gbx) and plays it: the client downloads it, races it from the file and its
## finish is ranked.

const PORT := 18091


## Addresses: a bare host is its first server (/ws), the server list's /ws/<id> stays.
class TmOnlineUrls:
	const CASES := [["x:8090", "ws://x:8090/ws", "http://x:8090/status"], ["https://a.b", "wss://a.b/ws", "https://a.b/status"],
		["https://a.b/ws/rounds", "wss://a.b/ws/rounds", "https://a.b/ws/rounds/status"], ["http://1.2.3.4:8090/ws/", "ws://1.2.3.4:8090/ws", "http://1.2.3.4:8090/status"]]

	static func ok() -> bool:
		for c: Array in CASES:
			if Online.ws_url(c[0]) != c[1] or Online.status_url(c[0]) != c[2]:
				return false
		return true

	static func report() -> String:
		return str(CASES.map(func(c: Array) -> String: return "%s -> %s %s" % [c[0], Online.ws_url(c[0]), Online.status_url(c[0])]))
var _pid := -1


func _ready() -> void:
	TestHooks.args["records"] = "user://test_records"
	TestHooks.args["settings"] = "user://test_settings.cfg"     # never the player's own settings
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	TestHooks.check(TmOnlineUrls.ok(), "online_addresses", TmOnlineUrls.report())
	var node := _node()
	var script := ProjectSettings.globalize_path("res://server/server.js")
	if node.is_empty() or not FileAccess.file_exists(script) or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://server/node_modules/ws")):
		TestHooks.ok("online_skipped_no_node_or_ws")
		TestHooks.finish()
		return
	var data := ProjectSettings.globalize_path("user://test_master")
	if DirAccess.dir_exists_absolute(data):
		for f in DirAccess.get_files_at(data):
			DirAccess.remove_absolute(data.path_join(f))
	_pid = OS.create_process(node, [script, "--port=%d" % PORT, "--round-ms=6000", "--results-ms=1500", "--name=Test", "--data=" + data])
	await _wait(func() -> bool: return _up(), 8000)
	await _account()
	Online.join("127.0.0.1:%d" % PORT, "Tester", Color(0.1, 0.35, 0.9), Master.token())
	var ok := await _wait(func() -> bool: return Online.is_online(), 8000)
	TestHooks.check(ok and Online.server_name == "Test", "online_joins", "%s" % Online.server_name)
	if ok:
		var trk := String(Online.round.get("track", ""))
		TestHooks.check(TmTracks.has(trk) and Online.players.size() == 1 and int(Online.players[0]["id"]) == Online.my_id,
			"online_round_and_players", "%s %s" % [trk, Online.players])
		TestHooks.check(String(Online.players[0]["name"]) == "$f00Tes$ffter" and String(Online.players[0]["login"]) == "tester",
			"online_joins_as_the_account", str(Online.players[0]))
		TestHooks.check(absf(Online.time_left_ms() - 6000) < 1500, "online_clock", "%d" % Online.time_left_ms())
		await _race(trk)
	Online.leave()
	await Master.log_out()
	TestHooks.check(not Master.logged_in() and Master.account.is_empty(), "online_log_out")
	OS.kill(_pid)
	TestHooks.args.erase("master")
	await _rounds(node, script)
	await _community(node, script)
	TestHooks.finish()


## An admin (the admin password) uploads a track file to a server and jumps to it: the round names
## its file, the client downloads it (cached by SHA-256), races it from the file under the round's
## id, and a finish on it is ranked.
func _community(node: String, script: String) -> void:
	var port := PORT + 2
	var pid := OS.create_process(node, [script, "--port=%d" % port, "--name=Community", "--tracks=SF01", "--admin-password=let-me-in"])
	await _wait(func() -> bool: return _up_at(port), 8000)
	var file := ProjectSettings.globalize_path("user://test_upload.Challenge.Gbx")
	var lib := ProjectSettings.globalize_path("res://server/lib/gbx.js").replace("\\", "/")
	var js := "const fs=require('fs');const g=require('%s');const b=(name,z,flags)=>({name,dir:0,coord:[10,1,z],flags});" % lib \
		+ "fs.writeFileSync('%s',g.writeChallenge({uid:'CommunityTest00000000000000',name:'$o$f80Community',author:'tester'," % file.replace("\\", "/") \
		+ "compress:true,blocks:[b('StadiumRoadMainStartLine',10,0x1000),b('StadiumRoadMain',11,0x1003),b('StadiumRoadMain',12,0x1003)," \
		+ "b('StadiumRoadMainFinishLine',13,0x1000)]}))"
	var out := []
	OS.execute(node, ["-e", js], out, true)
	var raw := FileAccess.get_file_as_bytes(file)
	TestHooks.check(raw.size() > 100, "community_track_written", str(out))
	var base := "http://127.0.0.1:%d" % port
	var up: Dictionary = await _http(base + "/api/admin/tracks?servers=main", HTTPClient.METHOD_POST, raw, "application/octet-stream")
	TestHooks.check(int(up["code"]) == 200 and String(up["body"].get("track", {}).get("uid", "")) == "CommunityTest00000000000000",
		"community_admin_upload", str(up))
	var bad: Dictionary = await _http(base + "/api/admin/tracks", HTTPClient.METHOD_POST, raw, "application/octet-stream", "Admin wrong")
	TestHooks.check(int(bad["code"]) == 401, "community_admin_password_checked", str(bad))
	var jump: Dictionary = await _http(base + "/api/admin/servers/main", HTTPClient.METHOD_POST,
		JSON.stringify({"jump": "CommunityTest00000000000000"}).to_utf8_buffer(), "application/json")
	TestHooks.check(int(jump["code"]) == 200, "community_admin_jump", str(jump))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Online.cached_path(String(up["body"].get("track", {}).get("sha256", "x")), ".Challenge.Gbx")))
	Online.join("127.0.0.1:%d" % port, "Racer", Color(0.9, 0.1, 0.1))
	var ok := await _wait(func() -> bool: return Online.is_online(), 8000)
	var f: Variant = Online.round.get("file", null)
	TestHooks.check(ok and f is Dictionary and String(Online.round["track"]) == "CommunityTest00000000000000", "community_round_names_its_file",
		str(Online.round))
	if not (ok and f is Dictionary):
		OS.kill(pid)
		return
	var path: String = await Online.round_track_file()
	TestHooks.check(not path.is_empty() and Online.has_cached(String(f["sha256"]), ".Challenge.Gbx"), "community_track_downloaded", path)
	TestHooks.args.erase("track")
	TestHooks.args["map"] = path
	TestHooks.args["online_track"] = String(Online.round["track"])
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	await _wait(func() -> bool: return scene.ready_to_race, 20000)
	TestHooks.check(scene.challenge.ok() and scene.builder.has_start and scene.online != null
		and String(scene.track_id) == "CommunityTest00000000000000", "community_track_raced_online",
		"%s %s %s" % [scene.challenge.error, scene.track_id, scene.builder.stats])
	scene.online.on_finish(31234)
	var ranked := await _wait(func() -> bool:
		return Online.players.any(func(p: Dictionary) -> bool: return int(p["id"]) == Online.my_id and int(p["best"]) == 31234), 5000)
	TestHooks.check(ranked, "community_finish_ranked")
	await _community_car(base, scene)
	scene.queue_free()
	TestHooks.args.erase("map")
	TestHooks.args.erase("online_track")
	Online.leave()
	OS.kill(pid)


## An admin uploads a car pack (a ManiaPark-like zip of our own: TmTestCar) to the server, which
## offers it to its players: we pick it, it is downloaded (cached by SHA-256) and our car in the race
## is drawn with its model; when the admin makes it the server's car, everyone drives it.
func _community_car(base: String, scene: Node) -> void:
	var zip := ProjectSettings.globalize_path("user://test_online_car.zip")
	TmTestCar.write_pack(zip)
	var up: Dictionary = await _http(base + "/api/admin/cars?name=Test%20Car&servers=main", HTTPClient.METHOD_POST,
		FileAccess.get_file_as_bytes(zip), "application/zip")
	DirAccess.remove_absolute(zip)
	var car: Dictionary = up["body"].get("car", {})
	var id := String(car.get("id", ""))
	TestHooks.check(int(up["code"]) == 200 and bool(car.get("mesh", false)), "community_car_upload", str(up))
	var listed := await _wait(func() -> bool: return not Online.car(id).is_empty(), 5000)
	TestHooks.check(listed, "community_car_offered", str(Online.cars))
	if not listed:
		return
	scene.online.toggle_car_menu()
	TestHooks.check(scene.online._car_menu.visible, "community_car_menu")
	scene.online.toggle_car_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Online.cached_path(String(car["sha256"]), ".zip")))
	Online.pick_car(id)
	var drawn := await _wait(func() -> bool:
		for c in scene.car.get_children():
			if c is TmCarVisual and (c as TmCarVisual).pack != null and not c.is_queued_for_deletion():
				return true
		return false, 10000)
	TestHooks.check(String(Online.me().get("car", "")) == id and Online.has_cached(String(car["sha256"]), ".zip"),
		"community_car_picked_and_downloaded", str(Online.me()))
	TestHooks.check(drawn, "community_car_drawn")
	TestHooks.check(String(TmUi.setting("car_pack")) == String(car["sha256"]), "community_car_remembered")
	var force: Dictionary = await _http(base + "/api/admin/servers/main", HTTPClient.METHOD_POST,
		JSON.stringify({"forced_car": id}).to_utf8_buffer(), "application/json")
	Online.pick_car("")
	var forced := await _wait(func() -> bool: return Online.forced_car == id, 5000)
	await get_tree().create_timer(0.3).timeout
	TestHooks.check(int(force["code"]) == 200 and forced and String(Online.me().get("car", "")) == id, "community_car_forced",
		"%s %s" % [force, Online.me()])
	TmUi.set_setting("car_pack", "")


## An HTTP call with a body (the admin password by default): {code, body (Dictionary)}.
func _http(url: String, method: int, body: PackedByteArray, type: String, auth := "Admin let-me-in") -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_raw(url, PackedStringArray(["content-type: " + type, "authorization: " + auth]), method, body)
	var res: Array = await req.request_completed
	req.queue_free()
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"code": int(res[1]), "body": parsed if parsed is Dictionary else {}}


## A Rounds server: the race holds its countdown until the server's start (everyone starts
## together), restarting is refused mid-round, a finish scores the round's points, the next round
## restarts the same track in place, a vote (alone: it passes) moves to the next map, spectating
## parks the car.
func _rounds(node: String, script: String) -> void:
	var port := PORT + 1
	var pid := OS.create_process(node, [script, "--port=%d" % port, "--mode=Rounds", "--name=Rounds Test", "--tracks=SF01,SF02"])
	await _wait(func() -> bool: return _up_at(port), 8000)
	Online.join("127.0.0.1:%d" % port, "Racer", Color(0.9, 0.1, 0.1))
	var ok := await _wait(func() -> bool: return Online.is_online(), 8000)
	TestHooks.check(ok and Online.mode == "Rounds" and Online.synced(), "rounds_joins", Online.mode)
	if not ok:
		OS.kill(pid)
		return
	TestHooks.args["track"] = String(Online.round["track"])
	var scene: Node = (load("res://race/race.tscn") as PackedScene).instantiate()
	add_child(scene)
	await _wait(func() -> bool: return scene.ready_to_race, 20000)
	var start := float(Online.round.get("start", 0))
	var held: bool = scene.sync_start == start and not scene.waiting
	if Online.now_ms() < start - TmRace.COUNTDOWN_MS - 300.0:
		held = held and scene.race.state == TmRace.State.COUNTDOWN and scene.race.countdown_ms == TmRace.COUNTDOWN_MS
	TestHooks.check(held, "rounds_start_held", "sync %s start %s now %s countdown %d" % [scene.sync_start, start, Online.now_ms(), scene.race.countdown_ms])
	await _wait(func() -> bool: return scene.race.racing(), 8000)
	var at_start := Online.now_ms() - start
	TestHooks.check(scene.race.racing() and absf(at_start) < 400.0, "rounds_start_together", "%.0f ms off the server's start" % at_start)
	await get_tree().physics_frame
	var t0: int = scene.race.time_ms
	scene.restart()
	await get_tree().physics_frame
	TestHooks.check(scene.race.racing() and scene.race.time_ms > t0, "rounds_no_restart_mid_round",
		"%s %d -> %d" % [scene.race.state, t0, scene.race.time_ms])
	var first_round := int(Online.round["id"])
	scene.online.on_finish(scene.race.time_ms + 30000)
	var res := await _wait(func() -> bool: return not Online.last_round.is_empty(), 6000)
	TestHooks.check(res and int(Online.last_round[0]["points"]) == 10 and not Online.map_over, "rounds_points", str(Online.last_round))
	var next := await _wait(func() -> bool: return int(Online.round.get("id", -1)) > first_round and String(Online.round["state"]) == "race", 15000)
	TestHooks.check(next and scene.pending_track.is_empty() and scene.sync_start == float(Online.round["start"]) and int(Online.round["number"]) == 2,
		"rounds_next_round_same_track", "%s %s" % [scene.pending_track, Online.round])
	Online.call_vote("next")
	var moved := await _wait(func() -> bool: return int(Online.round.get("map", 1)) == 2, 6000)
	TestHooks.check(moved and not scene.pending_track.is_empty() or (moved and String(Online.round["track"]) == String(scene.track_id)),
		"rounds_vote_next_map", "%s %s" % [scene.pending_track, Online.round])
	scene.online.set_spectating(true)
	var watching := await _wait(func() -> bool: return Online.is_spectator(), 4000)
	TestHooks.check(watching and scene.waiting and not scene.car.visible, "rounds_spectate")
	scene.queue_free()
	Online.leave()
	OS.kill(pid)


func _up_at(port: int) -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", port) != OK:
		return false
	for i in 20:
		tcp.poll()
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			tcp.disconnect_from_host()
			return true
		OS.delay_msec(10)
	return false


## The master: register (with the profile's nickname and zone), log in again, the server list,
## a solo record, the rankings.
func _account() -> void:
	TestHooks.args["master"] = "http://127.0.0.1:%d" % PORT
	TmUi.set_setting("name", "$f00Tes$ffter")
	TmUi.set_setting("zone", "Europe|United Kingdom")
	TmUi.set_setting("token", "")
	var why: String = await Master.register("tester", "password1")
	TestHooks.check(why.is_empty() and Master.logged_in() and String(Master.account.get("login", "")) == "tester"
		and String(Master.account.get("zone", "")) == "Europe|United Kingdom" and int(Master.ranks.get("world", 0)) == 1, "online_register",
		"%s %s %s" % [why, Master.account, Master.ranks])
	why = await Master.register("tester", "password1")
	TestHooks.check(why.contains("taken"), "online_register_taken", why)
	why = await Master.log_in("tester", "wrong-password")
	TestHooks.check(why == "wrong login or password" and Master.logged_in(), "online_wrong_password", why)   # the session stays
	why = await Master.log_in("tester", "password1")
	TestHooks.check(why.is_empty() and Master.logged_in(), "online_log_in", why)
	var list: Array = await Master.servers()
	TestHooks.check(list.size() == 1 and String(list[0]["address"]) == "http://127.0.0.1:%d/ws/main" % PORT and String(list[0]["mode"]) == "TimeAttack",
		"online_server_list", str(list))
	var rec: Dictionary = await Master.submit_record("SF-test-uid", 51230)
	var recs: Dictionary = await Master.records("SF-test-uid", "Europe")
	TestHooks.check(int(rec.get("rank", 0)) == 1 and (recs.get("top", []) as Array).size() == 1 and int(recs["mine"]["time"]) == 51230,
		"online_records", "%s %s" % [rec, recs])
	var r: Dictionary = await Master.rankings("Europe")
	TestHooks.check(int(r.get("total", 0)) == 1 and String(r["players"][0]["login"]) == "tester", "online_rankings", str(r))


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
	var finished_uid: String = scene.challenge.uid
	var ranked := await _wait(func() -> bool:
		return Online.players.any(func(p: Dictionary) -> bool: return int(p["id"]) == Online.my_id and int(p["best"]) == 42000), 5000)
	TestHooks.check(ranked, "online_finish_ranked")
	var recs: Dictionary = await Master.records(finished_uid)
	TestHooks.check((recs.get("top", []) as Array).size() == 1 and int(recs["top"][0]["time"]) == 42000 and String(recs["top"][0]["login"]) == "tester",
		"online_server_finish_is_a_record", str(recs))
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
