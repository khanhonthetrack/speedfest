extends Node3D
## Looks at one of our cars on a concrete plaza in our light (screenshots, a turntable):
## --model=hyper ("" the open-wheeler; a road car's id) [--livery=0] [--colour=0 (TmUi.CAR_COLOURS)] [--yaw=35 (0: from the
## front, 90: its left side)] [--pitch=12] [--dist=6.5 (m)] [--look=0,0.55,0 (the point looked at,
## visual coords)] [--fov=40] [--spin=0 (degrees the car turns each frame: a turntable with
## --shots=a.png@N,...)] [--mood=night] [--ghost] --frames=N --shot=/abs.png.
## Prints the car's triangles.

var _car: TmCarVisual
var _spin := 0.0


func _ready() -> void:
	TmStadiumEnv.add(self)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.material_override = TmMaterials.get_material("concrete")
	add_child(ground)
	_car = TmCarVisual.new()
	_car.model = String(TestHooks.arg("model", "hyper"))
	_car.livery = int(TestHooks.arg("livery", 0))
	_car.paint_colour = TmUi.CAR_COLOURS[clampi(int(TestHooks.arg("colour", 0)), 0, TmUi.CAR_COLOURS.size() - 1)]
	_car.ghost = TestHooks.has_arg("ghost")
	_car.position = TmCarVisual.VIS          # its ground on the plaza
	add_child(_car)
	var tris := 0
	for mi: MeshInstance3D in _car.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			tris += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	print("CAR %s: %d triangles" % [_car.model if not _car.model.is_empty() else "formula", tris])
	_spin = float(TestHooks.arg("spin", 0.0))
	var cam := Camera3D.new()
	cam.fov = float(TestHooks.arg("fov", 40.0))
	add_child(cam)
	cam.current = true
	var l := String(TestHooks.arg("look", "0,0.55,0")).split(",")
	var at := Vector3(float(l[0]), float(l[1]), float(l[2]))
	var yaw := deg_to_rad(float(TestHooks.arg("yaw", 35.0)))
	var pitch := deg_to_rad(float(TestHooks.arg("pitch", 12.0)))
	var d := float(TestHooks.arg("dist", 6.5))
	cam.position = at + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * d
	cam.look_at(at)


func _process(_delta: float) -> void:
	if _spin != 0.0:
		_car.rotation.y += deg_to_rad(_spin)
