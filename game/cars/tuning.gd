class_name Tuning
extends RefCounted
## Maps the 7 tuning sliders (-1..1, DESIGN §3.1) to resolved physics params for `Car`, and
## estimates garage stats with a 1D longitudinal model that uses the same engine/drag/traction
## formulas as the car. API fixed by docs/ARCHITECTURE.md "Tuning".
##
## Trade-offs (no slider setting is strictly better):
##   gearing    -: shorter gears, more force per gear (accel)   +: higher limiter (top speed)
##   turbo      -: fat low-end torque (accel)                    +: top-end power (top speed)
##   downforce  -: less drag (top speed)                         +: more grip at speed (handling)
##   suspension -: soft, more mechanical grip (accel, drift)     +: stiff, responsive (handling)
##   balance    -: planted (handling)                            +: loose rear (drift)
##   steering   -: stable, forgiving (drift control)             +: sharp, more lock (handling)
##   nitro      -: long and gentle (more total boost)            +: short and strong (peak push)

const G := CarPhysicsDefs.GRAVITY

## Normalization ranges for stats (fitted over every car with every slider at -1/0/+1;
## see tests/physics/test_tuning.gd which prints the observed ranges).
const TOP_KMH_RANGE := Vector2(240.0, 335.0)
const ACCEL_S_RANGE := Vector2(3.9, 2.3)        # slow .. quick 0-100 time
const HANDLING_RANGE := Vector2(0.55, 1.45)
const DRIFT_RANGE := Vector2(0.15, 1.25)
const NITRO_RANGE := Vector2(3.5, 12.0)          # m/s^2


static func _t(tuning: Dictionary, key: String) -> float:
	var v: Variant = tuning.get(key, 0.0)
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return 0.0
	return clampf(float(v), -1.0, 1.0)


## Resolved physics parameters for Car, given a car id and tuning sliders (-1..1).
static func physics_params(car_id: String, tuning: Dictionary) -> Dictionary:
	var b := CarPhysicsDefs.base(car_id)
	var gearing := _t(tuning, "gearing")
	var turbo := _t(tuning, "turbo")
	var downforce := _t(tuning, "downforce")
	var susp := _t(tuning, "suspension")
	var balance := _t(tuning, "balance")
	var steering := _t(tuning, "steering")
	var nitro := _t(tuning, "nitro")
	var p := {}
	p["car"] = car_id
	p["drive"] = String(CarDefs.get_def(car_id).get("drive", "rwd"))
	p["mass"] = b["mass"]
	p["power"] = b["power"]
	p["shape_low"] = b["torque_low"]
	p["shape_peak_u"] = b["torque_peak_u"]
	p["turbo"] = turbo
	p["shape_norm"] = CarPhysicsDefs.shape_norm(b["torque_low"], b["torque_peak_u"])
	# drag calibrated so the stock car tops out at v_top in 6th
	var v_top: float = b["v_top"]
	var g6_stock: float = v_top * float(b["gear6_over_top"])
	var u_top := v_top / g6_stock
	var p_wheel_top: float = float(b["power"]) * u_top * CarPhysicsDefs.torque_shape(u_top, b["torque_low"], b["torque_peak_u"], 0.0) / float(p["shape_norm"])
	var rolling: float = 0.015 * float(b["mass"]) * G
	var drag_stock := (p_wheel_top - rolling * v_top) / pow(v_top, 3.0)
	p["rolling"] = rolling
	p["drag"] = drag_stock * (1.0 + 0.085 * downforce)
	var g6 := g6_stock * (1.0 + 0.11 * gearing)
	var tops: Array[float] = []
	for f in CarPhysicsDefs.GEAR_SPREAD:
		tops.append(g6 * f)
	p["gear_top"] = tops
	p["reverse_top"] = 13.0
	p["downforce"] = float(b["downforce"]) * (1.0 + 0.5 * downforce)
	p["weight_front"] = b["weight_front"]
	p["grip"] = float(b["grip"]) * (1.0 - 0.025 * susp)
	p["grip_long"] = b["grip_long"]
	p["traction"] = float(b["traction"]) * (1.0 - 0.05 * susp)
	p["slip_peak"] = deg_to_rad(float(b["slip_peak_deg"]))
	p["rear_slide"] = clampf(float(b["rear_slide"]) - 0.10 * balance, 0.4, 0.95)
	p["front_slide"] = b["front_slide"]
	p["rear_grip_bias"] = float(b["rear_grip_bias"]) * (1.0 - 0.07 * balance)
	p["spring_hz"] = float(b["spring_hz"]) * (1.0 + 0.22 * susp)
	p["damping"] = float(b["damping"]) + 0.07 * susp
	p["anti_roll"] = float(b["anti_roll"]) * (1.0 + 0.45 * susp)
	p["steer_max"] = deg_to_rad(float(b["steer_max_deg"]) * (1.0 + 0.10 * steering))
	p["steer_speed"] = float(b["steer_speed"]) * (1.0 + 0.35 * steering)
	p["yaw_damp"] = float(b["yaw_damp"]) * (1.0 - 0.30 * steering)
	p["drift_assist"] = float(b["drift_assist"]) * (1.0 + 0.35 * balance) * (1.0 - 0.15 * susp)
	p["brake_decel"] = float(b["brake_g"]) * G
	p["nitro_accel"] = float(b["nitro_accel"]) * (1.0 + 0.35 * nitro)
	p["nitro_time"] = float(b["nitro_time"]) * (1.0 - 0.45 * nitro)
	p["cg_height"] = b["cg_height"]
	return p


# --- engine model shared by Car and the estimator ----------------------------------------

