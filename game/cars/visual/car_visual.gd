class_name CarVisual
extends Node3D
## STUB: the car-visuals module replaces this with procedural car models.
## API fixed by docs/ARCHITECTURE.md "CarVisual". This stub shows a colored box + 4 wheels.

var car_id: String = "kaze"
var style: Dictionary = {}
var _wheels: Array[Node3D] = []


func build(p_car_id: String, p_style: Dictionary) -> void:
	car_id = p_car_id
	style = p_style.duplicate(true)
	for c in get_children():
		c.queue_free()
	_wheels.clear()
	var g := CarDefs.geometry(car_id)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(g["width"], g["height"] - g["ground_clearance"], g["length"])
	body.mesh = bm
	body.position.y = -g["wheel_radius"] + g["ground_clearance"] + bm.size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(style.get("paint", "#ff6a00")))
	mat.metallic = 0.6
	mat.roughness = 0.3
	bm.material = mat
	add_child(body)
	for p in CarDefs.wheel_positions(car_id):
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = g["wheel_radius"]
		cm.bottom_radius = g["wheel_radius"]
		cm.height = g["wheel_width"]
		w.mesh = cm
		w.rotation.z = PI * 0.5
		var pivot := Node3D.new()
		pivot.position = p
		pivot.add_child(w)
		add_child(pivot)
		_wheels.append(pivot)


func apply_style(p_style: Dictionary) -> void:
	build(car_id, p_style)


func set_wheel_state(steer_angle_rad: float, _spin_rad: Array, susp_offsets: Array) -> void:
	var base := CarDefs.wheel_positions(car_id)
	for i in _wheels.size():
		_wheels[i].position = base[i] + Vector3(0, float(susp_offsets[i]) if i < susp_offsets.size() else 0.0, 0)
		_wheels[i].rotation.y = steer_angle_rad if i < 2 else 0.0


func set_lights(_braking: bool, _reversing: bool) -> void:
	pass


func set_nitro(_active: bool) -> void:
	pass


func set_ghost(_alpha: float) -> void:
	pass


func set_underglow_enabled(_on: bool) -> void:
	pass
