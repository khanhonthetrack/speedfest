class_name TmBody
extends RefCounted
## The Stadium car's rigid body, TMNF style: its own integrator (not a RigidBody3D) stepped one TMNF
## tick at a time, sub-stepped like TMNF, colliding by shape queries against the physics server.
## Shared by the Stadium remake (TmCar) and SpeedFest (CarTm): stadium/core is the source,
## game/cars/tm a copy (tools/sync_tm_core.sh). Behaviour: docs/research/tmnf_physics.md §2-3, §3.9.
##
## - each tick is split into n = round(dt * (|v| + |w|) / 0.3) + 1 sub-steps (max 1000);
## - every sub-step: suspension -> TmCarModel forces -> integrate -> collide -> absorb contacts;
## - wheels and chassis are convex ellipsoids queried with collide_shape (contact pairs clustered per
##   surface direction);
## - a wheel's penetration along the car's up axis goes into its suspension (up to its length); the
##   rest, and every chassis penetration, is pushed out of the surface;
## - contact impulses keep a share of the approach speed: wheel on the ground 0.8, wheel side or
##   chassis 0.5; the chassis impulse runs along the approach clipped to a friction cone (mu 0.3).
##
## Pose: `xform.basis` is the car frame (+X left, +Y up, +Z forward), `xform.origin` the centre of
## mass. Mass 1: everything is an acceleration.

const T := preload("tm_tuning.gd")
const GRAVITY := Vector3(0.0, -T.GRAVITY, 0.0)
const IGNORED_SURFACES := [13, 23]   ## water and the like: the chassis ignores them
const CHASSIS_CLEARANCE := 0.09      ## the Stadium car's lowest chassis point above the road at rest
const NORMAL_MIN_DEPTH := 0.002      ## contact pairs shallower than this take the face normal
const NEAR_CONTACT := 0.25           ## m: a shallow pair this close to a found contact joins it

var model := TmCarModel.new()
var xform := Transform3D()
var lin_vel := Vector3.ZERO           ## world
var ang_vel := Vector3.ZERO           ## world
## Inputs, set by the host before each tick. steer: -1..1, + = left.
var gas := 0.0
var brake := 0.0
var steer := 0.0
## Extra acceleration (world) the host adds over the tick (SpeedFest's nitro and pads).
var extra_accel := Vector3.ZERO
var now_ms := 0
var collision_mask := 1
## Returns [surface id, pad direction (world)] for a contact point and normal; default: the collider's
## metadata ("surface", per-face "surfaces", "pad_dir").
var surface_fn := Callable()

# --- outputs of the last tick ---
var substeps := 1
var body_contact := false             ## the chassis touched something
var wall_touch := false               ## a wheel's side touched a wall
var wheel_contact: Array[bool] = [false, false, false, false]
var wheel_hit_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var wheel_hit_n: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
var wheel_surface := PackedInt32Array([16, 16, 16, 16])
var wall_normals: Array[Vector3] = []  ## world normals of wall/chassis contacts (host signals)

## Geometry (car frame, relative to the centre of mass).
var wheel_pos: Array[Vector3] = []    ## wheel centres at the static suspension length
var wheel_radius := T.WHEEL_RADIUS

var _wheels: Array = []
var _absorb := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _wheel_shape: ConvexPolygonShape3D
var _wheel_half := Vector3.ONE
var _body_shapes: Array[ConvexPolygonShape3D] = []
var _body_half: Array[Vector3] = []
var _body_xforms: Array[Transform3D] = []
var _query := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _nray := PhysicsRayQueryParameters3D.new()
var _inv_inertia := Vector3.ONE / T.INERTIA
var _body_hit := false
var _space: PhysicsDirectSpaceState3D


func _init() -> void:
	setup(T.WHEELS, T.WHEEL_RADIUS, T.WHEEL_HALF_WIDTH, T.BODY_ELLIPSOIDS, Vector3.ONE)
	_ray.hit_back_faces = false
	_nray.hit_back_faces = true


