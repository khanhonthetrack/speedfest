class_name Track
extends Node3D
## STUB: the track module replaces this with the spline road builder.
## API fixed by docs/ARCHITECTURE.md "Track". This stub is a flat plane with a straight path.

signal checkpoint_reached(car: Node, index: int)
signal finish_reached(car: Node)

var track_id: String = "arena"
var path: TrackPath
var checkpoint_count: int = 0
var kill_y: float = -50.0


static func build(p_track_id: String) -> Track:
	var t := Track.new()
	t.track_id = p_track_id
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(0, 0, -400))
	t.path = TrackPath.new(c, false, 14.0)
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 1000)
	cs.shape = box
	cs.position.y = -0.5
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 1000)
	mi.mesh = pm
	ground.add_child(mi)
	t.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	t.add_child(sun)
	return t


func get_start_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))


func get_checkpoint_transform(index: int) -> Transform3D:
	if index < 0:
		return get_start_transform()
	return get_start_transform()


func get_minimap_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 64
	for i in n + 1:
		var p := path.sample_position(path.length * i / n)
		pts.append(Vector2(p.x, p.z))
	return pts
