extends Node3D
## AutoDriver on a closed test circuit (hairpin, sweepers, banked turn, elevation) without walls:
## must complete 2 laps without leaving the road or resetting. Prints lap times.
## Run: tools/run_scene.sh res://tests/physics/test_circuit.tscn --headless -- --car=kaze

var car_id := "kaze"
var path: TrackPath
var car: Car
var ai: AutoDriver
var tick := 0
var stuck_count := 0
var off_ticks := 0
var max_off := -99.0
var lap_ticks: Array[int] = []
var last_lap_tick := 0
var max_kmh := 0.0
var cam: Camera3D


func _ready() -> void:
	car_id = String(TestHooks.arg("car", "kaze"))
	path = PhysicsTestGround.circuit_path(14.0)
	add_child(PhysicsTestGround.road_from_path(path))
	car = Car.create(CarDefs.default_config(car_id))
	add_child(car)
	var t := path.sample_transform(0.0)
	t.origin += t.basis.y * 0.6
	car.teleport(t)
	ai = AutoDriver.new()
	ai.path = path
	car.add_child(ai)
	ai.stuck.connect(func() -> void: stuck_count += 1)
	print("circuit length %.0f m" % path.length)
	if not TestHooks.has_arg("headless_only"):
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55, 20, 0)
		add_child(sun)
		cam = Camera3D.new()
		add_child(cam)


func _physics_process(_delta: float) -> void:
	tick += 1
	max_kmh = maxf(max_kmh, car.get_speed_kmh())
	var d := ai.get_distance()
	var tr := path.sample_transform(d)
	var lc := tr.affine_inverse() * car.global_position
	var off := absf(lc.x) - path.width_at(d) * 0.5
	max_off = maxf(max_off, off)
	if off > 0.5:
		off_ticks += 1
	if TestHooks.has_arg("trace") and (tick % 15 == 0) and tick < 60 * 30:
		print("  t=%.2f d=%.0f v=%.0f vt=%.0f thr=%.1f br=%.1f st=%.2f n=%d drift=%.2f slip=%.0f off=%.1f lat=%.1f" % [tick / 60.0, d, car.get_speed_kmh(), ai._target_speed(car.linear_velocity.length()) * 3.6, car.controls["throttle"], car.controls["brake"], car.controls["steer"], int(car.controls["nitro"]), car.get_drift_amount(), rad_to_deg(car.get_slip_angle()), off, lc.x])
	var laps := int(floor(ai.get_progress() / path.length))
	if laps > lap_ticks.size():
		lap_ticks.append(tick - last_lap_tick)
		last_lap_tick = tick
		print("RESULT circuit %s lap %d time=%.2fs avg=%.0f km/h" % [car_id, laps, (lap_ticks[-1]) / 60.0, path.length / (lap_ticks[-1] / 60.0) * 3.6])
	if lap_ticks.size() >= 2 or tick > 60 * 150:
		print("RESULT circuit %s laps=%d max=%.0f km/h stuck=%d off_ticks=%d max_off=%.2f m" % [car_id, lap_ticks.size(), max_kmh, stuck_count, off_ticks, max_off])
		TestHooks.check(lap_ticks.size() >= 2, "circuit_two_laps_%s" % car_id, "laps %d" % lap_ticks.size())
		TestHooks.check(stuck_count == 0, "circuit_no_stuck_%s" % car_id, "%d" % stuck_count)
		TestHooks.check(off_ticks < 30, "circuit_stays_on_road_%s" % car_id, "%d ticks off, max %.2f m" % [off_ticks, max_off])
		TestHooks.finish()


func _process(_delta: float) -> void:
	if cam:
		var b := car.global_transform.basis
		cam.global_position = car.global_position + b.z * 7.0 + Vector3.UP * 2.5
		cam.look_at(car.global_position + Vector3.UP, Vector3.UP)
