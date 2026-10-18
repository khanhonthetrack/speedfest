class_name TmRoadDecals
extends RefCounted
## Marks on the road, laid out from the map's built road blocks (TmMapBuilder.road_blocks) with our
## own textures (stadium/tools/texgen/decals.py): tyre marks along the racing line through GT curves
## and corners (outside at the entry, the apex inside, outside again at the exit), rubber scuffed
## onto the inner curb at the apex, the burnout behind the start line, an oil stain on a few
## straights. Seeded by each block's place, so a map always looks the same. Visual only (Decal
## nodes projecting down onto the road), faded out with distance. HD graphics only.

const TOP := 1.345                  ## the road surface (road.gd TOP, block-local)
const HALF_ROAD := 10.46            ## the asphalt's half width
const LINE_SWING := 6.0             ## the racing line's distance from the centre at entry / apex
const FADE_BEGIN := 90.0
const STAIN_CHANCE := 0.12          ## of a straight block getting an oil stain

## kind -> [texture, size (u across, v along) in m, box height]
const KINDS := {
	"skid": ["decal_skid", Vector2(2.6, 10.0), 1.0],
	"burnout": ["decal_burnout", Vector2(3.0, 3.0), 1.0],
	"stain": ["decal_stain", Vector2(2.5, 2.5), 1.0],
	"scuff": ["decal_scuff", Vector2(1.2, 4.0), 3.0],
}

static var _tex := {}


static func place(b: TmMapBuilder) -> Node3D:
	var root := Node3D.new()
	root.name = "RoadDecals"
	if b.has_start:
		var s := b.start
		# the rear wheels sit 1.2 m behind the car's centre; the spawn is 0.87 m above the road
		var at := s.origin - s.basis.y * 0.87 + s.basis.z * 0.3
		_add(root, "burnout", Transform3D(s.basis.orthonormalized(), at), 0.85)
	for r: Dictionary in b.road_blocks:
		var shape := String(r["shape"]).trim_prefix("Road/Main/")
		var xf: Transform3D = r["xform"]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(xf.origin.round()))
		if shape.begins_with("GTCurve/"):
			var k := int(shape.substr(8, 1))
			if k >= 2 and k <= 5:
				_curve(root, xf, k, rng)
		elif shape.begins_with("Corner"):
			_curve(root, xf, 1, rng)
		elif shape.begins_with("Straight") and rng.randf() < STAIN_CHANCE:
			var p := Vector3(rng.randf_range(16.0 - HALF_ROAD + 2.0, 16.0 + HALF_ROAD - 2.0), TOP, rng.randf_range(4.0, 28.0))
			var yaw := rng.randf() * TAU
			_add(root, "stain", _on_block(xf, p, Vector3(cos(yaw), 0.0, sin(yaw))), rng.randf_range(0.45, 0.85))
	return root


## A curve's marks: 2-4 tyre-mark decals along the racing line, tangent to it, and a scuff on the
## inner curb at the apex (half the curves). The road's centre line is the quarter circle of
## radius 32k - 16 about the block corner (0, 32k), from -90 to 0 degrees (road.gd _curve).
static func _curve(root: Node3D, xf: Transform3D, k: int, rng: RandomNumberGenerator) -> void:
	var c := Vector2(0.0, 32.0 * k)
	var rc := 32.0 * k - 16.0
	var swing := minf(LINE_SWING, rc * 0.4)
	var line := func(t: float) -> Vector3:
		var a := deg_to_rad(-90.0 + 90.0 * t)
		var r := rc + swing * cos(TAU * t)
		return Vector3(c.x + cos(a) * r, TOP, c.y + sin(a) * r)
	for i in rng.randi_range(2, 4):
		var t := rng.randf_range(0.12, 0.88)
		var p: Vector3 = line.call(t)
		var tangent: Vector3 = (line.call(t + 0.01) as Vector3) - (line.call(t - 0.01) as Vector3)
		_add(root, "skid", _on_block(xf, p, tangent), rng.randf_range(0.7, 1.0))
	if rng.randf() < 0.5:
		var a := deg_to_rad(-45.0 + rng.randf_range(-8.0, 8.0))
		var r := rc - (16.0 - 2.2)          # the inner curb's top, 2.2 m from the block's side
		var p := Vector3(c.x + cos(a) * r, TOP + 0.9, c.y + sin(a) * r)
		_add(root, "scuff", _on_block(xf, p, Vector3(-sin(a), 0.0, cos(a))), rng.randf_range(0.5, 0.8))


## A decal's transform on a block: centred at block-local p (TMNF), its length along `along`
## (TMNF direction), projecting down the block's up axis.
static func _on_block(xf: Transform3D, p: Vector3, along: Vector3) -> Transform3D:
	var up := xf.basis.y.normalized()
	var fwd := (xf.basis * TmGeo.g(along)).normalized()
	fwd = (fwd - up * fwd.dot(up)).normalized()
	return Transform3D(Basis(up.cross(fwd).normalized(), up, fwd), xf * TmGeo.g(p))


static func _add(root: Node3D, kind: String, at: Transform3D, strength: float) -> void:
	var spec: Array = KINDS[kind]
	var d := Decal.new()
	d.texture_albedo = _texture(String(spec[0]))
	var size: Vector2 = spec[1]
	d.size = Vector3(size.x, float(spec[2]), size.y)
	d.modulate = Color(1, 1, 1, strength)
	d.normal_fade = 0.5
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.distance_fade_enabled = true
	d.distance_fade_begin = FADE_BEGIN
	d.distance_fade_length = 30.0
	d.transform = at
	root.add_child(d)


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = TmMaterials._tex(name, "albedo")
	return _tex[name]
