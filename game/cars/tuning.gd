class_name Tuning
extends RefCounted
## The garage catalogue: sixteen modification slots per car, Underground 2 style — eight that change
## how the car drives and eight that change how it looks. A car's "setup" is a plain Dictionary
## (slot -> level index, or a colour string), saved by the Garage autoload and read by both the
## physics (cars/tm_car.gd) and the model builder (cars/visual/car_model.gd).
##
## Effects are deltas on CarDefs.specs(): multipliers (`mul`) and additions (`add`). Nothing here
## knows about Godot nodes, so the garage screen can price, preview and compare setups cheaply.

enum Kind { PERFORMANCE, LOOK }

const PERF_SLOTS: Array[String] = ["engine", "turbo", "nitrous", "tyres", "brakes", "suspension",
	"gearbox", "weight"]
const LOOK_SLOTS: Array[String] = ["bodykit", "spoiler", "rims", "paint", "vinyl", "neon",
	"headlights", "tint"]
const SLOTS: Array[String] = ["engine", "turbo", "nitrous", "tyres", "brakes", "suspension",
	"gearbox", "weight", "bodykit", "spoiler", "rims", "paint", "vinyl", "neon", "headlights", "tint"]

## Slots whose value is a colour (everything else is a level index into CATALOGUE[slot].levels).
const COLOUR_SLOTS: Array[String] = ["paint", "neon", "headlights"]

const PAINT_COLOURS: Array[String] = [
	"#ff5a00", "#ff1744", "#b2000e", "#ff2bd6", "#8a2be2", "#3d5afe", "#12d6ff", "#00e5a0",
	"#a6ff00", "#f2b000", "#e8e2d2", "#f5f7fa", "#9aa3ad", "#3a4049", "#12151a", "#5b3a1e",
]
const NEON_COLOURS: Array[String] = [
	"#00e5ff", "#12d6ff", "#2b6bff", "#8a2be2", "#ff2bd6", "#ff1744", "#ff7a00", "#f2d000",
	"#a6ff00", "#00ffa6", "#ffffff",
]
const HEADLIGHT_COLOURS: Array[String] = ["#fff0c8", "#fffaf0", "#eaf4ff", "#dbeaff", "#bcd2ff", "#d8c8ff"]
const HEADLIGHT_NAMES: Array[String] = ["Halogen", "Warm white", "Xenon", "Cool xenon", "Ice blue", "Violet HID"]
const RIM_COLOURS: Array[String] = ["#e8e8ea", "#d8d8dc", "#c9ccd1", "#9aa3ad", "#2a2d33", "#1d1d20",
	"#f2b000", "#12d6ff", "#ff2bd6", "#b87333"]

