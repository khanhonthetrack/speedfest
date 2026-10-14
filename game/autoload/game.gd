extends Node
## Scene flow and current mode. Scenes call these instead of change_scene directly.

const SCENE_MENU := "res://ui/main_menu.tscn"
const SCENE_GARAGE := "res://ui/garage.tscn"
const SCENE_LOBBY := "res://ui/online_lobby.tscn"
const SCENE_TRACK_SELECT := "res://ui/track_select.tscn"
const SCENE_SETTINGS := "res://ui/settings_menu.tscn"
const SCENE_RACE := "res://race/race.tscn"

var mode: String = "solo"            # "solo" | "online"
var track_id: String = "arena"
var round_info: Dictionary = {}      # Net.round_started payload while online
var garage_return_scene: String = SCENE_MENU


func goto(scene_path: String) -> void:
	# Deferred so callers can finish their frame (signal handlers, input events) first.
	get_tree().call_deferred("change_scene_to_file", scene_path)


func start_solo(p_track_id: String) -> void:
	mode = "solo"
	track_id = p_track_id
	round_info = {}
	goto(SCENE_RACE)


func start_online_round(info: Dictionary) -> void:
	mode = "online"
	track_id = String(info.get("track", "arena"))
	round_info = info
	goto(SCENE_RACE)


func to_menu() -> void:
	mode = "solo"
	round_info = {}
	goto(SCENE_MENU)


func to_lobby() -> void:
	round_info = {}
	goto(SCENE_LOBBY)


func to_garage(return_to: String = "") -> void:
	garage_return_scene = return_to if return_to != "" else SCENE_MENU
	goto(SCENE_GARAGE)


func leave_garage() -> void:
	Profile.save()
	if Net.in_room():
		Net.set_profile(Profile.player_name, Profile.get_config())
	goto(garage_return_scene)
