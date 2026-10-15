class_name SceneryDemoPaths
extends RefCounted
## Sample track paths for the scenery demo and tests (stand-ins for the real track layouts):
## city: ~2 km grid circuit with an elevated section and a sunk underpass;
## arena: ~1.5 km stunt circuit with a vertical loop, a jump hill and a 180;
## coast: ~3 km point-to-point clifftop sprint (sea on the left) with a bridge and a tunnel.


## Corner list [Vector3 corner, radius] -> Curve3D with straight edges and round corners.
static func rounded(ctrl: Array, circuit: bool) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 0.5
	var n := ctrl.size()
	for i in n:
		var p: Vector3 = ctrl[i][0]
		var r: float = ctrl[i][1]
		var has_prev := circuit or i > 0
		var has_next := circuit or i < n - 1
		if r <= 0.0 or not has_prev or not has_next:
			c.add_point(p)
			continue
		var pp: Vector3 = ctrl[(i - 1 + n) % n][0]
		var pn: Vector3 = ctrl[(i + 1) % n][0]
		var din := (p - pp).normalized()
		var dout := (pn - p).normalized()
		r = minf(r, minf((p - pp).length(), (pn - p).length()) * 0.45)
		var a := p - din * r
		var b := p + dout * r
		c.add_point(a, Vector3.ZERO, din * r * 0.55)
		c.add_point(b, -dout * r * 0.55, Vector3.ZERO)
	if circuit:
		c.add_point(c.get_point_position(0), c.get_point_in(0), Vector3.ZERO)
	return c


static func zones_by_height(path: TrackPath, above: float, below: float) -> void:
	# "bridge" where the road is above `above`, "tunnel" where it is below `below`.
	var kinds := {"bridge": [], "tunnel": []}
	var cur := ""
	var start := 0.0
	var d := 0.0
	while d <= path.length:
		var y := path.sample_position(d).y
		var k := "bridge" if y > above else ("tunnel" if y < below else "")
		if k != cur:
			if cur != "":
				path.zones.append({"from": start, "to": d, "kind": cur})
			cur = k
			start = d
		d += 2.0
	if cur != "":
		path.zones.append({"from": start, "to": path.length, "kind": cur})


static func city() -> TrackPath:
	var ctrl := [
		[Vector3(0, 0, 60), 28.0], [Vector3(0, 0, -450), 30.0], [Vector3(300, 0, -450), 30.0],
		[Vector3(300, 0, -280), 18.0], [Vector3(345, 0, -240), 18.0], [Vector3(345, 0, -140), 30.0],
		[Vector3(345, 11, 20), 40.0], [Vector3(200, 11, 160), 40.0], [Vector3(120, 0, 160), 20.0],
		[Vector3(60, -7, 160), 20.0], [Vector3(-60, -7, 160), 30.0], [Vector3(-60, 0, 60), 25.0],
	]
	var p := TrackPath.new(rounded(ctrl, true), true, 16.0)
	zones_by_height(p, 3.0, -2.0)
	return p


static func arena() -> TrackPath:
	var c := Curve3D.new()
	c.bake_interval = 0.5
	c.add_point(Vector3(0, 0, 40))
	c.add_point(Vector3(0, 0, -260))
	# vertical loop r = 19 with an 8 m lateral shift
	var r := 19.0
	var n := 24
	var z0 := -280.0
	for i in n + 1:
		var a := TAU * i / n
		c.add_point(Vector3(8.0 * i / n, r - r * cos(a), z0 - r * sin(a)))
	c.add_point(Vector3(8, 0, -300))
	c.add_point(Vector3(8, 0, -480), Vector3.ZERO, Vector3(0, 0, -70))
	c.add_point(Vector3(138, 0, -480), Vector3(0, 0, -70), Vector3.ZERO)
	# jump hill on the way back
	c.add_point(Vector3(138, 0, -260))
	c.add_point(Vector3(138, 5, -225))
	c.add_point(Vector3(138, 5.5, -205))
	c.add_point(Vector3(138, 0, -170))
	c.add_point(Vector3(138, 0, 40), Vector3.ZERO, Vector3(0, 0, 75))
	c.add_point(Vector3(0, 0, 40), Vector3(0, 0, 75), Vector3.ZERO)
	var p := TrackPath.new(c, true, 16.0)
	p.zones.append({"from": 290.0, "to": 430.0, "kind": "loop"})
	var dj := p.closest_distance(Vector3(138, 5, -215))
	p.zones.append({"from": dj - 40.0, "to": dj + 40.0, "kind": "jump"})
	p.zones.append({"from": 100.0, "to": 130.0, "kind": "boost"})
	return p


static func coast() -> TrackPath:
	var ctrl := [
		[Vector3(0, 32, 0), 0.0], [Vector3(10, 34, -300), 160.0], [Vector3(-60, 30, -620), 180.0],
		[Vector3(30, 26, -950), 200.0], [Vector3(-20, 16, -1250), 150.0], [Vector3(-90, 13, -1450), 120.0],
		[Vector3(-90, 13, -1750), 150.0], [Vector3(20, 22, -2000), 160.0], [Vector3(60, 24, -2350), 180.0],
		[Vector3(0, 28, -2700), 150.0], [Vector3(-30, 30, -3000), 0.0],
	]
	var p := TrackPath.new(rounded(ctrl, false), false, 14.0)
	var db0 := p.closest_distance(Vector3(-90, 13, -1480))
	var db1 := p.closest_distance(Vector3(-90, 13, -1720))
	p.zones.append({"from": db0, "to": db1, "kind": "bridge"})
	var dt0 := p.closest_distance(Vector3(48, 23, -2180))
	var dt1 := p.closest_distance(Vector3(55, 24, -2420))
	p.zones.append({"from": dt0, "to": dt1, "kind": "tunnel"})
	p.set_meta("sea_side", -1.0)   # this sample hugs the sea on its left
	return p


static func for_theme(theme: String) -> TrackPath:
	match theme:
		"arena":
			return arena()
		"coast":
			return coast()
	return city()


## Simple road strip with trimesh collision (the real road comes from the tracks module).
static func road_node(path: TrackPath, theme: String) -> Node3D:
	var root := Node3D.new()
	root.name = "DemoRoad"
	var m := SceneryMesh.new()
	var frames: Array = []
	var d := 0.0
	while d < path.length:
		frames.append(path.sample_transform(d))
		d += 2.0
	frames.append(path.sample_transform(path.length - 0.01))
	var w := 8.0
	var prof := PackedVector2Array([Vector2(-w, 0.0), Vector2(w, 0.0)])
	m.add_loft(prof, frames, Color(1, 1, 1))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.06) if theme != "coast" else Color(0.12, 0.12, 0.13)
	mat.roughness = 0.04 if theme == "city" else 0.5
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := m.to_instance(mat, "RoadMesh")
	root.add_child(mi)
	# centre and edge lines
	var lines := SceneryMesh.new()
	for lat in [-w + 0.4, w - 0.4]:
		lines.add_loft(PackedVector2Array([Vector2(lat - 0.12, 0.02), Vector2(lat + 0.12, 0.02)]), frames, Color(0.9, 0.9, 0.9))
	var lmat := StandardMaterial3D.new()
	lmat.vertex_color_use_as_albedo = true
	lmat.roughness = 0.4
	lmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(lines.to_instance(lmat, "RoadLines"))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	root.add_child(body)
	return root
