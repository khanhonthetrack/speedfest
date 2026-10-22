class_name TmRoadCars
extends RefCounted
## Our own road cars (PLAN M17: the class of cars NFS Most Wanted's Blacklist drove, our own
## shapes and names, no makers' badges): tools/assets/roadcar.py builds each into
## assets/car/<id>.glb (the body, its spoiler, a tyre, rim and brake per axle), its tuning kit
## (assets/car/<id>_kit.glb, TUNING) and assets/car/<id>.json (its
## wheel places, tyre sizes, and the body's lines along the car for the livery shader). Each car,
## and the hypercar, has five liveries (no sponsors): car/tm_car_surface.gdshader mode 4 draws
## them from a pattern, colours and parameters.

const DIR := "res://assets/car/"

## What each car is, under its name in the garage.
const BLURBS := {
	"": "Our open-wheeler, the Stadium's own racing car.",
	"hyper": "Our Le Mans hypercar: a closed prototype, hybrid V6.",
	"kobold": "Supercharged front-drive compact coupe.",
	"ayame": "Compact rear-drive sports sedan, straight six.",
	"birdie": "Turbocharged three-door hot hatch.",
	"nemesis": "Widened homologation coupe, straight six. The one to beat.",
	"umbra": "Front-drive V6 sport coupe.",
	"zenith": "Twin-turbo grand tourer, straight six.",
	"stallion": "Retro V8 muscle fastback.",
	"kaiten": "Four-door rotary sports coupe.",
	"halberd": "Turbo four-wheel-drive rally sedan.",
	"gavial": "Mid-engined flat-six coupe.",
	"argent": "V8 grand-touring coupe.",
	"albion": "British V12 grand tourer.",
	"taipan": "American V10 brute.",
	"corrida": "Mid-engined Italian V10, four-wheel drive.",
	"frigate": "Front-engined American V8 sports car.",
	"quicksilver": "Supercharged V8 grand tourer with a racing nose.",
}

## The garage's order: [id, name].
const CARS := [
	["kobold", "Kobold SS"], ["ayame", "Ayame 300"], ["birdie", "Birdie GT"], ["nemesis", "Nemesis GT"],
	["umbra", "Umbra GTS"], ["zenith", "Zenith TT"], ["stallion", "Stallion GT"], ["kaiten", "Kaiten R"],
	["halberd", "Halberd VIII"], ["gavial", "Gavial S"], ["argent", "Argent 500"], ["albion", "Albion GT"],
	["taipan", "Taipan V10"], ["corrida", "Corrida V10"], ["frigate", "Frigate V8"], ["quicksilver", "Quicksilver"],
]

## The livery patterns (tm_car_surface.gdshader `livery`), by name.
const PATTERNS := ["plain", "stripes", "flames", "tribal", "tiger", "shards", "halftone", "sweep", "checker", "camo",
	"twotone", "bolt", "fade", "claws"]

