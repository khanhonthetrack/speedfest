class_name TmCar
extends Node3D
## The Stadium car as a TMNF-style rigid body, stepped at 100 Hz by our own integrator (no RigidBody3D).
## Behaviour from docs/research/tmnf_physics.md §2-3 and the contact rules of §3.9:
## - each 10 ms tick is split into n = round(dt * (|v| + |w|) / 0.3) + 1 sub-steps (max 1000);
## - every sub-step: suspension -> TmCarModel forces -> integrate -> collide -> absorb contacts;
## - wheels and chassis are ellipsoids queried against the world (Jolt) with collide_shape;
## - a wheel's penetration along the car's up axis goes into its suspension (up to its length);
##   the rest, and every chassis penetration, is pushed out of the surface;
## - contact impulses keep a share of the approach speed: wheel on the ground 0.8, wheel side or
##   chassis 0.5; the chassis impulse runs along the approach clipped to a friction cone (mu 0.3).
##
## The node's basis IS the car frame: +X left, +Y up, +Z forward (the car faces the node's +Z).
## The node's origin is the centre of mass. Mass 1.

signal wheel_hit_wall

const T := preload("res://core/tm_tuning.gd")
const DT := 0.01
const GRAVITY := Vector3(0.0, -T.GRAVITY, 0.0)
const WORLD_MASK := 1
const IGNORED_SURFACES := [13, 23]   ## water and the like: the chassis ignores them

## Inputs (set by a controller every tick). steer: -1..1, + = left.
var gas := 0.0
var brake := 0.0
var steer := 0.0
var controls_enabled := true

var model := TmCarModel.new()
var lin_vel := Vector3.ZERO           ## world
var ang_vel := Vector3.ZERO           ## world
var now_ms := 0
var tick_count := 0
var substeps := 1                     ## sub-steps used by the last tick
var body_contact := false             ## the chassis touched something during the last tick
var wheel_contact: Array[bool] = [false, false, false, false]

var _wheels: Array = []               ## TmCarModel.WheelInput, from the last collision pass
var _absorb := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _wheel_shape: ConvexPolygonShape3D
var _body_shapes: Array[ConvexPolygonShape3D] = []
var _body_xforms: Array[Transform3D] = []
var _query := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _inv_inertia := Vector3.ONE / T.INERTIA
var _body_hit := false


func _ready() -> void:
	for i in 4:
		var wi := TmCarModel.WheelInput.new()
		wi.pos = T.WHEELS[i]
		_wheels.append(wi)
	_wheel_shape = make_ellipsoid(Vector3(T.WHEEL_HALF_WIDTH, T.WHEEL_RADIUS, T.WHEEL_RADIUS))
	for e in T.BODY_ELLIPSOIDS:
		_body_shapes.append(make_ellipsoid(e[1]))
		_body_xforms.append(Transform3D(Basis(Vector3(1, 0, 0), -float(e[2])), e[0]))
	_query.collision_mask = WORLD_MASK
	_ray.collision_mask = WORLD_MASK
	_ray.hit_back_faces = false


## Convex point cloud of an ellipsoid with the given half-axes.
static func make_ellipsoid(half: Vector3, rings: int = 8, segments: int = 16) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for i in rings + 1:
		var lat := -PI * 0.5 + PI * i / float(rings)
		for j in segments:
			if (i == 0 or i == rings) and j > 0:
				break
			var lon := TAU * j / float(segments)
			pts.append(Vector3(half.x * cos(lat) * cos(lon), half.y * sin(lat), half.z * cos(lat) * sin(lon)))
	var s := ConvexPolygonShape3D.new()
	s.points = pts
	return s


## Put the car at rest on the ground at `xf` (origin = where the wheels touch the ground).
func place(xf: Transform3D) -> void:
	transform = Transform3D(xf.basis.orthonormalized(), xf.origin + xf.basis.y.normalized() * 0.45)
	lin_vel = Vector3.ZERO
	ang_vel = Vector3.ZERO
	model.reset()
	for i in 4:
		_absorb[i] = 0.0
		(_wheels[i] as TmCarModel.WheelInput).contact = false
		(_wheels[i] as TmCarModel.WheelInput).side_contact = false
	reset_physics_interpolation()


func speed_kmh() -> float:
	return lin_vel.dot(global_transform.basis.z) * 3.6


func local_velocity() -> Vector3:
	return transform.basis.transposed() * lin_vel


func _physics_process(_delta: float) -> void:
	step_tick()


func step_tick() -> void:
	var n := clampi(roundi(DT * (lin_vel.length() + ang_vel.length()) / T.SUBSTEP_DIST) + 1, 1, 1000)
	substeps = n
	body_contact = false
	var h := DT / float(n)
	for s in n:
		_substep(h)
	now_ms += 10
	tick_count += 1


