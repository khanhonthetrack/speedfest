extends Node3D
## Wall-ride test: AutoDriver through a left curve whose roll ramps to ~85 deg (TMNF: 60) and back, on a
## floating road (falling off = fail). Variants: entry capped at ~142 km/h, fast (nitro), and a
## wide radius (little centripetal load; the stick force must hold the car on the wall).
## Run: tools/run_scene.sh res://tests/physics/test_wallride.tscn --headless -- --car=kaze [--roll=85] [--only=wide]

var car_id := "kaze"
var runs: Array = []   # [{name, car, ai, path, entry, min, air, ticks, max_lat, done}]
var tick := 0
var cam: Camera3D
var shotdir := ""
var shot_done := false
var roll := 85.0


func _ready() -> void:
	car_id = String(TestHooks.arg("car", "kaze"))
	shotdir = String(TestHooks.arg("shotdir", ""))
	# TMNF's side grip fades from ~46 deg of tilt and is gone above ~73 deg (an 85 deg wall can't be
	# ridden along there): 60 deg for TMNF handling, 85 for the M7 car
	roll = float(TestHooks.arg("roll", 60.0 if Car.handling() == "tmnf" else 85.0))
	# name, x offset, radius, entry cap km/h (0 = none), nitro, hold length
	var specs := [
		["slow", 0.0, 70.0, 142.0, false, 120.0],
		["fast", 600.0, 70.0, float(TestHooks.arg("fastcap", 215.0)), false, 120.0],
		["wide", 1200.0, 220.0, 150.0, false, 160.0],
		["tight", 1800.0, float(TestHooks.arg("tight_r", 55.0)), 142.0, false, 90.0],
	]
	var only := String(TestHooks.arg("only", ""))
	for sp in specs:
		if only != "" and sp[0] != only:
			continue
		var o := Vector3(sp[1], 0, 0)
		var path := PhysicsTestGround.wallride_path(sp[2], roll, float(TestHooks.arg("ramp", 110.0)), sp[5], 260.0, 12.0, o)
		add_child(PhysicsTestGround.road_from_path(path))
		var car := Car.create(PhysicsTestGround.test_config(car_id))
		add_child(car)
		car.teleport(Transform3D(Basis.IDENTITY, o + Vector3(0, 0.6, -2)))
		var ai := AutoDriver.new()
		ai.path = path
		ai.use_nitro = sp[4]
		ai.target_speed_kmh = sp[3]
		car.add_child(ai)
		if bool(TestHooks.arg("keyboard", false)):
			var emu := Node.new()
			emu.set_script(load("res://tests/physics/key_emulator.gd"))
			emu.set("car", car)
			car.add_child(emu)
			var inp := CarInput.new()
			car.add_child(inp)
			emu.set("inp", inp)
		var z: Dictionary = path.zones[0]
		runs.append({"name": sp[0], "car": car, "ai": ai, "path": path, "from": float(path.get_meta("wall_start")),
			"to": float(path.get_meta("wall_end")), "zfrom": float(z["from"]), "zto": float(z["to"]), "cap": sp[3],
			"entry": -1.0, "min": 1e9, "air": 0, "ticks": 0, "max_lat": 0.0, "max_roll": 0.0, "done": false})
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.far = 2000
	add_child(cam)


func _physics_process(_delta: float) -> void:
	tick += 1
	var all := true
	for r in runs:
		_check(r)
		all = all and r["done"]
	if all or tick > 60 * 40:
		for r in runs:
			if not r["done"]:
				TestHooks.fail("wallride_%s_%s_complete" % [r["name"], car_id], "d=%.0f" % (r["ai"] as AutoDriver).get_distance())
		TestHooks.finish()