## Five liveries per car: name, pattern, base paint, vinyl colours a (main), b (outline/second),
## c (accent), p (the pattern's parameters), finish ("gloss", "metallic", "pearl", "matte",
## "chrome"), rim colour, caliper colour, hood ("" paint, "carbon", "black"), roof ("" or "black").
const LIVERIES := {
	"hyper": [
		# its own: the player's colour, gloss black below the sill and round the canopy, white stripes
		{"name": "Endurance", "pattern": "hyper", "base": Color(0.85, 0.08, 0.06), "a": Color(0.02, 0.02, 0.025)},
		{"name": "Nightfall", "pattern": "sweep", "base": Color(0.02, 0.02, 0.025), "a": Color(0.95, 0.35, 0.02),
			"b": Color(0.95, 0.95, 0.95), "c": Color(0, 0, 0), "p": Vector4(0, 0, 0, 0), "finish": "gloss"},
		{"name": "Hypernova", "pattern": "shards", "base": Color(0.93, 0.94, 0.96), "a": Color(0.55, 0.12, 0.85),
			"b": Color(0.08, 0.08, 0.1), "c": Color(0.2, 0.6, 1.0), "p": Vector4(0.24, 0.3, 1.0, 0.014), "finish": "pearl"},
		{"name": "Liquid Silver", "pattern": "twotone", "base": Color(0.72, 0.74, 0.78), "a": Color(0.02, 0.02, 0.025),
			"b": Color(0.35, 0.95, 0.15), "c": Color(0, 0, 0), "p": Vector4(0, 0, 0, 0), "finish": "metallic"},
		{"name": "Red Shift", "pattern": "fade", "base": Color(0.03, 0.03, 0.035), "a": Color(0.9, 0.05, 0.08),
			"b": Color(1.0, 0.45, 0.1), "c": Color(0.9, 0.2, 0.1), "p": Vector4(0.25, 0.75, 0, 0), "finish": "pearl"},
	],
	"kobold": [
		{"name": "Midnight Blue", "pattern": "plain", "base": Color(0.04, 0.1, 0.32), "a": Color(0.72, 0.74, 0.78), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Street Heat", "pattern": "flames", "base": Color(0.02, 0.02, 0.025), "a": Color(0.95, 0.25, 0.03), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.8, 0.1),
			"p": Vector4(1.2, 0.7, 0.11, 2.2), "finish": "gloss", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Lime Rush", "pattern": "bolt", "base": Color(0.45, 0.82, 0.08), "a": Color(0.02, 0.02, 0.025), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.55, 0, 0, 0), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.1, 0.1, 0.12), "roof": "black"},
		{"name": "Ice Shard", "pattern": "shards", "base": Color(0.93, 0.93, 0.95), "a": Color(0.1, 0.65, 0.95), "b": Color(0.05, 0.12, 0.35), "c": Color(0.4, 0.8, 1),
			"p": Vector4(0.2, 0.3, 1, 0.012), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.1, 0.35, 0.9)},
		{"name": "Rally Stripe", "pattern": "stripes", "base": Color(0.98, 0.78, 0.05), "a": Color(0.02, 0.02, 0.025), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.12, 0.04, 0.012, 1), "finish": "gloss", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.1, 0.1, 0.12), "hood": "carbon"},
	],
	"ayame": [
		{"name": "Gold Rush", "pattern": "tribal", "base": Color(0.8, 0.6, 0.18), "a": Color(0.02, 0.02, 0.025), "b": Color(0.45, 0.03, 0.03), "c": Color(0, 0, 0),
			"p": Vector4(1, 0, 0, 0), "finish": "metallic", "rim": Color(0.75, 0.06, 0.06), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Crimson Claw", "pattern": "claws", "base": Color(0.93, 0.93, 0.95), "a": Color(0.85, 0.05, 0.06), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0.5, 0, 0, 0), "finish": "pearl", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Sakura", "pattern": "halftone", "base": Color(0.95, 0.95, 0.96), "a": Color(0.95, 0.35, 0.62), "b": Color(0.6, 0.1, 0.35), "c": Color(1, 0.75, 0.85),
			"p": Vector4(0.045, 0.3, 0.8, 0), "finish": "pearl", "rim": Color(0.8, 0.8, 0.82), "caliper": Color(0.95, 0.4, 0.65)},
		{"name": "Shadow Line", "pattern": "twotone", "base": Color(0.22, 0.23, 0.25), "a": Color(0.02, 0.02, 0.025), "b": Color(0.85, 0.08, 0.08), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Purple Haze", "pattern": "fade", "base": Color(0.02, 0.02, 0.025), "a": Color(0.45, 0.08, 0.75), "b": Color(0.75, 0.25, 0.95), "c": Color(0.5, 0.2, 0.9),
			"p": Vector4(0.3, 0.8, 0, 0), "finish": "pearl", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.55, 0.2, 0.85)},
	],
	"birdie": [
		{"name": "Street Samurai", "pattern": "tribal", "base": Color(0.93, 0.93, 0.95), "a": Color(0.06, 0.25, 0.65), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(1, 0, 0, 0), "finish": "pearl", "rim": Color(0.8, 0.8, 0.82), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Red Line", "pattern": "stripes", "base": Color(0.02, 0.02, 0.025), "a": Color(0.85, 0.06, 0.06), "b": Color(0.9, 0.9, 0.9), "c": Color(0, 0, 0),
			"p": Vector4(0.11, 0.035, 0.01, 1), "finish": "gloss", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Urban Camo", "pattern": "camo", "base": Color(0.55, 0.57, 0.6), "a": Color(0.2, 0.21, 0.23), "b": Color(0.85, 0.86, 0.88), "c": Color(0.08, 0.08, 0.09),
			"p": Vector4(0.05, 0, 0, 0), "finish": "matte", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Thunder", "pattern": "bolt", "base": Color(0.95, 0.75, 0.05), "a": Color(0.02, 0.02, 0.025), "b": Color(0.95, 0.95, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.55, 0, 0, 0), "finish": "metallic", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.1, 0.1, 0.12), "roof": "black"},
		{"name": "Checkmate", "pattern": "checker", "base": Color(0.05, 0.3, 0.75), "a": Color(0.95, 0.95, 0.96), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0.07, 0.45, 0.85, 0), "finish": "metallic", "rim": Color(0.8, 0.8, 0.82), "caliper": Color(0.85, 0.1, 0.05), "hood": "carbon"},
	],
	"nemesis": [
		{"name": "Hunted", "pattern": "sweep", "base": Color(0.72, 0.74, 0.78), "a": Color(0.08, 0.22, 0.62), "b": Color(0.14, 0.15, 0.18), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Black Ops", "pattern": "camo", "base": Color(0.25, 0.26, 0.28), "a": Color(0.02, 0.02, 0.025), "b": Color(0.42, 0.43, 0.45), "c": Color(0.12, 0.14, 0.12),
			"p": Vector4(0.06, 0, 0, 0), "finish": "matte", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Heritage", "pattern": "stripes", "base": Color(0.93, 0.93, 0.95), "a": Color(0.05, 0.12, 0.45), "b": Color(0.85, 0.08, 0.08), "c": Color(0, 0, 0),
			"p": Vector4(0.08, 0.06, 0.012, 1), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.1, 0.25, 0.75)},
		{"name": "Inferno", "pattern": "flames", "base": Color(0.02, 0.02, 0.025), "a": Color(0.9, 0.08, 0.04), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.55, 0.05),
			"p": Vector4(1.3, 0.8, 0.12, 2.2), "finish": "gloss", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.95, 0.75, 0.1), "hood": "carbon"},
		{"name": "Arctic", "pattern": "shards", "base": Color(0.93, 0.93, 0.95), "a": Color(0.55, 0.8, 0.98), "b": Color(0.72, 0.74, 0.78), "c": Color(0.6, 0.85, 1),
			"p": Vector4(0.22, 0.25, 1, 0.012), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.1, 0.35, 0.9)},
	],
	"umbra": [
		{"name": "Tiger Claw", "pattern": "tiger", "base": Color(0.95, 0.48, 0.05), "a": Color(0.03, 0.03, 0.035), "b": Color(0, 0, 0), "c": Color(0, 0, 0),
			"p": Vector4(2.6, 0, 0, 0), "finish": "metallic", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Silver Fang", "pattern": "claws", "base": Color(0.72, 0.74, 0.78), "a": Color(0.02, 0.02, 0.025), "b": Color(0.95, 0.45, 0.05), "c": Color(0, 0, 0),
			"p": Vector4(0.55, 0, 0, 0), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.95, 0.45, 0.05)},
		{"name": "Neon Nights", "pattern": "bolt", "base": Color(0.35, 0.08, 0.6), "a": Color(0.1, 0.9, 0.95), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.6, 0, 0, 0), "finish": "pearl", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.1, 0.9, 0.95), "roof": "black"},
		{"name": "Lava", "pattern": "flames", "base": Color(0.18, 0.18, 0.2), "a": Color(0.85, 0.08, 0.03), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.5, 0.05),
			"p": Vector4(1.3, 0.8, 0.12, 2.2), "finish": "metallic", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Mint", "pattern": "halftone", "base": Color(0.55, 0.9, 0.75), "a": Color(0.03, 0.32, 0.3), "b": Color(0, 0, 0), "c": Color(0.3, 0.8, 0.7),
			"p": Vector4(0.05, 0.25, 0.75, 0), "finish": "pearl", "rim": Color(0.8, 0.8, 0.82), "caliper": Color(0.1, 0.1, 0.12)},
	],
	"zenith": [
		{"name": "Afterburner", "pattern": "flames", "base": Color(0.62, 0.64, 0.68), "a": Color(0.92, 0.22, 0.04), "b": Color(0.05, 0.05, 0.06), "c": Color(1, 0.78, 0.1),
			"p": Vector4(1.25, 0.75, 0.12, 2.2), "finish": "metallic", "rim": Color(0.12, 0.12, 0.13), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Midnight Stripe", "pattern": "stripes", "base": Color(0.03, 0.035, 0.05), "a": Color(0.85, 0.86, 0.9), "b": Color(0.8, 0.1, 0.12), "c": Color(0, 0, 0),
			"p": Vector4(0.13, 0.045, 0.012, 1), "finish": "gloss", "rim": Color(0.8, 0.8, 0.82), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Shatter", "pattern": "shards", "base": Color(0.95, 0.95, 0.96), "a": Color(0.45, 0.1, 0.75), "b": Color(0.1, 0.1, 0.12), "c": Color(0, 0, 0),
			"p": Vector4(0.2, 0.25, 1, 0.012), "finish": "pearl", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.5, 0.2, 0.8), "hood": "carbon"},
		{"name": "Bengal", "pattern": "tiger", "base": Color(0.95, 0.95, 0.96), "a": Color(0.03, 0.03, 0.035), "b": Color(0, 0, 0), "c": Color(0, 0, 0),
			"p": Vector4(2.4, 0, 0, 0), "finish": "pearl", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Ice Fade", "pattern": "halftone", "base": Color(0.92, 0.93, 0.95), "a": Color(0.05, 0.35, 0.85), "b": Color(0.02, 0.1, 0.3), "c": Color(0, 0, 0),
			"p": Vector4(0.05, 0.25, 0.75, 0), "finish": "pearl", "rim": Color(0.75, 0.76, 0.8), "caliper": Color(0.1, 0.35, 0.9)},
	],
	"stallion": [
		{"name": "Heritage", "pattern": "stripes", "base": Color(0.75, 0.04, 0.05), "a": Color(0.93, 0.93, 0.95), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0.14, 0.05, 0.012, 0), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.1, 0.1, 0.12)},
		{"name": "Outlaw", "pattern": "twotone", "base": Color(0.72, 0.74, 0.78), "a": Color(0.02, 0.02, 0.025), "b": Color(0.85, 0.08, 0.06), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Wildfire", "pattern": "flames", "base": Color(0.02, 0.02, 0.025), "a": Color(0.95, 0.3, 0.03), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.85, 0.15),
			"p": Vector4(1.5, 0.9, 0.12, 2), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Thunderhoof", "pattern": "bolt", "base": Color(0.98, 0.78, 0.05), "a": Color(0.02, 0.02, 0.025), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.6, 0, 0, 0), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.1, 0.1, 0.12), "hood": "black"},
		{"name": "Desert Storm", "pattern": "camo", "base": Color(0.72, 0.62, 0.45), "a": Color(0.45, 0.36, 0.24), "b": Color(0.85, 0.78, 0.62), "c": Color(0.3, 0.25, 0.18),
			"p": Vector4(0.06, 0, 0, 0), "finish": "matte", "rim": Color(0.3, 0.28, 0.25), "caliper": Color(0.85, 0.1, 0.05)},
	],
	"kaiten": [
		{"name": "Red Swirl", "pattern": "tribal", "base": Color(0.72, 0.74, 0.78), "a": Color(0.8, 0.06, 0.06), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(1, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Velocity", "pattern": "sweep", "base": Color(0.93, 0.93, 0.95), "a": Color(0.85, 0.06, 0.06), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "pearl", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Kaiju", "pattern": "shards", "base": Color(0.02, 0.02, 0.025), "a": Color(0.25, 0.85, 0.25), "b": Color(0.05, 0.35, 0.1), "c": Color(0, 0, 0),
			"p": Vector4(0.2, 0.3, 1, 0.012), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.25, 0.85, 0.25)},
		{"name": "Blossom", "pattern": "halftone", "base": Color(0.93, 0.93, 0.95), "a": Color(0.92, 0.3, 0.55), "b": Color(0.6, 0.1, 0.35), "c": Color(1, 0.7, 0.8),
			"p": Vector4(0.045, 0.3, 0.8, 0), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.95, 0.4, 0.65)},
		{"name": "Sunset", "pattern": "fade", "base": Color(0.98, 0.65, 0.05), "a": Color(0.85, 0.08, 0.05), "b": Color(0.95, 0.35, 0.05), "c": Color(1, 0.6, 0.1),
			"p": Vector4(0.25, 0.8, 0, 0), "finish": "pearl", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.85, 0.1, 0.05)},
	],
	"halberd": [
		{"name": "Blue Storm", "pattern": "tribal", "base": Color(0.93, 0.93, 0.95), "a": Color(0.06, 0.25, 0.75), "b": Color(0.02, 0.05, 0.2), "c": Color(0, 0, 0),
			"p": Vector4(1, 0, 0, 0), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.1, 0.25, 0.75)},
		{"name": "Rally Legend", "pattern": "stripes", "base": Color(0.05, 0.18, 0.55), "a": Color(0.93, 0.93, 0.95), "b": Color(0.95, 0.75, 0.05), "c": Color(0, 0, 0),
			"p": Vector4(0.1, 0.05, 0.012, 1), "finish": "metallic", "rim": Color(0.95, 0.75, 0.2), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Gravel", "pattern": "camo", "base": Color(0.75, 0.68, 0.52), "a": Color(0.45, 0.38, 0.28), "b": Color(0.55, 0.58, 0.4), "c": Color(0.3, 0.26, 0.2),
			"p": Vector4(0.06, 0, 0, 0), "finish": "matte", "rim": Color(0.3, 0.28, 0.25), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Scorch", "pattern": "flames", "base": Color(0.93, 0.93, 0.95), "a": Color(0.9, 0.12, 0.04), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.75, 0.1),
			"p": Vector4(1.2, 0.75, 0.11, 2.2), "finish": "pearl", "rim": Color(0.1, 0.1, 0.11), "caliper": Color(0.85, 0.1, 0.05), "hood": "carbon"},
		{"name": "Volt", "pattern": "bolt", "base": Color(0.02, 0.02, 0.025), "a": Color(0.98, 0.85, 0.05), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.55, 0, 0, 0), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.98, 0.85, 0.05)},
	],
	"gavial": [
		{"name": "Ghost Flame", "pattern": "flames", "base": Color(0.02, 0.02, 0.025), "a": Color(0.92, 0.3, 0.04), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.82, 0.15),
			"p": Vector4(1.2, 0.75, 0.11, 2.2), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Heritage Red", "pattern": "stripes", "base": Color(0.8, 0.05, 0.04), "a": Color(0.93, 0.93, 0.95), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0.09, 0.06, 0.01, 1), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.1, 0.1, 0.12)},
		{"name": "Racing Silver", "pattern": "halftone", "base": Color(0.72, 0.74, 0.78), "a": Color(0.02, 0.02, 0.025), "b": Color(0, 0, 0), "c": Color(0.5, 0.55, 0.6),
			"p": Vector4(0.045, 0.3, 0.8, 0), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Acid", "pattern": "shards", "base": Color(0.6, 0.9, 0.1), "a": Color(0.02, 0.02, 0.025), "b": Color(0.2, 0.3, 0.05), "c": Color(0, 0, 0),
			"p": Vector4(0.2, 0.3, 1, 0.012), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.6, 0.9, 0.1)},
		{"name": "Speed Racer", "pattern": "sweep", "base": Color(0.93, 0.93, 0.95), "a": Color(0.08, 0.2, 0.65), "b": Color(0.85, 0.08, 0.06), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
	],
	"argent": [
		{"name": "Silver Arrow", "pattern": "twotone", "base": Color(0.72, 0.74, 0.78), "a": Color(0.05, 0.05, 0.06), "b": Color(0.15, 0.4, 0.9), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.6, 0.6, 0.62)},
		{"name": "Black Dragon", "pattern": "tribal", "base": Color(0.02, 0.02, 0.025), "a": Color(0.72, 0.74, 0.78), "b": Color(0.35, 0.36, 0.38), "c": Color(0, 0, 0),
			"p": Vector4(1.1, 0, 0, 0), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Ice Queen", "pattern": "shards", "base": Color(0.95, 0.96, 0.98), "a": Color(0.6, 0.82, 0.98), "b": Color(0.55, 0.58, 0.62), "c": Color(0.7, 0.9, 1),
			"p": Vector4(0.22, 0.25, 1, 0.012), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.6, 0.6, 0.62)},
		{"name": "Royal", "pattern": "stripes", "base": Color(0.22, 0.05, 0.38), "a": Color(0.85, 0.68, 0.25), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0.07, 0.05, 0.01, 1), "finish": "pearl", "rim": Color(0.85, 0.68, 0.25), "caliper": Color(0.85, 0.68, 0.25)},
		{"name": "Phantom", "pattern": "fade", "base": Color(0.1, 0.1, 0.11), "a": Color(0.5, 0.52, 0.56), "b": Color(0.2, 0.2, 0.22), "c": Color(0.6, 0.62, 0.66),
			"p": Vector4(0.3, 0.85, 0, 0), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05)},
	],
	"albion": [
		{"name": "Racing Green", "pattern": "stripes", "base": Color(0.03, 0.2, 0.1), "a": Color(0.72, 0.74, 0.78), "b": Color(0.85, 0.68, 0.25), "c": Color(0, 0, 0),
			"p": Vector4(0.1, 0.04, 0.008, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.68, 0.25)},
		{"name": "Gilded Tiger", "pattern": "tiger", "base": Color(0.85, 0.68, 0.22), "a": Color(0.03, 0.2, 0.1), "b": Color(0, 0, 0), "c": Color(0, 0, 0),
			"p": Vector4(2.2, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.68, 0.25)},
		{"name": "Grand Tour", "pattern": "twotone", "base": Color(0.72, 0.74, 0.78), "a": Color(0.15, 0.16, 0.18), "b": Color(0.75, 0.1, 0.1), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Crown", "pattern": "halftone", "base": Color(0.04, 0.08, 0.25), "a": Color(0.85, 0.68, 0.25), "b": Color(0, 0, 0), "c": Color(0.6, 0.5, 0.2),
			"p": Vector4(0.05, 0.3, 0.8, 0), "finish": "pearl", "rim": Color(0.85, 0.68, 0.25), "caliper": Color(0.85, 0.68, 0.25)},
		{"name": "Wyvern", "pattern": "tribal", "base": Color(0.02, 0.02, 0.025), "a": Color(0.1, 0.6, 0.25), "b": Color(0.85, 0.68, 0.25), "c": Color(0, 0, 0),
			"p": Vector4(1.1, 0, 0, 0), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.1, 0.6, 0.25)},
	],
	"taipan": [
		{"name": "Venom", "pattern": "stripes", "base": Color(0.08, 0.55, 0.18), "a": Color(0.93, 0.93, 0.95), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0.15, 0.06, 0.012, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Snakebite", "pattern": "claws", "base": Color(0.02, 0.02, 0.025), "a": Color(0.55, 0.95, 0.1), "b": Color(0.15, 0.3, 0.05), "c": Color(0, 0, 0),
			"p": Vector4(0.5, 0, 0, 0), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.55, 0.95, 0.1)},
		{"name": "Coiled", "pattern": "tribal", "base": Color(0.75, 0.04, 0.04), "a": Color(0.02, 0.02, 0.025), "b": Color(0.25, 0.02, 0.02), "c": Color(0, 0, 0),
			"p": Vector4(1.1, 0, 0, 0), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Toxic", "pattern": "camo", "base": Color(0.55, 0.9, 0.1), "a": Color(0.02, 0.02, 0.025), "b": Color(0.1, 0.35, 0.08), "c": Color(0.95, 0.9, 0.1),
			"p": Vector4(0.06, 0, 0, 0), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.95, 0.9, 0.1)},
		{"name": "Blue Strike", "pattern": "bolt", "base": Color(0.05, 0.2, 0.75), "a": Color(0.93, 0.93, 0.95), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0.6, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
	],
	"corrida": [
		{"name": "Arancia", "pattern": "shards", "base": Color(0.95, 0.42, 0.02), "a": Color(0.02, 0.02, 0.025), "b": Color(0.3, 0.1, 0.02), "c": Color(0, 0, 0),
			"p": Vector4(0.2, 0.3, 1, 0.012), "finish": "pearl", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Toro Nero", "pattern": "flames", "base": Color(0.04, 0.04, 0.045), "a": Color(0.85, 0.06, 0.04), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.5, 0.05),
			"p": Vector4(1.1, 0.7, 0.11, 2.2), "finish": "matte", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Verde", "pattern": "sweep", "base": Color(0.5, 0.85, 0.05), "a": Color(0.02, 0.02, 0.025), "b": Color(0.2, 0.35, 0.02), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "pearl", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.5, 0.85, 0.05)},
		{"name": "Giallo", "pattern": "stripes", "base": Color(0.98, 0.8, 0.05), "a": Color(0.02, 0.02, 0.025), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.1, 0.04, 0.01, 1), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.1, 0.1, 0.12)},
		{"name": "Nero Opaco", "pattern": "twotone", "base": Color(0.12, 0.12, 0.13), "a": Color(0.02, 0.02, 0.025), "b": Color(0.95, 0.42, 0.02), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "matte", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.95, 0.42, 0.02)},
	],
	"frigate": [
		{"name": "Bronze Age", "pattern": "flames", "base": Color(0.02, 0.02, 0.025), "a": Color(0.8, 0.45, 0.15), "b": Color(0.02, 0.02, 0.025), "c": Color(1, 0.8, 0.35),
			"p": Vector4(1.3, 0.8, 0.12, 2.2), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.8, 0.45, 0.15)},
		{"name": "Endurance Yellow", "pattern": "stripes", "base": Color(0.98, 0.8, 0.05), "a": Color(0.02, 0.02, 0.025), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.1, 0.05, 0.01, 1), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.1, 0.1, 0.12)},
		{"name": "Velocity Red", "pattern": "sweep", "base": Color(0.78, 0.04, 0.05), "a": Color(0.72, 0.74, 0.78), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "metallic", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.1, 0.1, 0.12)},
		{"name": "Shark", "pattern": "halftone", "base": Color(0.45, 0.47, 0.5), "a": Color(0.02, 0.02, 0.025), "b": Color(0, 0, 0), "c": Color(0.3, 0.32, 0.35),
			"p": Vector4(0.05, 0.3, 0.8, 0), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Electric", "pattern": "bolt", "base": Color(0.02, 0.02, 0.025), "a": Color(0.1, 0.55, 1), "b": Color(0.93, 0.93, 0.95), "c": Color(0, 0, 0),
			"p": Vector4(0.6, 0, 0, 0), "finish": "gloss", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.1, 0.55, 1), "hood": "carbon"},
	],
	"quicksilver": [
		{"name": "Quicksilver", "pattern": "plain", "base": Color(0.82, 0.84, 0.88), "a": Color(0.02, 0.02, 0.025), "b": Color(0.02, 0.02, 0.025), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "chrome", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Obsidian", "pattern": "twotone", "base": Color(0.03, 0.03, 0.035), "a": Color(0.02, 0.02, 0.025), "b": Color(0.85, 0.08, 0.06), "c": Color(0, 0, 0),
			"p": Vector4(0, 0, 0, 0), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Carbon Arrow", "pattern": "shards", "base": Color(0.25, 0.26, 0.28), "a": Color(0.02, 0.02, 0.025), "b": Color(0.55, 0.56, 0.6), "c": Color(0, 0, 0),
			"p": Vector4(0.18, 0.25, 1, 0.01), "finish": "metallic", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.85, 0.1, 0.05), "hood": "carbon"},
		{"name": "Ruby", "pattern": "fade", "base": Color(0.04, 0.04, 0.045), "a": Color(0.65, 0.02, 0.06), "b": Color(0.95, 0.2, 0.25), "c": Color(0.8, 0.1, 0.15),
			"p": Vector4(0.3, 0.85, 0, 0), "finish": "pearl", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Silver Streak", "pattern": "stripes", "base": Color(0.02, 0.02, 0.025), "a": Color(0.72, 0.74, 0.78), "b": Color(0.15, 0.15, 0.17), "c": Color(0, 0, 0),
			"p": Vector4(0.12, 0.05, 0.008, 0), "finish": "gloss", "rim": Color(0.78, 0.78, 0.8), "caliper": Color(0.6, 0.6, 0.62)},
	],
}

