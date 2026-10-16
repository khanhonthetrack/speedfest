extends RefCounted
## Locked In: a ~16 s stadium map with no-steering pads (M7-6, TMX style "No Steer"). Each purple
## pad locks the wheel: line up BEFORE it, then ride the narrow chute (and the jump) on that line.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 16, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "magenta",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 10}, {"s": 30},
			{"t": 60, "r": 55, "bank": 16},
			{"s": 35},
			{"effect": "no_steer", "len": 6.0, "dur": 1.5},
			{"s": 25, "w": 12.0},
			{"s": 55, "w": 12.0},
			{"s": 20, "w": 18.0},
			{"t": -90, "r": 50, "bank": 20},
			{"s": 20},
			{"cp": true},
			{"s": 30},
			{"effect": "no_steer", "len": 6.0, "dur": 2.0},
			{"s": 15, "w": 14.0},
			{"jump": {"ramp": 26.0, "h": 2.2, "gap": 16.0, "land": 60.0, "drop": 1.0, "end_dy": -1.0, "check_kmh": 170.0}, "w": 14.0},
			{"s": 50, "w": 18.0},
			{"cp": true},
			{"t": 70, "r": 60, "bank": 18},
			{"s": 20},
			{"boost": 10},
			{"s": 35, "w": 22.0},
			{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 24.0},
			{"s": 45},
		],
	}
