extends RefCounted
## Infield Rush: a ~10 s stadium sprint that uses the ground (owner, session 4: "short maps on the
## stadium or the coast which actually use grass, gravel or sand ... make them clever").
##  1. turbo into a fast banked 120 whose INSIDE half is grass: the short line is on grass (less
##     grip, some drag), the long line on asphalt keeps full grip. Pick one.
##  2. a gravel flick (left-right) over the whole width: brake-drift it (brake + steer).
##  3. a kicker over a sand trap: carry speed and fly over it; land short and the sand bogs you
##     down for the last straight.
## Rain: the asphalt (outside) line of the 120 gets a puddle, so the grass cut is the safer call;
## storm floods the run-out after the sand trap.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 8, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "neon",
		"edge_neon": "cyan",
		"ground": "arena",
		"ground_y": 0.0,
		"ground_collision": false,
		"lift_banks": false,
		"kill_below": 5.0,
		"wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 15},
			{"boost": 12}, {"s": 45, "w": 28.0},
			# 1. banked 120: grass on the inside (right) half, asphalt outside
			{"surface": "grass", "len": 105.0, "x0": 2.0, "x1": 14.0, "at": 0.0},
			{"puddle": 16, "w": 7.0, "x": -8.0, "at": 30.0},
			{"t": 120, "r": 50, "bank": 22, "w": 28.0},
			{"s": 15, "w": 18.0},
			{"cp": true},
			{"s": 15},
			# 2. gravel flick, full width
			{"surface": "gravel", "len": 64.0, "x0": -12.0, "x1": 12.0, "at": 0.0},
			{"t": -25, "r": 70, "w": 22.0},
			{"t": 25, "r": 70, "w": 22.0},
			{"puddle": 10, "w": 8.0, "x": 3.0, "at": 4.0},
			# stays 22 wide into the kicker: a taper here caught cars sliding off the gravel
			{"s": 15, "w": 22.0},
			{"cp": true},
			{"s": 10, "w": 22.0},
			# 3. kicker over a sand trap: the first 18 m of the landing are sand
			{"jump": {"ramp": 28.0, "h": 2.5, "gap": 14.0, "land": 45.0, "drop": 0.0, "end_dy": 0.0, "check_kmh": 150.0}, "w": 22.0},
			{"surface": "sand", "len": 18.0, "x0": -11.0, "x1": 11.0, "at": -45.0},
			{"puddle": 12, "w": 10.0, "x": -3.0, "at": 2.0, "storm": true},
			{"s": 20, "w": 18.0},
			{"finish": true},
			{"s": 30},
		],
	}
