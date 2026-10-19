class_name CarDefs
extends RefCounted
## The five cars of the garage: identity, geometry, stock performance and the look they roll out of
## the showroom with. Everything the physics (cars/tm_car.gd) and the model builder
## (cars/visual/car_model.gd) need comes from here, so a new car is one entry in DEFS.
##
## Performance is expressed in the terms of the TMNF force model (core/tm_car_model.gd):
##   top_kmh      hard top speed (the over-speed push starts here)
##   accel        engine acceleration multiplier on the TMNF staircase
##   launch       extra on the first step of the staircase (0-101 km/h): low-end torque
##   grip         side friction cap multiplier (tyres + downforce)
##   brake        brake force and cap multiplier
##   steer        steering yaw torque multiplier
##   slide_grip   grip of a wheel that has broken away (lower = looser, more drift)
##   mass_kg      shown in the garage and used for the weight-reduction maths (physics is mass 1)
##   boost_power  extra forward acceleration (m/s^2) while the nitrous is held
##   boost_tank   seconds of nitrous at full
##   boost_gain   tank refilled per second of driving (the owner's "boost gain")
##   boost_kmh    how much the top speed cap lifts while boosting
## `surface_bonus` overrides TmTuning.SURFACES entries for this car (the offroad truck keeps its
## grip on dirt and grass, slicks lose it).

const IDS: Array[String] = ["f4", "kaze", "vector", "polonez", "ridge"]