## Catalogue. Each level: name, price, and its effect.
##   mul: {spec_key: factor}   add: {spec_key: delta}
## Spec keys are CarDefs.specs() keys (top_kmh, accel, launch, grip, brake, steer, slide_grip,
## mass_kg, boost_power, boost_tank, boost_gain, boost_kmh) plus the visual-only `ride` (metres the
## body drops) and `width` (metres each side gains).
const CATALOGUE := {
	"engine": {
		"label": "Engine", "kind": Kind.PERFORMANCE,
		"hint": "Internals: cams, head work, forged bottom end. Power everywhere.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Street port", "price": 2400, "mul": {"accel": 1.07}, "add": {"top_kmh": 4.0}},
			{"name": "Sport cams", "price": 6800, "mul": {"accel": 1.16}, "add": {"top_kmh": 9.0}},
			{"name": "Race build", "price": 15600, "mul": {"accel": 1.28}, "add": {"top_kmh": 14.0}},
		],
	},
	"turbo": {
		"label": "Turbo", "kind": Kind.PERFORMANCE,
		"hint": "Bigger snail, bigger top end — and more lag off the line.",
		"levels": [
			{"name": "None", "price": 0, "mul": {}, "add": {}},
			{"name": "Street T25", "price": 3200, "mul": {"accel": 1.05, "launch": 0.98}, "add": {"top_kmh": 6.0}},
			{"name": "Big single", "price": 8900, "mul": {"accel": 1.12, "launch": 0.92}, "add": {"top_kmh": 13.0}},
			{"name": "Twin-scroll", "price": 18400, "mul": {"accel": 1.21, "launch": 0.87}, "add": {"top_kmh": 21.0}},
		],
	},
	"nitrous": {
		"label": "Nitrous", "kind": Kind.PERFORMANCE,
		"hint": "Bottle size and shot strength. The boost meter refills as you drive.",
		"levels": [
			{"name": "None", "price": 0, "mul": {"boost_power": 0.0, "boost_tank": 0.0}, "add": {}},
			{"name": "Single shot", "price": 2600, "mul": {"boost_tank": 1.0}, "add": {"boost_power": 1.5, "boost_kmh": 5.0}},
			{"name": "Twin bottle", "price": 7400, "mul": {"boost_tank": 1.35, "boost_gain": 1.12}, "add": {"boost_power": 3.5, "boost_kmh": 11.0}},
			{"name": "NOS Pro", "price": 16200, "mul": {"boost_tank": 1.75, "boost_gain": 1.25}, "add": {"boost_power": 6.0, "boost_kmh": 18.0}},
		],
	},
	"tyres": {
		"label": "Tyres", "kind": Kind.PERFORMANCE,
		"hint": "Compound and width. Slicks bite tarmac and hate anything else.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Sport", "price": 1800, "mul": {"grip": 1.08}, "add": {"slide_grip": 0.02}},
			{"name": "Semi-slick", "price": 5200, "mul": {"grip": 1.17}, "add": {"slide_grip": 0.045}},
			{"name": "Slick", "price": 11800, "mul": {"grip": 1.27}, "add": {"slide_grip": 0.07}},
		],
	},
	"brakes": {
		"label": "Brakes", "kind": Kind.PERFORMANCE,
		"hint": "Discs and calipers. Later braking, shorter stops.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Sport pads", "price": 1400, "mul": {"brake": 1.12}, "add": {}},
			{"name": "Big brake kit", "price": 4600, "mul": {"brake": 1.26}, "add": {}},
			{"name": "Carbon-ceramic", "price": 12400, "mul": {"brake": 1.42}, "add": {}},
		],
	},
	"suspension": {
		"label": "Suspension", "kind": Kind.PERFORMANCE,
		"hint": "Springs, dampers and ride height. Lower is sharper and scrapes more.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Lowering springs", "price": 1600, "mul": {"grip": 1.04, "steer": 1.05}, "add": {"ride": -0.022}},
			{"name": "Coilovers", "price": 5400, "mul": {"grip": 1.09, "steer": 1.11}, "add": {"ride": -0.040}},
			{"name": "Race damper kit", "price": 13200, "mul": {"grip": 1.15, "steer": 1.17}, "add": {"ride": -0.055}},
		],
	},
	"gearbox": {
		"label": "Gearbox", "kind": Kind.PERFORMANCE, "choice": true,
		"hint": "Final drive. Trade top speed for punch, or the other way round.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Close ratio", "price": 3400, "mul": {"accel": 1.07, "launch": 1.05}, "add": {"top_kmh": -9.0}},
			{"name": "Drag set", "price": 8200, "mul": {"accel": 1.15, "launch": 1.12}, "add": {"top_kmh": -19.0}},
			{"name": "Long highway", "price": 8200, "mul": {"accel": 0.94, "launch": 0.93}, "add": {"top_kmh": 24.0}},
		],
	},
	"weight": {
		"label": "Weight", "kind": Kind.PERFORMANCE,
		"hint": "Strip it, panel it in carbon, cage it. Everything improves at once.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Stripped", "price": 2200, "mul": {"mass_kg": 0.94, "accel": 1.04, "grip": 1.02, "brake": 1.03}, "add": {}},
			{"name": "Carbon panels", "price": 7600, "mul": {"mass_kg": 0.88, "accel": 1.09, "grip": 1.04, "brake": 1.06}, "add": {}},
			{"name": "Titanium + cage", "price": 17800, "mul": {"mass_kg": 0.80, "accel": 1.15, "grip": 1.07, "brake": 1.10}, "add": {}},
		],
	},
	"bodykit": {
		"label": "Body kit", "kind": Kind.LOOK,
		"hint": "Bumpers, splitters and arches. Wide kits put more rubber on the road.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Street", "price": 2800, "mul": {}, "add": {"grip": 0.02}},
			{"name": "Wide body", "price": 9400, "mul": {}, "add": {"grip": 0.06, "width": 0.055, "top_kmh": -3.0}},
			{"name": "Race aero", "price": 19600, "mul": {}, "add": {"grip": 0.10, "width": 0.075, "top_kmh": -6.0}},
		],
	},
	"spoiler": {
		"label": "Spoiler", "kind": Kind.LOOK,
		"hint": "Rear downforce. Planted in the corners, slower on the straight.",
		"levels": [
			{"name": "None", "price": 0, "mul": {}, "add": {}},
			{"name": "Lip", "price": 900, "mul": {}, "add": {"grip": 0.015}},
			{"name": "Ducktail", "price": 2100, "mul": {}, "add": {"grip": 0.03, "top_kmh": -1.0}},
			{"name": "GT wing", "price": 5400, "mul": {}, "add": {"grip": 0.06, "top_kmh": -4.0}},
			{"name": "Swan-neck", "price": 11200, "mul": {}, "add": {"grip": 0.09, "top_kmh": -7.0}},
		],
	},
	"rims": {
		"label": "Rims", "kind": Kind.LOOK,
		"hint": "Wheel design. Forged sets shave unsprung weight.",
		"levels": [
			{"name": "5-spoke", "price": 0, "mul": {}, "add": {}},
			{"name": "Mesh", "price": 1200, "mul": {}, "add": {}},
			{"name": "Deep dish", "price": 1600, "mul": {}, "add": {}},
			{"name": "Turbine", "price": 2400, "mul": {}, "add": {}},
			{"name": "Split-6 forged", "price": 4800, "mul": {"mass_kg": 0.985}, "add": {"brake": 0.02}},
			{"name": "Carbon blade", "price": 9600, "mul": {"mass_kg": 0.975}, "add": {"brake": 0.04, "grip": 0.01}},
		],
	},
	"paint": {
		"label": "Paint", "kind": Kind.LOOK, "colour": true, "choice": true,
		"hint": "Base colour. The finish decides how the city lights sit on it.",
		"levels": [
			{"name": "Gloss", "price": 400, "mul": {}, "add": {}},
			{"name": "Metallic", "price": 900, "mul": {}, "add": {}},
			{"name": "Pearl", "price": 1800, "mul": {}, "add": {}},
			{"name": "Matte", "price": 1400, "mul": {}, "add": {}},
			{"name": "Chrome", "price": 4200, "mul": {}, "add": {}},
		],
	},
	"vinyl": {
		"label": "Vinyl", "kind": Kind.LOOK, "choice": true,
		"hint": "Graphics over the paint, in the accent colour.",
		"levels": [
			{"name": "None", "price": 0, "mul": {}, "add": {}},
			{"name": "Racing stripes", "price": 600, "mul": {}, "add": {}},
			{"name": "Side stripe", "price": 600, "mul": {}, "add": {}},
			{"name": "Two tone", "price": 900, "mul": {}, "add": {}},
			{"name": "Fade", "price": 1200, "mul": {}, "add": {}},
			{"name": "Checker", "price": 900, "mul": {}, "add": {}},
			{"name": "Flames", "price": 1500, "mul": {}, "add": {}},
			{"name": "Bolt", "price": 1200, "mul": {}, "add": {}},
			{"name": "Retro", "price": 1400, "mul": {}, "add": {}},
			{"name": "Camo", "price": 1600, "mul": {}, "add": {}},
			{"name": "Tiger", "price": 1800, "mul": {}, "add": {}},
			{"name": "Hex", "price": 1600, "mul": {}, "add": {}},
			{"name": "Gradient", "price": 1900, "mul": {}, "add": {}},
			{"name": "Race livery", "price": 2200, "mul": {}, "add": {}},
			{"name": "Drip", "price": 1700, "mul": {}, "add": {}},
			{"name": "Circuit", "price": 2400, "mul": {}, "add": {}},
		],
	},
	"neon": {
		"label": "Neon", "kind": Kind.LOOK, "colour": true,
		"hint": "Underglow tubes. Pure Underground.",
		"levels": [
			{"name": "Off", "price": 0, "mul": {}, "add": {}},
			{"name": "Static", "price": 1100, "mul": {}, "add": {}},
			{"name": "Pulse", "price": 1600, "mul": {}, "add": {}},
			{"name": "Strobe", "price": 1900, "mul": {}, "add": {}},
			{"name": "Rainbow", "price": 2600, "mul": {}, "add": {}},
			{"name": "Full kit", "price": 4400, "mul": {}, "add": {}},
		],
	},
	"headlights": {
		"label": "Headlights", "kind": Kind.LOOK, "colour": true,
		"hint": "Bulb colour and reach. Lights up the city in front of you.",
		"levels": [
			{"name": "Stock", "price": 0, "mul": {}, "add": {}},
			{"name": "Projector", "price": 1200, "mul": {}, "add": {}},
			{"name": "LED bar", "price": 2600, "mul": {}, "add": {}},
			{"name": "Angel eyes", "price": 3400, "mul": {}, "add": {}},
		],
	},
	"tint": {
		"label": "Window tint", "kind": Kind.LOOK,
		"hint": "How dark the glass goes.",
		"levels": [
			{"name": "Clear", "price": 0, "mul": {}, "add": {}},
			{"name": "Light", "price": 300, "mul": {}, "add": {}},
			{"name": "Medium", "price": 500, "mul": {}, "add": {}},
			{"name": "Dark", "price": 700, "mul": {}, "add": {}},
			{"name": "Limo", "price": 900, "mul": {}, "add": {}},
		],
	},
}

