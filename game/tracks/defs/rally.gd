extends RefCounted
## Rally Stage: a ~26 s rally special stage on the coast (M7-6, TMX styles "Dirt" + "Offroad"). A
## narrow dirt road with gravel shoulders, crests that hide the next bend, and a gravel hairpin.


func layout() -> Dictionary:
	return {
		"width": 15.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 14, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "guardrail", "edge_neon": "orange",
		"ground": "terrain", "ground_y": 0.0, "terrain_clearance": 6.0, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"surface": "dirt", "len": 900.0, "x0": -6.0, "x1": 6.0, "at": 0.0},
			{"surface": "gravel", "len": 900.0, "x0": 6.0, "x1": 7.5, "at": 0.0},
			{"surface": "gravel", "len": 900.0, "x0": -7.5, "x1": -6.0, "at": 0.0},
			{"s": 40},
			{"s": 30, "dy": 3.0},
			{"s": 30, "dy": -3.0},
			{"t": -60, "r": 70, "bank": 6},
			{"s": 30},
			{"t": 80, "r": 50, "bank": 8},
			{"s": 25, "dy": 2.5},
			{"s": 25, "dy": -2.5},
			{"cp": true},
			{"s": 20},
			{"surface": "gravel", "len": 90.0, "x0": -7.5, "x1": 7.5, "at": 0.0},
			{"t": -160, "r": 30, "bank": 8, "w": 20.0},
			{"s": 25, "w": 15.0},
			{"t": 50, "r": 80, "bank": 6},
			{"s": 30, "dy": 3.0},
			{"s": 30, "dy": -3.0},
			{"cp": true},
			{"t": -45, "r": 90, "bank": 6},
			{"s": 50},
			{"s": 30, "w": 20.0},
			{"jump": {"ramp": 32.0, "h": 3.0, "gap": 18.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 22.0},
			{"s": 45},
		],
	}
