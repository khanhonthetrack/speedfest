extends RefCounted
## Neon Downtown: rainy night city circuit (~2 km). Grid corners, a chicane, an elevated
## highway with on/off ramps that crosses over the home straight, and a sodium-lit tunnel.


func layout() -> Dictionary:
	return {
		"width": 16.0,
		"circuit": true,
		"start_pos": Vector3(0, 0, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "concrete",
		"ground": "city",
		"ground_y": 0.0,
		"wet": true,
		"segments": [
			{"s": 40}, {"start": true}, {"s": 160},
			{"t": 90, "r": 32, "bank": 3},
			{"s": 60}, {"cp": true}, {"s": 80},
			# chicane
			{"t": -32, "r": 36, "bank": 3}, {"t": 64, "r": 36, "bank": 3}, {"t": -32, "r": 36, "bank": 3},
			{"s": 60},
			{"t": 90, "r": 32, "bank": 3},
			{"s": 30},
			# on-ramp up to the elevated highway
			{"s": 170, "dy": 10.0},
			{"cp": true},
			{"s": 30},
			{"t": 90, "r": 55, "bank": 6},
			{"zone": "bridge", "on": true},
			{"s": 210},
			{"cp": true},
			{"s": 210},
			{"zone": "bridge", "on": false},
			{"t": -90, "r": 45, "bank": 6},
			# off-ramp
			{"s": 170, "dy": -10.0},
			{"cp": true},
			{"s": 20},
			{"t": -90, "r": 32, "bank": 3},
			{"s": 60},
			{"t": -90, "r": 32, "bank": 3},
			{"s": 20},
			{"zone": "tunnel", "on": true},
			{"s": 130},
			{"zone": "tunnel", "on": false},
			{"cp": true},
			{"close": true},
		],
	}
