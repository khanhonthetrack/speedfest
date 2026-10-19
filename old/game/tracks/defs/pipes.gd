extends RefCounted
## Pipe Dream: a ~16 s stadium flow run through three banked half-pipe 180s that swap direction
## (owner, session 6: "more maps ... between 10 and 30 s ... keep it fun, and clever").
## The trick in every pipe: the low (inside) line is short but paved with gravel; the high line up
## the bank is clean asphalt and keeps your speed, and the side turbo pad on each exit sits on the
## high side. Low and slidey or high and fast: pick per pipe. Ends with a jump through the finish.
## Rain: water pools at the bottom of each pipe (the inside line gets even worse); storm adds one
## on the last exit.


func layout() -> Dictionary:
	return {
		"width": 22.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 18, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "neon",
		"edge_neon": "cyan",
		"ground": "arena",
		"ground_y": 0.0,
		"ground_collision": false,
		"lift_banks": false,
		"kill_below": 6.0,
		"wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 50},
			{"walls": "both"},
			# pipe 1: right-hand 180, inside (right) third gravel; exit pad on the high (left) side
			{"surface": "gravel", "len": 130.0, "x0": 4.0, "x1": 11.0, "at": 0.0},
			{"puddle": 40, "w": 5.0, "x": 8.0, "at": 45.0},
			{"t": 180, "r": 40, "bank": 32},
			{"s": 12},
			{"boost": 10, "x": -5.0, "pw": 8.0},
			{"s": 25},
			{"cp": true},
			{"s": 20},
			# pipe 2: left-hand 180, inside (left) third gravel; exit pad on the high (right) side
			{"surface": "gravel", "len": 130.0, "x0": -11.0, "x1": -4.0, "at": 0.0},
			{"puddle": 40, "w": 5.0, "x": -8.0, "at": 45.0},
			{"t": -180, "r": 40, "bank": 32},
			{"s": 12},
			{"boost": 10, "x": 5.0, "pw": 8.0},
			{"s": 25},
			{"cp": true},
			{"s": 20},
			# pipe 3: right-hand 180 again, tighter
			{"surface": "gravel", "len": 115.0, "x0": 4.0, "x1": 11.0, "at": 0.0},
			{"puddle": 36, "w": 5.0, "x": 8.0, "at": 40.0},
			{"t": 180, "r": 36, "bank": 34},
			{"s": 12},
			{"boost": 10, "x": -5.0, "pw": 8.0},
			{"puddle": 14, "w": 10.0, "x": 4.5, "at": 2.0, "storm": true},
			{"s": 45, "w": 24.0},
			{"walls": "both"},
			{"jump": {"ramp": 36.0, "h": 4.0, "gap": 22.0, "land": 55.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 28.0},
			{"s": 50},
		],
	}
