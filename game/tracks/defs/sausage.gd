extends RefCounted
## Sausage Run: a ~16 s coast map of rolling humps (M7-6, TMX style "Sausage"/bumps). Crest the
## humps flat: lift a little before each top and you stay planted; go over them nose-up and you
## float into the next dip. Two humpy straights, a banked bend between them, then the finish jump.


func layout() -> Dictionary:
	var segs: Array = [{"s": 12}, {"start": true}, {"s": 20}, {"boost": 10}, {"s": 30}]
	for i in 4:
		segs.append({"s": 24, "dy": 2.2})
		segs.append({"s": 24, "dy": -2.2})
	segs.append_array([
		{"s": 20}, {"cp": true},
 # WEATHER: rain pools left after the checkpoint, storm adds one on the right
 {"puddle": 10, "w": 6.0, "x": -4.0, "at": 2.0},
 {"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0, "storm": true},
		{"walls": "both"},
		{"t": -110, "r": 75, "bank": 20},
		{"s": 25}, {"cp": true},
 {"puddle": 10, "w": 6.0, "x": 4.0, "at": 2.0},
	])
	for i in 3:
		segs.append({"s": 22, "dy": 2.6})
		segs.append({"s": 22, "dy": -2.6})
	segs.append_array([
		{"boost": 10},
		{"s": 40, "w": 22.0},
		{"jump": {"ramp": 30.0, "h": 3.0, "gap": 16.0, "land": 45.0, "drop": 2.0, "end_dy": -2.0, "finish": true}, "w": 24.0},
		{"s": 45},
	])
	return {
		"width": 18.0, "circuit": false, "platform": true,
		"start_pos": Vector3(0, 16, 0), "start_yaw": 0.0,
		"walls": "both", "wall_style": "neon", "road_style": "guardrail", "edge_neon": "orange",
		"ground": "terrain", "ground_y": 0.0, "terrain_clearance": 7.0, "lift_banks": false,
		"kill_below": 5.0, "wet": false, "segments": segs,
	}