## Tuning (PLAN M18): the parts a player picks for a car of ours (the road cars and the hypercar),
## each a list of choices; 0 is the car as it comes. Spoilers and hood shapes are kit parts fitted
## to each car (tools/assets/tuning_kit.py: assets/car/<id>_kit.glb), rims a shared library scaled to
## each car's wheels (tools/assets/rims.py: assets/car/rims.glb), underglow is drawn by the game.
const TUNING := ["spoiler", "rims", "glow", "hood"]
const TUNING_NAMES := {"spoiler": "Spoiler", "rims": "Rims", "glow": "Underglow", "hood": "Hood"}
## Spoilers: 0 the car's own, 1 none, then the kit's (Spoiler2..9).
const SPOILERS := [{"name": "Stock"}, {"name": "None"}, {"name": "Lip"}, {"name": "Ducktail"}, {"name": "Low Wing"},
	{"name": "Street Wing"}, {"name": "GT Wing"}, {"name": "Swan Neck"}, {"name": "Twin Plane"}, {"name": "Drift Wing"}]
## Rims: 0 the car's own, then the library's (Rim1..9) in their own finishes (no colour: the
## livery's rim colour).
const RIMS := [
	{"name": "Stock"},
	{"name": "Five Spoke"},
	{"name": "Split Spoke", "colour": Color(0.2, 0.21, 0.23), "metallic": 0.85, "roughness": 0.32},
	{"name": "Gold Mesh", "colour": Color(0.78, 0.6, 0.24), "metallic": 1.0, "roughness": 0.25},
	{"name": "Multi-Spoke", "colour": Color(0.82, 0.83, 0.86), "metallic": 1.0, "roughness": 0.2},
	{"name": "Turbine", "colour": Color(0.03, 0.03, 0.035), "metallic": 0.5, "roughness": 0.35},
	{"name": "Chrome Star", "colour": Color(0.92, 0.92, 0.94), "metallic": 1.0, "roughness": 0.05},
	{"name": "Deep Dish", "colour": Color(0.06, 0.06, 0.07), "metallic": 0.6, "roughness": 0.3},
	{"name": "White Six", "colour": Color(0.92, 0.92, 0.93), "metallic": 0.1, "roughness": 0.3},
	{"name": "Bronze Twist", "colour": Color(0.55, 0.38, 0.18), "metallic": 0.95, "roughness": 0.3},
]
## The library rims' size (rims.py: bead radius, half width): scaled to each car's.
const RIM_REF := Vector2(0.24, 0.12)
## Underglow (TmUnderglow): 0 off; a colour, two (the front's fading to the rear's along the car), or a
## rainbow flowing along the car.
const GLOWS := [
	{"name": "Off"},
	{"name": "Neon Blue", "colour": Color(0.1, 0.4, 1.0)},
	{"name": "Cyan", "colour": Color(0.0, 0.95, 1.0)},
	{"name": "Magenta", "colour": Color(1.0, 0.1, 0.8)},
	{"name": "Toxic Green", "colour": Color(0.3, 1.0, 0.1)},
	{"name": "Red", "colour": Color(1.0, 0.06, 0.04)},
	{"name": "Purple", "colour": Color(0.55, 0.1, 1.0)},
	{"name": "Amber", "colour": Color(1.0, 0.55, 0.05)},
	{"name": "Synthwave", "colours": [Color(1.0, 0.08, 0.7), Color(0.0, 0.85, 1.0)]},
	{"name": "Rainbow", "cycle": true},
]
## Hoods: a kit shape (assets/car/<id>_kit.glb "Hood<Shape>") and a finish ("" the livery's; the
## paint shader's carbon or black hood).
const HOODS := [
	{"name": "Stock", "shape": "", "finish": ""},
	{"name": "Carbon", "shape": "", "finish": "carbon"},
	{"name": "Matte Black", "shape": "", "finish": "black"},
	{"name": "Vented", "shape": "vents", "finish": ""},
	{"name": "Ram Scoop", "shape": "scoop", "finish": ""},
	{"name": "Power Bulge", "shape": "bulge", "finish": ""},
	{"name": "Louvred", "shape": "louvres", "finish": ""},
	{"name": "Cowl Induction", "shape": "cowl", "finish": ""},
	{"name": "Carbon Vented", "shape": "vents", "finish": "carbon"},
	{"name": "Carbon Scoop", "shape": "scoop", "finish": "carbon"},
]