## Collision geometry. wheels: 4 centres (FL, FR, RL, RR) at the static length; ellipsoids:
## [[centre, half-axes, pitch], ...] (TmTuning.BODY_ELLIPSOIDS layout), scaled by body_scale and
## raised if needed so the chassis keeps the Stadium car's ground clearance (0.09 m at rest).
func setup(wheels: Array, radius: float, half_width: float, ellipsoids: Array, body_scale: Vector3) -> void:
	wheel_pos.clear()
	_wheels.clear()
	for i in 4:
		var p: Vector3 = wheels[i]
		wheel_pos.append(p)
		var wi := TmCarModel.WheelInput.new()
		wi.pos = T.WHEELS[i]                 # the force model keeps the Stadium car's geometry
		_wheels.append(wi)
	wheel_radius = radius
	_wheel_half = Vector3(half_width, radius, radius)
	_wheel_shape = make_ellipsoid(_wheel_half)
	_body_shapes.clear()
	_body_half.clear()
	_body_xforms.clear()
	var lowest := 0.0
	for e in ellipsoids:
		lowest = minf(lowest, ((e[0] as Vector3).y - (e[1] as Vector3).y) * body_scale.y)
	var rest_h := -float((wheels[0] as Vector3).y) + radius
	var raise := maxf(0.0, (rest_h - CHASSIS_CLEARANCE) * -1.0 - lowest) if lowest < -(rest_h - CHASSIS_CLEARANCE) else 0.0
	for e in ellipsoids:
		_body_half.append((e[1] as Vector3) * body_scale)
		_body_shapes.append(make_ellipsoid((e[1] as Vector3) * body_scale))
		_body_xforms.append(Transform3D(Basis(Vector3(1, 0, 0), -float(e[2])), (e[0] as Vector3) * body_scale + Vector3(0.0, raise, 0.0)))


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


func reset() -> void:
	lin_vel = Vector3.ZERO
	ang_vel = Vector3.ZERO
	model.reset()
	for i in 4:
		_absorb[i] = 0.0
		(_wheels[i] as TmCarModel.WheelInput).contact = false
		(_wheels[i] as TmCarModel.WheelInput).side_contact = false
		wheel_contact[i] = false
	_body_hit = false


## Height of the centre of mass above the ground with the car at rest.
func rest_height() -> float:
	return -wheel_pos[0].y + wheel_radius


## Wheel centre in the car frame at its current suspension length.
func wheel_center_local(i: int) -> Vector3:
	return wheel_pos[i] + Vector3(0.0, T.SUSP_STATIC - model.susp_len[i], 0.0)


func local_velocity() -> Vector3:
	return xform.basis.transposed() * lin_vel


## One tick of `dt` seconds (TMNF: 0.01), sub-stepped.
func step(space: PhysicsDirectSpaceState3D, dt: float) -> void:
	_space = space
	var n := clampi(roundi(dt * (lin_vel.length() + ang_vel.length()) / T.SUBSTEP_DIST) + 1, 1, 1000)
	substeps = n
	body_contact = false
	wall_touch = false
	wall_normals.clear()
	var h := dt / float(n)
	for s in n:
		_substep(h)
	now_ms += roundi(dt * 1000.0)


func _substep(h: float) -> void:
	var b := xform.basis
	var inv := b.transposed()
	# 1) suspension: lengths take the penetration absorbed by the last collision pass
	for i in 4:
		model.integrate_suspension(i, _absorb[i], h)
		_absorb[i] = 0.0
	# 2) forces, from the contacts of the last pass
	model.tick(h, now_ms, gas, brake, steer, inv * lin_vel, inv * ang_vel, inv * Vector3.UP, _wheels, _body_hit)
	# 3) integrate (semi-implicit Euler); the air control may set the angular speed first
	var w_loc := inv * ang_vel
	if model.air_set_w:
		w_loc = model.air_w
	var f_loc := model.force
	var t_loc := model.torque
	for i in 4:
		var wf: Vector3 = model.wheel_force[i]
		if wf == Vector3.ZERO:
			continue
		f_loc += wf
		t_loc += wheel_center_local(i).cross(wf)
	model.last_force = f_loc + inv * (GRAVITY * model.gravity_coef)
	lin_vel += (b * f_loc + GRAVITY * model.gravity_coef + extra_accel) * h
	if model.linear_damp > 0.0:
		lin_vel *= maxf(0.0, 1.0 - model.linear_damp * h)
	w_loc += t_loc * _inv_inertia * h
	ang_vel = b * w_loc
	var pos := xform.origin + lin_vel * h
	var wl := ang_vel.length()
	if wl > 1e-9:
		b = Basis(ang_vel / wl, wl * h) * b
	xform = Transform3D(b.orthonormalized(), pos)
	# 4) collide and absorb
	_collide()


## Contacts of an ellipsoid (half-axes `half`) at xf: [[normal (world, out of the surface, toward the
## car), depth, point on the surface], ...], one per surface direction. Double-sided triangles (road
## meshes made for rays) can resolve a deep contact out of their back face: the normal is turned to
## the side the shape's centre is on and the depth re-measured from the ellipsoid's extent.
## A shallow pair's point difference has no usable direction (the query returns world points in
## float32: ~0.1 mm steps at 1 km from the origin, so a 0.01 mm contact reads as straight up or down):
## its normal is the face normal under the point, or that of a nearby contact already found.
func _contacts(shape: Shape3D, xf: Transform3D, half: Vector3) -> Array:
	_query.shape = shape
	_query.transform = xf
	_query.collision_mask = collision_mask
	var res := _space.collide_shape(_query, 16)
	var out: Array = []
	var inv_b := xf.basis.transposed()
	for k in range(0, res.size() - 1, 2):
		var a: Vector3 = res[k]
		var p: Vector3 = res[k + 1]
		var d := p - a
		var depth := d.length()
		var to_c := xf.origin - p
		var n: Vector3
		if depth >= NORMAL_MIN_DEPTH:
			n = d / depth
			if to_c.dot(n) < 0.0:
				n = -n
				var u := inv_b * n
				var ext := Vector3(half.x * u.x, half.y * u.y, half.z * u.z).length()
				depth = ext - to_c.dot(n)
				if depth <= 1e-6:
					continue
		else:
			var near := false
			for c in out:
				if ((c[2] as Vector3) - p).length_squared() < NEAR_CONTACT * NEAR_CONTACT:
					c[1] = maxf(c[1], depth)
					near = true
					break
			if near:
				continue
			n = _face_normal(p, to_c)
			if n == Vector3.ZERO:
				continue
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


