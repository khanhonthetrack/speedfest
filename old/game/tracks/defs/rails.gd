extends RefCounted
## Rail Rush: a ~10 s stadium sprint built around one trick (owner, session 5: "the player starts,
## jumps out off a start ledge, has to grind on a short rail, and lands on a platform that has the
## finish"). Start high in the stands, turbo along the start deck, fly off the open ledge and come
## down onto the rail. The rail bends 30 deg left: it carries you round to the finish platform.
## Miss it (or try to jump straight) and you fall to the infield and respawn at the checkpoint
## before the ledge. Grind mechanics: res://tracks/track_rail.gd.


func layout() -> Dictionary:
	return {
		"width": 16.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 16, 0),
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
			{"s": 10}, {"start": true}, {"s": 30},
			{"boost": 10}, {"s": 40},
			{"cp": true},
			# WEATHER: rain pools on both sides of the run-up (keep it straight down the middle
			# so you leave the ledge lined up with the rail); storm adds one on the platform
			{"puddle": 14, "w": 5.0, "x": -4.5, "at": 2.0},
			{"puddle": 12, "w": 4.0, "x": 4.0, "at": 16.0},
			# start deck narrows to the ledge, lined up with the rail
			{"s": 30, "w": 12.0},
			# the ledge: the deck just ends. 6 m of air, then the rail starts 1 m lower
			{"s": 6, "dy": -1.0, "nodeck": true},
			# the rail: straight and gently down, then a 30 deg left bend, then a short run-out
			{"s": 40, "dy": -2.0, "rail": true},
			{"t": -30, "r": 100, "dy": -2.5, "rail": true},
			{"s": 6, "dy": -0.3, "rail": true},
			# hop off the end over a 12 m gap onto the finish platform (a little lower)
			{"s": 12, "dy": -1.4, "nodeck": true},
			{"s": 6, "w": 18.0},
			{"puddle": 12, "w": 10.0, "x": 2.0, "at": 6.0, "storm": true},
			{"finish": true},
			{"s": 45},
		],
	}
