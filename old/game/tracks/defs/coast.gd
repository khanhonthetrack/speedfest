extends RefCounted
## Sunset Coast: Trackmania-style cliff run (~40 s, point to point) hanging over the cliffs and the
## bay at dusk. Fast banked sweepers, a wall ride along the cliff face, a red super boost into a
## huge jump across the bay, a loop on the headland, a drop and a final jump through the finish.
## The sea is on the right (east).


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 46, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "guardrail",
		"edge_neon": "orange",
		"ground": "terrain",
		"ground_y": 0.0,
		"terrain_clearance": 16.0,
		"lift_banks": false,
		"kill_below": 7.0,
		"wet": false,
		"segments": [
			{"s": 15}, {"start": true}, {"s": 25},
			{"boost": 12}, {"s": 50},
			# fast banked sweepers
			{"walls": "both"},
			# WEATHER: both sweeper apexes hold water (left, then right)
			{"puddle": 24, "w": 6.0, "x": -5.0, "at": 26.0},
			{"puddle": 24, "w": 6.0, "x": 5.0, "at": 107.0},
			{"t": -40, "r": 110, "bank": 16},
			{"t": 45, "r": 110, "bank": 16},
			{"walls": "both"},
			{"cp": true},
			{"s": 40},
			# wall ride along the cliff face (right-hand)
			{"walls": "both"},
			{"wallride": 110, "r": 70, "roll": 65, "ramp": 95.0},
			{"s": 40},
			{"walls": "both"},
			{"cp": true},
			{"s": 130}, {"boost": 12}, {"s": 40, "w": 24.0},
			# the huge jump across the bay: a wide landing pad well below the lip, long run-out
			{"jump": {"ramp": 45.0, "h": 3.0, "gap": 45.0, "land": 90.0, "drop": 8.0, "end_dy": -10.0, "check_kmh": 260.0}, "w": 40.0, "zone": "bridge"},
			{"cp": true},
			# WEATHER (storm): standing water on the left of the bay-jump landing: land on the
			# centre/right and keep it straight
			{"puddle": 16, "w": 9.0, "x": -7.0, "at": 10.0, "storm": true},
			{"s": 120, "w": 30.0},
			# WEATHER: a pool on the outside (right) turn-in line for the left 70
			{"puddle": 18, "w": 8.0, "x": 4.5, "at": 22.0},
			{"s": 50, "w": 18.0},
			{"walls": "both"},
			{"t": -70, "r": 80, "bank": 20},
			{"walls": "both"},
			{"s": 30}, {"boost": 12}, {"s": 40, "w": 16.0},
			# loop on the headland
			{"loop": 20.0, "shift": -17.0},
			{"s": 40, "w": 18.0},
			{"cp": true},
			# drop toward the beach
			# WEATHER (storm): runoff streams down the drop
			{"puddle": 14, "w": 7.0, "x": 4.5, "at": 30.0, "storm": true},
			{"puddle": 14, "w": 7.0, "x": -4.5, "at": 70.0, "storm": true},
			{"s": 120, "dy": -16.0},
			{"boost": 12, "super": true},
			{"s": 60, "w": 22.0},
			{"jump": {"ramp": 40.0, "h": 4.0, "gap": 24.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "finish": true}, "w": 30.0},
			{"s": 70},
		],
	}
