extends Node
## Screenshot helper: the online room view with a faked room (no server). Frame 60: 4 players;
## then a 5th joins and one changes car/paint (lineup updates live). Use --shot for the final frame.
## tools/run_scene.sh res://tests/ui_menus/lobby_room_shot.tscn -- --frames=200 --shot=/abs/room.png [--shot1=/abs/early.png]

var lobby: Control
var players: Array = []


func _ready() -> void:
	lobby = load("res://ui/online_lobby.tscn").instantiate()
	add_child(lobby)
	var a := CarDefs.default_config("veloce")
	var b := CarDefs.default_config("brute")
	var c := CarDefs.default_config("kaze")
	var d := CarDefs.default_config("kaze")
	d["style"]["paint"] = "#2b7bff"
	d["style"]["livery"] = "two_tone"
	players = [
		{"id": 3, "name": "Khanh", "car": a, "ready": true, "best_ms": -1, "runs": 0},
		{"id": 4, "name": "NightRider", "car": b, "ready": true, "best_ms": 45678, "runs": 3},
		{"id": 5, "name": "Drift_Queen", "car": c, "ready": false, "best_ms": -1, "runs": 0},
		{"id": 6, "name": "Turbo Tom", "car": d, "ready": false, "best_ms": -1, "runs": 0},
	]
	_emit()


func _emit() -> void:
	Net.my_id = 3
	Net.room = {"code": "QX7P", "name": "Game night", "host": 3, "phase": "lobby", "max_players": 8,
		"settings": {"track": "downtown", "duration_s": 300, "weather": "rain"}, "players": players.duplicate(true), "round": {}}
	Net.room_changed.emit(Net.room)


func _process(_d: float) -> void:
	if TestHooks.frame == 70 and TestHooks.has_arg("shot1"):
		TestHooks.save_screenshot(String(TestHooks.arg("shot1", "")))
	if TestHooks.frame == 80:
		var e := CarDefs.default_config("brute")
		e["style"]["paint"] = "#ffd400"
		players.append({"id": 7, "name": "Late Larry", "car": e, "ready": false, "best_ms": -1, "runs": 0})
		players[2]["car"] = CarDefs.default_config("veloce")
		players[2]["car"]["style"]["paint"] = "#a6ff00"
		players[2]["ready"] = true
		_emit()
