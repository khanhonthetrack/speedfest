extends RefCounted
## Skyline Hop: an ~18 s rooftop platform map (M7-6, TMX styles "Platform" + rooftops). Three roof
## hops, each a little lower, then the last ledge: land on the grind rail across to the finish
## tower (it doesn't pull you on: line up on the ledge).


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 70, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "concrete", "edge_neon": "magenta",
		"ground": "none", "ground_y": 0.0, "lift_banks": false, "kill_below": 7.0, "wet": true,
		"segments": [
			{"building": "roof", "len": 75.0, "at": 0.0, "margin": 7.0},
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 10}, {"s": 40},
			{"building": "roof", "len": 30.0, "at": 0.0, "margin": 5.0},
			{"building": "roof", "len": 110.0, "at": 56.0, "margin": 6.0},
			{"jump": {"ramp": 34.0, "h": 2.5, "gap": 22.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "check_kmh": 180.0}},
			{"s": 50},
			{"building": "roof", "len": 30.0, "at": 0.0, "margin": 5.0},
			{"building": "roof", "len": 120.0, "at": 56.0, "margin": 6.0},
			{"jump": {"ramp": 34.0, "h": 2.5, "gap": 22.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "check_kmh": 180.0}},
			{"s": 70},
			{"cp": true},
			{"t": 40, "r": 90, "bank": 12},
			{"s": 20},
			{"building": "roof", "len": 117.0, "at": 0.0, "margin": 5.0},
			{"s": 45},
			{"cp": true},
			{"s": 30},
			{"s": 35, "w": 10.0},
			{"s": 7, "dy": -0.3, "nodeck": true},
			{"s": 50, "dy": -1.5, "rail": true},
			{"s": 12, "dy": -1.4, "nodeck": true},
			{"building": "roof", "len": 80.0, "at": 0.0, "margin": 6.0},
			{"s": 6, "w": 18.0},
			{"finish": true},
			{"s": 60},
		],
	}