## The physics/visual keys a setup resolves to, with their units, for the garage UI.
const SPEC_BARS := [
	{"key": "top_kmh", "label": "Top speed", "lo": 210.0, "hi": 400.0},
	{"key": "accel", "label": "Acceleration", "lo": 0.80, "hi": 1.85},
	{"key": "grip", "label": "Grip", "lo": 0.80, "hi": 1.75},
	{"key": "brake", "label": "Braking", "lo": 0.78, "hi": 2.05},
	{"key": "boost", "label": "Boost", "lo": 0.0, "hi": 1.0},
]


static func slot_label(slot: String) -> String:
	return String((CATALOGUE.get(slot, {}) as Dictionary).get("label", slot.capitalize()))


static func slot_kind(slot: String) -> int:
	return int((CATALOGUE.get(slot, {}) as Dictionary).get("kind", Kind.LOOK))


## True when the levels are alternatives to pick from (paint finishes, vinyls, gearbox ratios)
## rather than an upgrade ladder where each level costs more than the last.
static func is_choice(slot: String) -> bool:
	return bool((CATALOGUE.get(slot, {}) as Dictionary).get("choice", false))


static func levels(slot: String) -> Array:
	return (CATALOGUE.get(slot, {}) as Dictionary).get("levels", []) as Array


