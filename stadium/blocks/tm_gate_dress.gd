class_name TmGateDress
extends RefCounted
## What tells a start, a finish and a checkpoint apart (the arch itself is TMNF's measured one,
## blocks/shapes/road.gd _gate): the arch's inner face glows in the gate's colour (green start, red
## finish, cyan checkpoint, amber lap line; materials "gate_glow_<kind>"), a lit banner on the arch
## says START / FINISH / CHECKPOINT to both sides (the finish's with chequered bands), and the
## road is marked: a white line under the start, a chequered band under the finish. All visual
## (no collision). Built in TMNF block-local coordinates like the block, then sheared with it
## (sloped and banked checkpoints).

const KINDS := {
	"start": [Color(0.30, 1.00, 0.45), "START"],
	"finish": [Color(1.00, 0.22, 0.18), "FINISH"],
	"cp": [Color(0.25, 0.82, 1.00), "CHECKPOINT"],
	"lap": [Color(1.00, 0.72, 0.15), "LAP"],
}
const ROAD_X := [5.54, 26.46]          ## the asphalt across (road.gd ROAD_EDGE)
const BANNER := [10.3, 21.7, 9.15, 11.75]   ## x0, x1, y0, y1 (over the arch's crown at 8.8)
const BANNER_T := 0.5

static var _checker: StandardMaterial3D
static var _line: StandardMaterial3D


## The gate's kind for a road shape name ("" if it has no gate).
static func kind_of(rest: String) -> String:
	if rest.begins_with("Start/"):
		return "start"
	if rest.begins_with("Finish/"):
		return "finish"
	if rest.begins_with("MultiLap/"):
		return "lap"
	return "cp"


## Adds the dressing of a gate at zc (road top `top`) under `root`, sheared like the block
## (TmGeo.sheared: kx, kz, dy in TMNF coordinates).
static func dress(root: Node3D, kind: String, zc: float, top: float, shear := Vector3.ZERO) -> void:
	var spec: Array = KINDS.get(kind, KINDS["cp"])
	var colour: Color = spec[0]
	var holder := Node3D.new()
	holder.name = "GateDress"
	# Godot block-local (x = -TMNF x): y += -kx * x + kz * z + dy
	holder.transform = Transform3D(Basis(Vector3(1, -shear.x, 0), Vector3(0, 1, 0), Vector3(0, shear.y, 1)),
		Vector3(0, shear.z, 0))
	root.add_child(holder)
	# the banner: a dark panel on two posts over the arch's crown, lit edges in the gate's colour
	var geo := TmGeo.new()
	var b: Array = BANNER
	var x0: float = b[0]
	var x1: float = b[1]
	var y0: float = b[2]
	var y1: float = b[3]
	geo.box(Vector3(x0, y0, zc - BANNER_T * 0.5), Vector3(x1, y1, zc + BANNER_T * 0.5), "banner", TmGeo.NO_COLLISION)
	for edge: float in [y0, y1 - 0.16]:
		geo.box(Vector3(x0 - 0.05, edge, zc - BANNER_T * 0.5 - 0.05), Vector3(x1 + 0.05, edge + 0.16, zc + BANNER_T * 0.5 + 0.05),
			"gate_glow_" + kind, TmGeo.NO_COLLISION)
	for px: float in [x0 + 1.4, x1 - 1.6]:
		geo.box(Vector3(px, 7.9, zc - 0.12), Vector3(px + 0.2, y0, zc + 0.12), "gate", TmGeo.NO_COLLISION)
	holder.add_child(geo.build())
	var words := String(spec[1])
	for side: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = words
		l.font = TmUi.font(TmUi.TITLE)
		l.font_size = 150 if words.length() <= 6 else 96
		l.pixel_size = 0.01
		l.modulate = colour.lightened(0.25)
		l.outline_size = 10
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.shaded = false
		l.double_sided = false
		l.position = TmGeo.g(Vector3(16.0, (y0 + y1) * 0.5, zc + side * (BANNER_T * 0.5 + 0.02)))
		l.rotation.y = 0.0 if side > 0.0 else PI
		holder.add_child(l)
		if kind in ["finish", "lap"]:
			# chequered bands either side of the word
			for bx: Array in [[x0 + 0.3, x0 + 2.5], [x1 - 2.5, x1 - 0.3]]:
				var q := MeshInstance3D.new()
				var qm := QuadMesh.new()
				qm.size = Vector2(float(bx[1]) - float(bx[0]), (y1 - y0) - 0.5)
				q.mesh = qm
				var m := checker().duplicate() as StandardMaterial3D
				m.uv1_scale = Vector3(qm.size.x, qm.size.y, 1.0)   # 0.5 m squares
				m.cull_mode = BaseMaterial3D.CULL_BACK
				q.material_override = m
				q.position = TmGeo.g(Vector3((float(bx[0]) + float(bx[1])) * 0.5, (y0 + y1) * 0.5, zc + side * (BANNER_T * 0.5 + 0.015)))
				q.rotation.y = 0.0 if side > 0.0 else PI
				holder.add_child(q)
	# the road marking
	if kind == "start":
		holder.add_child(_road_band(zc, 1.0, top, line()))
	elif kind in ["finish", "lap"]:
		var band := _road_band(zc, 3.0, top, checker())
		var m := checker().duplicate() as StandardMaterial3D
		m.uv1_scale = Vector3((ROAD_X[1] - ROAD_X[0]) / 3.0, 1.0, 1.0)
		band.material_override = m
		holder.add_child(band)


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
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
		img.set_pixel(0, 0, Color(0.95, 0.95, 0.95))
		img.set_pixel(1, 1, Color(0.95, 0.95, 0.95))
		img.set_pixel(1, 0, Color(0.04, 0.04, 0.05))
		img.set_pixel(0, 1, Color(0.04, 0.04, 0.05))
		_checker = StandardMaterial3D.new()
		_checker.albedo_texture = ImageTexture.create_from_image(img)
		_checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_checker.roughness = 0.75
	return _checker


## The start line's white paint.
static func line() -> StandardMaterial3D:
	if _line == null:
		_line = StandardMaterial3D.new()
		_line.albedo_color = Color(0.95, 0.95, 0.94)
		_line.roughness = 0.7
	return _line
