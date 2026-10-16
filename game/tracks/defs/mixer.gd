extends RefCounted
## Surface Mixer: a ~24 s stadium map that changes surface every section (M7-6, TMX style
## "Transitional"): asphalt -> dirt hairpin -> ice bend -> grass slalom -> plastic climb. Each
## surface wants a different line and a different amount of brake.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 14, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "cyan",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 40},
			{"surface": "dirt", "len": 120.0, "x0": -9.0, "x1": 9.0, "at": 0.0},
			{"s": 15},
			{"t": 150, "r": 32, "bank": 10, "w": 22.0},
			{"s": 25, "w": 18.0},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"s": 20},
			{"surface": "ice", "len": 140.0, "x0": -10.0, "x1": 10.0, "at": 0.0},
			{"t": -90, "r": 75, "bank": 26, "w": 20.0},
			{"s": 25, "w": 18.0},
			{"s": 20},
			{"surface": "grass", "len": 140.0, "x0": -9.0, "x1": 9.0, "at": 0.0},
			{"t": -35, "r": 70},
			{"t": 35, "r": 70},
			{"s": 25},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"s": 15},
			{"surface": "plastic", "len": 110.0, "x0": -9.0, "x1": 9.0, "at": 0.0},
			{"boost": 10},
			{"s": 70, "dy": 7.0},
			{"s": 30},
			{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 50.0, "drop": 2.5, "end_dy": -2.5, "finish": true}, "w": 24.0},
			{"s": 45},
		],
	}
