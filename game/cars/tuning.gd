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
const TOP_KMH_RANGE := Vector2(228.0, 330.0)
const ACCEL_S_RANGE := Vector2(4.35, 3.05)       # slow .. quick (0-100 + 0-200 * ACCEL_200_WEIGHT)
const ACCEL_200_WEIGHT := 0.25
const SHIFT_LOSS := 0.985                         # average drive loss from shift cuts (fitted)
const HANDLING_RANGE := Vector2(0.1, 1.9)
const DRIFT_RANGE := Vector2(-0.45, 1.7)
const NITRO_RANGE := Vector2(3.5, 12.0)          # m/s^2
const NITRO_TIME_RANGE := Vector2(2.0, 9.0)      # s
const POWER_SCALE := 1.35
## TMNF handling: the car's top speed (where TMNF's over-speed push starts) = v_top x this
const TM_TOP_SCALE := 1.12


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
	# M7: more power for Trackmania-style acceleration; drag is calibrated from the same power,
	# so every car keeps its top speed
	b["power"] = float(b["power"]) * POWER_SCALE
	var p := {}
	p["car"] = car_id
	p["drive"] = String(CarDefs.get_def(car_id).get("drive", "rwd"))
	p["mass"] = b["mass"]
	p["power"] = float(b["power"]) * (1.0 - 0.06 * minf(gearing, 0.0) - 0.025 * maxf(gearing, 0.0))   # short gears: more wheel torque
	p["shape_low"] = b["torque_low"]
	p["shape_peak_u"] = b["torque_peak_u"]
	p["turbo"] = turbo
	p["shape_norm"] = CarPhysicsDefs.shape_norm(b["torque_low"], b["torque_peak_u"])
	# drag calibrated so that peak power balances drag + rolling at v_top
	var v_top: float = b["v_top"]
	var rolling: float = 0.015 * float(b["mass"]) * G
	var drag_stock := (float(b["power"]) - rolling * v_top) / pow(v_top, 3.0)
	p["rolling"] = rolling
	p["drag"] = drag_stock * (1.0 + 0.085 * downforce)
	var g6 := v_top * float(b["gear6_over_top"]) * (1.0 + 0.11 * gearing)
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
	p["power_oversteer"] = float(b.get("power_oversteer", 0.0))
	p["drift_assist"] = float(b["drift_assist"]) * (1.0 + 0.35 * balance) * (1.0 - 0.15 * susp)
	p["brake_decel"] = float(b["brake_g"]) * G
	p["nitro_accel"] = float(b["nitro_accel"]) * (1.0 + 0.35 * nitro)
	p["nitro_time"] = float(b["nitro_time"]) * (1.0 - 0.45 * nitro)
	p["cg_height"] = b["cg_height"]
	p["loose_grip"] = clampf(float(b.get("loose_grip", 0.0)), 0.0, 1.0)
	# TMNF handling (CarTm, session 9): multipliers on the Stadium car's model, relative to a stock Kaze
	var kz := CarPhysicsDefs.base("kaze")
	var pw_ref := float(kz["power"]) * POWER_SCALE / float(kz["mass"])
	p["tm_accel"] = pow(float(p["power"]) / float(p["mass"]) / pw_ref, 0.6)
	p["tm_top"] = v_top * (1.0 + 0.11 * gearing) * TM_TOP_SCALE
	p["tm_steer"] = float(p["steer_speed"])
	p["tm_grip"] = float(p["grip"]) / float(kz["grip"])
	p["tm_brake"] = float(p["brake_decel"]) / (float(kz["brake_g"]) * G)
	p["tm_slide"] = 0.35 * float(p["rear_slide"]) / float(kz["rear_slide"])
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
	# same rule as Car (M7): AWD can use the whole load, RWD a fixed share of it
	var share := 1.0 if p["drive"] == "awd" else Car.RWD_TRACTION_SHARE
	return float(p["traction"]) * Car.TRACTION_SCALE * (m * G + df) * share


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
	# 0-100 and 0-200: integrate at 60 Hz with the same gear logic and shift cuts as the car
	var dt := 1.0 / 60.0
	var v := 0.0
	var t := 0.0
	var gear := 1
	var t100 := -1.0
	var t200 := 30.0
	while t < 30.0:
		# ideal gear choice (smooth in the params); shift cuts are folded into SHIFT_LOSS
		gear = best_gear(p, v, gear)
		var f := minf(drive_force(p, gear, v), traction_limit(p, v)) * SHIFT_LOSS
		var a := (f - drag_force(p, v)) / m
		var v0 := v
		v += a * dt
		t += dt
		if t100 < 0.0 and v >= 27.78:
			t100 = t - dt * (v - 27.78) / maxf(v - v0, 1e-4)
		if v >= 55.56:
			t200 = t - dt * (v - 55.56) / maxf(v - v0, 1e-4)
			break
	return {"top_speed_kmh": v_top * 3.6, "zero_to_100_s": t100 if t100 > 0.0 else 30.0, "zero_to_200_s": t200}


static func _norm(x: float, r: Vector2) -> float:
	return clampf((x - r.x) / (r.y - r.x), 0.0, 1.0)


## Normalized stats for the garage UI. Extra keys: zero_to_200_s, nitro_duration_s (and
## nitro_duration 0..1), handling_raw, drift_raw.
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
		"accel": _norm(float(e["zero_to_100_s"]) + float(e["zero_to_200_s"]) * ACCEL_200_WEIGHT, ACCEL_S_RANGE),
		"handling": _norm(handling, HANDLING_RANGE),
		"drift": _norm(drift, DRIFT_RANGE),
		"nitro": _norm(float(p["nitro_accel"]), NITRO_RANGE),
		"top_speed_kmh": snappedf(e["top_speed_kmh"], 0.1),
		"zero_to_100_s": snappedf(e["zero_to_100_s"], 0.01),
		"zero_to_200_s": snappedf(e["zero_to_200_s"], 0.01),
		"nitro_duration_s": snappedf(float(p["nitro_time"]), 0.1),
		"nitro_duration": _norm(float(p["nitro_time"]), NITRO_TIME_RANGE),
		"accel_raw": float(e["zero_to_100_s"]) + float(e["zero_to_200_s"]) * ACCEL_200_WEIGHT,
		"handling_raw": handling,
		"drift_raw": drift,
	}
