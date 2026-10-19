extends Node3D
## Probe: what Jolt's shape queries return for a convex ellipsoid touching a box floor and a wall.

func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	var wall := StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(1, 4, 20)
	cs2.shape = box2
	wall.add_child(cs2)
	wall.position = Vector3(3.0, 2.0, 0)
	add_child(wall)
	var tri := StaticBody3D.new()
	var cs3 := CollisionShape3D.new()
	var mesh := ConcavePolygonShape3D.new()
	mesh.set_faces(PackedVector3Array([Vector3(-10, 0, 20), Vector3(10, 0, 20), Vector3(-10, 0, 40),
		Vector3(10, 0, 20), Vector3(10, 0, 40), Vector3(-10, 0, 40)]))
	cs3.shape = mesh
	tri.add_child(cs3)
	add_child(tri)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ell := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for i in 9:
		var lat := -PI / 2 + PI * i / 8.0
		for j in 16:
			var lon := TAU * j / 16.0
			pts.append(Vector3(0.182 * cos(lat) * cos(lon), 0.364 * sin(lat), 0.364 * cos(lat) * sin(lon)))
	ell.points = pts
	print("margin ", ell.margin)
	var space := get_world_3d().direct_space_state
	for case in [[Vector3(0, 0.364 - 0.05, 0), "floor pen 0.05"], [Vector3(0, 0.364 - 0.002, 0), "floor pen 0.002"],
			[Vector3(2.5 - 0.182 + 0.03, 1.0, 0), "wall pen 0.03"], [Vector3(2.5 - 0.182 + 0.03, 0.364 - 0.04, 0), "wall 0.03 + floor 0.04"],
			[Vector3(0, 0.364 - 0.05, 30), "trimesh pen 0.05"], [Vector3(0, 0.364 + 0.01, 0), "floor gap 0.01"]]:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = ell
		q.transform = Transform3D(Basis(), case[0])
		var res := space.collide_shape(q, 8)
		var info := space.get_rest_info(q)
		print("CASE ", case[1], " collide=", res, " rest=", info)
	get_tree().quit()