static func level_count(slot: String) -> int:
	return levels(slot).size()


static func level_name(slot: String, index: int) -> String:
	var ls := levels(slot)
	if ls.is_empty():
		return "-"
	return String((ls[clampi(index, 0, ls.size() - 1)] as Dictionary)["name"])


static func level_price(slot: String, index: int) -> int:
	var ls := levels(slot)
	if ls.is_empty():
		return 0
	return int((ls[clampi(index, 0, ls.size() - 1)] as Dictionary)["price"])


## A fresh, stock setup for a car: every performance slot at 0, the look slots at the car's own
## showroom style.
static func default_setup(car_id: String) -> Dictionary:
	var style := CarDefs.default_style(car_id)
	var s := {}
	for slot in PERF_SLOTS:
		s[slot] = 0
	s["bodykit"] = 0
	s["spoiler"] = 0
	s["rims"] = int(style.get("rims", 0))
	s["paint"] = int(FINISH_INDEX.get(String(style.get("finish", "gloss")), 0))
	s["paint_color"] = String(style.get("paint", "#ff5a00"))
	s["accent_color"] = String(style.get("accent", "#121418"))
	s["rim_color"] = String(style.get("rim_color", "#d8d8dc"))
	s["caliper_color"] = String(style.get("caliper", "#ff1a1a"))
	s["vinyl"] = int(VINYL_INDEX.get(String(style.get("vinyl", "none")), 0))
	s["neon"] = int(NEON_MODE_INDEX.get(String(style.get("neon_mode", "static")), 1))
	s["neon_color"] = String(style.get("neon", "#00e5ff"))
	s["headlights"] = 0
	s["headlight_color"] = String(style.get("headlight", "#eaf4ff"))
	s["tint"] = int(round(clampf(float(style.get("tint", 0.5)), 0.0, 1.0) * 4.0))
	s["plate"] = String(style.get("plate", "SPEEDFST"))
	return s


const FINISH_INDEX := {"gloss": 0, "metallic": 1, "pearl": 2, "matte": 3, "chrome": 4}
const FINISH_NAMES: Array[String] = ["gloss", "metallic", "pearl", "matte", "chrome"]
## Order fixed by shaders/car_paint.gdshader's livery_mask(): index = uniform `livery`.
const VINYL_NAMES: Array[String] = ["none", "racing_stripes", "side_stripe", "two_tone", "fade",
	"checker", "flames", "bolt", "retro", "camo", "tiger", "hex", "gradient", "race", "drip", "circuit"]
