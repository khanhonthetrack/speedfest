class_name Tuning
extends RefCounted
## STUB: the car-physics module implements this. API fixed by docs/ARCHITECTURE.md "Tuning".


## Resolved physics parameters for Car, given a car id and tuning sliders (-1..1).
static func physics_params(car_id: String, _tuning: Dictionary) -> Dictionary:
	return {"car": car_id}


## Normalized stats for the garage UI.
static func stats(_car_id: String, _tuning: Dictionary) -> Dictionary:
	return {"top_speed": 0.5, "accel": 0.5, "handling": 0.5, "drift": 0.5, "nitro": 0.5,
		"top_speed_kmh": 280.0, "zero_to_100_s": 3.5}
