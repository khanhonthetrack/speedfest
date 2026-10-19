class_name TmCarVisual
extends Node3D
## Placeholder look for the Stadium car until our own model exists (PLAN M8-6): the four chassis
## collision ellipsoids as smooth bodies and four wheels that follow suspension, steering and spin.
## Parent it to a TmCar.

const T := preload("res://core/tm_tuning.gd")

var car: TmCar
var _wheels: Array[Node3D] = []
var _spin := 0.0


func _ready() -> void:
	car = get_parent() as TmCar
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.08, 0.06)
	paint.metallic = 0.6
	paint.roughness = 0.25
	paint.clearcoat_enabled = true
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	dark.roughness = 0.6
	for k in T.BODY_ELLIPSOIDS.size():
		var e: Array = T.BODY_ELLIPSOIDS[k]
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 48
		sm.rings = 24
		mi.mesh = sm
		mi.material_override = dark if k == 3 else paint
		mi.transform = Transform3D(Basis(Vector3(1, 0, 0), -float(e[2])).scaled(e[1]), e[0])
		add_child(mi)
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color(0.03, 0.03, 0.03)
	tyre.roughness = 0.9
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.75, 0.75, 0.78)
	rim.metallic = 1.0
	rim.roughness = 0.3
	for i in 4:
		var pivot := Node3D.new()
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var t := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = T.WHEEL_RADIUS
		cyl.bottom_radius = T.WHEEL_RADIUS
		cyl.height = T.WHEEL_HALF_WIDTH * 2.0
		cyl.radial_segments = 32
		t.mesh = cyl
		t.material_override = tyre
		t.rotation = Vector3(0, 0, PI * 0.5)
		spin.add_child(t)
		var r := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = T.WHEEL_RADIUS * 0.62
		rc.bottom_radius = T.WHEEL_RADIUS * 0.62
		rc.height = T.WHEEL_HALF_WIDTH * 2.0 + 0.01
		rc.radial_segments = 6
		r.mesh = rc
		r.material_override = rim
		r.rotation = Vector3(0, 0, PI * 0.5)
		spin.add_child(r)
		_wheels.append(pivot)


func _process(delta: float) -> void:
	if car == null:
		return
	var v := car.local_velocity()
	_spin += v.z / T.WHEEL_RADIUS * delta
	var steer_vis := deg_to_rad(T.lin([[0.0, 30.0], [100.0, 10.0]], absf(v.z) * 3.6)) * car.model.steer
	for i in 4:
		var w := _wheels[i]
		w.position = T.WHEELS[i] + Vector3(0.0, T.SUSP_STATIC - car.model.susp_len[i], 0.0)
		w.rotation = Vector3(0.0, steer_vis if i < 2 else 0.0, 0.0)
		(w.get_child(0) as Node3D).rotation = Vector3(_spin, 0.0, 0.0)
