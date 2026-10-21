class_name TmTyreMarks
extends Node3D
## Tyre marks, as TMNF lays them: while a wheel slides on the ground (a drift, or the wheels locked
## by hard braking: TmCarModel.sliding) it leaves a mark one tyre wide behind it, rubber on the road
## and the decks, grooves in dirt, torn turf on grass, and smoke or dust puffs off it. The marks
## stay; once CAPACITY of a kind are down the oldest fade out and are reused. Each segment is a
## MultiMesh quad (race/tm_tyre_marks.gdshader); textures by stadium/tools/texgen/marks.py.
##
## Fed by a car's TmBody (wheel contacts, normals, surfaces) and model (sliding wheels) every
## physics tick; a replay feeds the same fields from its samples.

const T := preload("res://core/tm_tuning.gd")
const SEG := 0.4                 ## metres between a mark's points
const WIDTH := 0.3               ## a mark's width (the tyre's contact patch)
const LIFT := 0.025              ## above the surface (no z-fighting)
const MIN_SPEED := 3.0           ## m/s the wheel must slide over the ground to mark it
const JUMP := 3.0                ## a wheel moving further in a tick was respawned: the mark ends
## kind: [texture, segments kept, roughness, smoke colour (its alpha: one puff's; they overlap)]
const KINDS := {
	"rubber": ["mark_asphalt", 3000, 0.65, Color(0.9, 0.9, 0.92, 0.5)],
	"dirt": ["mark_dirt", 1500, 0.95, Color(0.5, 0.43, 0.33, 0.42)],
	"grass": ["mark_grass", 1500, 0.95, Color(0.33, 0.38, 0.24, 0.26)],
}
const PUFF_RISE := 0.2           ## puffs start this far over the wheel's contact (m)

var car: TmCar
var smoke := true                ## puffs off sliding wheels

var _mm := {}                    ## kind -> MultiMesh
var _mat := {}                   ## kind -> ShaderMaterial
var _laid := {}                  ## kind -> segments laid so far (the next one's serial)
var _last: Array = [{}, {}, {}, {}]      ## per wheel: {p, m (metres along), kind} of the open mark
var _puffs: Array[CPUParticles3D] = []
var _puff_at: Array = [null, null, null, null]   ## per wheel: its contact at the last tick (Vector3), or null
var recent: Array = []           ## the last segments laid: [wheel, kind, metres at start, at end]


## The kind of mark a surface takes ("" for none: ice, water).
static func kind_of(surface: int) -> String:
	match surface:
		T.Surface.DIRT, T.Surface.DIRT_ROAD, T.Surface.WET_DIRT_ROAD, T.Surface.SAND:
			return "dirt"
		T.Surface.GRASS, T.Surface.WET_GRASS, T.Surface.SNOW:
			return "grass"
		T.Surface.ICE, T.Surface.WATER:
			return ""
	return "rubber"


func _ready() -> void:
	var quad := _quad()
	for kind: String in KINDS:
		var spec: Array = KINDS[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = int(spec[1])
		mm.visible_instance_count = 0
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://race/tm_tyre_marks.gdshader")
		mat.set_shader_parameter("mark_tex", load("res://assets/tex/%s_albedo.png" % spec[0]))
		mat.set_shader_parameter("roughness", float(spec[2]))
		mat.set_shader_parameter("capacity", float(spec[1]))
		var mi := MultiMeshInstance3D.new()
		mi.name = "Marks_" + kind
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-4096, -512, -4096), Vector3(8192, 2048, 8192))   # never culled
		add_child(mi)
		_mm[kind] = mm
		_mat[kind] = mat
		_laid[kind] = 0
	if smoke:
		for i in 4:
			_puffs.append(_puff())


## A unit quad in the x-z plane: x across the mark (u 0..1), z along it (v 0 at -z, the start).
static func _quad() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[Vector3(-0.5, 0, -0.5), Vector2(0, 0)], [Vector3(0.5, 0, -0.5), Vector2(1, 0)],
		[Vector3(0.5, 0, 0.5), Vector2(1, 1)], [Vector3(-0.5, 0, 0.5), Vector2(0, 1)]]
	for k: int in [0, 2, 1, 0, 3, 2]:
		st.set_normal(Vector3.UP)
		st.set_uv(corners[k][1])
		st.add_vertex(corners[k][0])
	return st.commit()


