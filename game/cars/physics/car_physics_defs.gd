class_name CarPhysicsDefs
extends RefCounted
## Stock (untuned) physics parameters per car. `Tuning.physics_params()` starts from these and
## applies the 7 sliders. Units: SI (m, s, kg, N, W). Speeds in m/s.
##
## The engine model is "constant power with a torque-curve shape": in gear g the wheel force at
## rpm ratio u is  F = power / gear_top[g] * shape(u) / SHAPE_NORM, so peak power is reached near
## u ~ 0.85 in every gear. gear_top[g] is the road speed at the rev limiter in that gear.

const GRAVITY := 9.8

## Gear top speeds as a fraction of 6th gear's top speed.
const GEAR_SPREAD: Array[float] = [0.24, 0.38, 0.52, 0.67, 0.83, 1.0]

const TOP_FALL := 0.55      # torque at the limiter relative to peak
const TURBO_PIVOT := 0.86
const TURBO_AMOUNT := 0.45

const BASE := {
	"kaze": {
		"mass": 1180.0,
		"power": 315000.0,          # W at the wheels (peak)
		"v_top": 81.8,              # drag-limited top speed at peak power, m/s (stock tops out ~3.5% lower on the limiter)
		"gear6_over_top": 1.02,     # stock 6th-gear limiter speed / v_top
		"torque_low": 0.80,         # torque-curve shape at idle (relative)
		"torque_peak_u": 0.62,      # rpm ratio of peak torque
		"weight_front": 0.52,       # static weight on the front axle
		"grip": 1.55,               # lateral friction coefficient
		"grip_long": 1.75,          # longitudinal friction coefficient (brakes)
		"traction": 1.72,           # drive traction coefficient on the driven wheels (launch)
		"slip_peak_deg": 7.5,       # slip angle of peak lateral grip
		"rear_slide": 0.70,         # rear grip ratio when fully sliding (lower = drifts more)
		"front_slide": 0.88,
		"rear_grip_bias": 1.00,     # rear/front lateral grip ratio
		"downforce": 1.25,          # N per (m/s)^2
		"spring_hz": 2.1,           # suspension natural frequency
		"damping": 0.42,            # fraction of critical damping
		"anti_roll": 0.55,          # fraction of spring rate
		"steer_max_deg": 33.0,
		"steer_speed": 1.0,
		"brake_g": 1.30,
		"nitro_accel": 7.0,
		"nitro_time": 5.5,   # one fixed tank per run (owner: NOS is strategy, no refill)
		"drift_assist": 1.0,
		"yaw_damp": 1.0,            # stability assist strength (Car.STAB_YAW); lively but catchable
		"power_oversteer": 0.4,     # throttle-held slides grow into drifts (0 = only on handbrake/brake-drift)
		"cg_height": 0.12,          # center of mass height above the wheel centers (negative = lower)
	},
	"brute": {
		"mass": 1480.0,
		"power": 400000.0,
		"v_top": 78.3,
		"gear6_over_top": 1.02,
		"torque_low": 1.00,         # big-block: flat, fat low end
		"torque_peak_u": 0.45,
		"weight_front": 0.54,
		"grip": 1.50,
		"grip_long": 1.80,
		"traction": 2.12,
		"slip_peak_deg": 8.0,
		"rear_slide": 0.66,
		"front_slide": 0.86,
		"rear_grip_bias": 1.0,
		"downforce": 1.30,
		"spring_hz": 1.9,
		"damping": 0.40,
		"anti_roll": 0.45,
		"steer_max_deg": 32.0,
		"steer_speed": 0.9,
		"brake_g": 1.25,
		"nitro_accel": 8.5,
		"nitro_time": 6.5,   # one fixed tank per run (owner: NOS is strategy, no refill)
		"drift_assist": 1.0,
		"yaw_damp": 1.2,
		"power_oversteer": 0.25,
		"cg_height": 0.14,
	},
	"veloce": {
		"mass": 1340.0,
		"power": 430000.0,
		"v_top": 89.5,
		"gear6_over_top": 1.02,
		"torque_low": 0.70,
		"torque_peak_u": 0.70,
		"weight_front": 0.43,
		"grip": 1.68,
		"grip_long": 1.80,
		"traction": 1.02,
		"slip_peak_deg": 7.0,
		"rear_slide": 0.80,
		"front_slide": 0.90,
		"rear_grip_bias": 1.04,
		"downforce": 1.45,
		"spring_hz": 2.3,
		"damping": 0.45,
		"anti_roll": 0.65,
		"steer_max_deg": 31.0,
		"steer_speed": 1.05,
		"brake_g": 1.40,
		"nitro_accel": 6.5,
		"nitro_time": 5.0,   # one fixed tank per run (owner: NOS is strategy, no refill)
		"drift_assist": 0.8,
		"yaw_damp": 1.3,
		"power_oversteer": 0.0,
		"cg_height": 0.06,
	},
}


static func base(car_id: String) -> Dictionary:
	return BASE.get(car_id, BASE["kaze"]).duplicate(true)


## Torque-curve shape: 1.0 at the peak, `low` at idle, falling to TOP_FALL at the limiter.
## `turbo` (-1..1) moves torque from the low end to the top end.
static func torque_shape(u: float, low: float, peak_u: float, turbo: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var t: float
	if u < peak_u:
		var f := u / peak_u
		t = lerpf(low, 1.0, f * (2.0 - f))
	else:
		var f := (u - peak_u) / maxf(1.0 - peak_u, 0.01)
		t = lerpf(1.0, TOP_FALL, f * f)
	# turbo: + = top-end power (above TURBO_PIVOT), - = fatter mid-range
	t *= 1.0 + turbo * TURBO_AMOUNT * (u - TURBO_PIVOT)
	return maxf(t, 0.05)


## max over u of u * shape(u) for the stock curve (normalizes power so `power` is the true peak).
static func shape_norm(low: float, peak_u: float) -> float:
	var best := 0.0
	for i in 101:
		var u := i / 100.0
		best = maxf(best, u * torque_shape(u, low, peak_u, 0.0))
	return best
