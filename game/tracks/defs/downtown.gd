extends RefCounted
## Neon Downtown: Trackmania-style rooftop run (~35 s, point to point) at skyscraper height in a
## rainy neon city. Floating wet platform roads: a rooftop gap jump, a wall ride along a building
## face, a super-boosted loop around a giant neon sign, a dive between towers and a final jump
## through the finish arch.


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
			{"s": 15}, {"start": true}, {"s": 25},
			{"boost": 12}, {"s": 50, "w": 22.0},
			# rooftop gap jump
			{"jump": {"ramp": 40.0, "h": 3.0, "gap": 30.0, "land": 70.0, "drop": 4.0, "end_dy": -6.0, "check_kmh": 220.0}, "w": 26.0},
			{"cp": true},
			# WEATHER: "rooftop pool" on the left half, right on the turn-in line for the right 90
			{"puddle": 16, "w": 9.0, "x": -4.5, "at": 32.0},
			{"s": 100, "w": 18.0},
			{"walls": "both"},
			# WEATHER: the apex of the right 90 is flooded: take it wide or slide through
			{"puddle": 24, "w": 6.0, "x": 5.0, "at": 18.0},
			{"t": 90, "r": 60, "bank": 22},
			{"s": 20},
			# wall ride along a building face (left-hand)
			{"wallride": -120, "r": 70, "roll": 65, "ramp": 95.0},
			{"s": 40},
			{"walls": "both"},
			{"cp": true},
			{"s": 30}, {"boost": 12}, {"s": 50, "w": 16.0},
			# loop around the giant neon sign
			{"loop": 20.0, "shift": 17.0},
			{"s": 40, "w": 18.0},
			{"cp": true},
			# dive between the towers
			# WEATHER: "dive slalom", puddles alternate sides down the dive (the middle one is
			# storm-only): thread the dry center line or keep it straight through the water
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
			{"jump": {"ramp": 40.0, "h": 4.0, "gap": 24.0, "land": 60.0, "drop": 3.0, "end_dy": -3.0, "finish": true}, "w": 30.0},
			{"s": 70},
		],
	}
