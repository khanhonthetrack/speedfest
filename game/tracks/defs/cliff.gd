extends RefCounted
## Cliff Hanger: a ~18 s downhill run on the sunset coast (owner, session 6: "more maps ... between
## 10 and 30 s ... keep it fun, and clever").
##  1. two downhill sweepers with SAND on the inside half: clip the sand for the short line and
##     bog down, or stay wide on the asphalt.
##  2. a wall ride along the cliff face above the sea.
##  3. red super boost into the bay jump: the finish arch stands on the far headland. Not enough
##     speed and you drop short into the water.
## Rain: water on the outside (asphalt) lines of both sweepers; storm floods the boost run-up.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 46, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "guardrail",
		"edge_neon": "orange",
		"ground": "terrain",
		"ground_y": 0.0,
		"terrain_clearance": 14.0,
		"lift_banks": false,
		"kill_below": 7.0,
		"wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 40, "w": 22.0},
			# 1. downhill sweepers, sand on the inside half
			{"walls": "both"},
			{"surface": "sand", "len": 90.0, "x0": -11.0, "x1": -3.0, "at": 0.0},
			{"puddle": 22, "w": 6.0, "x": 6.0, "at": 30.0},
			{"t": -55, "r": 90, "bank": 14, "dy": -6.0, "w": 22.0},
			{"surface": "sand", "len": 95.0, "x0": 3.0, "x1": 11.0, "at": 0.0},
			{"puddle": 22, "w": 6.0, "x": -6.0, "at": 32.0},
			{"t": 60, "r": 90, "bank": 14, "dy": -6.0, "w": 22.0},
			{"s": 15, "w": 18.0},
			{"walls": "both"},
			{"cp": true},
			{"s": 30},
			# 2. cliff wall ride (right-hand)
			{"walls": "both"},
			{"wallride": 100, "r": 70, "roll": 62, "ramp": 90.0},
			{"s": 35},
			{"walls": "both"},
			{"cp": true},
			# 3. super boost into the bay jump, finish arch on the landing
			{"puddle": 12, "w": 14.0, "x": 0.0, "at": 4.0, "storm": true},
			{"boost": 12, "super": true},
			{"s": 55, "w": 22.0},
			{"walls": "both"},
			{"jump": {"ramp": 40.0, "h": 4.5, "gap": 34.0, "land": 60.0, "drop": 6.0, "end_dy": -8.0, "finish": true}, "w": 30.0},
			{"s": 60},
		],
	}
