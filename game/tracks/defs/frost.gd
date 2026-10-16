extends RefCounted
## Frostbite: a ~20 s ice map in the stadium (M7-6, TMX style "Ice"). The ice keeps a third of the
## grip: brake on the asphalt strips, then let the banking carry you round the ice.
##  1. turbo into a banked ice 120: turn in early, the bank holds you.
##  2. asphalt strip (checkpoint) to scrub speed, then an ice slalom on light banking.
##  3. the ice bowl: a steep banked 180 with walls; carry speed or slide down into the wall.


func layout() -> Dictionary:
	return {
		"width": 20.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 20, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "cyan",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 6.0, "wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 40, "w": 24.0},
			{"surface": "ice", "len": 150.0, "x0": -12.0, "x1": 12.0, "at": 0.0},
			{"t": 120, "r": 72, "bank": 30, "w": 24.0},
			{"s": 30, "w": 20.0},
			{"cp": true},
			{"s": 15},
			{"surface": "ice", "len": 125.0, "x0": -10.0, "x1": 10.0, "at": 0.0},
			{"t": -45, "r": 80, "bank": 14},
			{"t": 45, "r": 80, "bank": 14},
			{"s": 30},
			{"cp": true},
			{"s": 20, "w": 24.0},
			{"walls": "both"},
			{"surface": "ice", "len": 180.0, "x0": -12.0, "x1": 12.0, "at": 0.0},
			{"t": -180, "r": 55, "bank": 36, "w": 24.0},
			{"s": 25, "w": 22.0},
			{"boost": 12, "super": true},
			{"s": 50},
			{"jump": {"ramp": 34.0, "h": 3.5, "gap": 20.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 26.0},
			{"s": 50},
		],
	}
