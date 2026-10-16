extends RefCounted
## Green Mile: a ~22 s coast map where every corner has a grass cut on the inside (M7-6, TMX style
## "Grass"). The cut is shorter but slides and drags; the asphalt line is longer and grippy. Pick per
## corner; in the rain the asphalt apexes hold water.


func layout() -> Dictionary:
	return {
		"width": 22.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 12, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "guardrail", "edge_neon": "orange",
		"ground": "terrain", "ground_y": 0.0, "terrain_clearance": 6.0, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 10}, {"s": 35},
			{"surface": "grass", "len": 95.0, "x0": 2.0, "x1": 11.0, "at": 0.0},
			{"puddle": 18, "w": 6.0, "x": -6.0, "at": 30.0},
			{"t": 90, "r": 55, "bank": 10},
			{"s": 30},
			{"surface": "grass", "len": 110.0, "x0": -11.0, "x1": -2.0, "at": 0.0},
			{"puddle": 18, "w": 6.0, "x": 6.0, "at": 35.0},
			{"t": -100, "r": 55, "bank": 10},
			{"s": 25},
			{"cp": true},
			{"s": 25},
			{"surface": "grass", "len": 150.0, "x0": 2.0, "x1": 11.0, "at": 0.0},
			{"t": 140, "r": 55, "bank": 12},
			{"s": 30},
			{"cp": true},
			{"surface": "grass", "len": 80.0, "x0": -11.0, "x1": -2.0, "at": 0.0},
			{"t": -70, "r": 60, "bank": 10},
			{"s": 25},
			{"boost": 10},
			{"s": 35, "w": 24.0},
			{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 26.0},
			{"s": 45},
		],
	}
