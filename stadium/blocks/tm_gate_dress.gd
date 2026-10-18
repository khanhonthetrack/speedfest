class_name TmGateDress
extends RefCounted
## What the road shows at a gate (the arch itself, with the gate's word on its faces and its
## underside lit in the gate's colour, and the gate block's curbs, are in blocks/shapes/road.gd
## _gate): the start and the finish paint a pad across the road (the kind's colour, a chequered
## band on the line, the word either side; our own textures, stadium/tools/texgen/gates.py), a
## checkpoint a band of its colour across the road; every gate gets an LED screen in its crown
## and a spotlight in its colour (`crown`, TmGateScreen). Visual only. Built in TMNF block-local
## coordinates like the block, then sheared with it (sloped and banked checkpoints).

const KINDS := {
	"start": [Color(0.30, 1.00, 0.45), "START"],
	"finish": [Color(1.00, 0.22, 0.18), "FINISH"],
	"cp": [Color(0.25, 0.82, 1.00), "CHECKPOINT"],
	"lap": [Color(1.00, 0.22, 0.18), "FINISH"],      # a start/finish line: where our races end
}
const ROAD_X := [5.54, 26.46]          ## the asphalt across (road.gd ROAD_EDGE)
const PAD_DEPTH := 8.0                 ## the start and finish pads (m along the road)

static var _checker: StandardMaterial3D
static var _line: StandardMaterial3D
static var _paint := {}                ## texture name -> material


## The gate's kind for a road shape name ("" if it has no gate).
static func kind_of(rest: String) -> String:
	if rest.begins_with("Start/"):
		return "start"
	if rest.begins_with("Finish/"):
		return "finish"
	if rest.begins_with("MultiLap/"):
		return "lap"
	return "cp"


## Adds the road's paint at a gate at zc (road top `top`) under `root`, sheared like the block
## (TmGeo.sheared: kx, kz, dy in TMNF coordinates).
static func dress(root: Node3D, kind: String, zc: float, top: float, shear := Vector3.ZERO) -> void:
	var holder := Node3D.new()
	holder.name = "GateDress"
	# Godot block-local (x = -TMNF x): y += -kx * x + kz * z + dy
	holder.transform = Transform3D(Basis(Vector3(1, -shear.x, 0), Vector3(0, 1, 0), Vector3(0, shear.y, 1)),
		Vector3(0, shear.z, 0))
	root.add_child(holder)
	crown(holder, kind, zc)
	if kind == "start":
		holder.add_child(_road_band(zc, PAD_DEPTH, top, _painted("pad_start", line())))
	elif kind in ["finish", "lap"]:
		holder.add_child(_road_band(zc, PAD_DEPTH, top, _painted("pad_finish", checker())))
	else:
		holder.add_child(_road_band(zc, 1.0, top, _painted("line_cp", line())))


## The gate's crown screen and spotlight (TmGateScreen) under `root` (already sheared like the
## block, or pass `shear` for a holder of its own: dirt checkpoints, which have no road paint).
static func crown(root: Node3D, kind: String, zc: float, shear := Vector3.ZERO, own_holder := false) -> void:
	var holder := root
	if own_holder:
		holder = Node3D.new()
		holder.name = "GateCrown"
		holder.transform = Transform3D(Basis(Vector3(1, -shear.x, 0), Vector3(0, 1, 0), Vector3(0, shear.y, 1)),
			Vector3(0, shear.z, 0))
		root.add_child(holder)
	var spec: Array = KINDS.get(kind, KINDS["cp"])
	TmGateScreen.add(holder, "finish" if kind == "lap" else kind, zc, spec[0])


## A painted marking (textured with HD graphics; `flat` otherwise).
static func _painted(tex: String, flat: Material) -> Material:
	if not TmMaterials.hd():
		return flat
	if not _paint.has(tex):
		var m := TmMaterials.textured(tex)
		if m == null:
			return flat
		_paint[tex] = m
	return _paint[tex]


## The arch's inner (underside) line, from one foot to the other (the "metal" points of GATE_ARCH).
static func _arch_inner() -> Array:
	var out := []
	for q: Array in load("res://blocks/shapes/road.gd").GATE_ARCH:
		if String(q[2]) == "metal" or (out.size() > 0 and String(q[2]) == "structure" and int(q[3]) == 4 and float(q[1]) < 4.0):
			out.append(Vector2(float(q[0]), float(q[1])))
	return out


## A flat band across the asphalt at z, `depth` long, just above the road.
static func _road_band(z: float, depth: float, top: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ROAD_X[1] - ROAD_X[0], depth)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = TmGeo.g(Vector3((ROAD_X[0] + ROAD_X[1]) * 0.5, top + 0.03, z))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Black and white squares (a 2 x 2 texture, repeated by uv1_scale).
static func checker() -> StandardMaterial3D:
	if _checker == null:
		# 64 x 64 (2 x 2 squares), mipmapped and filtered: a nearest 2 x 2 made moire far away
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for x in 64:
			for y in 64:
				img.set_pixel(x, y, Color(0.95, 0.95, 0.95) if (x < 32) == (y < 32) else Color(0.04, 0.04, 0.05))
		img.generate_mipmaps()
		_checker = StandardMaterial3D.new()
		_checker.albedo_texture = ImageTexture.create_from_image(img)
		_checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_checker.roughness = 0.75
	return _checker


## The start line's white paint.
static func line() -> StandardMaterial3D:
	if _line == null:
		_line = StandardMaterial3D.new()
		_line.albedo_color = Color(0.95, 0.95, 0.94)
		_line.roughness = 0.7
	return _line