static var _meshes := {}
static var _manifests := {}
static var _kits := {}
static var _rims := {}


## The choices of tuning part `part` (TUNING).
static func options(part: String) -> Array:
	match part:
		"spoiler": return SPOILERS
		"rims": return RIMS
		"glow": return GLOWS
		"hood": return HOODS
	return []


## Whether a car takes tuning: ours with kits (the road cars and the hypercar).
static func tunable(id: String) -> bool:
	return id == "hyper" or is_road(id)


## A car's tuning kit (TUNING's spoilers and hood shapes fitted to it): {part name: mesh}, loaded
## once; empty when it isn't there.
static func kit(id: String) -> Dictionary:
	if not _kits.has(id):
		_kits[id] = _glb_meshes(DIR + ("hypercar" if id == "hyper" else id) + "_kit.glb")
	return _kits[id]


## The rim library: {"Rim1".."Rim9": mesh}.
static func rims() -> Dictionary:
	if _rims.is_empty():
		_rims = _glb_meshes(DIR + "rims.glb")
	return _rims


static func _glb_meshes(path: String) -> Dictionary:
	var out := {}
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene != null:
		var root := scene.instantiate()
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			out[String(mi.name)] = mi.mesh
		root.free()
	return out


static func is_road(id: String) -> bool:
	return CARS.any(func(c: Array) -> bool: return c[0] == id)


