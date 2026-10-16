extends RefCounted
## Spiral: a ~20 s stadium map built around a climbing banked spiral (M7-6, TMX style "Race"). One
## full turn up the tower on a steady bank, then the dive back down to the finish.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 10, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "magenta",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 40},
			{"walls": "both"},
			{"t": 180, "r": 52, "bank": 24, "dy": 9.0},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"t": 180, "r": 52, "bank": 24, "dy": 9.0},
			{"s": 25},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"s": 30},
			{"boost": 12},
			{"s": 120, "dy": -16.0},
			{"walls": "both"},
			{"t": -70, "r": 70, "bank": 18},
			{"s": 25, "w": 22.0},
			{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 24.0},
			{"s": 45},
		],
	}