## A wheel's smoke: soft puffs, many and overlapping so they blend into one plume (few small ones
## read as a trail of dots), each fading in as it leaves the tyre, growing, turning slowly and
## fading out. Each tick's puffs are spread along the stretch the wheel just covered (the
## emission box, _smoke), so the plume stays whole at any speed.
func _puff() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 110
	p.lifetime = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.12, 0.05, 0.1)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.25, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -25.0
	p.angular_velocity_max = 25.0
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.3
	var grow := Curve.new()
	grow.max_value = 3.0                # (a Curve's range is 0..1 unless widened first)
	grow.add_point(Vector2(0.0, 0.55))
	grow.add_point(Vector2(1.0, 3.0))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.4, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	p.mesh = quad
	# its own shader: the colour is the surface's tint and the particle only fades it (with a
	# vertex-coloured StandardMaterial3D the newest puffs drew black)
	var m := ShaderMaterial.new()
	m.shader = preload("res://race/tm_tyre_smoke.gdshader")
	m.set_shader_parameter("puff_tex", load("res://assets/tex/smoke_puff_albedo.png"))
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# sorted back to front: in index order the newest puffs drew black (seen in Forward+)
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	add_child(p)
	return p


## All marks gone (a restart).
func clear() -> void:
	for kind: String in _mm:
		(_mm[kind] as MultiMesh).visible_instance_count = 0
		_laid[kind] = 0
	for i in 4:
		_last[i] = {}
	recent.clear()


func _physics_process(_delta: float) -> void:
	if car == null:
		return
	var b := car.body
	var m := car.model
	for i in 4:
		var kind := ""
		var p: Vector3 = b.wheel_hit_pos[i]
		var n: Vector3 = b.wheel_hit_n[i]
		var slide := Vector3.ZERO
		if b.wheel_contact[i] and m.sliding[i]:
			kind = kind_of(b.wheel_surface[i])
			slide = b.lin_vel + b.ang_vel.cross(p - b.xform.origin)
			slide -= n * slide.dot(n)
		if kind.is_empty() or slide.length() < MIN_SPEED:
			_last[i] = {}
			_smoke(i, "", p, n)
			continue
		_smoke(i, kind, p, n)
		var last: Dictionary = _last[i]
		if last.is_empty() or String(last["kind"]) != kind or (last["p"] as Vector3).distance_to(p) > JUMP:
			_last[i] = {"p": p, "m": randf() * 4.0, "kind": kind}
			continue
		var from: Vector3 = last["p"]
		var d := from.distance_to(p)
		if d < SEG:
			continue
		var at: float = last["m"]
		lay(kind, from, p, n, at, at + d, clampf(slide.length() / 8.0, 0.6, 1.0))
		last["p"] = p
		last["m"] = at + d
		recent.append([i, kind, at, at + d])
		if recent.size() > 32:
			recent.pop_front()


## One segment of a mark from a to b on a surface with normal n; m0, m1 the metres along the mark
## at its ends; strength 0..1.
func lay(kind: String, a: Vector3, b: Vector3, n: Vector3, m0: float, m1: float, strength: float) -> void:
	var mm: MultiMesh = _mm[kind]
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return
	var dir := along / length
	var across := n.cross(dir).normalized()
	if across.length_squared() < 0.5:
		return
	var up := dir.cross(across)
	# a little longer than the step so the segments overlap at their joins
	var xf := Transform3D(Basis(across * WIDTH, up, dir * length * 1.06), (a + b) * 0.5 + up * LIFT)
	var serial: int = _laid[kind]
	var slot := serial % mm.instance_count
	mm.set_instance_transform(slot, xf)
	mm.set_instance_custom_data(slot, Color(m0, m1, strength, float(serial)))
	_laid[kind] = serial + 1
	mm.visible_instance_count = mini(serial + 1, mm.instance_count)
	(_mat[kind] as ShaderMaterial).set_shader_parameter("newest", float(serial))


## Marks laid so far of a kind (tests).
func laid(kind: String) -> int:
	return int(_laid.get(kind, 0))


func _smoke(i: int, kind: String, p: Vector3, n: Vector3) -> void:
	if i >= _puffs.size():
		return
	var pf := _puffs[i]
	var on := not kind.is_empty()
	var last: Variant = _puff_at[i]
	_puff_at[i] = p if on else null
	if on:
		# the emission box along the last two ticks of the wheel's travel (a frame can span two)
		var d: Vector3 = (p - (last as Vector3)) if last != null else Vector3.ZERO
		d -= n * d.dot(n)
		var step := d.length()
		if step > JUMP or step < 0.01:
			d = Vector3.ZERO
			step = 0.0
		var along := d / step if step > 0.0 else n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.FORWARD).normalized()
		var side := n.cross(along).normalized()
		pf.global_transform = Transform3D(Basis(side, n, n.cross(side)), p - d + n * PUFF_RISE)
		pf.emission_box_extents = Vector3(0.12, 0.05, maxf(0.1, step))
		(pf.material_override as ShaderMaterial).set_shader_parameter("tint", KINDS[kind][3])
	if pf.emitting != on:
		pf.emitting = on