func _substep(h: float) -> void:
	var b := transform.basis
	var inv := b.transposed()
	# 1) suspension: lengths take the penetration absorbed by the last collision pass
	for i in 4:
		model.integrate_suspension(i, _absorb[i], h)
		_absorb[i] = 0.0
	# 2) forces, from the contacts of the last pass
	var v_loc := inv * lin_vel
	var w_loc := inv * ang_vel
	var up_loc := inv * Vector3.UP
	var g := gas if controls_enabled else 0.0
	var br := brake if controls_enabled else 0.0
	var st := steer if controls_enabled else 0.0
	model.tick(h, now_ms, g, br, st, v_loc, w_loc, up_loc, _wheels, _body_hit)
	# 3) integrate (semi-implicit Euler); the air control may set the angular speed first
	if model.air_set_w:
		w_loc = model.air_w
	var f_loc := model.force
	var t_loc := model.torque
	for i in 4:
		var wf: Vector3 = model.wheel_force[i]
		if wf == Vector3.ZERO:
			continue
		f_loc += wf
		t_loc += _wheel_center_local(i).cross(wf)
	var acc := b * f_loc + GRAVITY * model.gravity_coef
	lin_vel += acc * h
	if model.linear_damp > 0.0:
		lin_vel *= maxf(0.0, 1.0 - model.linear_damp * h)
	w_loc += t_loc * _inv_inertia * h
	ang_vel = b * w_loc
	var pos := transform.origin + lin_vel * h
	var wl := ang_vel.length()
	if wl > 1e-9:
		b = Basis(ang_vel / wl, wl * h) * b
	b = b.orthonormalized()
	transform = Transform3D(b, pos)
	# 4) collide and absorb
	_collide()


## Wheel centre in the car frame at its current suspension length.
func _wheel_center_local(i: int) -> Vector3:
	return T.WHEELS[i] + Vector3(0.0, T.SUSP_STATIC - model.susp_len[i], 0.0)


## Contacts of a convex shape at xf against the world: [[normal (world, out of the surface), depth,
## point on the surface], ...], one per surface direction.
func _contacts(shape: Shape3D, xf: Transform3D) -> Array:
	_query.shape = shape
	_query.transform = xf
	var res := get_world_3d().direct_space_state.collide_shape(_query, 16)
	var out: Array = []
	for k in range(0, res.size() - 1, 2):
		var a: Vector3 = res[k]
		var p: Vector3 = res[k + 1]
		var d := p - a
		var depth := d.length()
		if depth < 1e-6:
			continue
		var n := d / depth
		var merged := false
		for c in out:
			if (c[0] as Vector3).dot(n) > 0.95:
				if depth > c[1]:
					c[0] = n
					c[1] = depth
					c[2] = p
				merged = true
				break
		if not merged:
			out.append([n, depth, p])
	return out


## Surface id and turbo pad direction of what lies under a contact point.
func _surface_at(p: Vector3, n: Vector3) -> Array:
	_ray.from = p + n * 0.05
	_ray.to = p - n * 0.05
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	var surf := T.Surface.ASPHALT
	var pad := Vector3.ZERO
	if not hit.is_empty():
		var col: Object = hit.collider
		if col != null:
			if col.has_meta("surfaces"):
				var faces: PackedInt32Array = col.get_meta("surfaces")
				var fi: int = hit.get("face_index", -1)
				if fi >= 0 and fi < faces.size():
					surf = faces[fi]
				elif col.has_meta("surface"):
					surf = col.get_meta("surface")
			elif col.has_meta("surface"):
				surf = col.get_meta("surface")
			if col.has_meta("pad_dir"):
				pad = col.get_meta("pad_dir")
			elif col is Node3D:
				pad = (col as Node3D).global_transform.basis.z.normalized()
	return [surf, pad]


func _apply_impulse(j: Vector3, at: Vector3) -> void:
	lin_vel += j / T.MASS
	var r := at - transform.origin
	var inv := transform.basis.transposed()
	var dw_loc := (inv * r.cross(j)) * _inv_inertia
	ang_vel += transform.basis * dw_loc


## Velocity change per unit impulse along dir at r (world), for ComputeImpulse.
func _inv_mass_along(dir: Vector3, r: Vector3) -> float:
	var inv := transform.basis.transposed()
	var rxn := inv * r.cross(dir)
	var iw := transform.basis * (rxn * _inv_inertia)
	return 1.0 / T.MASS + dir.dot(iw.cross(r))


