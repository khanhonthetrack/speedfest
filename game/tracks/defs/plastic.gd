extends RefCounted
## Plastic Fantastic: an ~18 s stadium map on plastic (M7-6, TMX style "Plastic"). Plastic grips
## less and drags you down; the turbo pads sit on the lines that keep you fast. A climb, a plastic
## slalom with a side pad, and a plastic half-pipe.


func layout() -> Dictionary:
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 14, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "cyan",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 5.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 25},
			{"surface": "plastic", "len": 270.0, "x0": -9.0, "x1": 9.0, "at": 0.0},
			{"s": 60, "dy": 8.0},
			{"boost": 8, "x": -4.0, "pw": 7.0},
			{"s": 25},
			{"t": 90, "r": 45, "bank": 22},
			{"s": 20},
			{"cp": true},
			# WEATHER: rain pools left after the checkpoint, storm adds one on the right
			{"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
			{"s": 15},
			{"t": -40, "r": 60},
			{"boost": 8, "x": 4.0, "pw": 7.0},
			{"t": 40, "r": 60},
			{"s": 25},
			{"cp": true},
			{"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
			{"walls": "both"},
			{"surface": "plastic", "len": 160.0, "x0": -10.0, "x1": 10.0, "at": 0.0},
			{"t": -180, "r": 45, "bank": 32, "w": 20.0},
			{"s": 20, "w": 20.0},
			{"boost": 12},
			{"s": 40, "w": 22.0},
			{"jump": {"ramp": 32.0, "h": 3.0, "gap": 18.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 24.0},
			{"s": 45},
		],
	}
