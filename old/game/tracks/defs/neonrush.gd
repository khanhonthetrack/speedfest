extends RefCounted
## Neon Rush: a ~20 s flow map through the neon city (M7-6, TMX style "SpeedFun"). Boost, a long
## facade wall ride, straight through a tower, a second wall ride the other way, and a dive to the
## finish roof. No braking if you hold the lines.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 60, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "concrete", "edge_neon": "magenta",
		"ground": "none", "ground_y": 0.0, "lift_banks": false, "kill_below": 7.0, "wet": true,
		"segments": [
			{"building": "roof", "len": 80.0, "at": 0.0, "margin": 7.0},
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 40},
			{"walls": "both"},
			{"building": "facade", "side": "right", "len": 160.0, "at": 0.0, "gap": 1.4, "height": 30.0},
			{"wallride": -120, "r": 75, "roll": 64, "ramp": 90.0},
			{"s": 35},
			{"walls": "both"},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"building": "through", "len": 50.0, "at": 0.0, "sign": "NEON RUSH", "margin": 12.0, "height": 46.0},
			{"s": 50},
			{"s": 20},
			{"boost": 10},
			{"s": 25},
			{"walls": "both"},
			{"building": "facade", "side": "left", "len": 135.0, "at": 0.0, "gap": 1.4, "height": 30.0},
			{"wallride": 95, "r": 80, "roll": 56, "ramp": 60.0},
			{"s": 30},
			{"walls": "both"},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"s": 90, "dy": -14.0},
			{"s": 30, "w": 22.0},
			{"building": "roof", "len": 90.0, "at": 64.0, "margin": 8.0},
			{"jump": {"ramp": 36.0, "h": 3.0, "gap": 20.0, "land": 55.0, "drop": 3.0, "end_dy": -3.0, "finish": true}, "w": 26.0},
			{"s": 55},
		],
	}
