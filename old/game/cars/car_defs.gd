class_name CarDefs
extends RefCounted
## Static definitions of the cars: identity, shared geometry, part counts, default style.
## kaze/brute/veloce (M1) + kitsune/pixie/goliath (session 6: "different types of cars").
## Geometry is shared by physics (cars/car.gd) and visuals (cars/visual/). Changing it requires
## updating both. See docs/ARCHITECTURE.md "Coordinate conventions".

const IDS: Array[String] = ["kaze", "brute", "veloce", "kitsune", "pixie", "goliath"]

const TUNING_KEYS: Array[String] = ["gearing", "turbo", "downforce", "suspension", "balance", "steering", "nitro"]

const TUNING_LABELS := {
	"gearing": ["Gearing", "Acceleration", "Top speed"],
	"turbo": ["Turbo", "Low-end torque", "Top-end power"],
	"downforce": ["Downforce", "Low drag", "High grip"],
	"suspension": ["Suspension", "Soft", "Stiff"],
	"balance": ["Balance", "Planted", "Loose / drift"],
	"steering": ["Steering", "Stable", "Sharp"],
	"nitro": ["Nitrous", "Long & gentle", "Short & strong"],
}

const FINISHES: Array[String] = ["gloss", "metallic", "pearl", "matte", "chrome"]
const LIVERIES: Array[String] = ["none", "racing_stripes", "side_stripe", "two_tone", "fade", "checker",
	"flames", "bolt", "retro", "camo", "tiger", "hex", "gradient", "race", "drip", "circuit"]
const UNDERGLOW_MODES: Array[String] = ["off", "static", "pulse", "strobe", "rainbow"]

## Number of variants per part slot (index 0 = stock / none).
const PART_COUNTS := {"hood": 4, "front": 3, "rear": 3, "skirts": 3, "spoiler": 5, "rims": 5}

const PART_NAMES := {
	"hood": ["Stock", "Vented", "Scoop", "Twin scoop"],
	"front": ["Stock", "Street", "Race"],
	"rear": ["Stock", "Street", "Race"],
	"skirts": ["Stock", "Street", "Race"],
	"spoiler": ["None", "Lip", "Ducktail", "GT wing", "High wing"],
	"rims": ["Spoke-5", "Mesh", "Deep dish", "Turbine", "Split-6"],
}

