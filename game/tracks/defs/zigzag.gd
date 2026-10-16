extends RefCounted
## Zig Zag: an ~18 s technical stadium map (M7-6, TMX style "Tech"): alternating 90 deg turns, each
## exit with a side turbo pad on the outside line. Take the turbos and the next turn-in comes sooner.


func layout() -> Dictionary:
	var segs: Array = [{"s": 12}, {"start": true}, {"s": 20}, {"boost": 10}, {"s": 30}]
	var dirs := [1.0, -1.0, 1.0, -1.0, 1.0, -1.0]
	for i in 6:
		segs.append({"t": 90.0 * dirs[i], "r": 30})
		segs.append({"s": 10})
		# exit pad on the outside of the turn just made
		segs.append({"boost": 8, "x": -4.5 * dirs[i], "pw": 6.0})
		segs.append({"s": 28})
		if i == 2:
			segs.append({"cp": true})
	segs.append_array([
		{"cp": true},
		{"s": 20},
		{"boost": 10},
		{"s": 35, "w": 20.0},
		{"jump": {"ramp": 34.0, "h": 3.0, "gap": 20.0, "land": 50.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 22.0},
		{"s": 45},
	])
	return {
		"width": 16.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 14, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "neon", "edge_neon": "cyan",
		"ground": "arena", "ground_y": 0.0, "ground_collision": false, "lift_banks": false,
		"kill_below": 5.0, "wet": false, "segments": segs,
	}
