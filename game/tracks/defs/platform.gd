extends RefCounted
## Stepping Stones: a ~15 s precision map (M7-6, TMX style "Platform"). Narrow platforms with gaps
## between them: hop, land straight, hop again. Each platform turns a little, so line up before the
## next lip. No walls on the platforms: precision, not speed.


func layout() -> Dictionary:
	return {
		"width": 12.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 22, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "magenta",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 6.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 25},
			{"s": 30},
			{"jump": {"ramp": 20.0, "h": 1.6, "gap": 12.0, "land": 40.0, "drop": 1.0, "end_dy": -1.0, "check_kmh": 170.0}},
			{"s": 45},
			{"t": 25, "r": 80},
			{"s": 25},
			{"jump": {"ramp": 24.0, "h": 1.6, "gap": 13.0, "land": 40.0, "drop": 1.2, "end_dy": -1.2, "check_kmh": 170.0}},
			{"s": 30},
			{"cp": true},
			{"s": 20},
			{"t": -30, "r": 80},
			{"s": 30},
			{"jump": {"ramp": 22.0, "h": 2.0, "gap": 14.0, "land": 42.0, "drop": 1.5, "end_dy": -1.5, "check_kmh": 175.0}},
			{"s": 45},
			{"t": 20, "r": 90},
			{"s": 20},
			{"cp": true},
			{"s": 15},
			{"boost": 10},
			{"s": 30, "w": 16.0},
			{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 45.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 20.0},
			{"s": 45},
		],
	}