func _check(r: Dictionary) -> void:
	if r["done"]:
		return
	var car: Car = r["car"]
	var ai: AutoDriver = r["ai"]
	var path: TrackPath = r["path"]
	var d := ai.get_distance()
	if d >= r["from"] and d <= r["to"]:
		if r["entry"] < 0.0:
			r["entry"] = car.get_speed_kmh()
			if float(r["cap"]) > 0.0:
				ai.target_speed_kmh = 0.0
		var tr := path.sample_transform(d)
		var lc := tr.affine_inverse() * car.global_position
		r["max_lat"] = maxf(r["max_lat"], absf(lc.x))
		r["ticks"] += 1
		r["min"] = minf(r["min"], car.get_speed_kmh())
		if not car.is_grounded():
			r["air"] += 1
		if d >= r["zfrom"] and d <= r["zto"]:
			r["max_roll"] = maxf(r["max_roll"], rad_to_deg(acos(clampf(car.global_transform.basis.y.y, -1.0, 1.0))))
		if TestHooks.has_arg("fine") and r["name"] == "slow" and d > float(TestHooks.arg("fa", 270)) and d < float(TestHooks.arg("fb", 300)):
			var tn := tr.basis.y
			print("  F d=%.1f h=%.2f roll=%.1f road_roll=%.1f contact=%d%d%d%d comp=%s n.car_up=%.3f" % [d, lc.y, rad_to_deg(acos(clampf(car.global_transform.basis.y.y, -1, 1))), rad_to_deg(acos(clampf(tn.y, -1, 1))), int(car.get_wheel_contact(0)), int(car.get_wheel_contact(1)), int(car.get_wheel_contact(2)), int(car.get_wheel_contact(3)), car._comp, tn.dot(car.global_transform.basis.y)])
		if TestHooks.has_arg("trace") and tick % 6 == 0 and r["name"] == String(TestHooks.arg("trace", "")):
			print("  %s d=%.0f v=%.0f lat=%.2f h=%.2f roll=%.0f gnd=%s st=%.2f wheel=%.1f slip=%.1f drift=%.2f th=%.2f br=%.2f" % [r["name"], d, car.get_speed_kmh(), lc.x, lc.y, rad_to_deg(acos(clampf(car.global_transform.basis.y.y, -1, 1))), car.is_grounded(), car.controls["steer"], rad_to_deg(car.get_steer_angle()), rad_to_deg(car.get_slip_angle()), car.get_drift_amount(), car.controls["throttle"], car.controls["brake"]])
	if d > float(r["to"]) + 60.0:
		r["done"] = true
		var n: String = r["name"]
		var up := car.global_transform.basis.y.y
		print("RESULT wallride_%s %s entry=%.0f km/h min=%.0f max_roll=%.0f max_lat=%.2f air=%d/%d up_y=%.2f" % [n, car_id, r["entry"], r["min"], r["max_roll"], r["max_lat"], r["air"], r["ticks"], up])
		TestHooks.check(r["air"] <= maxi(3, int(r["ticks"] * 0.03)), "wallride_%s_grounded_%s" % [n, car_id], "air %d/%d" % [r["air"], r["ticks"]])
		TestHooks.check(r["max_roll"] > minf(70.0, roll - 5.0), "wallride_%s_on_wall_%s" % [n, car_id], "max roll %.0f" % r["max_roll"])
		TestHooks.check(r["max_lat"] < 4.5, "wallride_%s_stays_on_road_%s" % [n, car_id], "max lateral %.2f m" % r["max_lat"])
		TestHooks.check(up > 0.9 and car.is_grounded(), "wallride_%s_exit_upright_%s" % [n, car_id], "up_y %.2f" % up)
		TestHooks.check(absf(ai.get_progress() - d) < 5.0, "wallride_%s_no_reset_%s" % [n, car_id])
		if float(r["cap"]) > 0.0:
			TestHooks.check(r["name"] == "fast" or r["entry"] < 155.0, "wallride_%s_entry_low_%s" % [n, car_id], "%.0f" % r["entry"])
	elif car.global_position.y < -40.0:
		r["done"] = true
		TestHooks.fail("wallride_%s_fell_%s" % [r["name"], car_id], "d=%.0f" % d)


func _process(_delta: float) -> void:
	var car: Car = runs[0]["car"]
	var b := car.global_transform.basis
	cam.global_position = car.global_position + b.z * 9.0 + b.y * 3.0
	cam.look_at(car.global_position + b.y, b.y)
	if shotdir != "" and not shot_done and runs[0]["max_roll"] > minf(75.0, roll - 3.0):
		shot_done = true
		TestHooks.save_screenshot(shotdir.path_join("physics_wallride_%s.png" % car_id))
