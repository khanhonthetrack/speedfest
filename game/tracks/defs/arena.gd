extends RefCounted
## Pulse Arena: neon stunt stadium circuit (~1.5 km). Boost pads, a vertical loop, a gap
## jump, a steeply banked 180 and a final jump that lands on the start/finish straight.


func layout() -> Dictionary:
	return {
		"width": 16.0,
		"circuit": true,
		"start_pos": Vector3(0, 0, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"ground": "arena",
		"ground_y": 0.0,
		"wet": false,
		"segments": [
			{"s": 30}, {"start": true}, {"s": 40}, {"boost": 12}, {"s": 100},
			{"t": 90, "r": 50, "bank": 10},
			{"s": 20}, {"cp": true}, {"s": 20}, {"boost": 12},
			{"s": 60, "w": 13.0},
			{"loop": 20.0, "shift": 17.0},
			{"s": 40, "w": 16.0}, {"cp": true}, {"s": 30},
			{"t": 180, "r": 45, "bank": 32},
			{"s": 20}, {"boost": 12}, {"s": 30},
			{"t": -90, "r": 40, "bank": 8},
			{"s": 30},
			{"jump": {"ramp": 40.0, "h": 4.0, "gap": 20.0, "land": 60.0}},
			{"cp": true},
			{"s": 150},
			{"t": 90, "r": 60, "bank": 10},
			{"s": 10},
			{"cp": true},
			{"t": 90, "r": 60, "bank": 10},
			{"s": 40},
			{"jump": {"ramp": 45.0, "h": 3.2, "gap": 20.0, "land": 55.0}},
			{"close": true},
		],
	}
