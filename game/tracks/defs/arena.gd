extends RefCounted
## Pulse Arena: classic Trackmania-style stadium run (~35 s, point to point). Floating platform
## road with open edges: start ramp, turbo straight, banked turn, red super boost into a loop,
## a wall ride, a gap jump, a banked half-pipe 180 and a final jump through the finish arch.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 30, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "neon",
		"edge_neon": "cyan",
		"ground": "arena",
		"ground_y": 0.0,
		"ground_collision": false,
		"lift_banks": false,
		"kill_below": 7.0,
		"wet": false,
		"segments": [
			{"s": 15}, {"start": true}, {"s": 25},
			# start ramp: dive from the start tower
			{"s": 70, "dy": -12.0},
			{"boost": 12}, {"s": 80},
			{"walls": "both"},
			{"t": 90, "r": 60, "bank": 24},
			{"s": 10},
			{"walls": "both"},
			{"cp": true},
			{"s": 30}, {"boost": 12, "super": true}, {"s": 50, "w": 14.0},
			{"loop": 20.0, "shift": 17.0},
			{"s": 40, "w": 18.0},
			{"cp": true},
			{"s": 30},
			# wall ride (left-hand): lips on both edges catch cars that come off the wall
			{"walls": "both"},
			{"wallride": -130, "r": 70, "roll": 75, "ramp": 62.0},
			{"s": 40},
			{"walls": "both"},
			{"s": 60, "w": 22.0},
			{"jump": {"ramp": 40.0, "h": 3.0, "gap": 26.0, "land": 70.0, "drop": 3.0, "end_dy": -4.0, "check_kmh": 220.0}, "w": 28.0},
			{"cp": true},
			{"s": 110, "w": 20.0},
			# banked half-pipe 180 with walls on both sides
			{"walls": "both"},
			{"t": 180, "r": 50, "bank": 34},
			{"s": 40},
			{"cp": true},
			{"boost": 12},
			{"s": 60, "w": 22.0},
			{"walls": "both"},
			{"jump": {"ramp": 40.0, "h": 5.0, "gap": 24.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "finish": true}},
			{"s": 70},
		],
	}
