extends RefCounted
## Dune Dash: a ~10 s beach sprint at dusk (owner, session 4: short maps that use the ground).
##  1. boardwalk start, then a left sweeper whose inside is loose sand: cut it (shorter, heavy
##     drag) or stay on the boardwalk round the outside.
##  2. a dune jump whose landing starts in sand: fly long or bog down.
##  3. a banked gravel bend: brake-drift it.
##  4. the clifftop straight has grass verges: keep it on the asphalt strip into the finish jump.
## Rain: a puddle on the boardwalk line of the sweeper and one after the dune jump; storm also
## floods the clifftop strip.


func layout() -> Dictionary:
	return {
		"width": 18.0,
		"circuit": false,
		"platform": true,
		"start_pos": Vector3(0, 12, 0),
		"start_yaw": 0.0,
		"walls": "both",
		"wall_style": "neon",
		"road_style": "guardrail",
		"edge_neon": "orange",
		"ground": "terrain",
		"ground_y": 0.0,
		"terrain_clearance": 6.0,
		"lift_banks": false,
		"kill_below": 5.0,
		"wet": false,
		"segments": [
			{"s": 12}, {"start": true}, {"s": 18},
			{"boost": 12}, {"s": 30, "w": 26.0},
			# 1. sand on the inside (left) of the sweeper
			{"surface": "sand", "len": 75.0, "x0": -13.0, "x1": -2.0, "at": 0.0},
			{"puddle": 14, "w": 7.0, "x": 7.0, "at": 25.0},
			{"t": -60, "r": 70, "bank": 15, "w": 26.0},
			{"s": 10, "w": 20.0},
			{"cp": true},
			{"s": 15},
			# 2. dune jump, the landing starts in sand
			{"jump": {"ramp": 24.0, "h": 2.0, "gap": 12.0, "land": 40.0, "drop": 1.0, "end_dy": -1.0, "check_kmh": 140.0}, "w": 22.0},
			{"surface": "sand", "len": 16.0, "x0": -11.0, "x1": 11.0, "at": -40.0},
			{"puddle": 12, "w": 8.0, "x": -4.0, "at": 6.0},
			{"s": 25, "w": 22.0},
			# 3. banked gravel bend
			{"surface": "gravel", "len": 66.0, "x0": -11.0, "x1": 11.0, "at": 0.0},
			{"t": 90, "r": 40, "bank": 12, "w": 22.0},
			{"s": 10, "w": 18.0},
			{"cp": true},
			# 4. clifftop straight with grass verges, then the finish jump
			{"surface": "grass", "len": 45.0, "x0": -9.0, "x1": -4.5, "at": 0.0},
			{"surface": "grass", "len": 45.0, "x0": 4.5, "x1": 9.0, "at": 0.0},
			{"puddle": 14, "w": 6.0, "x": 1.5, "at": 15.0, "storm": true},
			{"s": 45, "w": 18.0},
			{"jump": {"ramp": 22.0, "h": 2.5, "gap": 10.0, "land": 30.0, "drop": 0.0, "end_dy": 0.0, "finish": true}, "w": 22.0},
			{"s": 30},
		],
	}