static func car_name(id: String) -> String:
	for c: Array in CARS:
		if c[0] == id:
			return String(c[1])
	return id


static func blurb(id: String) -> String:
	return String(BLURBS.get(id, ""))


static func manifest(id: String) -> Dictionary:
	if not _manifests.has(id):
		var path := DIR + ("hypercar" if id == "hyper" else id) + ".json"
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_manifests[id] = data if data is Dictionary else {}
	return _manifests[id]


## A car's meshes (Body, Spoiler (its own, if it has one), TyreF/R, RimF/R, BrakeF/R) from its glb,
## loaded once; empty when it isn't there.
static func meshes(id: String) -> Dictionary:
	if not _meshes.has(id):
		var out := {}
		var scene := load(DIR + id + ".glb") as PackedScene if ResourceLoader.exists(DIR + id + ".glb") else null
		if scene != null and not manifest(id).is_empty():
			var root := scene.instantiate()
			for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
				out[String(mi.name)] = mi.mesh
			root.free()
			if not out.has("Body"):
				out = {}
		_meshes[id] = out
	return _meshes[id]


## A car's liveries (the hypercar's too): five each; none for the open-wheeler (its colour is the
## player's).
static func liveries(id: String) -> Array:
	if id == "":
		return []
	return LIVERIES.get(id, LIVERIES["zenith"])


static func livery(id: String, i: int) -> Dictionary:
	var all := liveries(id)
	return all[clampi(i, 0, all.size() - 1)] if not all.is_empty() else {}
