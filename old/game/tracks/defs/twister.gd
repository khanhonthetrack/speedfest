extends RefCounted
## Twister: a ~14 s stadium sprint built around two loops that twist opposite ways (owner, session 6:
## "more maps ... between 10 and 30 s ... keep it fun, and clever").
##  1. turbo into a banked right 90 whose inside half is grass: cut it (less grip, a little drag)
##     or stay on the asphalt.
##  2. the twister: a loop that drifts right, a short breather, then a loop that drifts left. Too
##     slow and you fall out of the first. Between them a small turbo pad sits on the LEFT half only:
##     line up for it on the loop exit and you carry extra speed through the second loop and the jump.
##  3. out of the second loop straight onto a kicker: jump through the finish arch.
## Rain: a pool on the outside of the banked 90 (the grass cut is the safer call) and between the
## loops; storm floods the run-out before the kicker.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 22, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "neon",
		"edge_neon": "magenta",
		"ground": "arena",
		"ground_y": 0.0,
		"ground_collision": false,
		"lift_banks": false,
		"kill_below": 6.0,
		"wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 45, "w": 26.0},
			# 1. banked right 90: grass inside (right) half
			{"surface": "grass", "len": 75.0, "x0": 2.0, "x1": 13.0, "at": 0.0},
			{"puddle": 16, "w": 7.0, "x": -8.0, "at": 22.0},
			{"t": 90, "r": 45, "bank": 24, "w": 26.0},
			{"s": 25, "w": 18.0},
			{"cp": true},
			{"s": 20},
			{"boost": 12},
			{"s": 45, "w": 16.0},
			# 2. the twister: right-drifting loop, breather, left-drifting loop
			{"loop": 19.0, "shift": 16.0},
			{"s": 14, "w": 18.0},
			{"puddle": 12, "w": 7.0, "x": 4.0, "at": 2.0},
			{"boost": 8, "x": -4.5, "pw": 6.0},
			{"s": 26, "w": 16.0},
			{"loop": 19.0, "shift": -16.0},
			{"s": 30, "w": 20.0},
			{"cp": true},
			{"puddle": 12, "w": 12.0, "x": 0.0, "at": 6.0, "storm": true},
			{"s": 25, "w": 22.0},
			# 3. kicker through the finish arch
			{"jump": {"ramp": 34.0, "h": 4.0, "gap": 22.0, "land": 55.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 26.0},
			{"s": 50},
		],
	}