const DEFS := {
	"f4": {
		"name": "Vireo F4",
		"archetype": "FIA F4 Single-seater",
		"blurb": "Spec-series open-wheeler. No weight, no mercy, corner speed nothing else touches.",
		"drive": "rwd",
		"body": "formula",
		"price": 48000,
		"geometry": {
			"length": 4.42, "width": 1.74, "height": 0.98,
			"wheelbase": 2.47, "track_front": 1.45, "track_rear": 1.40,
			"wheel_radius": 0.283, "wheel_width": 0.200, "rear_wheel_extra": 0.045,
			"ground_clearance": 0.055,
		},
		"specs": {
			"top_kmh": 302.0, "accel": 1.14, "launch": 1.06, "grip": 1.34, "brake": 1.40,
			"steer": 1.18, "slide_grip": 0.30, "mass_kg": 570.0,
			"boost_power": 9.0, "boost_tank": 3.2, "boost_gain": 0.20, "boost_kmh": 22.0,
		},
		"surface_bonus": {2: [0.42, 0.10, 0.35, 0.03], 6: [0.80, 0.18, 0.80, 0.30]},
		"style": {
			"paint": "#12d6ff", "finish": "gloss", "accent": "#0a0e18", "vinyl": "race",
			"rims": 4, "rim_color": "#e8e8ea", "caliper": "#ff2a2a",
			"neon": "#12d6ff", "neon_mode": "static", "tint": 0.0,
			"headlight": "#eaf4ff", "plate": "VIREO 04",
		},
	},
	"kaze": {
		"name": "Kaze RS",
		"archetype": "JDM Sport Coupe",
		"blurb": "Turbo straight-six, rear drive, and a tail that answers the throttle. The tuner's car.",
		"drive": "rwd",
		"body": "coupe",
		"price": 32000,
		"geometry": {
			"length": 4.52, "width": 1.80, "height": 1.29,
			"wheelbase": 2.62, "track_front": 1.52, "track_rear": 1.54,
			"wheel_radius": 0.330, "wheel_width": 0.235, "rear_wheel_extra": 0.025,
			"ground_clearance": 0.125,
		},
		"specs": {
			"top_kmh": 291.0, "accel": 1.00, "launch": 1.02, "grip": 1.00, "brake": 1.00,
			"steer": 1.00, "slide_grip": 0.38, "mass_kg": 1290.0,
			"boost_power": 11.0, "boost_tank": 5.0, "boost_gain": 0.34, "boost_kmh": 28.0,
		},
		"surface_bonus": {},
		"style": {
			"paint": "#ff5a00", "finish": "metallic", "accent": "#111214", "vinyl": "side_stripe",
			"rims": 0, "rim_color": "#d8d8dc", "caliper": "#ff1a1a",
			"neon": "#00e5ff", "neon_mode": "static", "tint": 0.6,
			"headlight": "#dbeaff", "plate": "KAZE RS",
		},
	},
	"vector": {
		"name": "Vector GT8",
		"archetype": "Grand Tourer V8",
		"blurb": "Long-geared, wide and heavy. Nothing on the island beats it down a straight.",
		"drive": "awd",
		"body": "gt",
		"price": 76000,
		"geometry": {
			"length": 4.74, "width": 1.98, "height": 1.21,
			"wheelbase": 2.74, "track_front": 1.68, "track_rear": 1.70,
			"wheel_radius": 0.348, "wheel_width": 0.275, "rear_wheel_extra": 0.040,
			"ground_clearance": 0.110,
		},
		"specs": {
			"top_kmh": 334.0, "accel": 1.09, "launch": 0.92, "grip": 0.94, "brake": 1.05,
			"steer": 0.94, "slide_grip": 0.44, "mass_kg": 1620.0,
			"boost_power": 13.0, "boost_tank": 4.4, "boost_gain": 0.26, "boost_kmh": 34.0,
		},
		"surface_bonus": {},
		"style": {
			"paint": "#b2000e", "finish": "pearl", "accent": "#0b0b0c", "vinyl": "none",
			"rims": 3, "rim_color": "#1d1d20", "caliper": "#ffcc00",
			"neon": "#ff2bd6", "neon_mode": "pulse", "tint": 0.5,
			"headlight": "#e8f0ff", "plate": "GT8",
		},
	},
	"polonez": {
		"name": "Lodowiec 1600",
		"archetype": "Eastern Bloc Classic",
		"blurb": "A square hatchback from 1983 with a borrowed turbo. Soft, loud, and sideways by default.",
		"drive": "rwd",
		"body": "classic",
		"price": 14000,
		"geometry": {
			"length": 4.27, "width": 1.68, "height": 1.40,
			"wheelbase": 2.51, "track_front": 1.40, "track_rear": 1.39,
			"wheel_radius": 0.318, "wheel_width": 0.195, "rear_wheel_extra": 0.015,
			"ground_clearance": 0.155,
		},
		"specs": {
			"top_kmh": 248.0, "accel": 0.88, "launch": 0.96, "grip": 0.86, "brake": 0.82,
			"steer": 0.92, "slide_grip": 0.52, "mass_kg": 1180.0,
			"boost_power": 10.0, "boost_tank": 6.2, "boost_gain": 0.44, "boost_kmh": 26.0,
		},
		"surface_bonus": {2: [0.62, 0.22, 0.48, 0.10], 6: [0.92, 0.30, 0.92, 0.50]},
		"style": {
			"paint": "#e8e2d2", "finish": "gloss", "accent": "#2a2f3a", "vinyl": "two_tone",
			"rims": 2, "rim_color": "#c9ccd1", "caliper": "#8a8f98",
			"neon": "#a6ff00", "neon_mode": "static", "tint": 0.35,
			"headlight": "#fff0c8", "plate": "PL 1600",
		},
	},
	"ridge": {
		"name": "Ridge RX",
		"archetype": "Offroad Pre-runner",
		"blurb": "Long-travel truck on knobbly tyres. Kerbs, dirt and gaps are shortcuts, not hazards.",
		"drive": "awd",
		"body": "offroad",
		"price": 41000,
		"geometry": {
			"length": 4.98, "width": 2.04, "height": 1.88,
			"wheelbase": 2.98, "track_front": 1.76, "track_rear": 1.76,
			"wheel_radius": 0.405, "wheel_width": 0.315, "rear_wheel_extra": 0.0,
			"ground_clearance": 0.300,
		},
		"specs": {
			"top_kmh": 236.0, "accel": 0.96, "launch": 1.22, "grip": 0.96, "brake": 0.92,
			"steer": 0.88, "slide_grip": 0.46, "mass_kg": 2050.0,
			"boost_power": 12.0, "boost_tank": 5.6, "boost_gain": 0.30, "boost_kmh": 24.0,
		},
		# knobbly tyres: grass, dirt, sand and snow barely slow this one down
		"surface_bonus": {
			2: [0.85, 0.70, 0.85, 0.62], 5: [0.70, 0.85, 0.80, 1.00], 6: [1.00, 0.85, 1.00, 0.90],
			8: [0.95, 0.90, 1.00, 1.00], 20: [0.70, 0.80, 0.80, 1.00], 21: [0.55, 0.45, 0.75, 0.45],
		},
		"style": {
			"paint": "#f2b000", "finish": "matte", "accent": "#16181c", "vinyl": "circuit",
			"rims": 1, "rim_color": "#2a2d33", "caliper": "#f2b000",
			"neon": "#ff7a00", "neon_mode": "static", "tint": 0.7,
			"headlight": "#fff4de", "plate": "RIDGE",
		},
	},
}


static func has(id: String) -> bool:
	return DEFS.has(id)


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["kaze"])


static func name_of(id: String) -> String:
	return String(get_def(id)["name"])


static func geometry(id: String) -> Dictionary:
	return get_def(id)["geometry"]


static func specs(id: String) -> Dictionary:
	return get_def(id)["specs"]


static func default_style(id: String) -> Dictionary:
	return (get_def(id)["style"] as Dictionary).duplicate(true)


