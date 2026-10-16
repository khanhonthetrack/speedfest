extends RefCounted
## Autopilot: a ~20 s city map with cruise control (M7-6, TMX style "Cruise"). The cruise pad locks
## your speed: no throttle, no brake, you only steer, through a facade wall ride and a loop. A reset
## pad gives the pedals back for the last section.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 62, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "concrete", "edge_neon": "magenta",
		"ground": "none", "ground_y": 0.0, "lift_banks": false, "kill_below": 7.0, "wet": true,
		"segments": [
			{"building": "roof", "len": 85.0, "at": 0.0, "margin": 7.0},
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 40},
			{"effect": "cruise", "len": 6.0, "dur": 7.0},
			{"s": 20},
			{"walls": "both"},
			{"building": "facade", "side": "right", "len": 140.0, "at": 0.0, "gap": 1.4, "height": 28.0},
			{"wallride": -100, "r": 70, "roll": 62, "ramp": 85.0},
			{"s": 30},
			{"walls": "both"},
			{"cp": true},
			{"s": 30, "w": 16.0},
			{"loop": 20.0, "shift": 17.0},
			{"s": 30, "w": 18.0},
			{"effect": "reset", "len": 6.0},
			{"s": 15},
			{"cp": true},
			{"walls": "both"},
			{"t": 60, "r": 80, "bank": 18},
			{"s": 30},
			{"boost": 12, "super": true},
			{"s": 50, "w": 22.0},
			{"building": "roof", "len": 90.0, "at": 64.0, "margin": 8.0},
			{"jump": {"ramp": 36.0, "h": 3.0, "gap": 20.0, "land": 55.0, "drop": 3.0, "end_dy": -3.0, "finish": true}, "w": 26.0},
			{"s": 55},
		],
	}
