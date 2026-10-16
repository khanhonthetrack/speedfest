class_name TmCarVisual
extends Node3D
## Our own Stadium car: an open-wheel racer with TMNF's proportions (measured from the Stadium
## car's visual locally: 3.94 m long, 1.64 m wide body, 1.1 m tall, the driver just behind the
## middle, guards over the front wheels and pods over the rear ones), its shapes our own: lofted
## superellipse sections, wishbones, five-spoke wheels, our livery. The wheels follow suspension,
## steering and spin. Parent it to a TmCar; or, as a ghost (ghost = true), to any Node3D and feed
## ghost_speed and ghost_steer (a replayed run): translucent, no shadow.

const T := preload("res://core/tm_tuning.gd")

## The measured visual's origin in the car's frame (the physics origin is the centre of mass):
## stations below are in visual coordinates (ground at y 0, nose towards +z).
const VIS := Vector3(0.0, 0.441, 0.29)
## Lofts: [z, bottom, top, half width, roundness] stations (visual coordinates).
const TUB := [[2.13, 0.24, 0.34, 0.08, 2.2], [2.00, 0.20, 0.42, 0.20, 2.4], [1.70, 0.17, 0.52, 0.26, 2.6],
	[1.30, 0.16, 0.62, 0.29, 2.6], [0.90, 0.15, 0.72, 0.31, 2.6], [0.50, 0.14, 0.78, 0.34, 2.8],
	[0.15, 0.14, 0.62, 0.36, 3.0], [-0.20, 0.14, 0.66, 0.40, 3.0], [-0.40, 0.14, 0.70, 0.45, 3.0]]
const ENGINE := [[0.05, 0.16, 0.55, 0.30, 2.6], [-0.30, 0.15, 0.86, 0.62, 3.2], [-0.70, 0.15, 0.92, 0.70, 3.4],
	[-1.10, 0.17, 0.90, 0.62, 3.2], [-1.45, 0.30, 0.92, 0.55, 3.0], [-1.75, 0.55, 0.94, 0.42, 2.6],
	[-1.82, 0.70, 0.93, 0.30, 2.4]]
const AIRBOX := [[-0.10, 0.70, 0.80, 0.12, 2.4], [-0.35, 0.70, 1.00, 0.16, 2.6], [-0.65, 0.72, 1.04, 0.20, 2.8],
	[-1.00, 0.74, 0.96, 0.24, 2.8], [-1.30, 0.80, 0.92, 0.24, 2.4]]
const PODS := [[0.75, 0.16, 0.28, 0.36, 2.4], [0.50, 0.14, 0.40, 0.66, 3.4], [0.10, 0.14, 0.44, 0.80, 3.6],
	[-0.40, 0.14, 0.44, 0.80, 3.6], [-0.80, 0.15, 0.42, 0.70, 3.2], [-1.05, 0.18, 0.38, 0.50, 2.6]]
const HELMET := Vector3(0.0, 0.86, -0.25)
const HELMET_R := 0.17
## The guards over the front wheels and the pods over the rear ones: [angle from, to (deg, from
## straight ahead over the top to behind), radius over the tyre, inner and outer x].
const FRONT_GUARD := [-20.0, 120.0, 0.42, 0.66, 0.92]
const REAR_POD := [-10.0, 160.0, 0.43, 0.60, 0.92]

var car: TmCar
var ghost := false
var ghost_speed := 0.0            ## m/s along the car
var ghost_steer := 0.0
var paint_colour := Color(0.85, 0.08, 0.06)
var _wheels: Array[Node3D] = []
var _spin := 0.0
var _mats := {}


func _ghostly(m: StandardMaterial3D) -> StandardMaterial3D:
	if ghost:
		m.albedo_color = Color(m.albedo_color, 0.38)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.clearcoat_enabled = false
		m.emission_enabled = false
	return m