## Wheel centres in the car frame (+X left, +Y up, +Z forward) measured from the centre of mass,
## in the layout TmBody.setup() wants: FL, FR, RL, RR.
static func wheel_positions(id: String, ride_drop: float = 0.0) -> Array:
	var g := geometry(id)
	var wb: float = g["wheelbase"]
	var tf: float = float(g["track_front"]) * 0.5
	var tr: float = float(g["track_rear"]) * 0.5
	# the centre of mass sits at the wheel-centre height plus a little, like the Stadium car
	var y := -0.086 + ride_drop
	return [Vector3(tf, y, wb * 0.5), Vector3(-tf, y, wb * 0.5),
		Vector3(tr, y, -wb * 0.5), Vector3(-tr, y, -wb * 0.5)]


## Chassis collision ellipsoids for this car, in TmTuning.BODY_ELLIPSOIDS layout
## ([centre, half-axes, pitch]). Scaled from the car's own box so a truck does not collide like an
## F4, while the force model keeps the Stadium geometry.
static func body_ellipsoids(id: String) -> Array:
	var g := geometry(id)
	var hl: float = float(g["length"]) * 0.5
	var hw: float = float(g["width"]) * 0.5
	var h: float = float(g["height"])
	var r: float = float(g["wheel_radius"])
	var body := String(get_def(id)["body"])
	# y is relative to the wheel centres (the car origin): the hull spans clearance..height
	var low: float = float(g["ground_clearance"]) - r
	var top: float = h - r
	var mid := (low + top) * 0.5
	var half_h := (top - low) * 0.5
	match body:
		"formula":
			# nose cone, survival cell, engine cover, rear wing pylon
			return [
				[Vector3(0.0, mid * 0.6, hl * 0.62), Vector3(hw * 0.30, half_h * 0.55, hl * 0.36), 0.03],
				[Vector3(0.0, mid, hl * 0.02), Vector3(hw * 0.52, half_h * 0.95, hl * 0.52), 0.0],
				[Vector3(0.0, mid * 1.1, -hl * 0.52), Vector3(hw * 0.46, half_h * 1.0, hl * 0.40), 0.0],
				[Vector3(0.0, top * 0.92, -hl * 0.88), Vector3(hw * 0.62, half_h * 0.35, hl * 0.14), 0.0],
			]
		"offroad":
			return [
				[Vector3(0.0, mid * 0.75, hl * 0.52), Vector3(hw * 0.90, half_h * 0.70, hl * 0.46), 0.0],
				[Vector3(0.0, mid, 0.0), Vector3(hw * 0.95, half_h * 0.95, hl * 0.74), 0.0],
				[Vector3(0.0, top * 0.80, -hl * 0.10), Vector3(hw * 0.82, half_h * 0.80, hl * 0.42), 0.0],
				[Vector3(0.0, mid * 0.85, -hl * 0.78), Vector3(hw * 0.88, half_h * 0.62, hl * 0.26), 0.0],
			]
		_:
			# a long low hull, a cabin, and a nose/tail cap
			return [
				[Vector3(0.0, mid * 0.85, hl * 0.60), Vector3(hw * 0.78, half_h * 0.70, hl * 0.42), 0.04],
				[Vector3(0.0, mid, -hl * 0.05), Vector3(hw * 0.98, half_h * 0.92, hl * 0.66), 0.02],
				[Vector3(0.0, top * 0.78, -hl * 0.18), Vector3(hw * 0.74, half_h * 1.0, hl * 0.40), 0.0],
				[Vector3(0.0, mid * 0.85, -hl * 0.80), Vector3(hw * 0.86, half_h * 0.60, hl * 0.24), 0.0],
			]


# --- the bridge to the model builder --------------------------------------------------------
## The visual pipeline (cars/visual/) works in MODEL space: the car faces -Z, its left is -X and
## y = 0 is the road, which is Godot's own convention for an imported model. The physics works in
## the TMNF frame (+Z forward, +X left). CarVisual is therefore parented under a node rotated by
## PI around Y; these helpers speak model space.

## Wheel centres in model space, order FL, FR, RL, RR (front = -Z).
static func visual_wheel_positions(id: String) -> Array[Vector3]:
	var g := geometry(id)
	var hw: float = float(g["wheelbase"]) * 0.5
	var tf: float = float(g["track_front"]) * 0.5
	var tr: float = float(g["track_rear"]) * 0.5
	return [Vector3(-tf, 0.0, -hw), Vector3(tf, 0.0, -hw), Vector3(-tr, 0.0, hw), Vector3(tr, 0.0, hw)]


const STYLE_KEYS: Array[String] = ["paint", "finish", "accent", "livery", "hood", "hood_carbon",
	"front", "rear", "skirts", "spoiler", "rims", "rim_color", "caliper", "underglow",
	"underglow_mode", "underglow_full", "tint", "headlight", "headlight_kind", "ride_height", "plate"]

