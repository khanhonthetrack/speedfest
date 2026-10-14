extends Node
## STUB: the networking module replaces this with the real WebSocket client.
## The public API (signals + methods) is fixed by docs/ARCHITECTURE.md "Net".

signal connected
signal disconnected(reason: String)
signal rooms_listed(rooms: Array)
signal room_changed(room: Dictionary)
signal round_started(info: Dictionary)
signal round_ended(results: Array)
signal leaderboard_changed(entries: Array)
signal player_state(id: int, state: Dictionary)
signal player_left(id: int)
signal chat(from_name: String, text: String)
signal net_error(message: String)

var my_id: int = -1
var room: Dictionary = {}


func connect_to_server(_url: String = "") -> void:
	push_warning("Net stub: connect_to_server")


func disconnect_from_server() -> void:
	pass


func is_online() -> bool:
	return false


func in_room() -> bool:
	return not room.is_empty()


func is_host() -> bool:
	return in_room() and int(room.get("host", -2)) == my_id


func list_rooms() -> void:
	pass


func create_room(_room_name: String = "") -> void:
	pass


func join_room(_code: String) -> void:
	pass


func leave_room() -> void:
	room = {}


func set_profile(_player_name: String, _car_config: Dictionary) -> void:
	pass


func set_ready(_ready: bool) -> void:
	pass


func host_set_settings(_settings: Dictionary) -> void:
	pass


func host_start_round() -> void:
	pass


func send_state(_state: Dictionary) -> void:
	pass


func send_checkpoint(_round_id: int, _cp_index: int, _time_ms: int) -> void:
	pass


func send_finish(_round_id: int, _time_ms: int) -> void:
	pass


func send_chat(_text: String) -> void:
	pass


func local_ms() -> int:
	return Time.get_ticks_msec()


func server_to_local_ms(server_ms: int) -> int:
	return server_ms


func get_player(id: int) -> Dictionary:
	for p in room.get("players", []):
		if int(p.get("id", -1)) == id:
			return p
	return {}