## The car's own surface shader (HD graphics, not for ghosts): paint with flakes and a stripe,
## carbon weave, tyre tread.
func _surface(mode: int, colour: Color, stripe: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://car/tm_car_surface.gdshader")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("colour", colour)
	m.set_shader_parameter("stripe_half", stripe)
	m.set_shader_parameter("tyre_radius", T.WHEEL_RADIUS)
	m.set_shader_parameter("tyre_half_width", T.WHEEL_HALF_WIDTH)
	return m


func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	if not ghost and TmMaterials.hd() and key in ["paint", "white", "carbon", "tyre"]:
		var sm: ShaderMaterial
		match key:
			"paint": sm = _surface(0, paint_colour, 0.07)
			"white": sm = _surface(0, Color(0.93, 0.93, 0.94), 0.0)
			"carbon": sm = _surface(1, Color.BLACK, 0.0)
			"tyre": sm = _surface(2, Color.BLACK, 0.0)
		_mats[key] = sm
		return sm
	var m := StandardMaterial3D.new()
	match key:
		"paint":
			m.albedo_color = paint_colour if not ghost else Color(0.55, 0.75, 1.0)
			m.metallic = 0.5
			m.roughness = 0.28
			m.clearcoat_enabled = true
		"white":
			m.albedo_color = Color(0.93, 0.93, 0.94) if not ghost else Color(0.7, 0.85, 1.0)
			m.metallic = 0.2
			m.roughness = 0.3
			m.clearcoat_enabled = true
		"carbon":
			m.albedo_color = Color(0.07, 0.07, 0.08)
			m.metallic = 0.3
			m.roughness = 0.45
		"metal":
			m.albedo_color = Color(0.72, 0.73, 0.76)
			m.metallic = 1.0
			m.roughness = 0.25
		"tyre":
			m.albedo_color = Color(0.035, 0.035, 0.04)
			m.roughness = 0.9
		"visor":
			m.albedo_color = Color(0.05, 0.06, 0.09)
			m.metallic = 0.6
			m.roughness = 0.1
		"light":
			m.albedo_color = Color(0.9, 0.08, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.1, 0.05)
			m.emission_energy_multiplier = 2.0
	_mats[key] = _ghostly(m)
	return _mats[key]


## Catmull-Rom through a station table, `per` samples per span.
static func _resample(stations: Array, per: int) -> Array:
	var out := []
	var n := stations.size()
	for i in n - 1:
		var p0: Array = stations[maxi(i - 1, 0)]
		var p1: Array = stations[i]
		var p2: Array = stations[i + 1]
		var p3: Array = stations[mini(i + 2, n - 1)]
		for s in per:
			var t := float(s) / per
			var row := []
			for k in 5:
				var a := float(p0[k])
				var b := float(p1[k])
				var c := float(p2[k])
				var d := float(p3[k])
				row.append(0.5 * (2.0 * b + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (3.0 * b - a - 3.0 * c + d) * t * t * t))
			out.append(row)
	out.append(stations[n - 1])
	return out


## A loft of superellipse rings through the stations, closed at both ends; x offset dx (pods).
func _loft(stations: Array, mat: String, ring := 32, dx := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := _resample(stations, 6)
	var rings := []
	for r: Array in rows:
		var pts := []
		var yc := (float(r[1]) + float(r[2])) * 0.5
		var hh := (float(r[2]) - float(r[1])) * 0.5
		var e := 2.0 / float(r[4])
		for k in ring:
			var a := TAU * k / ring
			var c := cos(a)
			var s := sin(a)
			pts.append(Vector3(dx + float(r[3]) * signf(c) * pow(absf(c), e), yc + hh * signf(s) * pow(absf(s), e), float(r[0])) - VIS)
		rings.append(pts)
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for k in ring:
			var k1 := (k + 1) % ring
			# rings run nose (i = 0) to tail; counter-clockwise seen from the front: outward faces
			st.add_vertex(r0[k]); st.add_vertex(r0[k1]); st.add_vertex(r1[k1])
			st.add_vertex(r0[k]); st.add_vertex(r1[k1]); st.add_vertex(r1[k])
	for end: int in [0, rings.size() - 1]:
		var rr: Array = rings[end]
		var c := Vector3.ZERO
		for p: Vector3 in rr:
			c += p
		c /= ring
		for k in ring:
			var k1 := (k + 1) % ring
			if end == 0:
				st.add_vertex(c); st.add_vertex(rr[k1]); st.add_vertex(rr[k])
			else:
				st.add_vertex(c); st.add_vertex(rr[k]); st.add_vertex(rr[k1])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(mat)
	return mi


## A curved plate over a wheel: a band of the cylinder about the wheel's axis from angle a0 to a1.
func _guard(centre: Vector3, spec: Array, side: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 18
	var r_out: float = spec[2]
	var r_in := r_out - 0.03
	var x0: float = spec[3] * side
	var x1: float = spec[4] * side
	for i in steps:
		var a0 := deg_to_rad(lerpf(spec[0], spec[1], float(i) / steps))
		var a1 := deg_to_rad(lerpf(spec[0], spec[1], float(i + 1) / steps))
		for r: float in [r_out, r_in]:
			var p0 := centre + Vector3(0.0, sin(a0) * r, cos(a0) * r)   # from ahead (0) over the top
			var p1 := centre + Vector3(0.0, sin(a1) * r, cos(a1) * r)
			var q := [Vector3(x0, p0.y, p0.z), Vector3(x1, p0.y, p0.z), Vector3(x1, p1.y, p1.z), Vector3(x0, p1.y, p1.z)]
			var out := (p0 + p1) * 0.5 - centre
			out.x = 0.0
			if r == r_in:
				out = -out
			var n := ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[2] as Vector3) - (q[0] as Vector3))
			if n.dot(out) < 0.0:
				q.reverse()
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat("paint")
	return mi


func _pipe(a: Vector3, b: Vector3, r: float, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(mat)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	return mi


func _box(c: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(mat)
	mi.position = c - VIS
	return mi


func _part(mi: MeshInstance3D) -> void:
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ready() -> void:
	car = get_parent() as TmCar
	_part(_loft(TUB, "paint", 40))
	_part(_loft(ENGINE, "paint", 40))
	_part(_loft(PODS, "white", 36))
	_part(_loft(AIRBOX, "white", 28))
	# the floor, the nose's splitter and the spoiler at the tail
	_part(_box(Vector3(0.0, 0.13, -0.4), Vector3(1.2, 0.03, 2.0), "carbon"))
	_part(_box(Vector3(0.0, 0.17, 2.02), Vector3(0.9, 0.025, 0.28), "carbon"))
	_part(_box(Vector3(0.0, 0.99, -1.74), Vector3(0.84, 0.03, 0.22), "carbon"))
	for s: float in [-1.0, 1.0]:
		_part(_box(Vector3(s * 0.43, 0.94, -1.72), Vector3(0.025, 0.14, 0.26), "carbon"))
		_part(_box(Vector3(s * 0.2, 0.86, -1.81), Vector3(0.14, 0.05, 0.02), "light"))
	# the driver's helmet with its visor
	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = HELMET_R
	hm.height = HELMET_R * 2.0
	helmet.mesh = hm
	helmet.material_override = _mat("white")
	helmet.position = HELMET - VIS
	_part(helmet)
	var visor := MeshInstance3D.new()
	var vm := SphereMesh.new()
	vm.radius = HELMET_R * 1.02
	vm.height = HELMET_R * 0.8
	visor.mesh = vm
	visor.material_override = _mat("visor")
	visor.position = HELMET - VIS + Vector3(0.0, 0.01, 0.03)
	visor.scale = Vector3(0.92, 1.0, 1.0)
	_part(visor)
	# wheels: guards over the front ones, pods over the rear ones, wishbones and driveshafts
	for i in 4:
		var front := i < 2
		var w: Vector3 = T.WHEELS[i]
		var side := signf(w.x)
		var c := w + Vector3(0.0, T.SUSP_STATIC, 0.0)
		if not front:
			_part(_guard(c, REAR_POD, side))
		var hub := c + Vector3(-side * 0.14, 0.0, 0.0)
		var inner_x := side * (0.22 if front else 0.36)
		for dy: float in [-0.1, 0.1]:
			for dz: float in [-0.16, 0.16]:
				_part(_pipe(Vector3(inner_x, c.y + dy, c.z + dz), hub + Vector3(0.0, dy, 0.0), 0.018, "carbon"))
		if not front:
			_part(_pipe(Vector3(side * 0.3, c.y, c.z), hub, 0.035, "metal"))
	for i in 4:
		var pivot := Node3D.new()
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		spin.add_child(_tyre())
		spin.add_child(_rim(signf(T.WHEELS[i].x)))
		if i < 2:
			var g := _guard(Vector3.ZERO, FRONT_GUARD, signf(T.WHEELS[i].x))
			g.position.x = -T.WHEELS[i].x
			pivot.add_child(g)
		_wheels.append(pivot)


## The tyre: a lathed rounded section around the axle (along x).
func _tyre() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := T.WHEEL_RADIUS
	var hw := T.WHEEL_HALF_WIDTH
	var prof := []   # (x, radius) around the section, outside first
	for k in 9:
		var a := lerpf(-PI * 0.5, PI * 0.5, k / 8.0)
		prof.append(Vector2(hw * 0.78 * sin(a) + signf(sin(a)) * hw * 0.22 * absf(sin(a)), r - 0.05 + 0.05 * cos(a)))
	prof.append(Vector2(hw * 0.95, r * 0.66))
	prof.push_front(Vector2(-hw * 0.95, r * 0.66))
	var seg := 40
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		for j in prof.size() - 1:
			var p: Vector2 = prof[j]
			var q: Vector2 = prof[j + 1]
			var v00 := Vector3(p.x, cos(a0) * p.y, sin(a0) * p.y)
			var v01 := Vector3(q.x, cos(a0) * q.y, sin(a0) * q.y)
			var v10 := Vector3(p.x, cos(a1) * p.y, sin(a1) * p.y)
			var v11 := Vector3(q.x, cos(a1) * q.y, sin(a1) * q.y)
			st.add_vertex(v00); st.add_vertex(v01); st.add_vertex(v11)
			st.add_vertex(v00); st.add_vertex(v11); st.add_vertex(v10)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat("tyre")
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The rim: a dished disc with five spokes and a hub, on the wheel's outer side.
func _rim(side: float) -> Node3D:
	var n := Node3D.new()
	var r := T.WHEEL_RADIUS * 0.66
	var face := side * T.WHEEL_HALF_WIDTH * 0.55
	var barrel := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = r
	bc.bottom_radius = r
	bc.height = T.WHEEL_HALF_WIDTH * 1.9
	bc.radial_segments = 28
	bc.cap_top = false
	bc.cap_bottom = false
	barrel.mesh = bc
	barrel.material_override = _mat("carbon")
	barrel.rotation = Vector3(0, 0, PI * 0.5)
	n.add_child(barrel)
	var hub := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = 0.06
	hc.bottom_radius = 0.07
	hc.height = 0.06
	hc.radial_segments = 12
	hub.mesh = hc
	hub.material_override = _mat("metal")
	hub.rotation = Vector3(0, 0, PI * 0.5)
	hub.position = Vector3(face, 0, 0)
	n.add_child(hub)
	for k in 5:
		var a := TAU * k / 5.0
		var spoke := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.025, r * 0.95, 0.05)
		spoke.mesh = sb
		spoke.material_override = _mat("metal")
		var b := Basis(Vector3.RIGHT, a)
		spoke.transform = Transform3D(b, Vector3(face, 0, 0) + b * Vector3(0, r * 0.48, 0))
		n.add_child(spoke)
	for c in n.get_children():
		if ghost:
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


func _process(delta: float) -> void:
	if car and _mats.has("light"):   # brake lights
		(_mats["light"] as StandardMaterial3D).emission_energy_multiplier = 7.0 if car.brake > 0.1 else 1.6
	var vz := car.local_velocity().z if car else ghost_speed
	_spin += vz / T.WHEEL_RADIUS * delta
	var steer_vis := deg_to_rad(T.lin([[0.0, 30.0], [100.0, 10.0]], absf(vz) * 3.6)) * (car.model.steer if car else ghost_steer)
	for i in 4:
		var w := _wheels[i]
		w.position = T.WHEELS[i] + Vector3(0.0, T.SUSP_STATIC - (car.model.susp_len[i] if car else T.SUSP_STATIC), 0.0)
		w.rotation = Vector3(0.0, steer_vis if i < 2 else 0.0, 0.0)
		(w.get_child(0) as Node3D).rotation = Vector3(_spin, 0.0, 0.0)
