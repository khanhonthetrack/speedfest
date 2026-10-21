class_name TmRoadCars
extends RefCounted
## Our own road cars (PLAN M16: the class of cars NFS Most Wanted's Blacklist drove, our own
## shapes and names, no makers' badges): tools/assets/roadcar.py builds each into
## assets/car/<id>.glb (the body, a wheel and a brake per axle) and assets/car/<id>.json (its
## wheel places, tyre sizes, and the body's lines along the car for the livery shader). Each car,
## and the hypercar, has five liveries (no sponsors): car/tm_car_surface.gdshader mode 4 draws
## them from a pattern, colours and parameters.

const DIR := "res://assets/car/"

## The garage's order: [id, name].
const CARS := [
	["zenith", "Zenith TT"],
]

## The livery patterns (tm_car_surface.gdshader `livery`), by name.
const PATTERNS := ["plain", "stripes", "flames", "tribal", "tiger", "shards", "halftone", "sweep", "checker", "camo",
	"twotone", "bolt", "fade", "claws"]

## Five liveries per car: name, pattern, base paint, vinyl colours a (main), b (outline/second),
## c (accent), p (the pattern's parameters), finish ("gloss", "metallic", "pearl", "matte",
## "chrome"), rim colour, caliper colour, hood ("" paint, "carbon", "black"), roof ("" or "black").
const LIVERIES := {
	"zenith": [
		{"name": "Afterburner", "pattern": "flames", "base": Color(0.62, 0.64, 0.68), "a": Color(0.92, 0.22, 0.04),
			"b": Color(0.05, 0.05, 0.06), "c": Color(1.0, 0.78, 0.10), "p": Vector4(1.25, 0.75, 0.12, 2.2),
			"finish": "metallic", "rim": Color(0.12, 0.12, 0.13), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Midnight Stripe", "pattern": "stripes", "base": Color(0.03, 0.035, 0.05), "a": Color(0.85, 0.86, 0.9),
			"b": Color(0.8, 0.1, 0.12), "c": Color(0.0, 0.0, 0.0), "p": Vector4(0.13, 0.045, 0.012, 1.0),
			"finish": "gloss", "rim": Color(0.8, 0.8, 0.82), "caliper": Color(0.85, 0.1, 0.05)},
		{"name": "Shatter", "pattern": "shards", "base": Color(0.95, 0.95, 0.96), "a": Color(0.45, 0.1, 0.75),
			"b": Color(0.1, 0.1, 0.12), "c": Color(0, 0, 0), "p": Vector4(0.2, 0.25, 1.0, 0.012),
			"finish": "pearl", "rim": Color(0.08, 0.08, 0.09), "caliper": Color(0.5, 0.2, 0.8), "hood": "carbon"},
		{"name": "Tiger Claw", "pattern": "tiger", "base": Color(0.95, 0.48, 0.05), "a": Color(0.03, 0.03, 0.035),
			"b": Color(0, 0, 0), "c": Color(0, 0, 0), "p": Vector4(2.6, 0.0, 0.0, 0.0),
			"finish": "metallic", "rim": Color(0.10, 0.10, 0.11), "caliper": Color(0.95, 0.75, 0.1)},
		{"name": "Ice Fade", "pattern": "halftone", "base": Color(0.92, 0.93, 0.95), "a": Color(0.05, 0.35, 0.85),
			"b": Color(0.02, 0.1, 0.3), "c": Color(0, 0, 0), "p": Vector4(0.05, 0.25, 0.75, 0.0),
			"finish": "pearl", "rim": Color(0.75, 0.76, 0.8), "caliper": Color(0.1, 0.35, 0.9)},
	],
}

static var _meshes := {}
static var _manifests := {}


static func is_road(id: String) -> bool:
	return CARS.any(func(c: Array) -> bool: return c[0] == id)


static func car_name(id: String) -> String:
	for c: Array in CARS:
		if c[0] == id:
			return String(c[1])
	return id


static func manifest(id: String) -> Dictionary:
	if not _manifests.has(id):
		var path := DIR + id + ".json"
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_manifests[id] = data if data is Dictionary else {}
	return _manifests[id]


## A car's meshes (Body, WheelF, WheelR, BrakeF, BrakeR) from its glb, loaded once; empty when
## it isn't there.
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


## A car's liveries (the hypercar's too): five each.
static func liveries(id: String) -> Array:
	return LIVERIES.get(id, [])


static func livery(id: String, i: int) -> Dictionary:
	var all := liveries(id)
	return all[clampi(i, 0, all.size() - 1)] if not all.is_empty() else {}
