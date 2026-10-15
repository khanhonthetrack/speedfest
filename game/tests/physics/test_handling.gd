extends Node3D
## Handling tests on a flat pad: handbrake drift, wall scrape at 15 deg, teleport reset,
## self-righting, frozen hold, boost pads, nitro drain/refill, and a skidpad (lateral g).
## Run: tools/run_scene.sh res://tests/physics/test_handling.gd --headless -- --frames=2400 [--car=kaze]

var car_id := "kaze"
var tick := 0
var scen: Array = []   # [{name, car, t, state, ...}]


func _ready() -> void:
	car_id = String(TestHooks.arg("car", "kaze"))
	add_child(PhysicsTestGround.flat_pad(3000, 3000, Vector3(0, 0, -600)))
	# wall along -Z at x = 1100 (scenario "wall" drives into it at 15 deg)
	add_child(PhysicsTestGround.wall(Vector3(1110, 0, 200), Vector3(1110, 0, -1500), 2.0))
	_add("drift", Vector3(-900, 0, 300))
	_add("wall", Vector3(1100, 0, 100))
	_add("teleport", Vector3(-500, 0, 300))
	_add("righting", Vector3(-300, 0, 300))
	_add("frozen", Vector3(-200, 0, 300))
	_add("boost", Vector3(-100, 0, 300))
	_add("nitro", Vector3(0, 0, 300))
	_add("skidpad", Vector3(500, 0, -400))
	_add("reverse", Vector3(100, 0, 300))
	_add("superboost", Vector3(-1300, 0, 400))
	_add("boostwall", Vector3(-1400, 0, -500))
	_add("roofslide", Vector3(-1200, 0, -900))


func _add(n: String, pos: Vector3) -> void:
	var car := Car.create(PhysicsTestGround.test_config(car_id))
	add_child(car)
	var r: float = CarDefs.geometry(car_id)["wheel_radius"]
	car.teleport(Transform3D(Basis.IDENTITY, pos + Vector3(0, r + 0.05, 0)))
	scen.append({"name": n, "car": car, "t": 0, "state": "start", "origin": pos, "done": false})


func _physics_process(_delta: float) -> void:
	tick += 1
	var all_done := true
	for s in scen:
		if not s["done"]:
			s["t"] += 1
			call("_s_" + String(s["name"]), s, s["car"])
			all_done = false
	if all_done or tick > 60 * 38:
		for s in scen:
			if not s["done"]:
				TestHooks.fail("%s_%s_timeout" % [s["name"], car_id], "state %s" % s["state"])
		TestHooks.finish()


func _ctl(car: Car, thr: float, br: float, st: float, hb: bool = false, nitro: bool = false) -> void:
	car.controls["throttle"] = thr
	car.controls["brake"] = br
	car.controls["steer"] = st
	car.controls["handbrake"] = hb
	car.controls["nitro"] = nitro


func _phase(s: Dictionary, state: String) -> void:
	s["state"] = state
	s["t"] = 0


