extends RefCounted
## Drop Zone: a ~16 s stunt map (M7-6, TMX style "Stunt"). Three big drops off the stadium towers,
## each landing straight into a banked turn: land flat, then turn in right away.


func layout() -> Dictionary:
	return {
		"width": 20.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 44, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "cyan",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 6.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 10}, {"s": 30},
			{"jump": {"ramp": 34.0, "h": 2.0, "gap": 26.0, "land": 75.0, "drop": 6.0, "end_dy": -9.0, "check_kmh": 180.0}, "w": 24.0},
			{"s": 60, "w": 20.0},
			{"t": 90, "r": 55, "bank": 22},
			{"s": 20},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"s": 20},
			{"jump": {"ramp": 34.0, "h": 2.0, "gap": 26.0, "land": 75.0, "drop": 5.5, "end_dy": -8.0, "check_kmh": 180.0}, "w": 24.0},
			{"s": 60, "w": 20.0},
			{"t": -90, "r": 55, "bank": 22},
			{"s": 20},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"s": 15},
			{"boost": 10},
			{"s": 30, "w": 24.0},
			{"jump": {"ramp": 36.0, "h": 3.0, "gap": 24.0, "land": 55.0, "drop": 3.5, "end_dy": -5.0, "finish": true}, "w": 26.0},
			{"s": 45},
		],
	}