const DEFS := {
	"kaze": {
		"name": "Kaze RS",
		"archetype": "JDM Tuner Coupe",
		"blurb": "Light, rev-happy and rear-driven. Born to slide.",
		"drive": "rwd",
		"geometry": {
			"length": 4.40, "width": 1.76, "height": 1.26,
			"wheelbase": 2.56, "track_front": 1.50, "track_rear": 1.50,
			"wheel_radius": 0.32, "wheel_width": 0.235,
			"ground_clearance": 0.13,
		},
		"default_style": {
			"paint": "#ff6a00", "finish": "metallic", "accent": "#141414", "livery": "racing_stripes",
			"hood": 1, "hood_carbon": true, "front": 1, "rear": 1, "skirts": 1, "spoiler": 3,
			"rims": 0, "rim_color": "#d8d8d8", "caliper": "#ff1a1a",
			"underglow": "#00e5ff", "underglow_mode": "static", "tint": 0.6,
			"headlight": "#e6f2ff", "ride_height": -0.4, "plate": "KAZE RS",
		},
	},
	"brute": {
		"name": "Brute V8",
		"archetype": "American Muscle",
		"blurb": "Big-block torque, long hood, loose tail. Nitro monster.",
		"drive": "rwd",
		"geometry": {
			"length": 4.80, "width": 1.92, "height": 1.34,
			"wheelbase": 2.76, "track_front": 1.58, "track_rear": 1.60,
			"wheel_radius": 0.345, "wheel_width": 0.27,
			"ground_clearance": 0.14,
		},
		"default_style": {
			"paint": "#101218", "finish": "gloss", "accent": "#ffb300", "livery": "racing_stripes",
			"hood": 2, "hood_carbon": false, "front": 0, "rear": 1, "skirts": 0, "spoiler": 2,
			"rims": 2, "rim_color": "#1a1a1a", "caliper": "#ffb300",
			"underglow": "#ff2bd6", "underglow_mode": "pulse", "tint": 0.75,
			"headlight": "#fff3d6", "ride_height": -0.2, "plate": "BRUTE",
		},
	},
	"veloce": {
		"name": "Veloce GT",
		"archetype": "Euro Supercar",
		"blurb": "Mid-engine, all-wheel grip, the highest top speed.",
		"drive": "awd",
		"geometry": {
			"length": 4.52, "width": 1.98, "height": 1.14,
			"wheelbase": 2.66, "track_front": 1.66, "track_rear": 1.64,
			"wheel_radius": 0.34, "wheel_width": 0.28,
			"ground_clearance": 0.11,
		},
		"default_style": {
			"paint": "#d0101c", "finish": "pearl", "accent": "#0b0b0b", "livery": "none",
			"hood": 0, "hood_carbon": false, "front": 2, "rear": 2, "skirts": 2, "spoiler": 1,
			"rims": 3, "rim_color": "#2b2b2b", "caliper": "#ffd400",
			"underglow": "#a6ff00", "underglow_mode": "off", "tint": 0.5,
			"headlight": "#dfe9ff", "ride_height": -0.1, "plate": "VELOCE",
		},
	},
	"kitsune": {
		"name": "Kitsune R4",
		"archetype": "Rally Hatch",
		"blurb": "Turbo AWD hatch on long-travel springs. Grass, gravel and sand barely slow it.",
		"drive": "awd",
		"geometry": {
			"length": 4.10, "width": 1.80, "height": 1.44,
			"wheelbase": 2.50, "track_front": 1.54, "track_rear": 1.54,
			"wheel_radius": 0.33, "wheel_width": 0.225,
			"ground_clearance": 0.19,
		},
		"default_style": {
			"paint": "#f2f4f7", "finish": "gloss", "accent": "#1446d8", "livery": "side_stripe",
			"hood": 2, "hood_carbon": false, "front": 1, "rear": 1, "skirts": 0, "spoiler": 3,
			"rims": 1, "rim_color": "#d9a400", "caliper": "#1446d8",
			"underglow": "#00e5ff", "underglow_mode": "off", "tint": 0.55,
			"headlight": "#fff6d8", "ride_height": 0.6, "plate": "KITSUNE",
		},
	},
	"pixie": {
		"name": "Pixie S",
		"archetype": "Kei Roadster",
		"blurb": "Tiny, featherweight and glued to the road. The lowest top speed, the sharpest turn-in.",
		"drive": "rwd",
		"geometry": {
			"length": 3.60, "width": 1.62, "height": 1.14,
			"wheelbase": 2.28, "track_front": 1.40, "track_rear": 1.40,
			"wheel_radius": 0.29, "wheel_width": 0.205,
			"ground_clearance": 0.11,
		},
		"default_style": {
			"paint": "#36d6a0", "finish": "pearl", "accent": "#f4f1e6", "livery": "two_tone",
			"hood": 0, "hood_carbon": false, "front": 0, "rear": 0, "skirts": 1, "spoiler": 1,
			"rims": 4, "rim_color": "#f0f0f0", "caliper": "#d01010",
			"underglow": "#ff2bd6", "underglow_mode": "static", "tint": 0.4,
			"headlight": "#e6f2ff", "ride_height": -0.3, "plate": "PIXIE",
		},
	},
	"goliath": {
		"name": "Goliath HD",
		"archetype": "Pickup Truck",
		"blurb": "Two tons of 4x4 torque with the biggest nitro tank. Lands anything, turns in late.",
		"drive": "awd",
		"geometry": {
			"length": 5.30, "width": 2.04, "height": 1.80,
			"wheelbase": 3.30, "track_front": 1.72, "track_rear": 1.72,
			"wheel_radius": 0.42, "wheel_width": 0.31,
			"ground_clearance": 0.27,
		},
		"default_style": {
			"paint": "#7a1418", "finish": "metallic", "accent": "#1a1a1a", "livery": "fade",
			"hood": 2, "hood_carbon": false, "front": 1, "rear": 0, "skirts": 0, "spoiler": 0,
			"rims": 2, "rim_color": "#2a2a2a", "caliper": "#ffb300",
			"underglow": "#ffb300", "underglow_mode": "off", "tint": 0.7,
			"headlight": "#fff3d6", "ride_height": 0.5, "plate": "GOLIATH",
		},
	},
}