## Wheel drive force (N) at full throttle in `gear` (1..6) at road speed v (m/s), before traction.
static func drive_force(p: Dictionary, gear: int, v: float) -> float:
	var tops: Array = p["gear_top"]
	var top: float = tops[clampi(gear, 1, 6) - 1]
	var u := clampf(absf(v) / top, 0.0, 1.0)
	if absf(v) >= top:
		return 0.0  # rev limiter
	var shape := CarPhysicsDefs.torque_shape(maxf(u, 0.12), p["shape_low"], p["shape_peak_u"], p["turbo"])
	return float(p["power"]) / top * shape / float(p["shape_norm"])


## Rpm ratio (0..1) for a road speed in a gear.
static func rpm_ratio(p: Dictionary, gear: int, v: float) -> float:
	if gear < 0:
		return clampf(absf(v) / float(p["reverse_top"]), 0.0, 1.0)
	var tops: Array = p["gear_top"]
	return clampf(absf(v) / float(tops[clampi(gear, 1, 6) - 1]), 0.0, 1.0)


## Best gear for speed v: highest force, never above the limiter.
static func best_gear(p: Dictionary, v: float, current: int) -> int:
	var tops: Array = p["gear_top"]
	var g := clampi(current, 1, 6)
	# upshift while the next gear gives at least as much force (or we're at the limiter)
	while g < 6 and (absf(v) > float(tops[g - 1]) * 0.97 or drive_force(p, g + 1, v) >= drive_force(p, g, v)):
		g += 1
	# downshift while the lower gear clearly gives more force and isn't near its limiter
	while g > 1 and absf(v) < float(tops[g - 2]) * 0.92 and drive_force(p, g - 1, v) > drive_force(p, g, v) * 1.04:
		g -= 1
	return g


static func drag_force(p: Dictionary, v: float) -> float:
	return float(p["drag"]) * v * v + float(p["rolling"])


static func traction_limit(p: Dictionary, v: float) -> float:
	var m: float = p["mass"]
	var df := float(p["downforce"]) * v * v
	var share := 1.0 if p["drive"] == "awd" else (1.0 - float(p["weight_front"])) + 0.08
	return float(p["traction"]) * (m * G + df) * share


# --- estimates ----------------------------------------------------------------------------

## 1D straight-line estimate: {top_speed_kmh, zero_to_100_s}. Deterministic.
static func estimate(p: Dictionary) -> Dictionary:
	var m: float = p["mass"]
	# top speed: highest v where full-throttle force in the best gear >= drag
	var tops: Array = p["gear_top"]
	var v_lim: float = float(tops[5]) * 0.995
	var lo := 5.0
	var hi := v_lim
	for i in 40:
		var mid := (lo + hi) * 0.5
		var f := drive_force(p, best_gear(p, mid, 6), mid)
		if f > drag_force(p, mid):
			lo = mid
		else:
			hi = mid
	var v_top := lo
	# 0-100: integrate at 60 Hz with the same gear logic and shift cuts as the car
	var dt := 1.0 / 60.0
	var v := 0.0
	var t := 0.0
	var gear := 1
	var cut := 0.0
	while v < 27.78 and t < 20.0:
		var ng := best_gear(p, v, gear)
		if ng != gear:
			gear = ng
			cut = Car.SHIFT_TIME
		var f := minf(drive_force(p, gear, v), traction_limit(p, v))
		if cut > 0.0:
			f *= Car.SHIFT_CUT
			cut -= dt
		v += (f - drag_force(p, v)) / m * dt
		t += dt
	return {"top_speed_kmh": v_top * 3.6, "zero_to_100_s": t}


static func _norm(x: float, r: Vector2) -> float:
	return clampf((x - r.x) / (r.y - r.x), 0.0, 1.0)


## Normalized stats for the garage UI. Extra keys: nitro_duration_s, handling_raw, drift_raw.
static func stats(car_id: String, tuning: Dictionary) -> Dictionary:
	var p := physics_params(car_id, tuning)
	var e := estimate(p)
	var m: float = p["mass"]
	# handling: lateral grip at 150 km/h + steering response + stiffness + planted rear
	var v := 41.7
	var lat_g := float(p["grip"]) * (1.0 + float(p["downforce"]) * v * v / (m * G))
	var handling := lat_g * 0.45 \
		+ (float(p["steer_speed"]) - 1.0) * 0.5 \
		+ (float(p["spring_hz"]) - 2.0) * 0.35 \
		+ (minf(float(p["rear_grip_bias"]), 1.06) - 1.0) * 1.5 \
		+ (float(p["steer_max"]) - deg_to_rad(32.0)) * 1.2
	var drift := (1.0 - float(p["rear_slide"])) * 2.2 \
		+ (1.0 - float(p["rear_grip_bias"])) * 3.0 \
		+ (float(p["drift_assist"]) - 1.0) * 0.6 \
		+ (float(p["yaw_damp"]) - 1.0) * 0.5 \
		+ (2.0 - float(p["spring_hz"])) * 0.15 \
		+ (0.2 if p["drive"] == "rwd" else 0.0)
	return {
		"top_speed": _norm(e["top_speed_kmh"], TOP_KMH_RANGE),
		"accel": _norm(e["zero_to_100_s"], ACCEL_S_RANGE),
		"handling": _norm(handling, HANDLING_RANGE),
		"drift": _norm(drift, DRIFT_RANGE),
		"nitro": _norm(float(p["nitro_accel"]), NITRO_RANGE),
		"top_speed_kmh": snappedf(e["top_speed_kmh"], 0.1),
		"zero_to_100_s": snappedf(e["zero_to_100_s"], 0.01),
		"nitro_duration_s": snappedf(float(p["nitro_time"]), 0.1),
		"handling_raw": handling,
		"drift_raw": drift,
	}
