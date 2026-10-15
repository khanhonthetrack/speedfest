extends Node3D
## Loose surfaces vs car type (session 6 car types). Two runs per car, each on asphalt and on sand:
##  "launch": full throttle from a standstill for 4 s: every car must get out of a sand trap.
##  "carry": full throttle for 3 s entering at 120 km/h: the Kitsune R4's rally tires
##  ("loose_grip" 0.75) must keep much more of its asphalt speed than a road car, and the Goliath
##  ("loose_grip" 0.45) sits in between.
## Run: tools/run_scene.sh res://tests/physics/test_loose.tscn --headless -- --frames=600

const CARS := ["kaze", "brute", "veloce", "pixie", "goliath", "kitsune"]
const TICKS := {"launch": 240, "carry": 180}

var runs: Array = []   # [{car, id, sand, kind}]
var tick := 0


func _ready() -> void:
	add_child(PhysicsTestGround.flat_pad(1200.0, 3000.0, Vector3(0, 0, -1200)))
	var x := -560.0
	for id in CARS:
		for run in ["launch", "carry"]:
			_spawn(id, run, x)
			x += 90.0


func _spawn(id: String, run: String, x: float) -> void:
	for sand in [false, true]:
		var car := Car.create(PhysicsTestGround.test_config(id))
		add_child(car)
		for c in car.get_children():
			if c is CarInput:
				(c as CarInput).enabled = false
		var surf := TrackSurface.new()
		surf.set_mode("dry")
		if sand:
			surf.add_patch(TrackSurface.kind_id("sand"), 0.0, 1e6, -1e3, 1e3,
				[{"xf": Transform3D(Basis.IDENTITY, Vector3(x + 40.0, 0, -1200)), "hx": 15.0, "hz": 1500.0}])
		car.surface = surf
		var r: float = CarDefs.geometry(id)["wheel_radius"]
		var lx := x + (40.0 if sand else 0.0)
		car.teleport(Transform3D(Basis.IDENTITY, Vector3(lx, r + 0.05, 0)))
		runs.append({"car": car, "id": id, "sand": sand, "kind": run, "x": lx})


func _physics_process(_delta: float) -> void:
	tick += 1
	if tick < 30:
		return   # settle
	for r in runs:
		var car := r["car"] as Car
		if tick == 30 and r["kind"] == "carry":
			var r0: float = CarDefs.geometry(r["id"])["wheel_radius"]
			car.teleport(Transform3D(Basis.IDENTITY, Vector3(float(r["x"]), r0 + 0.02, 0)), Vector3(0, 0, -120.0 / 3.6))
		if tick - 30 == int(TICKS[r["kind"]]):
			r["kmh"] = car.get_speed_kmh()
		car.controls = {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "handbrake": false, "nitro": false}
	if tick < 31 + int(TICKS["launch"]):
		return
	var keep := {}
	for id in CARS:
		var v := {}
		for r in runs:
			if r["id"] == id:
				v["%s_%s" % [r["kind"], "sand" if r["sand"] else "asphalt"]] = float(r["kmh"])
		keep[id] = float(v["carry_sand"]) / maxf(float(v["carry_asphalt"]), 1.0)
		print("LOOSE %s launch asphalt=%.0f sand=%.0f | carry asphalt=%.0f sand=%.0f km/h keep=%.2f" % [id,
			v["launch_asphalt"], v["launch_sand"], v["carry_asphalt"], v["carry_sand"], keep[id]])
		TestHooks.check(float(v["launch_sand"]) > 30.0, "%s_drives_out_of_sand" % id, "%.0f km/h after 4 s" % v["launch_sand"])
	TestHooks.check(float(keep["kitsune"]) > float(keep["kaze"]) + 0.1, "kitsune_rally_tires_on_sand", str(keep))
	TestHooks.check(float(keep["goliath"]) > float(keep["kaze"]) and float(keep["goliath"]) < float(keep["kitsune"]), "goliath_between", str(keep))
	TestHooks.finish()
