extends RefCounted
## Snake Alley: a ~22 s technical run through the neon city (M7-6, TMX style "Tech"). A chain of
## S-bends between tower walls, rising and falling: rhythm and clean exits win it.


func layout() -> Dictionary:
	return {
		"width": 15.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 40, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "concrete", "edge_neon": "magenta",
		"ground": "none", "ground_y": 0.0, "lift_banks": false, "kill_below": 7.0, "wet": true,
		"segments": [
			{"building": "roof", "len": 70.0, "at": 0.0, "margin": 6.0},
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 10}, {"s": 30},
			{"building": "facade", "side": "both", "len": 200.0, "at": 0.0, "gap": 4.0, "height": 36.0},
			{"t": 60, "r": 35, "bank": 6},
			{"t": -60, "r": 35, "bank": 6},
			{"t": 60, "r": 35, "bank": 6},
			{"s": 25},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"s": 40, "dy": -6.0},
			{"t": -90, "r": 30, "bank": 8},
			{"s": 20},
			{"t": 90, "r": 30, "bank": 8},
			{"s": 25, "dy": 4.0},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"building": "facade", "side": "both", "len": 160.0, "at": 0.0, "gap": 4.0, "height": 36.0},
			{"t": -50, "r": 40, "bank": 6},
			{"t": 50, "r": 40, "bank": 6},
			{"t": -50, "r": 40, "bank": 6},
			{"s": 25},
			{"boost": 10},
			{"s": 30, "w": 20.0},
			{"building": "roof", "len": 80.0, "at": 60.0, "margin": 7.0},
			{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 22.0},
			{"s": 50},
		],
	}