const VINYL_INDEX := {"none": 0, "racing_stripes": 1, "side_stripe": 2, "two_tone": 3, "fade": 4,
	"checker": 5, "flames": 6, "bolt": 7, "retro": 8, "camo": 9, "tiger": 10, "hex": 11,
	"gradient": 12, "race": 13, "drip": 14, "circuit": 15}
const NEON_MODE_NAMES: Array[String] = ["off", "static", "pulse", "strobe", "rainbow", "full"]
const NEON_MODE_INDEX := {"off": 0, "static": 1, "pulse": 2, "strobe": 3, "rainbow": 4, "full": 5}


static func finish_of(setup: Dictionary) -> String:
	return FINISH_NAMES[clampi(int(setup.get("paint", 0)), 0, FINISH_NAMES.size() - 1)]


static func vinyl_of(setup: Dictionary) -> String:
	return VINYL_NAMES[clampi(int(setup.get("vinyl", 0)), 0, VINYL_NAMES.size() - 1)]


static func neon_mode_of(setup: Dictionary) -> String:
	return NEON_MODE_NAMES[clampi(int(setup.get("neon", 0)), 0, NEON_MODE_NAMES.size() - 1)]


## Resolve a car + setup into the numbers the game runs on. Returns CarDefs.specs() keys plus
## `ride` (body drop in metres), `width` (extra half-width from the kit) and `boost` (0..1 rating).
static func resolve(car_id: String, setup: Dictionary) -> Dictionary:
	var out := (CarDefs.specs(car_id) as Dictionary).duplicate()
	out["ride"] = 0.0
	out["width"] = 0.0
	for slot in SLOTS:
		var ls := levels(slot)
		if ls.is_empty():
			continue
		var idx := clampi(int(setup.get(slot, 0)), 0, ls.size() - 1)
		var lv: Dictionary = ls[idx]
		for k in (lv.get("mul", {}) as Dictionary):
			out[k] = float(out.get(k, 0.0)) * float(lv["mul"][k])
		for k in (lv.get("add", {}) as Dictionary):
			out[k] = float(out.get(k, 0.0)) + float(lv["add"][k])
	# nitrous level 0 means no bottle at all
	if int(setup.get("nitrous", 0)) <= 0:
		out["boost_power"] = 0.0
		out["boost_tank"] = 0.0
		out["boost_kmh"] = 0.0
	out["top_kmh"] = maxf(60.0, float(out["top_kmh"]))
	out["slide_grip"] = clampf(float(out["slide_grip"]), 0.08, 0.95)
	out["boost"] = clampf((float(out.get("boost_power", 0.0)) / 20.0) * 0.5
		+ (float(out.get("boost_tank", 0.0)) / 12.0) * 0.25
		+ (float(out.get("boost_gain", 0.0)) / 0.7) * 0.25, 0.0, 1.0)
	return out


## 0..1 ratings for the garage spec bars.
static func ratings(car_id: String, setup: Dictionary) -> Dictionary:
	var r := resolve(car_id, setup)
	var out := {}
	for bar in SPEC_BARS:
		var key: String = bar["key"]
		var v := float(r.get(key, 0.0))
		out[key] = clampf((v - float(bar["lo"])) / (float(bar["hi"]) - float(bar["lo"])), 0.0, 1.0)
	return out


## What a setup costs in total (every installed level above stock).
static func total_price(setup: Dictionary) -> int:
	var sum := 0
	for slot in SLOTS:
		var ls := levels(slot)
		if ls.is_empty():
			continue
		var idx := clampi(int(setup.get(slot, 0)), 0, ls.size() - 1)
		for i in range(1, idx + 1):
			sum += int((ls[i] as Dictionary)["price"])
	return sum


## Surface table for this car with its tyres: slicks give up grass and dirt, offroad tyres keep it.
static func surface_overrides(car_id: String, setup: Dictionary) -> Dictionary:
	var base: Dictionary = (CarDefs.get_def(car_id).get("surface_bonus", {}) as Dictionary).duplicate(true)
	var tyre := clampi(int(setup.get("tyres", 0)), 0, 3)
	if tyre >= 2:
		var loss := 0.75 if tyre == 2 else 0.55
		for id in [2, 5, 6, 8, 20, 21]:
			var vals: Array = base.get(id, TmTuning.surface_vals(id)).duplicate()
			vals[3] = float(vals[3]) * loss
			vals[1] = float(vals[1]) * loss
			base[id] = vals
	return base
