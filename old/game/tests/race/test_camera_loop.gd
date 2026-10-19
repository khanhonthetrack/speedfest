extends Node3D
## ChaseCamera through a vertical loop (r = 18 m) and a banked turn with a scripted target.
## Headless: checks that the camera stays behind the car with an up vector close to the car's
## (no flips at the top of the loop). With rendering: screenshots via --shots.
## Run: tools/run_scene.sh res://tests/race/test_camera_loop.tscn --headless -- --frames=2000
##      tools/run_scene.sh res://tests/race/test_camera_loop.tscn -- --shots=/abs/a.png@200,/abs/b.png@260 --frames=270

const SPEED := 40.0
const R := 18.0

var path: TrackPath
var target: RigidBody3D
var cam: ChaseCamera
var d := 0.0
var min_up_dot := 1.0
var min_behind := 1.0
var max_flip := 0.0
var prev_cam_up := Vector3.ZERO
var checked := 0
var mode := 0


func _ready() -> void:
	mode = int(TestHooks.arg("cam_mode", 0))
	path = _build_path()
	_build_road()
	target = RigidBody3D.new()
	target.freeze = true
	target.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	target.collision_layer = 0
	target.collision_mask = 0
	var vis := CarVisual.new()
	target.add_child(vis)
	vis.build("kaze", CarDefs.default_style("kaze"))
	add_child(target)
	cam = ChaseCamera.new()
	add_child(cam)
	cam.set_mode(mode)
	cam.set_target(target)
	_place(0.0)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	add_child(light)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.6)
	we.environment = env
	add_child(we)


func _build_path() -> TrackPath:
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 60))
	c.add_point(Vector3(0, 0, 0))
	# Vertical loop in the YZ plane going forward (-Z), drifting +X so it doesn't self-intersect.
	var n := 16
	for i in range(1, n):
		var a := TAU * i / n
		c.add_point(Vector3(6.0 * i / n, R - cos(a) * R, -sin(a) * R))
	c.add_point(Vector3(6, 0, 0))
	c.add_point(Vector3(6, 0, -60))
	# Banked right-hander.
	c.add_point(Vector3(30, 0, -100))
	c.add_point(Vector3(70, 0, -100))
	c.set_point_tilt(5, 0.0)
	c.set_point_tilt(6, 0.5)
	c.set_point_tilt(7, 0.0)
	for i in c.point_count:
		var prev := c.get_point_position(maxi(i - 1, 0))
		var next := c.get_point_position(mini(i + 1, c.point_count - 1))
		var tan := (next - prev) * 0.25
		if i >= 2 and i <= n:
			c.set_point_in(i, -tan)
			c.set_point_out(i, tan)
	var p := TrackPath.new(c, false, 12.0)
	return p


func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.0
	var dd := 0.0
	while dd < path.length - step:
		var a := path.sample_transform(dd)
		var b := path.sample_transform(dd + step)
		var w := 6.0
		var a0 := a.origin - a.basis.x * w
		var a1 := a.origin + a.basis.x * w
		var b0 := b.origin - b.basis.x * w
		var b1 := b.origin + b.basis.x * w
		st.set_normal(a.basis.y)
		st.set_color(Color(0.2, 0.2, 0.25) if int(dd / 4.0) % 2 == 0 else Color(0.3, 0.3, 0.38))
		for v in [a0, b0, a1, a1, b0, b1]:
			st.add_vertex(v)
		dd += step
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)


func _place(dist: float) -> void:
	var xf := path.sample_transform(dist)
	xf.origin += xf.basis.y * 0.32
	target.global_transform = xf
	target.linear_velocity = -xf.basis.z * SPEED


func _physics_process(delta: float) -> void:
	d = minf(d + SPEED * delta, path.length - 1.0)
	_place(d)


func _process(_delta: float) -> void:
	if d < 5.0:
		return
	# The camera updates itself in _process; measure after it (deferred).
	_measure.call_deferred()
	if d >= path.length - 1.0 and not TestHooks.has_arg("shots"):
		_report()


func _measure() -> void:
	var car_up := target.global_transform.basis.y
	var cam_up := cam.global_transform.basis.y
	min_up_dot = minf(min_up_dot, car_up.dot(cam_up))
	var to_car := (target.global_position - cam.global_position).normalized()
	if mode >= 2: # bumper/hood: the camera looks where the car goes
		to_car = -cam.global_transform.basis.z
	min_behind = minf(min_behind, to_car.dot(-target.global_transform.basis.z))
	if prev_cam_up != Vector3.ZERO:
		max_flip = maxf(max_flip, prev_cam_up.angle_to(cam_up))
	prev_cam_up = cam_up
	checked += 1


var _reported := false
func _report() -> void:
	if _reported:
		return
	_reported = true
	print("camera loop: frames=%d min_up_dot=%.3f min_behind=%.3f max_up_step=%.3f rad" % [checked, min_up_dot, min_behind, max_flip])
	TestHooks.check(checked > 100, "camera_measured")
	TestHooks.check(min_up_dot > 0.5, "camera_up_follows_car", "min dot %.3f" % min_up_dot)
	TestHooks.check(min_behind > (0.3 if mode < 2 else 0.8), "camera_stays_behind", "min %.3f" % min_behind)
	TestHooks.check(max_flip < 0.12, "camera_no_flip", "max up change per frame %.3f rad" % max_flip)
	TestHooks.finish()
