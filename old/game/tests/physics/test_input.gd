extends Node3D
## CarInput: keyboard steering ramps up (slower at speed), self-centers, counter-steers quickly,
## and the limit shrinks at high speed. Uses Input.action_press to simulate keys.

var car: Car
var inp: CarInput
var tick := 0
var rec := {}


func _ready() -> void:
	add_child(PhysicsTestGround.flat_pad(400, 4000, Vector3(0, 0, -1800)))
	car = Car.create(CarDefs.default_config("kaze"))
	add_child(car)
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)))
	inp = CarInput.new()
	car.add_child(inp)


func _physics_process(_delta: float) -> void:
	tick += 1
	match tick:
		10:
			Input.action_press("steer_right")
		16:
			rec["ramp_6"] = inp.steer_value
		40:
			rec["full_low"] = inp.steer_value
			Input.action_release("steer_right")
		46:
			rec["center_6"] = inp.steer_value
		60:
			Input.action_press("steer_right")
		90:
			Input.action_release("steer_right")
			Input.action_press("steer_left")
		96:
			rec["counter_6"] = inp.steer_value
			Input.action_release("steer_left")
		120:
			car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), Vector3(0, 0, -230.0 / 3.6))
			Input.action_press("accelerate")
		130:
			Input.action_press("steer_right")
		136:
			rec["ramp_6_fast"] = inp.steer_value
		170:
			rec["full_fast"] = inp.steer_value
			Input.action_release("steer_right")
			Input.action_release("accelerate")
			_report()


func _report() -> void:
	print("RESULT input %s" % rec)
	# M7 (Trackmania feel): one quick ramp at every speed; the car limits the angle by grip
	TestHooks.check(rec["ramp_6"] >= 0.9, "input_ramp_low_speed", str(rec["ramp_6"]))
	TestHooks.check(absf(rec["full_low"] - 1.0) < 0.01, "input_full_lock_low_speed", str(rec["full_low"]))
	TestHooks.check(rec["center_6"] < 0.35, "input_self_centers", str(rec["center_6"]))
	TestHooks.check(rec["counter_6"] < 0.0, "input_fast_countersteer", str(rec["counter_6"]))
	TestHooks.check(rec["ramp_6_fast"] >= 0.9, "input_quick_ramp_at_speed", "%.2f" % rec["ramp_6_fast"])
	TestHooks.check(rec["full_fast"] > 0.99, "input_full_lock_at_speed", str(rec["full_fast"]))
	TestHooks.check(float(car.controls["steer"]) == inp.steer_value, "input_writes_controls")
	TestHooks.finish()
