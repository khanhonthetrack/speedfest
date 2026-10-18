extends Node3D
## Research harness (M10): our car against a TMNF ghost over short stretches. Loads a TMNF map
## (--map) and one of its ghosts as JSON (tools/research/tmnf/ghost_dump.py --json: the samples
## every 100 ms and the run's controls every 10 ms), then for every --every'th sample puts our car
## in the ghost's state there (mirrored: our world is TMNF's mirror image, x negated) and drives it
## --horizon ms with the run's own controls; prints how far it ends from the ghost and the speeds,
## by the surface the wheels were on. --cols=a,b,c,d: which of TMNF's four surface factor columns
## (TmTuning.SURFACES as read) the model takes as top speed, accel, brake and grip (default
## 0,2,3,1, the reading these runs settled: M10-3; 0,1,2,3 was the one before).
##
## run: tools/run.sh res://race/ghost_fit.tscn --headless -- --map=<X.Challenge.Gbx>
##      --ghost=<X.json> [--horizon=500] [--every=1] [--cols=0,2,3,1] [--only=2,6] [--dump]

const T := preload("res://core/tm_tuning.gd")
## The car's centre of mass from a TMNF ghost's position, in the car's frame: a ghost records the
## car's model origin, the centre of mass sits 0.4385 above it and 0.288 ahead (StadiumCar.Solid;
## measured too: 0.43 m higher on flat ground, and the recorded positions move like a point behind
## the recorded velocities' by 0.29-0.40 m in turns: M10-4).
const OFFSET := Vector3(0.0, 0.4385, 0.28825)

var builder: TmMapBuilder
var car: TmCar


func _ready() -> void:
	var ch := TmStage.load_from_args()
	if not ch.ok():
		push_error("ghost_fit: %s" % ch.error)
		TestHooks.finish()
		return
	builder = TmMapBuilder.build(ch)
	add_child(builder.root)
	var f := FileAccess.open(String(TestHooks.arg("ghost", "")), FileAccess.READ)
	if f == null:
		push_error("ghost_fit: no --ghost json")
		TestHooks.finish()
		return
	var g: Dictionary = JSON.parse_string(f.get_as_text())
	car = TmCar.new()
	add_child(car)
	car.set_physics_process(false)
	_columns(String(TestHooks.arg("cols", "0,2,3,1")))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_fit(g)
	TestHooks.finish()


## TMNF's surface factor table as read (TmTuning.SURFACES rows), the columns `cols` names taken as
## the top speed, accel, brake and grip.
func _columns(spec: String) -> void:
	var c := spec.split(",")
	var m := car.model
	for id: int in T.SURFACES:
		var raw: Array = T.SURFACES[id]
		var f := [0.0, 0.0, 0.0, 0.0]
		f[T.S_TOP] = raw[int(c[0])]
		f[T.S_ACCEL] = raw[int(c[1])]
		f[T.S_BRAKE] = raw[int(c[2])]
		f[T.S_GRIP] = raw[int(c[3])]
		m.surface_override[id] = f


static func _mirror_pos(p: Array) -> Vector3:
	return Vector3(-float(p[0]), float(p[1]), float(p[2]))


static func _mirror_basis(q: Array) -> Basis:
	return Basis(Quaternion(float(q[0]), -float(q[1]), -float(q[2]), float(q[3])).normalized())


## The ghost's sample as our car's transform (centre of mass), velocity and angular velocity.
static func state_of(s: Dictionary) -> Array:
	var b := _mirror_basis(s["quat"])
	var o := _mirror_pos(s["pos"]) + b * OFFSET
	var v: Array = s["vel"]
	var w: Array = s["angvel"]
	return [Transform3D(b, o), Vector3(-float(v[0]), float(v[1]), float(v[2])),
		Vector3(float(w[0]), -float(w[1]), -float(w[2]))]


static func surfaces_of(s: Dictionary) -> String:
	var out := []
	for w: Dictionary in s.get("wheels", []):
		out.append(str(int(w["surface"])) + ("*" if bool(w.get("sliding", false)) else "") if bool(w.get("ground", true)) else "air")
	return ",".join(out)


func _fit(g: Dictionary) -> void:
	var samples: Array = g["record"]["samples"]
	var controls: Array = g["controls"]
	var period := int(g["record"]["period_ms"])
	var horizon := int(TestHooks.arg("horizon", 500))
	var every := int(TestHooks.arg("every", 1))
	var only := String(TestHooks.arg("only", ""))
	var dump := TestHooks.has_arg("dump")
	var hs := horizon / period
	var by := {}                      # group -> [distances, |speed diffs|]
	for i in range(0, samples.size() - hs, every):
		var s0: Dictionary = samples[i]
		var s1: Dictionary = samples[i + hs]
		var t0 := int(s0["t"])
		if t0 / 10 + horizon / 10 >= controls.size():
			break
		var group := surfaces_of(s0)
		var ids := group.replace("*", "").split(",")
		if not only.is_empty() and not (ids.size() == 4 and ids[0] == ids[1] and ids[1] == ids[2] and ids[2] == ids[3]
				and only.split(",").has(ids[0])):
			continue
		var st := state_of(s0)
		car.body.reset()
		car.model.reset()
		car.body.xform = st[0]
		car.transform = st[0]
		car.body.lin_vel = st[1]
		car.body.ang_vel = st[2]
		car.model.steer = float(s0.get("steer", 0.0))     # (TMNF + right = our + left, mirrored)
		for k in horizon / 10:
			var c: Array = controls[t0 / 10 + k]
			car.gas = float(c[0])
			car.brake = float(c[1])
			car.steer = float(c[2])
			car.step_tick()
		var want := state_of(s1)
		var d := car.body.xform.origin.distance_to((want[0] as Transform3D).origin)
		var v_ours := car.body.lin_vel.length() * 3.6
		var v_tm := (want[1] as Vector3).length() * 3.6
		var key := "all4:" + ids[0] if ids.size() == 4 and ids[0] == ids[1] and ids[1] == ids[2] and ids[2] == ids[3] else "mixed"
		if group.contains("air"):
			key = "air" if group.count("air") == 4 else "partly air"
		if not by.has(key):
			by[key] = [[], []]
		by[key][0].append(d)
		by[key][1].append(absf(v_ours - v_tm))
		if dump:
			print("FIT t %6d  %-22s apart %6.2f m  speed TMNF %6.1f ours %6.1f  ghost then %s" % [t0, group, d, v_tm, v_ours,
				surfaces_of(s1)])
	# medians and the 75th percentile: a few runs end in a crash where our terrain differs from TMNF's
	for key: String in by:
		var d: Array = by[key][0]
		var sp: Array = by[key][1]
		print("FIT_SUMMARY %-12s n %4d  apart median %5.2f p75 %5.2f m  |speed diff| median %5.2f p75 %5.2f km/h" % [
			key, d.size(), _pct(d, 0.5), _pct(d, 0.75), _pct(sp, 0.5), _pct(sp, 0.75)])


static func _pct(xs: Array, q: float) -> float:
	var s := xs.duplicate()
	s.sort()
	return float(s[mini(s.size() - 1, int(q * s.size()))])
