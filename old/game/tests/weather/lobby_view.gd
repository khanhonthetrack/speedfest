extends Node
## Screenshot helper: the online lobby room view (as host) with fake data, incl. the weather row.
## tools/run_scene.sh res://tests/weather/lobby_view.tscn -- --frames=60 --shot=/abs/lobby.png


func _ready() -> void:
	var lobby: Control = load("res://ui/online_lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	Net.my_id = 3
	Net.room = {
		"code": "WXYZ", "name": "Game night", "host": 3, "phase": "lobby", "max_players": 8,
		"settings": {"track": "downtown", "duration_s": 300, "weather": "storm"},
		"players": [
			{"id": 3, "name": "Khanh", "car": CarDefs.default_config("veloce"), "ready": true, "best_ms": -1, "runs": 0},
			{"id": 4, "name": "Friend", "car": CarDefs.default_config("brute"), "ready": true, "best_ms": 27345, "runs": 3},
			{"id": 5, "name": "Mate", "car": CarDefs.default_config("kaze"), "ready": false, "best_ms": -1, "runs": 0},
		],
		"round": {},
	}
	Net.room_changed.emit(Net.room)
	TestHooks.check((lobby.weather_row.get_child(2) as Button).button_pressed, "lobby_weather_chip_reflects_settings")