# --- drift: 90 km/h, handbrake + full steer, then hold with throttle, then release --------------
func _s_drift(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			_ctl(car, 1.0, 0.0, 0.0)
			s["max_drift"] = 0.0
			s["yaw_total"] = 0.0
			if car.get_speed_kmh() >= 90.0:
				_phase(s, "hb")
		"hb":
			_ctl(car, 1.0, 0.0, 1.0, true)
			s["max_drift"] = maxf(s["max_drift"], car.get_drift_amount())
			s["yaw_total"] += car.angular_velocity.y / 60.0
			if s["t"] >= 36:
				_phase(s, "hold")
		"hold":
			# countersteer a little, keep throttle: a held drift
			_ctl(car, 0.8, 0.0, -0.25)
			s["max_drift"] = maxf(s["max_drift"], car.get_drift_amount())
			s["yaw_total"] += car.angular_velocity.y / 60.0
			if s["t"] >= 60:
				s["held_drift"] = car.get_drift_amount()
				s["held_speed"] = car.linear_velocity.length() * 3.6
				_phase(s, "release")
		"release":
			_ctl(car, 0.3, 0.0, 0.0)
			s["yaw_total"] += car.angular_velocity.y / 60.0
			if s["t"] >= 240:
				var yaw_turns := absf(s["yaw_total"]) / TAU
				print("RESULT drift %s max=%.2f held=%.2f held_speed=%.0f final_drift=%.2f yaw_rate=%.2f turns=%.2f speed=%.0f" % [car_id, s["max_drift"], s["held_drift"], s["held_speed"], car.get_drift_amount(), car.angular_velocity.y, yaw_turns, car.get_speed_kmh()])
				TestHooks.check(s["max_drift"] > 0.4, "drift_amount_%s" % car_id, "max %.2f" % s["max_drift"])
				TestHooks.check(car.get_drift_amount() < 0.15 and absf(car.angular_velocity.y) < 0.4, "drift_recovers_%s" % car_id, "drift %.2f yaw %.2f" % [car.get_drift_amount(), car.angular_velocity.y])
				TestHooks.check(yaw_turns < 0.9, "drift_no_spin_%s" % car_id, "%.2f turns" % yaw_turns)
				TestHooks.check(car.global_transform.basis.y.y > 0.95, "drift_upright_%s" % car_id)
				s["done"] = true


# --- wall: 150 km/h at 15 deg into a wall on the right ----------------------------------------
func _s_wall(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			if s["t"] == 2:
				var b := Basis(Vector3.UP, deg_to_rad(-15.0))   # yaw right, toward +X
				var r: float = CarDefs.geometry(car_id)["wheel_radius"]
				var xf := Transform3D(b, Vector3(1100 - 20.0 * sin(deg_to_rad(15.0)) * 3.0, r, 100))
				car.teleport(xf, -b.z * (150.0 / 3.6))
				s["v0"] = 150.0
				s["hit"] = -1
				s["hits"] = 0
				car.wall_hit.connect(func(_st: float) -> void: s["hits"] += 1)
				_phase(s, "drive")
		"drive":
			_ctl(car, 1.0, 0.0, 0.0)
			if s["hit"] < 0 and car.global_position.x > 1110 - 0.5 - 1.1:
				s["hit"] = s["t"]
			if s["hit"] >= 0 and s["t"] - s["hit"] >= 60:
				var v := car.linear_velocity.length() * 3.6
				print("RESULT wall %s speed 1s after hit=%.0f km/h (from %.0f) up_y=%.2f wall_hit_signals=%d" % [car_id, v, s["v0"], car.global_transform.basis.y.y, s["hits"]])
				TestHooks.check(v > s["v0"] * 0.5, "wall_slide_keeps_speed_%s" % car_id, "%.0f km/h" % v)
				TestHooks.check(car.global_transform.basis.y.y > 0.9, "wall_upright_%s" % car_id)
				TestHooks.check(car.global_position.x < 1110.0, "wall_no_tunnel_%s" % car_id, "x=%.2f" % car.global_position.x)
				s["done"] = true
			elif s["t"] > 300:
				TestHooks.fail("wall_reached_%s" % car_id, "x=%.1f" % car.global_position.x)
				s["done"] = true


# --- teleport resets dynamics ----------------------------------------------------------------
func _s_teleport(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			_ctl(car, 1.0, 0.0, 1.0, true, true)
			if s["t"] >= 150:
				var o: Vector3 = s["origin"]
				var r: float = CarDefs.geometry(car_id)["wheel_radius"]
				s["target"] = Transform3D(Basis(Vector3.UP, 1.0), o + Vector3(0, r + 0.3, -50))
				_ctl(car, 0.0, 0.0, 0.0)
				car.teleport(s["target"])
				var ok_now := car.linear_velocity.length() < 0.01 and car.angular_velocity.length() < 0.01 \
					and car.global_position.distance_to(s["target"].origin) < 0.01 and car.get_drift_amount() == 0.0
				TestHooks.check(ok_now, "teleport_immediate_%s" % car_id, "v=%s av=%s drift=%.2f" % [car.linear_velocity, car.angular_velocity, car.get_drift_amount()])
				_phase(s, "after")
		"after":
			if s["t"] == 1:
				TestHooks.check(car.global_position.distance_to(s["target"].origin) < 0.05 and car.linear_velocity.length() < 0.5,
					"teleport_next_tick_%s" % car_id, "pos=%s v=%s" % [car.global_position, car.linear_velocity])
			if s["t"] >= 60:
				var moved := Vector2(car.global_position.x - s["target"].origin.x, car.global_position.z - s["target"].origin.z).length()
				TestHooks.check(moved < 0.2 and car.linear_velocity.length() < 0.3, "teleport_settles_%s" % car_id, "moved %.2f v %.2f" % [moved, car.linear_velocity.length()])
				# teleport with velocity keeps it
				car.teleport(s["target"], Vector3(0, 0, -30))
				_phase(s, "vel")
		"vel":
			if s["t"] == 2:
				TestHooks.check(absf(car.linear_velocity.z + 30.0) < 1.5, "teleport_velocity_%s" % car_id, str(car.linear_velocity))
				s["done"] = true


# --- self-righting: upside down at rest ------------------------------------------------------
func _s_righting(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			if s["t"] == 2:
				var o: Vector3 = s["origin"]
				car.teleport(Transform3D(Basis(Vector3.FORWARD, PI), o + Vector3(0, 1.5, 0)))
				_phase(s, "wait")
		"wait":
			_ctl(car, 0.0, 0.0, 0.0)
			if s["t"] >= 60 * 5:
				var up := car.global_transform.basis.y.y
				print("RESULT righting %s up_y=%.2f grounded=%s" % [car_id, up, car.is_grounded()])
				TestHooks.check(up > 0.9 and car.is_grounded(), "self_righting_%s" % car_id, "up_y=%.2f" % up)
				s["done"] = true


# --- frozen: held in place with throttle -------------------------------------------------------
func _s_frozen(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			car.frozen_controls = true
			_ctl(car, 1.0, 0.0, 1.0, false, true)
			if s["t"] == 30:
				s["p0"] = car.global_position
			if s["t"] >= 150:
				var moved: float = car.global_position.distance_to(s["p0"])
				TestHooks.check(moved < 0.05, "frozen_holds_%s" % car_id, "moved %.3f m" % moved)
				TestHooks.check(car.get_rpm_ratio() > 0.6, "frozen_revs_%s" % car_id, "rpm %.2f" % car.get_rpm_ratio())
				TestHooks.check(car.get_nitro_amount() > 0.99, "frozen_no_nitro_%s" % car_id)
				car.frozen_controls = false
				_ctl(car, 1.0, 0.0, 0.0)
				_phase(s, "go")
		"go":
			if s["t"] >= 60:
				TestHooks.check(car.get_speed_kmh() > 25.0, "unfrozen_drives_%s" % car_id, "%.0f km/h" % car.get_speed_kmh())
				s["done"] = true


# --- boost pad -------------------------------------------------------------------------------
func _s_boost(s: Dictionary, car: Car) -> void:
	if s["t"] == 30:
		_ctl(car, 0.0, 0.0, 0.0)
		car.apply_boost(-car.global_transform.basis.z, 25.0, 1.0)
	if s["t"] == 90:
		var v := car.get_speed_kmh()
		TestHooks.check(v > 60.0, "boost_pushes_%s" % car_id, "%.0f km/h" % v)
		s["done"] = true


# --- nitro drain / refill --------------------------------------------------------------------
func _s_nitro(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			_ctl(car, 1.0, 0.0, 0.0, false, false)
			if s["t"] >= 90:
				_phase(s, "burn")
		"burn":
			_ctl(car, 1.0, 0.0, 0.0, false, true)
			if s["t"] == 2:
				TestHooks.check(car.is_nitro_active() and (car.get_flags() & 2) != 0, "nitro_active_flag_%s" % car_id)
			if s["t"] >= 90:
				s["after_burn"] = car.get_nitro_amount()
				var expect := 1.0 - 1.5 / float(car.params["nitro_time"])
				TestHooks.check(absf(car.get_nitro_amount() - expect) < 0.05, "nitro_drains_%s" % car_id, "%.2f (expected %.2f)" % [car.get_nitro_amount(), expect])
				_phase(s, "refill")
		"refill":
			_ctl(car, 0.6, 0.0, 0.0, false, false)
			if s["t"] >= 120:
				TestHooks.check(car.get_nitro_amount() > s["after_burn"], "nitro_refills_%s" % car_id, "%.2f" % car.get_nitro_amount())
				car.refill_nitro()
				TestHooks.check(car.get_nitro_amount() == 1.0, "nitro_refill_call_%s" % car_id)
				s["done"] = true


# --- skidpad: steady circle with the AutoDriver (info + sanity) -----------------------------------
func _s_skidpad(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			if s["t"] == 2:
				var c := Curve3D.new()
				var o: Vector3 = s["origin"]
				var rad := 70.0
				for i in 25:
					var a := TAU * i / 24.0
					c.add_point(o + Vector3(rad - rad * cos(a), 0, -rad * sin(a)))
				PhysicsTestGround._smooth(c)
				var p := TrackPath.new(c, true, 14.0)
				var ai := AutoDriver.new()
				ai.path = p
				ai.use_nitro = false
				car.add_child(ai)
				s["ai"] = ai
				s["lat"] = []
				_phase(s, "drive")
		"drive":
			if s["t"] > 60 * 12:
				var v := car.linear_velocity.length()
				var lat := v * absf(car.angular_velocity.y)
				print("RESULT skidpad %s r=70 speed=%.0f km/h lateral=%.2f g drift=%.2f" % [car_id, v * 3.6, lat / 9.8, car.get_drift_amount()])
				TestHooks.check(lat / 9.8 > 1.0, "skidpad_grip_%s" % car_id, "%.2f g" % (lat / 9.8))
				TestHooks.check(car.global_transform.basis.y.y > 0.95, "skidpad_upright_%s" % car_id)
				s["done"] = true


# --- reverse: a brake hold at standstill reverses; a light brake doesn't ---------------------------
func _s_reverse(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			_ctl(car, 0.0, 0.3, 0.0)
			if s["t"] >= 90:
				TestHooks.check(car.get_gear() != -1 and car.get_speed_kmh() > -1.0, "light_brake_no_reverse_%s" % car_id, "gear %d v %.1f" % [car.get_gear(), car.get_speed_kmh()])
				_phase(s, "hold")
		"hold":
			_ctl(car, 0.0, 1.0, 0.0)
			if s["t"] >= 90:
				TestHooks.check(car.get_gear() == -1 and car.get_speed_kmh() < -10.0 and (car.get_flags() & 8) != 0, "brake_hold_reverses_%s" % car_id, "gear %d v %.1f" % [car.get_gear(), car.get_speed_kmh()])
				_phase(s, "forward")
		"forward":
			_ctl(car, 1.0, 0.0, 0.0)
			if s["t"] >= 120:
				TestHooks.check(car.get_gear() >= 1 and car.get_speed_kmh() > 10.0, "throttle_leaves_reverse_%s" % car_id, "gear %d v %.1f" % [car.get_gear(), car.get_speed_kmh()])
				s["done"] = true


# --- red super boost: strong, long, but capped -------------------------------------------------
func _s_superboost(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			_ctl(car, 1.0, 0.0, 0.0, false, true)
			if car.get_speed_kmh() >= 150.0:
				s["v0"] = car.get_speed_kmh()
				s["vmax"] = 0.0
				car.apply_boost(-car.global_transform.basis.z, 40.0, 3.0)
				car.apply_boost(-car.global_transform.basis.z, 15.0, 1.0)   # weaker pad must not cut it
				car.apply_boost(Vector3.DOWN, 9999.0, 99.0)                  # absurd input is clamped
				_phase(s, "boost")
		"boost":
			s["vmax"] = maxf(s["vmax"], car.linear_velocity.length() * 3.6)
			if s["t"] >= 240:
				print("RESULT superboost %s from %.0f -> max %.0f km/h, up_y=%.2f grounded=%s" % [car_id, s["v0"], s["vmax"], car.global_transform.basis.y.y, car.is_grounded()])
				TestHooks.check(s["vmax"] > s["v0"] + 120.0, "superboost_strong_%s" % car_id, "%.0f" % s["vmax"])
				TestHooks.check(s["vmax"] <= Car.MAX_SPEED * 3.6 + 1.0, "superboost_capped_%s" % car_id, "%.0f" % s["vmax"])
				TestHooks.check(car.is_grounded() and car.global_transform.basis.y.y > 0.95, "superboost_stays_on_road_%s" % car_id)
				s["done"] = true


# --- max-speed boost straight into a wall: no tunnelling ----------------------------------------
func _s_boostwall(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			if s["t"] == 2:
				var o: Vector3 = s["origin"]
				add_child(PhysicsTestGround.wall(o + Vector3(-15, 0, -300), o + Vector3(15, 0, -300), 3.0))
				var r: float = CarDefs.geometry(car_id)["wheel_radius"]
				car.teleport(Transform3D(Basis.IDENTITY, o + Vector3(0, r, 0)), Vector3(0, 0, -Car.MAX_SPEED))
				car.apply_boost(Vector3.FORWARD, 60.0, 4.0)
				_phase(s, "go")
		"go":
			_ctl(car, 1.0, 0.0, 0.0, false, true)
			if s["t"] >= 120:
				var z := car.global_position.z - float(s["origin"].z)
				TestHooks.check(z > -300.0, "boost_no_wall_tunnel_%s" % car_id, "z=%.1f" % z)
				s["done"] = true


# --- a car sliding on its roof stops and self-rights --------------------------------------------
func _s_roofslide(s: Dictionary, car: Car) -> void:
	match s["state"]:
		"start":
			if s["t"] == 2:
				var o: Vector3 = s["origin"]
				car.teleport(Transform3D(Basis(Vector3.FORWARD, PI), o + Vector3(0, 1.2, 0)), Vector3(0, 0, -30.0))
				_phase(s, "slide")
		"slide":
			_ctl(car, 0.0, 0.0, 0.0)
			if s["t"] == 240:
				TestHooks.check(car.linear_velocity.length() < 3.0, "roof_slide_stops_%s" % car_id, "%.1f m/s" % car.linear_velocity.length())
			if s["t"] >= 480:
				TestHooks.check(car.global_transform.basis.y.y > 0.9, "roof_slide_rights_%s" % car_id, "up_y %.2f" % car.global_transform.basis.y.y)
				s["done"] = true
