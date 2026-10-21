class_name TmCityAssets
extends RefCounted
## Dresses city models made in Blender (the owner's Blend Swap buildings, converted by
## tools/assets/blend_to_glb.py; their Cycles materials don't survive glTF) in our materials, each
## surface by its original material's name: glass of any kind is our curtain wall (TmTower's
## shader, windows mapped from the world position, rooms behind them, lit at night), steel is
## brushed steel, concrete our concrete, black glossy dark glass, white or painted cladding a
## painted panel, lights lit panels, leaves and trunks a tree's. Unknown names: light cladding.
## The buildings: res://assets/city/<set>_NN.glb with a manifest per set (<set>.json: sizes,
## triangles, licence; CREDITS.md); pick() finds one that fits a lot, building() places it dressed.

const DIR := "res://assets/city"
const MIN_SCALE := 0.8              ## a building is scaled to the height asked within these
const MAX_SCALE := 1.6

## Keyword (lower case, in the material's name) -> our kind; the first that matches wins.
const RULES := [
	[["glass", "vetro", "specchio", "window", "glaz", "mirror", "reflect"], "glass"],
	[["luce", "glow", "emiss", "bulb", "lamphead_lamp", "lampplane", "lens", "light"], "lit"],
	[["acciaio", "steel", "chrome", "metal", "alumin", "metl"], "steel"],
	[["cemento", "concrete", "cement", "pav"], "concrete"],
	[["black", "dark", "nero"], "dark"],
	[["leaf", "leaves", "foglie"], "leaves"],
	[["trunk", "tronco", "bark"], "trunk"],
	[["white", "bianco", "matte", "paint", "intonaco"], "white"],
]

static var _cache := {}
static var _catalogue: Array = []
static var _scenes := {}


## Every building of the manifests: [{name, size (Vector3: x, height, z; m), triangles, licence}].
static func catalogue() -> Array:
	if _catalogue.is_empty():
		for f: String in DirAccess.get_files_at(DIR):
			if not f.ends_with(".json"):
				continue
			var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(f)))
			if not m is Dictionary:
				continue
			for b: Dictionary in (m as Dictionary).get("buildings", []):
				var sz: Array = b["size"]
				if ResourceLoader.exists(DIR.path_join(String(b["name"]) + ".glb")):
					_catalogue.append({"name": String(b["name"]), "size": Vector3(sz[0], sz[1], sz[2]),
						"triangles": int(b.get("triangles", 0)), "licence": String(m.get("licence", ""))})
		_catalogue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"] < b["name"])
	return _catalogue


## A building for a lot `room` (m, x and z) about `height` tall: {name, scale, size (scaled), turn
## (quarter turns so it fits)}, or {} when none fits.
static func pick(rng: RandomNumberGenerator, room: Vector2, height: float) -> Dictionary:
	var fits := []
	for b: Dictionary in catalogue():
		var sz: Vector3 = b["size"]
		var k := clampf(height / sz.y, MIN_SCALE, MAX_SCALE)
		if absf(sz.y * k - height) > height * 0.3:
			continue
		var turn := 0
		if sz.x * k > room.x or sz.z * k > room.y:
			if sz.z * k > room.x or sz.x * k > room.y:
				continue
			turn = 1
		fits.append({"name": b["name"], "scale": k, "turn": turn,
			"size": Vector3(sz.z, sz.y, sz.x) * k if turn == 1 else sz * k})
	if fits.is_empty():
		return {}
	var f: Dictionary = fits[rng.randi() % fits.size()]
	if f["turn"] == 0 and rng.randf() < 0.5:
		f["turn"] = 2                        # the other way round (it still fits)
	elif f["turn"] == 1 and rng.randf() < 0.5:
		f["turn"] = 3
	return f


## A picked building (pick()) as a node, dressed: its foot at the origin, turned and scaled.
static func building(choice: Dictionary, glass := "blue", seed := 1, shadows := true) -> Node3D:
	var name := String(choice["name"])
	if not _scenes.has(name):
		_scenes[name] = load(DIR.path_join(name + ".glb"))
	var n := (_scenes[name] as PackedScene).instantiate() as Node3D
	n.scale = Vector3.ONE * float(choice.get("scale", 1.0))
	n.rotation.y = int(choice.get("turn", 0)) * PI * 0.5
	dress(n, glass, seed)
	if not shadows:
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Our kind for a material name ("cladding" when nothing matches).
static func kind_of(material_name: String) -> String:
	var n := material_name.to_lower()
	for r: Array in RULES:
		for k: String in r[0]:
			if n.contains(k):
				return String(r[1])
	return "cladding"


## Replaces every surface's material under `root` with ours (glass: the palette, rooms by seed).
## keep_textured: surfaces whose own material has a texture keep it (props' baked faces).
static func dress(root: Node, glass := "blue", seed := 1, floor_h := 3.8, keep_textured := false) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if keep_textured and src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				continue
			var kind := kind_of(src.resource_name if src != null else "")
			if keep_textured and kind in ["cladding", "white", "concrete"]:
				kind = "paint"                  # a prop's painted steel
			mi.set_surface_override_material(s, material(kind, glass, seed, floor_h))


static func material(kind: String, glass := "blue", seed := 1, floor_h := 3.8) -> Material:
	var key := "%s:%s:%d:%.1f:%s" % [kind, glass, seed, floor_h, TmStadiumEnv.night]
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match kind:
		"glass":
			var g := TmTower.material(glass, seed, floor_h, 3.0)
			g.set_shader_parameter("world_map", 1.0)
			m = g
		"concrete":
			m = TmMaterials.get_material("concrete")
		_:
			var s := StandardMaterial3D.new()
			match kind:
				"steel":
					s.albedo_color = Color(0.62, 0.64, 0.66)
					s.metallic = 1.0
					s.roughness = 0.32
				"dark":
					s.albedo_color = Color(0.04, 0.045, 0.05)
					s.metallic = 0.7
					s.roughness = 0.12
				"lit":
					s.albedo_color = Color(0.9, 0.9, 0.88)
					s.emission_enabled = true
					s.emission = Color(1.0, 0.92, 0.78)
					s.emission_energy_multiplier = 1.5 if TmStadiumEnv.night else 0.3
				"leaves":
					s.albedo_color = Color(0.20, 0.32, 0.12)
					s.roughness = 0.8
				"trunk":
					s.albedo_color = Color(0.25, 0.19, 0.14)
					s.roughness = 0.9
				"white":
					s.albedo_color = Color(0.82, 0.82, 0.80)
					s.roughness = 0.55
				"paint":
					s.albedo_color = Color(0.20, 0.21, 0.22)
					s.metallic = 0.6
					s.roughness = 0.45
				_:
					s.albedo_color = Color(0.66, 0.66, 0.64)
					s.roughness = 0.7
			m = s
	_cache[key] = m
	return m