const FINISHES: Array[String] = ["gloss", "metallic", "pearl", "matte", "chrome"]
const UNDERGLOW_MODES: Array[String] = ["off", "static", "pulse", "strobe", "rainbow"]


## Translate a garage setup (cars/tuning.gd) into the style Dictionary the model builder reads.
static func style_from_setup(id: String, setup: Dictionary) -> Dictionary:
	var kit := clampi(int(setup.get("bodykit", 0)), 0, 3)
	var neon_level := clampi(int(setup.get("neon", 0)), 0, 5)
	var susp := clampi(int(setup.get("suspension", 0)), 0, 3)
	var hood := 0
	match kit:
		1: hood = 1
		2: hood = 2
		3: hood = 3
	# an offroad truck keeps its stock hood: scoops belong on the tarmac cars
	if String(get_def(id)["body"]) == "offroad":
		hood = mini(hood, 1)
	return {
		"paint": String(setup.get("paint_color", "#ff5a00")),
		"finish": Tuning.finish_of(setup),
		"accent": String(setup.get("accent_color", "#121418")),
		"livery": Tuning.vinyl_of(setup),
		"hood": hood,
		"hood_carbon": int(setup.get("weight", 0)) >= 2,
		"front": mini(kit, 2),
		"rear": mini(kit, 2),
		"skirts": mini(kit, 2),
		"spoiler": clampi(int(setup.get("spoiler", 0)), 0, 4),
		"rims": clampi(int(setup.get("rims", 0)), 0, 5),
		"rim_color": String(setup.get("rim_color", "#d8d8dc")),
		"caliper": String(setup.get("caliper_color", "#ff1a1a")),
		"underglow": String(setup.get("neon_color", "#00e5ff")),
		"underglow_mode": UNDERGLOW_MODES[mini(neon_level, 4)],
		"underglow_full": neon_level >= 5,
		"tint": clampf(float(int(setup.get("tint", 2))) / 4.0, 0.0, 1.0),
		"headlight": String(setup.get("headlight_color", "#eaf4ff")),
		"headlight_kind": clampi(int(setup.get("headlights", 0)), 0, 3),
		# -1 .. +1; lowering springs and coilovers drop the body, nothing raises it
		"ride_height": -clampf(float(susp) / 3.0, 0.0, 1.0),
		"plate": sanitize_plate(String(setup.get("plate", "SPEEDFST"))),
	}


## Fill in and clamp a style Dictionary that came from disk, a test or another module.
static func sanitize_style(id: String, src: Variant) -> Dictionary:
	var out := style_from_setup(id, Tuning.default_setup(id))
	if typeof(src) != TYPE_DICTIONARY:
		return out
	var s: Dictionary = src
	for key in ["paint", "accent", "rim_color", "caliper", "underglow", "headlight"]:
		if s.has(key) and typeof(s[key]) == TYPE_STRING and Color.html_is_valid(String(s[key])):
			out[key] = String(s[key])
	if String(s.get("finish", "")) in FINISHES:
		out["finish"] = s["finish"]
	if String(s.get("livery", "")) in Tuning.VINYL_NAMES:
		out["livery"] = s["livery"]
	if String(s.get("underglow_mode", "")) in UNDERGLOW_MODES:
		out["underglow_mode"] = s["underglow_mode"]
	for slot in {"hood": 4, "front": 3, "rear": 3, "skirts": 3, "spoiler": 5, "rims": 6, "headlight_kind": 4}:
		if s.has(slot) and (typeof(s[slot]) == TYPE_INT or typeof(s[slot]) == TYPE_FLOAT):
			out[slot] = clampi(int(s[slot]), 0, int({"hood": 4, "front": 3, "rear": 3, "skirts": 3,
				"spoiler": 5, "rims": 6, "headlight_kind": 4}[slot]) - 1)
	for b in ["hood_carbon", "underglow_full"]:
		if s.has(b):
			out[b] = bool(s[b])
	for f in {"tint": [0.0, 1.0], "ride_height": [-1.0, 1.0]}:
		if s.has(f) and (typeof(s[f]) == TYPE_FLOAT or typeof(s[f]) == TYPE_INT):
			var r: Array = {"tint": [0.0, 1.0], "ride_height": [-1.0, 1.0]}[f]
			out[f] = clampf(float(s[f]), float(r[0]), float(r[1]))
	if s.has("plate") and typeof(s["plate"]) == TYPE_STRING:
		out["plate"] = sanitize_plate(String(s["plate"]))
	return out


static func sanitize_plate(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch == "-":
			out += ch
		if out.length() >= 8:
			break
	return out