## SDynaMath::ComputeImpulse: the impulse along dir that leaves `keep` of the velocity along dir.
func _impulse(keep: float, vel: Vector3, dir: Vector3, r: Vector3) -> Vector3:
	var k := _inv_mass_along(dir, r)
	if absf(k) < 1e-5:
		return Vector3.ZERO
	return dir * ((keep - 1.0) * vel.dot(dir) / k)


func _point_velocity(p: Vector3) -> Vector3:
	return lin_vel + ang_vel.cross(p - transform.origin)


func _collide() -> void:
	var b := transform.basis
	var inv := b.transposed()
	var pushes: Array = []   # world penetration vectors left after the suspensions
	# wheels
	for i in 4:
		var wi: TmCarModel.WheelInput = _wheels[i]
		wi.contact = false
		wi.side_contact = false
		var c_loc := _wheel_center_local(i)
		var c_world := transform * c_loc
		var contacts := _contacts(_wheel_shape, Transform3D(b, c_world))
		var n_sum := Vector3.ZERO
		var deepest := 0.0
		for c in contacts:
			var n: Vector3 = c[0]
			var depth: float = c[1]
			var p: Vector3 = c[2]
			var n_loc := inv * n
			var pen_loc := n_loc * depth
			var r := p - transform.origin
			var vrel := _point_velocity(p)
			if absf(n_loc.x) >= T.SIDE_CONTACT_SIN:
				# the wheel's side against a wall
				wi.side_contact = true
				wheel_hit_wall.emit()
				if vrel.dot(n) < 0.0:
					_apply_impulse(_impulse(T.WHEEL_SIDE_KEEP, vrel, n, r), p)
				pushes.append(b * pen_loc)
				continue
			wi.contact = true
			n_sum += n_loc
			if depth > deepest:
				deepest = depth
				var sp := _surface_at(p, n)
				wi.surface = sp[0]
				wi.pad_dir = inv * (sp[1] as Vector3)
			# the suspension absorbs the penetration along the car's up axis, up to its length
			var bottomed := true
			if pen_loc.y > 0.0:
				var room: float = model.susp_len[i] - T.DAMPER_ABSORB_FULL
				var take := pen_loc.y
				bottomed = room <= take
				if bottomed:
					take = maxf(room, 0.0)
				_absorb[i] = maxf(_absorb[i], take)
				pen_loc.y -= take
			var vn := vrel.dot(n)
			if vn < 0.0:
				var vn_up := (inv * (n * vn)).y
				if bottomed or vn_up >= 0.0:
					_apply_impulse(_impulse(T.WHEEL_GROUND_KEEP, vrel, n, r), p)
				else:
					# the spring takes the vertical approach; the rest is stopped at the wheel centre
					var v2 := vrel - b.y * vn_up
					if v2.dot(n) < 0.0:
						_apply_impulse(_impulse(T.WHEEL_GROUND_KEEP, v2, n, c_world - transform.origin), c_world)
			if pen_loc.length_squared() > 1e-10:
				pushes.append(b * pen_loc)
		if wi.contact:
			wi.normal = n_sum.normalized()
		wheel_contact[i] = wi.contact
	# chassis
	_body_hit = false
	for k in _body_shapes.size():
		var xf := transform * _body_xforms[k]
		for c in _contacts(_body_shapes[k], xf):
			var n: Vector3 = c[0]
			var depth: float = c[1]
			var p: Vector3 = c[2]
			var n_loc := inv * n
			var sp := _surface_at(p, n)
			if IGNORED_SURFACES.has(sp[0]):
				continue
			_body_hit = true
			body_contact = true
			var push := n * depth
			if n_loc.y < -0.75:
				push = n * push.dot(n)
			pushes.append(push)
			var vrel := _point_velocity(p)
			var vn := vrel.dot(n)
			if vn >= 0.0:
				continue
			var mu := T.BODY_FRICTION_METAL if sp[0] == T.Surface.METAL else T.BODY_FRICTION
			var vt := vrel - n * vn
			var vtl := vt.length()
			if vtl > mu * absf(vn):
				vt *= mu * absf(vn) / vtl
			var d := -(vt + n * vn)
			var dl := d.length()
			if dl > 1e-5:
				d /= dl
				_apply_impulse(_impulse(T.BODY_KEEP, vrel, d, p - transform.origin), p)
	# push the car out of what it still penetrates (each direction counted once)
	var corr := Vector3.ZERO
	for pv in pushes:
		var l: float = (pv as Vector3).length()
		if l < 1e-7:
			continue
		var dir: Vector3 = pv / l
		var need := l - corr.dot(dir)
		if need > 0.0:
			corr += dir * need
	if corr != Vector3.ZERO:
		transform.origin += corr
