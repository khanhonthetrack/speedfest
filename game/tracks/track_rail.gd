class_name TrackRail
extends Node3D
## Grind rail (layout segments with "rail": true; first used by the stadium map "Rail Rush").
## The rail runs along the path centerline at path height, with no road around it. NOT magnetic
## (owner, session 7: "Rails should not be magnetic to the car ... its the players job to land
## there"): only a car that actually comes down ONTO it (rail under the middle of the car, at
## ride height, falling or level, heading along it) is caught, and the catch doesn't teleport:
## the leftover offset blends out over ~0.15 s. Then the rail carries the body along it through
## Car._integrate_forces (Car.grind), keeping the car's speed (gravity along the slope, a little
## friction, no steering), and releases it at the end with a small hop. Land beside it and you
## fall (respawn at the last checkpoint). No collision on purpose: it's a landing line.

signal grind_started(car: Node)
signal grind_ended(car: Node)

const RIDE_H := 0.55            # car origin above the rail top while grinding (underbody on the rail)
const CAPTURE_LAT := 0.45       # max horizontal distance from the rail line (m): under the car's middle
const CAPTURE_BELOW := 0.35     # car may be this far below ride height and still catch the rail
const CAPTURE_ABOVE := 0.35     # ...or this far above (one frame of fall at landing speed)
const CAPTURE_ALIGN := 0.9      # cos of the max angle between the car's travel and the rail (~26 deg)
const MAX_RISE := 0.5           # m/s: a car still going up is passing over the rail, not landing
const SETTLE_T := 0.15          # s: the offset at the catch blends out (no snap)
const MIN_SPEED := 6.0          # m/s kept while grinding (never stalls on the rail)
const FRICTION := 1.0           # m/s² lost while grinding
const POP := 2.6                # upward m/s added at the end of the rail (hop off)
const STEP := 1.0               # rail sample spacing (m)
const RADIUS := 0.13            # rail tube radius

var path: TrackPath
var d_from := 0.0
var d_to := 0.0
var length := 0.0
var pts := PackedVector3Array()      # rail top centerline, STEP apart
var tans := PackedVector3Array()     # unit tangents
var _cars := {}                      # Car -> {"s": arc length, "v": speed, "off": Vector3 offset}
var _sparks: CPUParticles3D
var _watch: Array[Node] = []         # candidate cars (inside the capture box)


func setup(p_path: TrackPath, p_from: float, p_to: float) -> void:
	path = p_path
	d_from = p_from
	d_to = p_to
	name = "Rail"
	var n := maxi(2, ceili((d_to - d_from) / STEP) + 1)
	for i in n:
		var d := lerpf(d_from, d_to, float(i) / (n - 1))
		pts.append(path.sample_position(d))
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		tans.append((b - a).normalized())
	length = 0.0
	for i in range(1, n):
		length += pts[i].distance_to(pts[i - 1])
	_build_visual()
	_build_area()
	_build_sparks()


# --- queries -------------------------------------------------------------------------------------

## Arc length of the rail point nearest to `p` (horizontal distance), and that distance.
func nearest(p: Vector3) -> Vector2:
	var best := 1e9
	var bi := 0
	for i in pts.size():
		var q := pts[i] - p
		q.y = 0.0
		var dd := q.length_squared()
		if dd < best:
			best = dd
			bi = i
	# refine along the segment
	var s := float(bi) * (length / maxf(pts.size() - 1, 1))
	var t := tans[bi]
	var off := p - pts[bi]
	var along := off.dot(t)
	s = clampf(s + along, 0.0, length)
	var rp := point_at(s)
	var lat := p - rp
	lat.y = 0.0
	return Vector2(s, lat.length())


