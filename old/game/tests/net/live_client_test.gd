extends Node
## Real-network test for the LIVE room (tools/live_smoke_test.sh runs two of these).
##
## Args (after --): --url=ws://127.0.0.1:8080/ws --name=A --timeout_s=60
##
## Each client: connect -> Net.join_live() -> gets round_start straight away (no host, no ready)
## -> checks Net.is_live() and the announced next track -> finishes a run -> round_end ->
## the next round starts by itself on the announced track.

var url: String
var my_name: String
var timeout_ms: int
var started_ms := 0
var first_round: Dictionary = {}
var announced_next: Dictionary = {}
var finish_sent := false
var got_round_end := false
var done := false


func _ready() -> void:
	Engine.max_fps = 30
	url = String(TestHooks.arg("url", "ws://127.0.0.1:8080/ws"))
	my_name = String(TestHooks.arg("name", "Live"))
	timeout_ms = int(TestHooks.arg("timeout_s", 60)) * 1000
	Profile.player_name = my_name
	Net.connected.connect(func() -> void: Net.join_live())
	Net.round_started.connect(_on_round_started)
	Net.round_ended.connect(_on_round_ended)
	Net.finish_result.connect(func(ok: bool, ms: int, _b: int, reason: String) -> void:
		TestHooks.check(ok, "live_finish_accepted", "ms=%d reason=%s" % [ms, reason]))
	started_ms = Time.get_ticks_msec()
	Net.connect_to_server(url)


func _on_round_started(info: Dictionary) -> void:
	if first_round.is_empty():
		first_round = info
		TestHooks.check(Net.is_live(), "live_in_room", str(Net.room.get("code", "")))
		TestHooks.check(int(Net.room.get("host", 0)) == -1, "live_no_host", str(Net.room.get("host", 0)))
		var nx: Variant = Net.room.get("next", null)
		TestHooks.check(typeof(nx) == TYPE_DICTIONARY and String(nx.get("track", "")) in TrackDefs.IDS,
			"live_next_announced", str(nx))
		if typeof(nx) == TYPE_DICTIONARY:
			announced_next = nx
		TestHooks.check(String(info.get("track", "")) in TrackDefs.IDS, "live_track_known", str(info.get("track", "")))
		return
	if int(info.get("round_id", -1)) == int(first_round.get("round_id", -1)):
		return
	TestHooks.check(got_round_end, "live_results_before_next_round")
	TestHooks.check(int(info["round_id"]) == int(first_round["round_id"]) + 1, "live_next_round_id",
		"%s -> %s" % [first_round["round_id"], info["round_id"]])
	TestHooks.check(String(info.get("track", "")) == String(announced_next.get("track", "?")), "live_rotates_to_announced",
		"%s, announced %s" % [info.get("track", ""), announced_next.get("track", "")])
	done = true
	Net.leave_room()
	TestHooks.finish()


func _on_round_ended(results: Array) -> void:
	got_round_end = true
	var mine := false
	for r in results:
		if String(r.get("name", "")) == my_name and int(r.get("best_ms", -1)) > 0:
			mine = true
	TestHooks.check(mine, "live_my_time_in_results", JSON.stringify(results))


func _process(_delta: float) -> void:
	if done:
		return
	if Time.get_ticks_msec() - started_ms > timeout_ms:
		TestHooks.fail("live_timeout", "first_round=%s round_end=%s" % [str(first_round), got_round_end])
		done = true
		TestHooks.finish()
		return
	if not first_round.is_empty() and not finish_sent:
		var go_local := int(first_round.get("start_at_local_ms", 0))
		if go_local > 0 and Net.local_ms() > go_local + 1200:
			finish_sent = true
			Net.send_finish(int(first_round["round_id"]), 1000 + randi() % 200)
