extends RefCounted
## Glider: a ~18 s stadium map built around the reactor boost (M7-6, TMX style "Reactor"). Hit the
## reactor pad on the kicker and fly the long gap: the reactor lifts you and lets you steer in the
## air to line up the landing. Miss the pad and you drop short.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 24, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "cyan",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 6.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 50},
			{"t": 90, "r": 60, "bank": 20},
			{"s": 30, "w": 22.0},
			{"cp": true},
			{"s": 20},
			{"effect": "reactor", "len": 10.0, "dur": 1.2},
			{"s": 12},
			{"jump": {"ramp": 30.0, "h": 4.0, "gap": 50.0, "land": 80.0, "drop": 0.0, "end_dy": 0.0, "check_kmh": 160.0}, "w": 26.0},
			{"s": 20, "w": 20.0},
			{"cp": true},
			{"s": 40},
			{"t": -120, "r": 55, "bank": 28},
			{"s": 30},
			{"boost": 12},
			{"s": 50, "w": 24.0},
			{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 55.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 28.0},
			{"s": 50},
		],
	}
