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
			# WEATHER: stadium-floor pool on the outside line into the banked right 90
			{"puddle": 18, "w": 8.0, "x": -4.0, "at": 57.0},
			{"boost": 12}, {"s": 80},
			{"walls": "both"},
			{"t": 90, "r": 60, "bank": 24},
			{"s": 10},
			{"walls": "both"},
			{"cp": true},
			{"s": 30}, {"boost": 12}, {"s": 50, "w": 16.0},
			{"loop": 20.0, "shift": 17.0},
			{"s": 40, "w": 18.0},
			{"cp": true},
			{"s": 30},
			# wall ride (left-hand): lips on both edges catch cars that come off the wall
			{"walls": "both"},
			{"wallride": -130, "r": 70, "roll": 65, "ramp": 95.0},
			{"s": 40},
			{"walls": "both"},
			{"s": 60, "w": 22.0},
			{"jump": {"ramp": 40.0, "h": 3.0, "gap": 26.0, "land": 70.0, "drop": 3.0, "end_dy": -4.0, "check_kmh": 220.0}, "w": 28.0},
			{"cp": true},
			# WEATHER (storm): the gap-jump landing zone is under water: land straight
			{"puddle": 14, "w": 12.0, "x": 0.0, "at": 4.0, "storm": true},
			{"s": 110, "w": 20.0},
			# banked half-pipe 180 with walls on both sides
			{"walls": "both"},
			# WEATHER: water collects at the bottom (inside) of the banked half-pipe; in a storm
			# the outside floods too
			{"puddle": 30, "w": 6.0, "x": 5.0, "at": 55.0},
			{"puddle": 20, "w": 5.0, "x": -5.5, "at": 105.0, "storm": true},
			{"t": 180, "r": 50, "bank": 34},
			{"s": 40},
			{"cp": true},
			{"boost": 12, "super": true},
			{"s": 60, "w": 22.0},
			{"walls": "both"},
			{"jump": {"ramp": 40.0, "h": 5.0, "gap": 24.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "finish": true}, "w": 30.0},
			{"s": 70},
		],
	}