func point_at(s: float) -> Vector3:
	var f := clampf(s / maxf(length, 0.001), 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


func tangent_at(s: float) -> Vector3:
	var f := clampf(s / maxf(length, 0.001), 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return tans[i].lerp(tans[i + 1], f - i).normalized()


func is_grinding(car: Node) -> bool:
	return _cars.has(car)


# --- capture -------------------------------------------------------------------------------------

func _physics_process(_dt: float) -> void:
	for c in _watch:
		if not is_instance_valid(c) or not (c is Car):
			continue
		var car := c as Car
		if car.grind != null or (car.freeze and car.tm == null):
			continue
		_try_capture(car)
	_update_sparks()


func _try_capture(car: Car) -> void:
	var p := car.global_position
	var q := nearest(p)
	if q.y > CAPTURE_LAT or q.x >= length - 2.0:
		return
	var rp := point_at(q.x)
	var t := tangent_at(q.x)
	var h := p.y - (rp.y + RIDE_H)
	if h < -CAPTURE_BELOW or h > CAPTURE_ABOVE:
		return
	var v := car.linear_velocity
	if v.y > MAX_RISE:
		return   # still rising: it is flying over the rail, not landing on it
	var vh := Vector3(v.x, 0.0, v.z)
	var th := Vector3(t.x, 0.0, t.z).normalized()
	if vh.length() < 4.0 or vh.normalized().dot(th) < CAPTURE_ALIGN:
		return
	var up := (Vector3.UP - t * Vector3.UP.dot(t)).normalized()
	_cars[car] = {"s": q.x, "v": maxf(v.dot(t), MIN_SPEED), "off": p - (rp + up * RIDE_H)}
	car.grind = self
	Audio.play_sfx("grind", 0.0, randf_range(0.95, 1.05))
	grind_started.emit(car)


## Called by Car._integrate_forces while car.grind == self. Drives the body; false = released.
## `state`: the body state, or any object with step/transform/linear_velocity/angular_velocity
## (CarTm.GrindState: the TMNF car is kinematic).
func grind_step(car: Car, state) -> bool:
	if not _cars.has(car):
		return false
	var g: Dictionary = _cars[car]
	var dt: float = state.step
	var s: float = g["s"]
	var v: float = g["v"]
	var t := tangent_at(s)
	v += (-CarPhysicsDefs.GRAVITY * t.y - FRICTION) * dt
	v = maxf(v, MIN_SPEED)
	s += v * dt
	if s >= length:
		var te := tangent_at(length)
		state.linear_velocity = te * v + Vector3.UP * POP
		state.angular_velocity = Vector3.ZERO
		_cars.erase(car)
		grind_ended.emit(car)
		return false
	t = tangent_at(s)
	var up := (Vector3.UP - t * Vector3.UP.dot(t)).normalized()
	var right := t.cross(up).normalized()
	# the offset left at the catch (the car was up to CAPTURE_LAT beside / CAPTURE_* above or below
	# ride height) blends out instead of snapping
	var off: Vector3 = g.get("off", Vector3.ZERO)
	off *= exp(-dt / SETTLE_T)
	var pos := point_at(s) + up * RIDE_H + off
	var cur: Basis = (state.transform as Transform3D).basis
	var want := Basis(right, up, -t)
	state.transform = Transform3D(cur.slerp(want, clampf(dt / SETTLE_T * 1.5, 0.0, 1.0)).orthonormalized(), pos)
	state.linear_velocity = t * v
	state.angular_velocity = Vector3.ZERO
	g["s"] = s
	g["v"] = v
	g["off"] = off
	return true


## The car was teleported (respawn/restart): forget it.
func release(car: Node) -> void:
	if _cars.erase(car):
		grind_ended.emit(car)


# --- building ------------------------------------------------------------------------------------

func _build_visual() -> void:
	var tube := SceneryMesh.new()
	var glow := SceneryMesh.new()
	var sides := 8
	var up_prev := Vector3.UP
	for i in pts.size() - 1:
		var a := pts[i] - Vector3.UP * RADIUS
		var b := pts[i + 1] - Vector3.UP * RADIUS
		var t := (b - a).normalized()
		var r := t.cross(Vector3.UP).normalized()
		var u := r.cross(t).normalized()
		up_prev = u
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var o0 := (r * cos(a0) + u * sin(a0)) * RADIUS
			var o1 := (r * cos(a1) + u * sin(a1)) * RADIUS
			tube.add_quad(a + o0, b + o0, b + o1, a + o1, Color(0.85, 0.87, 0.9))
		# neon strip on both sides under the tube
		for sx: float in [-1.0, 1.0]:
			var off := r * sx * (RADIUS + 0.02) - u * 0.05
			glow.add_box(Transform3D(Basis(r, u, -t), (a + b) * 0.5 + off), Vector3(0.04, 0.06, a.distance_to(b) + 0.02), SceneryMat.hdr(Color(1.0, 0.75, 0.1), 1.6), Vector2(0, 0))
	# posts down to the ground every ~9 m, and a bright end cap so the hop-off point reads
	var posts := SceneryMesh.new()
	var ground_y := 0.0
	var i := 2
	while i < pts.size() - 1:
		var p := pts[i] - Vector3.UP * (RADIUS * 2.0)
		var h := p.y - ground_y
		if h > 0.5:
			posts.add_box(Transform3D(Basis.IDENTITY, Vector3(p.x, ground_y + h * 0.5, p.z)), Vector3(0.22, h, 0.22), Color(0.12, 0.12, 0.14))
			posts.add_box(Transform3D(Basis.IDENTITY, p + Vector3(0, -0.08, 0)), Vector3(0.5, 0.16, 0.5), Color(0.12, 0.12, 0.14))
		i += 9
	for e in [0, pts.size() - 1]:
		glow.add_box(Transform3D(Basis.IDENTITY, pts[e] - Vector3.UP * RADIUS), Vector3(0.36, 0.36, 0.36), SceneryMat.hdr(Color(1.0, 0.3, 0.1), 2.0), Vector2(0, 0))
	var mi := MeshInstance3D.new()
	mi.name = "RailTube"
	mi.mesh = tube.commit()
	mi.material_override = SceneryMat.vcolor(0.2, 0.9)
	add_child(mi)
	var gi := MeshInstance3D.new()
	gi.name = "RailGlow"
	gi.mesh = glow.commit()
	gi.material_override = SceneryMat.neon(3.5)
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gi)
	if not posts.is_empty():
		var pi := MeshInstance3D.new()
		pi.name = "RailPosts"
		pi.mesh = posts.commit()
		pi.material_override = SceneryMat.vcolor(0.4, 0.6)
		add_child(pi)


## Trigger volume around the rail (a few meters around it): cars inside are capture candidates.
func _build_area() -> void:
	var area := Area3D.new()
	area.name = "RailArea"
	area.collision_layer = 0
	area.collision_mask = TrackBuilder.MASK_CAR
	area.monitorable = false
	add_child(area)
	var i := 0
	while i < pts.size() - 1:
		var j := mini(i + 8, pts.size() - 1)
		var a := pts[i]
		var b := pts[j]
		var mid := (a + b) * 0.5
		var t := (b - a).normalized()
		var r := t.cross(Vector3.UP).normalized()
		var u := r.cross(t).normalized()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(CAPTURE_LAT * 2.0 + 3.0, 6.0, a.distance_to(b) + 2.0)
		cs.shape = box
		cs.transform = Transform3D(Basis(r, u, -t), mid + u * 1.0)
		area.add_child(cs)
		i = j
	area.body_entered.connect(func(b: Node3D) -> void:
		if not _watch.has(b):
			_watch.append(b))
	area.body_exited.connect(func(b: Node3D) -> void: _watch.erase(b))


func _build_sparks() -> void:
	_sparks = CPUParticles3D.new()
	_sparks.name = "GrindSparks"
	_sparks.emitting = false
	_sparks.amount = 48 if Settings.is_compat() else 96
	_sparks.lifetime = 0.35
	_sparks.local_coords = false
	_sparks.direction = Vector3(0, 0.6, 1)    # backwards along the rail (basis -Z = tangent)
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 4.0
	_sparks.initial_velocity_max = 9.0
	_sparks.gravity = Vector3(0, -14, 0)
	_sparks.scale_amount_min = 0.04
	_sparks.scale_amount_max = 0.09
	var qm := BoxMesh.new()
	qm.size = Vector3(1, 1, 1)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.75, 0.3)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.6, 0.15)
	sm.emission_energy_multiplier = 4.0
	qm.material = sm
	_sparks.mesh = qm
	add_child(_sparks)


func _update_sparks() -> void:
	var on := false
	for car: Node in _cars:
		if is_instance_valid(car):
			var c := car as Node3D
			var g: Dictionary = _cars[car]
			var t := tangent_at(float(g["s"]))
			_sparks.global_position = point_at(float(g["s"])) + Vector3.UP * 0.05
			_sparks.global_basis = Basis.looking_at(t, Vector3.UP)
			on = true
			if c != null:
				break
	_sparks.emitting = on
