extends Node3D
## Research tool (not in the gate): one block shape on its own in the Day light, to compare its look
## with TMNF's (--ref=<dir>: the original's meshes from local research files, TmRefVisuals).
## Run: stadium/tools/run.sh res://tests/block_view.tscn -- --shape=Circuit/Road/BaseAir \
##        [--yaw=35 --pitch=12 --dist=55 --target=16,4,16 --fov=50] --frames=10 --shot=/abs.png
## yaw: degrees about the target from the block's -z side toward +x (TMNF block-local), pitch: up.

func _ready() -> void:
	var lib := TmBlockLib.new()
	var shape := String(TestHooks.arg("shape", "Circuit/Road/BaseAir")).replace("__", "/")
	var node: Node3D = lib.make(shape, {}, shape.contains("Ground"))
	if node == null:
		push_error("block_view: no shape %s" % shape)
		TestHooks.finish()
		return
	add_child(node)
	TmStadiumEnv.add(self)
	var grass := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	grass.mesh = pm
	grass.material_override = TmMaterials.get_material("grass")
	grass.position = Vector3(0, 0.9 if shape.contains("Ground") else -0.02, 0)   # (under the blocks' own terrain)
	add_child(grass)
	var t := String(TestHooks.arg("target", "16,4,16")).split(",")
	var target := TmGeo.g(Vector3(float(t[0]), float(t[1]), float(t[2])))
	var yaw := deg_to_rad(float(TestHooks.arg("yaw", 35.0)))
	var pitch := deg_to_rad(float(TestHooks.arg("pitch", 12.0)))
	var dist := float(TestHooks.arg("dist", 55.0))
	var cam := Camera3D.new()
	cam.fov = float(TestHooks.arg("fov", 50.0))
	cam.far = 3000.0
	add_child(cam)
	cam.position = target + TmGeo.g(Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))) * dist
	cam.look_at(target)
