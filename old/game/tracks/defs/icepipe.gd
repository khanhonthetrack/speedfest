extends RefCounted
## Ice Pipe: a ~20 s ice slalom of steep banked turns (M7-6, TMX styles "Ice" + "Bobsleigh"). The
## banking does the turning; short asphalt strips between the ice pipes let you set the speed.


func layout() -> Dictionary:
	var segs: Array = [{"s": 12}, {"start": true}, {"s": 20}, {"boost": 10}, {"s": 35}, {"walls": "both"}]
	var dirs := [1.0, -1.0, 1.0, -1.0]
	for i in 4:
		segs.append({"surface": "ice", "len": 110.0, "x0": -11.0, "x1": 11.0, "at": 0.0})
		segs.append({"t": 110.0 * dirs[i], "r": 50, "bank": 34, "w": 22.0})
		# WEATHER: rain pools on the exit strips (left after pipe 2, right after pipe 4); storm adds one
		if i == 1:
			segs.append({"puddle": 10, "w": 6.0, "x": -4.0, "at": 4.0})
			segs.append({"puddle": 10, "w": 6.0, "x": 4.0, "at": 4.0, "storm": true})
		elif i == 3:
			segs.append({"puddle": 10, "w": 6.0, "x": 4.0, "at": 4.0})
		segs.append({"s": 22, "w": 20.0})
		if i == 1:
			segs.append({"cp": true})
		segs.append({"s": 12})
	segs.append_array([
		{"cp": true},
		{"boost": 10},
		{"s": 40, "w": 22.0},
		{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 24.0},
		{"s": 45},
	])
	return {
		"width": 20.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 18, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "cyan",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 6.0, "wet": false, "segments": segs,
	}
