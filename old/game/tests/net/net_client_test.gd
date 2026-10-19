extends Node
## Real-network test for the Net autoload. Run several copies against one server
## (tools/net_smoke_test.sh does this): one host and N-1 guests.
##
## Args (after --): --url=ws://127.0.0.1:8080/ws --role=host|guest --name=Host --index=0
##   --players=3       total clients expected in the room
##   --room=NetTest    room name the guests look for via list_rooms (or --code=ABCD to join directly)
##   --duration=4      round length (s) the host sets
##   --timeout_s=60    give up after this long
##
## Each client: connect -> host creates / guests discover + join -> profile + ready -> host sets
## settings + starts -> everyone sends states, a checkpoint and a finish -> checks that it got the
## others' states/checkpoints, the leaderboard, round_end, and the return to the lobby.

var url: String
var role: String
var my_name: String
var index: int
var players: int
var room_name: String
var code_arg: String
var duration: int
var timeout_ms: int

var started_ms := 0
var step := "connect"
var next_list_ms := 0
var joined_code := ""
var settings_sent := false
var start_sent := false
var round_info: Dictionary = {}
var racing := false
var race_t0 := 0
var cp_sent := false
var finish_sent := false
var my_finish_ms := 0
var seen_states: Dictionary = {}     # id -> count
var seen_cps: Dictionary = {}        # id -> cp
var last_leaderboard: Array = []
var finish_ack: Dictionary = {}
var results: Array = []
var saw_racing_phase := false
var saw_results_phase := false
var errors: Array = []
var done := false


func _ready() -> void:
	Engine.max_fps = 30 # real-time test: don't spin the CPU
	url = String(TestHooks.arg("url", "ws://127.0.0.1:8080/ws"))
	role = String(TestHooks.arg("role", "host"))
	my_name = String(TestHooks.arg("name", role.capitalize()))
	index = int(TestHooks.arg("index", 0))
	players = int(TestHooks.arg("players", 3))
	room_name = String(TestHooks.arg("room", "NetTest"))
	code_arg = String(TestHooks.arg("code", ""))
	duration = int(TestHooks.arg("duration", 4))
	timeout_ms = int(TestHooks.arg("timeout_s", 60)) * 1000
	Profile.player_name = my_name
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disconnected)
	Net.rooms_listed.connect(_on_rooms_listed)
	Net.room_changed.connect(_on_room_changed)
	Net.round_started.connect(_on_round_started)
	Net.round_ended.connect(_on_round_ended)
	Net.leaderboard_changed.connect(func(e: Array) -> void: last_leaderboard = e)
	Net.player_state.connect(_on_player_state)
	Net.player_checkpoint.connect(func(id: int, cp: int, _ms: int) -> void: seen_cps[id] = cp)
	Net.finish_result.connect(_on_finish_result)
	Net.net_error.connect(_on_net_error)
	started_ms = Time.get_ticks_msec()
	TestHooks.check(Net.connection_state() == "offline", "%s_offline_initially" % role)
	Net.connect_to_server(url)
	TestHooks.check(Net.connection_state() == "connecting", "%s_connecting" % role)


func _log(msg: String) -> void:
	print("[%s %5d ms] %s" % [my_name, Time.get_ticks_msec() - started_ms, msg])


func _on_connected() -> void:
	_log("connected as #%d" % Net.my_id)
	TestHooks.check(Net.my_id > 0, "%s_my_id" % role, "my_id=%d" % Net.my_id)
	TestHooks.check(Net.connection_state() == "online", "%s_online" % role)
	if role == "host":
		Net.create_room(room_name)
		step = "creating"
	elif code_arg != "":
		Net.join_room(code_arg)
		step = "joining"
	else:
		step = "discover"


func _on_disconnected(reason: String) -> void:
	if not done:
		TestHooks.fail("%s_unexpected_disconnect" % role, reason)
		_finish()


