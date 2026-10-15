extends Node3D
## Straight-line test per car on a long flat ground: 0-100 km/h time, top speed, braking 100->0,
## nitro top-speed gain, and estimate-vs-measured comparison for Tuning.stats().
## Run: tools/run_scene.sh res://tests/physics/test_straight.tscn --headless -- --frames=4000

var cars: Array[Car] = []
var tick := 0
var t100: Array[float] = []
var vmax: Array[float] = []
var brake_start: Array[Vector3] = []
var brake_dist: Array[float] = []
var nitro_vmax: Array[float] = []
var phase := "settle"
var phase_tick := 0
var tuning_arg := {}

const ACCEL_TICKS := 60 * 48


func _ready() -> void:
	add_child(PhysicsTestGround.flat_pad(400.0, 12000.0, Vector3(0, 0, -5800)))
	var ids: Array = CarDefs.IDS
	var only := String(TestHooks.arg("car", ""))
	if only != "":
		ids = [only]
	for k in CarDefs.TUNING_KEYS:
		if TestHooks.has_arg(k):
			tuning_arg[k] = float(TestHooks.arg(k, 0.0))
	for i in ids.size():
		var cfg := CarDefs.default_config(ids[i])
		for k in tuning_arg:
			cfg["tuning"][k] = tuning_arg[k]
		var car := Car.create(cfg)
		add_child(car)
		car.teleport(Transform3D(Basis.IDENTITY, Vector3(-60 + i * 60, 0.6, 0)))
		car.frozen_controls = true
		cars.append(car)
		t100.append(-1.0)
		vmax.append(0.0)
		brake_dist.append(-1.0)
		nitro_vmax.append(0.0)
		brake_start.append(Vector3.ZERO)


func _physics_process(_delta: float) -> void:
	tick += 1
	phase_tick += 1
	match phase:
		"settle":
			if phase_tick == 60:
				for car in cars:
					var y := car.global_position.y
					var r: float = CarDefs.geometry(car.car_id)["wheel_radius"]
					TestHooks.check(absf(y - r) < 0.05, "rest_height_%s" % car.car_id, "y=%.3f expected %.3f" % [y, r])
					car.frozen_controls = false
					car.controls["throttle"] = 1.0
				phase = "accel"
				phase_tick = 0
		"accel":
			var t := phase_tick / 60.0
			for i in cars.size():
				var v := cars[i].get_speed_kmh()
				vmax[i] = maxf(vmax[i], v)
				if t100[i] < 0.0 and v >= 100.0:
					t100[i] = t
				if phase_tick % 300 == 0:
					print("  %s t=%.0f v=%.1f gear=%d rpm=%.2f" % [cars[i].car_id, t, v, cars[i].get_gear(), cars[i].get_rpm_ratio()])
			if phase_tick >= ACCEL_TICKS:
				for i in cars.size():
					cars[i].controls["nitro"] = true
				phase = "nitro"
				phase_tick = 0
		"nitro":
			for i in cars.size():
				nitro_vmax[i] = maxf(nitro_vmax[i], cars[i].get_speed_kmh())
			if phase_tick >= 60 * 5:
				_report_accel()
				for i in cars.size():
					var car := cars[i]
					car.controls["nitro"] = false
					car.controls["throttle"] = 0.0
					car.controls["brake"] = 1.0
					car.teleport(Transform3D(Basis.IDENTITY, Vector3(-60 + i * 60, cars[i].get_wheelbase() * 0.0 + CarDefs.geometry(car.car_id)["wheel_radius"], 0)), Vector3(0, 0, -100.0 / 3.6))
					brake_start[i] = car.global_position
				phase = "brake"
				phase_tick = 0
		"brake":
			var done := true
			for i in cars.size():
				if brake_dist[i] < 0.0:
					if cars[i].linear_velocity.length() < 0.3 or phase_tick > 600:
						brake_dist[i] = (cars[i].global_position - brake_start[i]).length()
					else:
						done = false
			if done:
				_report_brake()
				TestHooks.finish()


func _report_accel() -> void:
	for i in cars.size():
		var id := cars[i].car_id
		var st := Tuning.stats(id, tuning_arg)
		print("RESULT %s 0-100=%.2fs (est %.2f) top=%.1f km/h (est %.1f) nitro_top=%.1f" % [id, t100[i], st["zero_to_100_s"], vmax[i], st["top_speed_kmh"], nitro_vmax[i]])
		TestHooks.check(t100[i] > 2.2 and t100[i] < 4.2, "zero_to_100_%s" % id, "%.2f s" % t100[i])
		if tuning_arg.is_empty():
			TestHooks.check(vmax[i] > 245.0 and vmax[i] < 330.0, "top_speed_%s" % id, "%.1f km/h" % vmax[i])
		TestHooks.check(absf(vmax[i] - float(st["top_speed_kmh"])) < 12.0, "top_estimate_%s" % id, "measured %.1f est %.1f" % [vmax[i], st["top_speed_kmh"]])
		TestHooks.check(absf(t100[i] - float(st["zero_to_100_s"])) < 0.45, "accel_estimate_%s" % id, "measured %.2f est %.2f" % [t100[i], st["zero_to_100_s"]])
		TestHooks.check(nitro_vmax[i] > vmax[i] + 8.0, "nitro_raises_top_%s" % id, "%.1f vs %.1f" % [nitro_vmax[i], vmax[i]])
	if tuning_arg.is_empty() and cars.size() == 3:
		TestHooks.check(t100[1] <= t100[0] and t100[1] <= t100[2], "brute_quickest_launch", str(t100))
		TestHooks.check(vmax[2] >= vmax[0] and vmax[2] >= vmax[1], "veloce_fastest", str(vmax))


func _report_brake() -> void:
	for i in cars.size():
		print("RESULT %s brake 100-0 = %.1f m" % [cars[i].car_id, brake_dist[i]])
		TestHooks.check(brake_dist[i] > 15.0 and brake_dist[i] < 45.0, "brake_100_0_%s" % cars[i].car_id, "%.1f m" % brake_dist[i])
