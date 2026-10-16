extends RefCounted
## Canyon Run: a ~25 s coast race (M7-6, TMX style "Race"): a cliff wall ride above the sea, then a
## long drop into the canyon with two banked bends at the bottom, and a super boost out to the
## finish jump.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 56, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "guardrail", "edge_neon": "orange",
		"ground": "terrain", "ground_y": 0.0, "terrain_clearance": 14.0, "lift_banks": false,
		"kill_below": 7.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 45},
			{"walls": "both"},
			{"t": -45, "r": 120, "bank": 14},
			{"s": 30},
			{"walls": "both"},
			{"wallride": 100, "r": 70, "roll": 62, "ramp": 90.0},
			{"s": 35},
			{"walls": "both"},
			{"cp": true},
			{"s": 100, "dy": -24.0},
			{"walls": "both"},
			{"t": 60, "r": 80, "bank": 16, "dy": -5.0},
			{"s": 35},
			{"cp": true},
			{"t": -50, "r": 90, "bank": 14},
			{"s": 30},
			{"boost": 12, "super": true},
			{"s": 55, "w": 22.0},
			{"jump": {"ramp": 38.0, "h": 3.5, "gap": 22.0, "land": 55.0, "drop": 4.0, "end_dy": -4.0, "finish": true}, "w": 26.0},
			{"s": 55},
		],
	}