func _on_rooms_listed(rooms: Array) -> void:
	if step != "discover":
		return
	for r in rooms:
		if String(r.get("name", "")) == room_name and String(r.get("phase", "")) == "lobby":
			_log("found room %s (%d players)" % [r["code"], int(r["players"])])
			Net.join_room(String(r["code"]))
			step = "joining"
			return


func _on_room_changed(r: Dictionary) -> void:
	if r.is_empty():
		return
	var code := String(r.get("code", ""))
	if joined_code == "":
		joined_code = code
		_log("in room %s (%s), host #%d" % [code, r.get("name", ""), int(r.get("host", -1))])
		TestHooks.check(code.length() == 4, "%s_room_code" % role, code)
		if role == "host":
			print("ROOM_CODE %s" % code)
			TestHooks.check(Net.is_host(), "host_is_host")
		else:
			TestHooks.check(not Net.is_host(), "guest_not_host")
		var cfg := Profile.get_config(CarDefs.IDS[index % CarDefs.IDS.size()])
		Net.set_profile(my_name, cfg)
		Net.set_ready(true)
		step = "lobby"
	var phase := String(r.get("phase", ""))
	if phase == "racing":
		saw_racing_phase = true
	elif phase == "results":
		saw_results_phase = true
	elif phase == "lobby" and not results.is_empty() and not done:
		_final_checks()
		return
	if role == "host" and phase == "lobby" and results.is_empty():
		var ps: Array = r.get("players", [])
		var all_ready := ps.size() >= players
		for p in ps:
			all_ready = all_ready and bool(p.get("ready", false))
		if all_ready and not settings_sent:
			_log("all %d players ready: settings + start" % ps.size())
			Net.host_set_settings({"track": "arena", "duration_s": duration})
			settings_sent = true
		var st: Dictionary = r.get("settings", {})
		if settings_sent and not start_sent and int(st.get("duration_s", 0)) == duration and String(st.get("track", "")) == "arena":
			Net.host_start_round()
			start_sent = true


func _on_round_started(info: Dictionary) -> void:
	_log("round_started %s" % [info])
	round_info = info
	var keys_ok := true
	for k in ["round_id", "track", "duration_s", "start_at_local_ms", "end_at_local_ms"]:
		keys_ok = keys_ok and info.has(k)
	TestHooks.check(keys_ok, "%s_round_info_keys" % role, str(info.keys()))
	TestHooks.check(String(info.get("track", "")) == "arena", "%s_round_track" % role)
	TestHooks.check(int(info["end_at_local_ms"]) - int(info["start_at_local_ms"]) == duration * 1000, "%s_round_duration" % role)
	var lead := int(info["start_at_local_ms"]) - Net.local_ms()
	TestHooks.check(lead > 0 and lead <= 6000, "%s_countdown_in_future" % role, "lead %d ms" % lead)
	# the room carries every player's (sanitized) car config for the RemoteCars
	var others_have_cars := true
	for p in Net.room.get("players", []):
		others_have_cars = others_have_cars and String(p.get("car", {}).get("car", "")) in CarDefs.IDS
	TestHooks.check(others_have_cars, "%s_room_has_car_configs" % role)


func _on_finish_result(ok: bool, ms: int, best: int, reason: String) -> void:
	finish_ack = {"ok": ok, "ms": ms, "best": best, "reason": reason}


func _on_net_error(msg: String) -> void:
	errors.append(msg)
	_log("net_error: %s" % msg)


func _on_player_state(id: int, s: Dictionary) -> void:
	seen_states[id] = int(seen_states.get(id, 0)) + 1
	if seen_states[id] == 1:
		var p: Variant = s.get("p")
		TestHooks.check(typeof(p) == TYPE_ARRAY and p.size() == 3 and s.has("rx_ms") and typeof(s.get("t")) == TYPE_INT,
			"%s_state_shape_from_%d" % [role, id], str(s))


func _on_round_ended(res: Array) -> void:
	_log("round_ended %s" % [res])
	results = res


