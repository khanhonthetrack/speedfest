extends Node
## Drives the real online lobby UI (res://ui/online_lobby.tscn) against a real server by pressing
## its buttons, like a player would. Used by lobby_smoke.sh (host + guests) and for screenshots.
##
## Args: --url=ws://127.0.0.1:8099/ws --role=host|guest --name=Host --players=2 --room=LobbyTest
##   --timeout_s=60   --stay=1 (host: don't start, just sit in the room; for screenshots)
## Success (TEST_OK lobby_round_started) = the lobby called Game.start_online_round on round start,
## then the race scene loads in online mode.

var role := "host"
var players := 2
var room_name := "LobbyTest"
var timeout_ms := 60000
var lobby: Control
var step := "connect"
var _t0 := 0
var _wait := 0.0
var _chat_seen := false


func _ready() -> void:
	role = String(TestHooks.arg("role", "host"))
	players = int(TestHooks.arg("players", 2))
	room_name = String(TestHooks.arg("room", "LobbyTest"))
	timeout_ms = int(TestHooks.arg("timeout_s", 60)) * 1000
	if TestHooks.has_arg("name"):
		Profile.set_player_name(String(TestHooks.arg("name", "Bot")))
	if TestHooks.has_arg("car"):
		Profile.set_selected_car(String(TestHooks.arg("car", "kaze")))
	if TestHooks.has_arg("url"):
		Settings.server_url = String(TestHooks.arg("url", ""))
	_t0 = Time.get_ticks_msec()
	lobby = load("res://ui/online_lobby.tscn").instantiate()
	add_child(lobby)
	# Connected after the lobby, so the lobby's own handler has already run.
	Net.round_started.connect(_on_round_started)
	Net.chat.connect(func(from: String, text: String) -> void:
		print("LOBBY_DRIVER chat from %s: %s" % [from, text])
		if text.begins_with("hello from"):
			_chat_seen = true)


func _say(s: String) -> void:
	print("LOBBY_DRIVER [%s] %s" % [role, s])


func _process(delta: float) -> void:
	if Time.get_ticks_msec() - _t0 > timeout_ms:
		TestHooks.fail("lobby_timeout", "stuck at step %s (view %s)" % [step, lobby.current_view if is_instance_valid(lobby) else "?"])
		TestHooks.finish()
		set_process(false)
		return
	if not is_instance_valid(lobby):
		return
	_wait -= delta
	if _wait > 0.0:
		return
	match step:
		"connect":
			if lobby.current_view == "browser":
				TestHooks.ok("lobby_connected")
				step = "create" if role == "host" else "find"
				_wait = 0.5
		"create":
			lobby.room_name_edit.text = room_name
			lobby.create_btn.pressed.emit()
			step = "wait_room"
		"find":
			for b in lobby.room_list.get_children():
				if b is Button and _button_mentions(b, room_name):
					_say("joining via room list")
					(b as Button).pressed.emit()
					step = "wait_room"
					return
			_wait = 0.5
		"wait_room":
			if lobby.current_view == "room":
				TestHooks.check(lobby.room_code_label.text.length() == 4, "lobby_room_view", "code '%s'" % lobby.room_code_label.text)
				_say("in room %s" % lobby.room_code_label.text)
				lobby.ready_btn.pressed.emit()
				if role == "guest":
					lobby.chat_edit.text_submitted.emit("hello from %s" % Profile.player_name)
				step = "wait_players" if role == "host" else "wait_round"
		"wait_players":
			var room: Dictionary = Net.room
			if room.get("players", []).size() >= players and _all_ready(room):
				if TestHooks.has_arg("stay"):
					step = "stay"
					return
				TestHooks.check(lobby.start_btn.visible, "lobby_host_sees_start")
				# Host settings through the UI chips: Neon Downtown, 3 min.
				(lobby.track_row.get_child(0) as Button).pressed.emit()
				(lobby.duration_row.get_child(0) as Button).pressed.emit()
				step = "wait_settings"
		"wait_settings":
			var s: Dictionary = Net.room.get("settings", {})
			if String(s.get("track", "")) == "downtown" and int(s.get("duration_s", 0)) == 180:
				TestHooks.ok("lobby_host_settings")
				if players > 1:
					TestHooks.check(_chat_seen, "lobby_chat_received")
				lobby.start_btn.pressed.emit()
				step = "wait_round"
		"wait_round", "stay":
			pass


func _all_ready(room: Dictionary) -> bool:
	for p in room.get("players", []):
		if not bool(p.get("ready", false)):
			return false
	return true


func _button_mentions(b: Node, text: String) -> bool:
	for c in b.find_children("*", "Label", true, false):
		if (c as Label).text == text:
			return true
	return false


func _on_round_started(info: Dictionary) -> void:
	_say("round_started %s" % JSON.stringify(info))
	TestHooks.check(Game.mode == "online" and Game.round_info.get("round_id", -1) == info.get("round_id", -2),
		"lobby_round_started", "Game.mode=%s" % Game.mode)
	if role == "guest":
		TestHooks.check(String(info.get("track", "")) == "downtown", "lobby_guest_gets_host_track", String(info.get("track", "")))
	step = "done"
	# The scene changes to the race now; a watcher outside the scene checks it, then quits.
	var w := Node.new()
	w.set_script(load("res://tests/ui_menus/race_watch.gd"))
	get_tree().root.add_child.call_deferred(w)
