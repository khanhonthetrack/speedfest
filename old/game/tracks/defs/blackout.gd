extends RefCounted
## Blackout: a ~20 s dive through the neon city with the engine OFF (M7-6, TMX style "Engine Off").
## Super boost on the helipad, the engine cuts at the edge, and from there it's gravity and lines:
## every brake tap or wide line costs speed you need for the finish jump onto the last roof.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 84, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "concrete", "edge_neon": "magenta",
		"ground": "none", "ground_y": 0.0, "lift_banks": false, "kill_below": 7.0, "wet": true,
		"segments": [
			{"building": "roof", "len": 80.0, "at": 0.0, "margin": 7.0},
			{"s": 12}, {"start": true}, {"s": 15},
			{"boost": 12, "super": true}, {"s": 40, "w": 20.0},
			{"effect": "engine_off", "len": 6.0},
			{"s": 20},
			{"s": 110, "dy": -24.0},
			{"walls": "both"},
			{"t": 60, "r": 95, "bank": 18, "dy": -8.0},
			{"s": 20},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"building": "through", "len": 50.0, "at": 0.0, "sign": "BLACKOUT", "margin": 12.0, "height": 44.0},
			{"s": 50},
			{"s": 15},
			{"walls": "both"},
			{"t": -70, "r": 95, "bank": 18, "dy": -8.0},
			{"s": 15},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"s": 80, "dy": -16.0},
			{"s": 30, "w": 22.0},
			{"building": "roof", "len": 90.0, "at": 66.0, "margin": 8.0},
			{"jump": {"ramp": 36.0, "h": 3.0, "gap": 20.0, "land": 55.0, "drop": 4.0, "end_dy": -4.0, "finish": true}, "w": 26.0},
			{"s": 55},
		],
	}
