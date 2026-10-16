extends RefCounted
## Full Send: a ~25 s full-speed coast run (M7-6, TMX style "FullSpeed"). No braking: wide banked
## sweepers, long drops and boosts. The skill is holding the line at 300+ km/h.


func layout() -> Dictionary:
	return {
		"width": 20.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 64, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "guardrail", "edge_neon": "orange",
		"ground": "terrain", "ground_y": 0.0, "terrain_clearance": 14.0, "lift_banks": false,
		"kill_below": 7.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 60, "dy": -14.0},
			{"walls": "both"},
			{"t": -40, "r": 200, "bank": 14},
			{"t": 50, "r": 180, "bank": 14, "dy": -8.0},
			{"s": 30},
			{"boost": 12},
			{"s": 50, "w": 24.0},
			{"jump": {"ramp": 40.0, "h": 3.0, "gap": 28.0, "land": 70.0, "drop": 6.0, "end_dy": -8.0, "check_kmh": 230.0}, "w": 26.0},
			{"s": 130, "w": 20.0, "dy": -6.0},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"walls": "both"},
			{"t": 45, "r": 220, "bank": 12},
			{"t": -60, "r": 200, "bank": 14},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 8.0},
			{"s": 30},
			{"cp": true},
			{"boost": 12},
			{"s": 70, "w": 24.0},
			{"jump": {"ramp": 40.0, "h": 4.0, "gap": 26.0, "land": 60.0, "drop": 4.0, "end_dy": -4.0, "finish": true}, "w": 28.0},
			{"s": 60},
		],
	}