func _process(_delta: float) -> void:
	if done:
		return
	var now := Time.get_ticks_msec()
	if now - started_ms > timeout_ms:
		TestHooks.fail("%s_timeout" % role, "stuck at step '%s' (states %s, cps %s, results %d)" % [step, seen_states, seen_cps, results.size()])
		_finish()
		return
	if step == "discover" and now >= next_list_ms:
		Net.list_rooms()
		next_list_ms = now + 400
	if round_info.is_empty():
		return
	if not racing and Net.local_ms() >= int(round_info["start_at_local_ms"]):
		racing = true
		race_t0 = now
		_log("GO")
	if not racing or Net.local_ms() > int(round_info["end_at_local_ms"]):
		return
	var t := now - race_t0
	# fake car driving in a circle; one lane per client
	var a := t * 0.002
	var state := {
		"t": t,
		"p": [cos(a) * (20.0 + index * 4.0), 0.5, sin(a) * (20.0 + index * 4.0)],
		"q": [0.0, sin(a * 0.5), 0.0, cos(a * 0.5)],
		"v": Vector3(-sin(a), 0.0, cos(a)) * 30.0,
		"st": 0.25,
		"rpm": 0.7,
		"fl": 16,
	}
	Net.send_state(state)
	if not cp_sent and t > 400:
		Net.send_checkpoint(int(round_info["round_id"]), 0, t)
		cp_sent = true
	if not finish_sent and t > 900:
		my_finish_ms = 1000 + index * 137
		Net.send_finish(int(round_info["round_id"]), my_finish_ms)
		finish_sent = true


func _final_checks() -> void:
	_log("back in lobby: final checks")
	var others := players - 1
	var with_states := 0
	for id in seen_states:
		if int(seen_states[id]) >= 5:
			with_states += 1
	TestHooks.check(with_states >= others, "%s_got_states_from_all" % role, "%s" % [seen_states])
	TestHooks.check(not seen_states.has(Net.my_id), "%s_no_echo" % role)
	TestHooks.check(seen_cps.size() >= others, "%s_got_checkpoints" % role, "%s" % [seen_cps])
	TestHooks.check(bool(finish_ack.get("ok", false)) and int(finish_ack.get("best", -1)) == my_finish_ms,
		"%s_finish_accepted" % role, "%s" % [finish_ack])
	TestHooks.check(last_leaderboard.size() >= 1, "%s_got_leaderboard" % role, "%s" % [last_leaderboard])
	TestHooks.check(results.size() == players, "%s_results_count" % role, "%d results" % results.size())
	var sorted_ok := true
	var all_finished := true
	var mine := -1
	for i in results.size():
		var e: Dictionary = results[i]
		all_finished = all_finished and int(e["best_ms"]) > 0
		if i > 0 and int(results[i - 1]["best_ms"]) > int(e["best_ms"]):
			sorted_ok = false
		if int(e["id"]) == Net.my_id:
			mine = int(e["best_ms"])
	TestHooks.check(sorted_ok and all_finished, "%s_results_sorted" % role, "%s" % [results])
	TestHooks.check(mine == my_finish_ms, "%s_results_has_my_time" % role, "mine=%d expected %d" % [mine, my_finish_ms])
	TestHooks.check(saw_racing_phase and saw_results_phase, "%s_phases_seen" % role)
	TestHooks.check(String(Net.room.get("phase", "")) == "lobby", "%s_back_in_lobby" % role)
	TestHooks.check(Net.ping_ms >= 0 and Net.ping_ms < 2000, "%s_ping_measured" % role, "ping %d" % Net.ping_ms)
	var skew := absi(Net.server_to_local_ms(Net.server_now_ms()) - Net.local_ms())
	TestHooks.check(skew <= 1, "%s_clock_roundtrip" % role)
	TestHooks.check(errors.is_empty(), "%s_no_net_errors" % role, "%s" % [errors])
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
	Net.disconnect_from_server()
	TestHooks.check(Net.connection_state() == "offline" and Net.room.is_empty() and Net.my_id == -1, "%s_clean_disconnect" % role)
	TestHooks.finish()
