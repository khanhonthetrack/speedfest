extends RefCounted
## Grand Finale: a ~28 s stadium map with a bit of everything (M7-6, TMX style "Mixed"): a loop,
## a wall ride, an ice bend, a dirt section, a banked half-pipe and the jump through the arch.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 26, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "magenta",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 6.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"s": 55, "w": 16.0},
			{"loop": 24.0, "shift": 20.0},
			{"s": 40, "w": 18.0},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"s": 25},
			{"walls": "both"},
			{"wallride": -110, "r": 70, "roll": 62, "ramp": 85.0},
			{"s": 35},
			{"walls": "both"},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"s": 20},
			{"surface": "ice", "len": 130.0, "x0": -10.0, "x1": 10.0, "at": 0.0},
			{"t": 90, "r": 75, "bank": 24, "w": 20.0},
			{"s": 15, "w": 18.0},
			{"surface": "dirt", "len": 120.0, "x0": -9.0, "x1": 9.0, "at": 0.0},
			{"s": 25},
			{"t": -40, "r": 60},
			{"t": 40, "r": 60},
			{"s": 20},
			{"cp": true},
			{"walls": "both"},
			{"t": -180, "r": 48, "bank": 32},
			{"s": 30},
			{"boost": 12, "super": true},
			{"s": 50, "w": 22.0},
			{"jump": {"ramp": 36.0, "h": 3.5, "gap": 22.0, "land": 55.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 26.0},
			{"s": 55},
		],
	}