## Normal of the face at a contact point, turned toward `to_c` (the shape's centre); zero if the
## short ray finds no face.
func _face_normal(p: Vector3, to_c: Vector3) -> Vector3:
	var u := to_c.normalized()
	_nray.from = p + u * 0.05
	_nray.to = p - u * 0.05
	_nray.collision_mask = collision_mask
	var hit := _space.intersect_ray(_nray)
	if hit.is_empty():
		return Vector3.ZERO
	var n: Vector3 = hit.normal
	return n if n.dot(u) >= 0.0 else -n


## Surface id and turbo pad direction of what lies under a contact point.
func _surface_at(p: Vector3, n: Vector3) -> Array:
	if surface_fn.is_valid():
		return surface_fn.call(p, n)
	_ray.from = p + n * 0.05
	_ray.to = p - n * 0.05
	_ray.collision_mask = collision_mask
	var hit := _space.intersect_ray(_ray)
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
	var r := at - xform.origin
	var inv := xform.basis.transposed()
	ang_vel += xform.basis * ((inv * r.cross(j)) * _inv_inertia)


## Velocity change per unit impulse along dir at r (world), for ComputeImpulse.
func _inv_mass_along(dir: Vector3, r: Vector3) -> float:
	var inv := xform.basis.transposed()
	var iw := xform.basis * ((inv * r.cross(dir)) * _inv_inertia)
	return 1.0 / T.MASS + dir.dot(iw.cross(r))


## SDynaMath::ComputeImpulse: the impulse along dir that leaves `keep` of the velocity along dir.
func _impulse(keep: float, vel: Vector3, dir: Vector3, r: Vector3) -> Vector3:
	var k := _inv_mass_along(dir, r)
	if absf(k) < 1e-5:
		return Vector3.ZERO
	return dir * ((keep - 1.0) * vel.dot(dir) / k)


func _point_velocity(p: Vector3) -> Vector3:
	return lin_vel + ang_vel.cross(p - xform.origin)


func _collide() -> void:
	var b := xform.basis
	var inv := b.transposed()
	var pushes: Array = []   # world penetration vectors left after the suspensions
	for i in 4:
		var wi: TmCarModel.WheelInput = _wheels[i]
		wi.contact = false
		wi.side_contact = false
		var c_loc := wheel_center_local(i)
		var c_world := xform * c_loc
		var n_sum := Vector3.ZERO
		var deepest := 0.0
		for c in _contacts(_wheel_shape, Transform3D(b, c_world), _wheel_half):
			var n: Vector3 = c[0]
			var depth: float = c[1]
			var p: Vector3 = c[2]
			var n_loc := inv * n
			var pen_loc := n_loc * depth
			var r := p - xform.origin
			var vrel := _point_velocity(p)
			if absf(n_loc.x) >= T.SIDE_CONTACT_SIN:
				# the wheel's side against a wall
				wi.side_contact = true
				wall_touch = true
				wall_normals.append(n)
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
				wheel_hit_pos[i] = p
				wheel_hit_n[i] = n
				wheel_surface[i] = wi.surface
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
						_apply_impulse(_impulse(T.WHEEL_GROUND_KEEP, v2, n, c_world - xform.origin), c_world)
			if pen_loc.length_squared() > 1e-10:
				pushes.append(b * pen_loc)
		if wi.contact:
			wi.normal = n_sum.normalized()
		wheel_contact[i] = wi.contact
	# chassis
	_body_hit = false
	for k in _body_shapes.size():
		for c in _contacts(_body_shapes[k], xform * _body_xforms[k], _body_half[k]):
			var n: Vector3 = c[0]
			var depth: float = c[1]
			var p: Vector3 = c[2]
			var sp := _surface_at(p, n)
			if IGNORED_SURFACES.has(sp[0]):
				continue
			_body_hit = true
			body_contact = true
			wall_normals.append(n)
			var push := n * depth
			if (inv * n).y < -0.75:
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
				_apply_impulse(_impulse(T.BODY_KEEP, vrel, d, p - xform.origin), p)
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
		xform.origin += corr
