extends RefCounted
## Tech Lab: a ~22 s technical stadium map (M7-6, TMX style "Tech"). A narrow 13 m deck, tight
## hairpins and chicanes: brake late, turn in early, brake-tap drift the hairpin.


func layout() -> Dictionary:
	return {
		"width": 13.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 12, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "magenta",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 15},
			{"s": 45},
			{"t": 90, "r": 22},
			{"s": 30},
			{"t": -90, "r": 22},
			{"s": 25},
			{"t": 45, "r": 20},
			{"t": -45, "r": 20},
			{"s": 15},
			{"cp": true},
			{"s": 35},
			{"t": 180, "r": 18, "bank": 8, "w": 15.0},
			{"s": 30, "w": 13.0},
			{"t": -90, "r": 25},
			{"s": 30},
			{"cp": true},
			{"t": 60, "r": 30},
			{"t": -60, "r": 30},
			{"s": 25},
			{"boost": 10},
			{"s": 40},
			{"finish": true},
			{"s": 40},
		],
	}
