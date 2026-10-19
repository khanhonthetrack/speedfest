extends RefCounted
## Neon Downtown: Trackmania-style rooftop run (~35 s, point to point) at skyscraper height in a
## rainy neon city, built around real buildings (M4.6-1, owner: "a checkpoint inside a building,
## wall rides on facades, jumping and bouncing off buildings, rooftops"):
##   helipad roof start -> turbo -> rooftop gap jump -> THROUGH the Hotel Orbit tower (cp1 inside)
##   -> banked right 90 -> left wall ride along a tower facade -> cp2 -> "needle" gap jump between
##   two towers -> right wall ride around a tower -> cp3 -> dive between towers + banked 75 -> cp4
##   -> super boost -> finish jump onto a rooftop.
## The old loop is gone: it was entered at ~284 km/h after the boost and the body bottomed out.
## Buildings: {"building": ...} markers, res://tracks/track_buildings.gd.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 56, 0),
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
			# helipad tower under the start
			{"building": "roof", "len": 95.0, "at": 0.0, "margin": 7.0},
			{"s": 15}, {"start": true}, {"s": 25},
			{"boost": 12}, {"s": 50, "w": 22.0},
			# rooftop gap jump: tower under the take-off, tower under the landing
			{"building": "roof", "len": 40.0, "at": 0.0, "margin": 5.0},
			{"building": "roof", "len": 95.0, "at": 92.0, "margin": 6.0},
			{"jump": {"ramp": 40.0, "h": 3.0, "gap": 30.0, "land": 70.0, "drop": 4.0, "end_dy": -6.0, "check_kmh": 220.0}, "w": 26.0},
			# WEATHER: "rooftop pool" on the left half of the landing roof
			{"puddle": 16, "w": 9.0, "x": -4.5, "at": 2.0},
			{"s": 25, "w": 18.0},
			# drive THROUGH the Hotel Orbit tower: checkpoint 1 is inside
			{"building": "through", "len": 56.0, "at": 0.0, "sign": "HOTEL ORBIT", "margin": 14.0, "height": 52.0},
			{"s": 28},
			{"cp": true},
			{"s": 28},
			{"s": 30},
			{"walls": "both"},
			# WEATHER: the apex of the right 90 is flooded: take it wide or slide through
			{"puddle": 24, "w": 6.0, "x": 5.0, "at": 18.0},
			{"t": 90, "r": 60, "bank": 22},
			{"s": 20},
			# wall ride along a tower facade (left-hand turn, the right edge climbs the facade)
			{"building": "facade", "side": "right", "len": 147.0, "at": 0.0, "gap": 1.4, "height": 30.0},
			{"wallride": -120, "r": 70, "roll": 65, "ramp": 95.0},
			{"s": 40},
			{"walls": "both"},
			{"cp": true},
			{"s": 40},
			# "needle": gap jump between two towers, landing into a right wall ride around a tower
			{"building": "facade", "side": "both", "len": 80.0, "at": 10.0, "gap": 3.0, "height": 40.0, "depth": 14.0},
			{"jump": {"ramp": 32.0, "h": 2.5, "gap": 22.0, "land": 36.0, "drop": 3.0, "end_dy": -3.0, "check_kmh": 170.0}},
			# run-out: a fast car flies ~95 m from the lip, so it lands before the wall ride bends
			{"s": 46},
			{"building": "facade", "side": "left", "len": 126.0, "at": 0.0, "gap": 1.4, "height": 30.0},
			{"wallride": 90, "r": 80, "roll": 55, "ramp": 50.0},
			{"s": 30},
			{"walls": "both"},
			{"cp": true},
			# dive between the towers
			# WEATHER: "dive slalom", puddles alternate sides down the dive (the middle one is
			# storm-only): thread the dry center line or keep it straight through the water
			{"building": "facade", "side": "both", "len": 120.0, "at": 5.0, "gap": 6.0, "height": 45.0},
			{"puddle": 12, "w": 8.0, "x": -4.6, "at": 25.0},
			{"puddle": 12, "w": 8.0, "x": 4.6, "at": 60.0, "storm": true},
			{"puddle": 12, "w": 8.0, "x": -4.6, "at": 95.0},
			{"s": 130, "dy": -18.0},
			{"walls": "both"},
			# WEATHER (storm): runoff on the outside of the final banked turn's exit
			{"puddle": 20, "w": 6.0, "x": -5.5, "at": 55.0, "storm": true},
			{"t": 75, "r": 70, "bank": 18},
			{"s": 20},
			{"walls": "both"},
			{"cp": true},
			# WEATHER (storm): standing water across the road before the super boost: stay straight
			{"puddle": 10, "w": 15.0, "x": 0.0, "at": -12.0, "storm": true},
			{"boost": 12, "super": true},
			{"s": 60, "w": 22.0},
			# finish jump onto a rooftop (the finish arch stands at the landing)
			{"building": "roof", "len": 100.0, "at": 64.0, "margin": 8.0},
			{"jump": {"ramp": 40.0, "h": 4.0, "gap": 24.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "finish": true}, "w": 30.0},
			{"s": 70},
		],
	}
