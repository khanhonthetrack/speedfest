extends RefCounted
## Coastline: a ~24 s full-speed run along the shore (M7-6, TMX style "FullSpeed"). Long sweeping
## bends just above the waves; in the rain the apexes flood, so the fast line moves out.


func layout() -> Dictionary:
	return {
		"width": 20.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 10, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "guardrail", "edge_neon": "orange",
		"ground": "terrain", "ground_y": 0.0, "terrain_clearance": 5.0, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 60},
			{"puddle": 24, "w": 7.0, "x": 6.0, "at": 40.0},
			{"t": 50, "r": 180, "bank": 10},
			{"s": 40},
			{"puddle": 24, "w": 7.0, "x": -6.0, "at": 45.0},
			{"t": -60, "r": 170, "bank": 10},
			{"s": 30},
			{"cp": true},
			{"boost": 12},
			{"s": 70},
			{"puddle": 26, "w": 7.0, "x": 6.0, "at": 60.0},
			{"t": 70, "r": 200, "bank": 12},
			{"s": 40},
			{"cp": true},
			{"puddle": 22, "w": 7.0, "x": -6.0, "at": 40.0, "storm": true},
			{"t": -55, "r": 190, "bank": 10},
			{"s": 40},
			{"boost": 12},
			{"s": 50, "w": 24.0},
			{"jump": {"ramp": 36.0, "h": 3.0, "gap": 22.0, "land": 55.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 26.0},
			{"s": 55},
		],
	}