static func get_def(car_id: String) -> Dictionary:
	return DEFS.get(car_id, DEFS["kaze"])


static func geometry(car_id: String) -> Dictionary:
	return get_def(car_id)["geometry"]


static func display_name(car_id: String) -> String:
	return get_def(car_id)["name"]


## Wheel center positions at rest in car-local space, order FL, FR, RL, RR.
static func wheel_positions(car_id: String) -> Array[Vector3]:
	var g := geometry(car_id)
	var hw: float = g["wheelbase"] * 0.5
	return [
		Vector3(-g["track_front"] * 0.5, 0.0, -hw),
		Vector3(g["track_front"] * 0.5, 0.0, -hw),
		Vector3(-g["track_rear"] * 0.5, 0.0, hw),
		Vector3(g["track_rear"] * 0.5, 0.0, hw),
	]


static func default_tuning() -> Dictionary:
	var t := {}
	for k in TUNING_KEYS:
		t[k] = 0.0
	return t


static func default_style(car_id: String) -> Dictionary:
	return get_def(car_id)["default_style"].duplicate(true)


static func default_config(car_id: String) -> Dictionary:
	return {"car": car_id, "tuning": default_tuning(), "style": default_style(car_id)}


## Returns a valid CarConfig: unknown car -> kaze, missing/invalid fields -> defaults, values clamped.
## Always call on configs that came from disk or the network.
static func sanitize_config(cfg: Variant) -> Dictionary:
	var src: Dictionary = cfg if typeof(cfg) == TYPE_DICTIONARY else {}
	var car_id := String(src.get("car", "kaze"))
	if not car_id in IDS:
		car_id = "kaze"
	var out := default_config(car_id)
	var tun: Variant = src.get("tuning", {})
	if typeof(tun) == TYPE_DICTIONARY:
		for k in TUNING_KEYS:
			if tun.has(k) and (typeof(tun[k]) == TYPE_FLOAT or typeof(tun[k]) == TYPE_INT):
				out["tuning"][k] = clampf(float(tun[k]), -1.0, 1.0)
	var sty: Variant = src.get("style", {})
	if typeof(sty) == TYPE_DICTIONARY:
		var o: Dictionary = out["style"]
		for key in ["paint", "accent", "rim_color", "caliper", "underglow", "headlight"]:
			if sty.has(key) and typeof(sty[key]) == TYPE_STRING and Color.html_is_valid(sty[key]):
				o[key] = String(sty[key])
		if sty.get("finish", "") in FINISHES:
			o["finish"] = sty["finish"]
		if sty.get("livery", "") in LIVERIES:
			o["livery"] = sty["livery"]
		if sty.get("underglow_mode", "") in UNDERGLOW_MODES:
			o["underglow_mode"] = sty["underglow_mode"]
		for slot in PART_COUNTS:
			if sty.has(slot) and (typeof(sty[slot]) == TYPE_INT or typeof(sty[slot]) == TYPE_FLOAT):
				o[slot] = clampi(int(sty[slot]), 0, PART_COUNTS[slot] - 1)
		if sty.has("hood_carbon"):
			o["hood_carbon"] = bool(sty["hood_carbon"])
		if sty.has("tint") and (typeof(sty["tint"]) == TYPE_FLOAT or typeof(sty["tint"]) == TYPE_INT):
			o["tint"] = clampf(float(sty["tint"]), 0.0, 1.0)
		if sty.has("ride_height") and (typeof(sty["ride_height"]) == TYPE_FLOAT or typeof(sty["ride_height"]) == TYPE_INT):
			o["ride_height"] = clampf(float(sty["ride_height"]), -1.0, 1.0)
		if sty.has("plate") and typeof(sty["plate"]) == TYPE_STRING:
			o["plate"] = sanitize_plate(sty["plate"])
	return out


static func sanitize_plate(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch == "-":
			out += ch
		if out.length() >= 8:
			break
	return out
