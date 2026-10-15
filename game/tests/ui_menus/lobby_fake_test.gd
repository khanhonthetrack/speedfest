extends Node
## Headless: the lobby reacts to Net signals (emitted directly, no server).


func _room(host: int, phase: String = "lobby") -> Dictionary:
	return {
		"code": "ABCD", "name": "Test room", "host": host, "phase": phase, "max_players": 8,
		"settings": {"track": "coast", "duration_s": 420},
		"players": [
			{"id": 3, "name": "Me", "car": CarDefs.default_config("veloce"), "ready": false, "best_ms": -1, "runs": 0},
			{"id": 4, "name": "Friend", "car": CarDefs.default_config("brute"), "ready": true, "best_ms": 45678, "runs": 3},
		],
		"round": {},
	}


func _ready() -> void:
	var lobby: Control = load("res://ui/online_lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	TestHooks.check(lobby.current_view == "connect", "lobby_starts_on_connect", lobby.current_view)

	Net.my_id = 3
	Net.room = _room(3)
	Net.room_changed.emit(Net.room)
	TestHooks.check(lobby.current_view == "room", "lobby_room_view_on_room_changed", lobby.current_view)
	TestHooks.check(lobby.room_code_label.text == "ABCD", "lobby_shows_code")
	TestHooks.check(lobby.player_list.get_child_count() == 2, "lobby_player_rows", str(lobby.player_list.get_child_count()))
	TestHooks.check(lobby.start_btn.visible and not lobby.start_btn.disabled, "lobby_host_can_start")
	TestHooks.check(lobby.start_btn.text.contains("1/2"), "lobby_ready_count", lobby.start_btn.text)
	TestHooks.check((lobby.track_row.get_child(2) as Button).button_pressed, "lobby_track_chip_reflects_settings")
	TestHooks.check((lobby.duration_row.get_child(2) as Button).button_pressed, "lobby_duration_chip_reflects_settings")
	TestHooks.check(lobby.ready_btn.text == "NOT READY", "lobby_ready_button_state")

	# not host anymore
	Net.room = _room(4)
	Net.room["players"][0]["ready"] = true
	Net.room_changed.emit(Net.room)
	TestHooks.check(not lobby.start_btn.visible, "lobby_guest_no_start")
	TestHooks.check((lobby.track_row.get_child(0) as Button).disabled and not (lobby.track_row.get_child(2) as Button).disabled,
		"lobby_guest_settings_locked")
	TestHooks.check(lobby.ready_btn.text == "READY!", "lobby_ready_from_room_state", lobby.ready_btn.text)

	# chat + errors
	Net.chat.emit("Friend", "gl hf [b]")
	TestHooks.check(lobby.chat_log.size() >= 2 and String(lobby.chat_log[-1]).contains("gl hf [lb]b]"), "lobby_chat_escaped", str(lobby.chat_log))
	Net.net_error.emit("Room XYZW not found")
	TestHooks.check(lobby.toast_label.text == "Room XYZW not found", "lobby_shows_net_error")

	# running round -> rejoin button
	Net.room = _room(4, "racing")
	Net.current_round = {"round_id": 9, "track": "coast", "duration_s": 420, "start_at_local_ms": 0, "end_at_local_ms": 999999}
	Net.room_changed.emit(Net.room)
	TestHooks.check(lobby.rejoin_btn.visible, "lobby_rejoin_visible_during_round")
	Net.current_round = {}

	# rooms list
	Net.rooms_listed.emit([{"code": "QWER", "name": "Night run", "players": 3, "phase": "lobby", "track": "arena", "max_players": 8, "host_name": "Ann"}])
	await get_tree().process_frame
	TestHooks.check(lobby.room_list.get_child_count() == 1 and not lobby.room_list_empty.visible, "lobby_room_list")

	# leaving the room while offline -> connect view; disconnect message shown
	Net.room = {}
	Net.room_changed.emit({})
	TestHooks.check(lobby.current_view == "connect", "lobby_left_room_offline_view", lobby.current_view)
	Net.disconnected.emit("Connection lost")
	TestHooks.check(lobby.connect_status.text == "Connection lost", "lobby_disconnect_status")

	# round start -> race
	Net.room = _room(3)
	Net.room_changed.emit(Net.room)
	Net.round_started.emit({"round_id": 5, "track": "downtown", "duration_s": 180, "start_at_local_ms": 1000, "end_at_local_ms": 181000})
	TestHooks.check(Game.mode == "online" and Game.track_id == "downtown" and int(Game.round_info.get("round_id", 0)) == 5, "lobby_round_started_starts_race")
	Net.room = {}
	Net.my_id = -1
	TestHooks.finish()
