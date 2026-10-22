extends Node3D
## Stages our cars on one of our tracks for the home page's picture panels (tools/icons/menu_art.sh
## renders every one of them into assets/ui/menu/): the track built as in a race (sky, Stadium or
## city, the map's mood), cars stood on the road along the bot's line, a camera in the lead car's
## frame with a soft depth of field.
## --track=C05 [--mood=night] --at=0.3 (fraction of the line where the lead car stands)
## --cars="colour:model:left:ahead[:lift[:g[:livery[:tuning]]]];..." (TmUi.CAR_COLOURS index; ""
##   the open-wheeler, "hyper" or a road car (TmRoadCars); metres to the left of the line and ahead
##   of the lead car, metres over the road (a jump); "g" draws it as a ghost ("-" not); its livery;
##   its tuning as "spoiler.rims.glow.hood" indices (TmRoadCars.TUNING))
## --cam=x,y,z --look=x,y,z (the lead car's frame: x left, y up, z ahead, m) [--fov=40] [--roll=deg]
## [--dof=far_m,transition_m,amount] [--sun=azimuth,elevation (degrees: a lower sun than the
## mood's)] [--grid (the editor's 32 m cells over the field)] --frames=N --shot=/abs.png

var builder: TmMapBuilder
var _lead := Transform3D()


func _ready() -> void:
	var ch := TmStage.load_from_args()
	if not ch.ok() or ch.path.is_empty():
		push_error("menu_art: %s" % ("no line on this track" if ch.ok() else ch.error))
		TestHooks.finish()
		return
	builder = TmMapBuilder.build(ch)
	add_child(builder.root)
	TmStage.add_environment(self, builder)
	await get_tree().physics_frame     # the road's collision is in the physics space
	var i := clampi(int(float(TestHooks.arg("at", 0.3)) * (ch.path.size() - 1)), 0, ch.path.size() - 1)
	_lead = _on_road(ch.path, i, 0.0, 0.0)
	for spec: String in String(TestHooks.arg("cars", "0:hyper:0:0")).split(";", false):
		var f := spec.split(":")
		var car := TmCarVisual.new()
		car.paint_colour = TmUi.CAR_COLOURS[clampi(int(f[0]), 0, TmUi.CAR_COLOURS.size() - 1)]
		car.model = f[1] if f.size() > 1 else "hyper"
		car.ghost = f.size() > 5 and f[5] == "g"
		car.livery = int(f[6]) if f.size() > 6 else 0
		if f.size() > 7:
			var picks := f[7].split(".")
			for k in mini(picks.size(), TmRoadCars.TUNING.size()):
				car.tuning[TmRoadCars.TUNING[k]] = int(picks[k])
		add_child(car)
		var at := _on_road(ch.path, i, float(f[2]) if f.size() > 2 else 0.0, float(f[3]) if f.size() > 3 else 0.0)
		var lift := float(f[4]) if f.size() > 4 else 0.0
		car.global_transform = Transform3D(at.basis, at * (TmCarVisual.VIS + Vector3(0.0, lift, 0.0)))
	_sun()
	if TestHooks.has_arg("grid"):
		_grid()
	_camera()


## The track editor's cells (32 m) over the whole field, white lines faintly violet.
func _grid() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1024, 1024)
	g.mesh = pm
	g.position = TmMenu.CENTRE + Vector3(0.0, 0.06, 0.0)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = abs(fract(world.xz / 32.0 + 0.5) - 0.5) * 32.0;
	float w = fwidth(world.x) * 1.2 + 0.08;
	float line = 1.0 - smoothstep(0.0, w, min(c.x, c.y));
	ALBEDO = vec3(0.85, 0.82, 1.0);
	ALPHA = line * 0.55;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	g.material_override = m
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


## --sun=azimuth,elevation: the sun turned round the field and lowered (long shadows, rim light).
func _sun() -> void:
	var v := String(TestHooks.arg("sun", "")).split(",")
	if v.size() != 2:
		return
	for l: DirectionalLight3D in find_children("*", "DirectionalLight3D", true, false):
		l.rotation = Vector3(-deg_to_rad(float(v[1])), deg_to_rad(float(v[0])), 0.0)
		return


## A place on the road: `ahead` metres along the line from its point i, `left` metres to its left,
## on the road's surface (a ray down), the road's normal up and the line's direction ahead.
func _on_road(path: Array, i: int, left: float, ahead: float) -> Transform3D:
	var j := i
	var walked := 0.0
	var step := 1 if ahead >= 0.0 else -1
	while absf(walked) < absf(ahead) and j + step >= 0 and j + step < path.size():
		walked += (path[j + step]["p"] as Vector3).distance_to(path[j]["p"])
		j += step
	var p: Vector3 = path[j]["p"]
	var d: Vector3 = (path[j]["dir"] as Vector3).normalized()
	var side := Vector3.UP.cross(d).normalized()          # the line's left (x left, z ahead)
	p += side * left
	var up := Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p - Vector3.UP * 6.0, TmCar.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		p = hit["position"]
		up = hit["normal"]
	var z := (d - up * d.dot(up)).normalized()
	return Transform3D(Basis(up.cross(z), up, z), p)


static func _vec(arg: String, fallback: Vector3) -> Vector3:
	var v := String(TestHooks.arg(arg, "")).split(",")
	return Vector3(float(v[0]), float(v[1]), float(v[2])) if v.size() == 3 else fallback


func _camera() -> void:
	var cam := Camera3D.new()
	cam.far = TmSkyline.FAR
	cam.fov = float(TestHooks.arg("fov", 40.0))
	add_child(cam)
	var b := _lead.basis
	cam.global_position = _lead * _vec("cam", Vector3(4.0, 1.2, 6.0))
	cam.look_at(_lead * _vec("look", Vector3(0.0, 0.6, 0.0)), b.y)
	cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(float(TestHooks.arg("roll", 0.0))))
	var d := String(TestHooks.arg("dof", "")).split(",")
	if d.size() == 3:
		var at := CameraAttributesPractical.new()
		at.dof_blur_far_enabled = true
		at.dof_blur_far_distance = float(d[0])
		at.dof_blur_far_transition = float(d[1])
		at.dof_blur_amount = float(d[2])
		cam.attributes = at
	cam.current = true
