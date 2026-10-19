extends RefCounted
## Dust Devil: a ~22 s dirt road on the dusk coast (M7-6, TMX style "Dirt"). Dirt slides: brake-tap
## drift the hairpins, hop the dunes straight. Gravel edges punish running wide.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 14, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "guardrail", "edge_neon": "orange",
		"ground": "terrain", "ground_y": 0.0, "terrain_clearance": 6.0, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 10}, {"s": 30},
			{"surface": "dirt", "len": 600.0, "x0": -7.0, "x1": 7.0, "at": 0.0},
			{"surface": "gravel", "len": 600.0, "x0": 7.0, "x1": 9.0, "at": 0.0},
			{"surface": "gravel", "len": 600.0, "x0": -9.0, "x1": -7.0, "at": 0.0},
			{"t": 90, "r": 45, "bank": 8},
			{"s": 25},
			{"jump": {"ramp": 18.0, "h": 1.4, "gap": 9.0, "land": 26.0, "drop": 0.0, "end_dy": 0.0, "check_kmh": 120.0}},
			{"s": 40},
			{"t": -150, "r": 32, "bank": 10, "w": 22.0},
			{"s": 20, "w": 18.0},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"s": 20},
			{"jump": {"ramp": 18.0, "h": 1.6, "gap": 10.0, "land": 28.0, "drop": 0.0, "end_dy": 0.0, "check_kmh": 130.0}},
			{"s": 40},
			{"t": 80, "r": 55, "bank": 8},
			{"s": 30},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"t": -70, "r": 60, "bank": 6},
			{"s": 40},
			{"boost": 10},
			{"s": 30, "w": 22.0},
			{"jump": {"ramp": 30.0, "h": 3.0, "gap": 16.0, "land": 45.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 24.0},
			{"s": 45},
		],
	}
