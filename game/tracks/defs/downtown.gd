extends RefCounted
## Neon Downtown: Trackmania-style rooftop run (~35 s, point to point) at skyscraper height in a
## rainy neon city. Floating wet platform roads: a rooftop gap jump, a wall ride along a building
## face, a super-boosted loop around a giant neon sign, a dive between towers and a final jump
## through the finish arch.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 56, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "concrete",
		"edge_neon": "magenta",
		"ground": "none",
		"ground_y": 0.0,
		"lift_banks": false,
		"kill_below": 7.0,
		"wet": true,
		"segments": [
			{"s": 15}, {"start": true}, {"s": 25},
			{"boost": 12}, {"s": 50, "w": 22.0},
			# rooftop gap jump
			{"jump": {"ramp": 40.0, "h": 3.0, "gap": 30.0, "land": 70.0, "drop": 4.0, "end_dy": -6.0, "check_kmh": 220.0}, "w": 26.0},
			{"cp": true},
			{"s": 100, "w": 18.0},
			{"walls": "both"},
			{"t": 90, "r": 60, "bank": 22},
			{"s": 20},
			# wall ride along a building face (left-hand)
			{"wallride": -120, "r": 70, "roll": 65, "ramp": 62.0},
			{"s": 40},
			{"walls": "both"},
			{"cp": true},
			{"s": 30}, {"boost": 12}, {"s": 50, "w": 16.0},
			# loop around the giant neon sign
			{"loop": 20.0, "shift": 17.0},
			{"s": 40, "w": 18.0},
			{"cp": true},
			# dive between the towers
			{"s": 130, "dy": -18.0},
			{"walls": "both"},
			{"t": 75, "r": 70, "bank": 18},
			{"s": 20},
			{"walls": "both"},
			{"cp": true},
			{"boost": 12, "super": true},
			{"s": 60, "w": 22.0},
			{"jump": {"ramp": 40.0, "h": 4.0, "gap": 24.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "finish": true}, "w": 30.0},
			{"s": 70},
		],
	}
