extends RefCounted
## Rooftop Rush: a ~18 s rooftop sprint in the neon city (owner, session 6: "more maps ... between
## 10 and 30 s ... keep it fun, and clever"). Never touch the street:
##  1. helipad start -> turbo -> drop jump onto the next roof.
##  2. straight THROUGH a tower (checkpoint inside), out into a left wall ride along a facade.
##  3. the cable: the last roof ends in an open ledge with a grind rail strung across to the finish
##     tower. Leave the ledge straight (the deck narrows to line you up), land on the cable, ride it
##     down and hop off onto the finish roof. Miss it and you fall to the street.
## Rain (default): a pool on the landing roof and puddles on both sides of the run-up to the cable.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 62, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "concrete",
		"edge_neon": "magenta",
		"ground": "none",
		"ground_y": 0.0,
		"lift_banks": false,
		"kill_below": 7.0,
		"wet": true,
		"segments": [
			# 1. helipad roof, turbo, drop jump onto the next roof
			{"building": "roof", "len": 90.0, "at": 0.0, "margin": 7.0},
			{"s": 12}, {"start": true}, {"s": 20},
			{"boost": 12}, {"s": 45, "w": 22.0},
			{"building": "roof", "len": 36.0, "at": 0.0, "margin": 5.0},
			{"building": "roof", "len": 90.0, "at": 84.0, "margin": 6.0},
			{"jump": {"ramp": 36.0, "h": 3.0, "gap": 26.0, "land": 60.0, "drop": 4.0, "end_dy": -6.0, "check_kmh": 200.0}, "w": 24.0},
			{"puddle": 14, "w": 8.0, "x": 4.5, "at": 2.0},
			{"s": 20, "w": 18.0},
			# 2. through the tower (checkpoint inside), then a left wall ride along a facade
			{"building": "through", "len": 50.0, "at": 0.0, "sign": "SKYLINE", "margin": 12.0, "height": 46.0},
			{"s": 25},
			{"cp": true},
			{"s": 25},
			{"s": 20},
			{"walls": "both"},
			{"building": "facade", "side": "right", "len": 135.0, "at": 0.0, "gap": 1.4, "height": 28.0},
			{"wallride": -110, "r": 66, "roll": 62, "ramp": 85.0},
			{"s": 30},
			{"walls": "both"},
			{"cp": true},
			# 3. the cable: last roof, open ledge, grind rail across to the finish tower
			{"building": "roof", "len": 92.0, "at": 0.0, "margin": 5.0},
			{"puddle": 14, "w": 4.5, "x": -4.5, "at": 30.0},
			{"puddle": 12, "w": 4.0, "x": 4.0, "at": 52.0},
			{"s": 55},
			{"s": 30, "w": 12.0},
			{"s": 7, "dy": -1.0, "nodeck": true},
			{"s": 55, "dy": -3.0, "rail": true},
			{"s": 12, "dy": -1.4, "nodeck": true},
			{"building": "roof", "len": 80.0, "at": 0.0, "margin": 6.0},
			{"s": 6, "w": 18.0},
			{"finish": true},
			{"s": 60},
		],
	}
