extends Node3D
## Looks at the tyre smoke (TmTyreMarks' puffs and marks) without a race: a car on a straight road,
## its wheels locked, braking from --kmh (140) at --decel m/s^2 (9), seen from behind as the race
## camera does (--view=chase) or from beside the road (--view=side); --surface=asphalt|dirt|grass.
## --frames=N --shot=/abs.png for a screenshot (100 frames a second: tools/run.sh), or
## --shots=a.png@60,b.png@150.

const T := preload("res://core/tm_tuning.gd")
const SURFACES := {"asphalt": T.Surface.ASPHALT, "dirt": T.Surface.DIRT, "grass": T.Surface.GRASS}
const BLOCKS := 14                 ## road blocks along +z, from 64 m behind the car
const TOP := 1.345                 ## the road's surface over its block's floor (blocks/shapes/road.gd)

var car: TmCar
var marks: TmTyreMarks
var cam: Camera3D
var speed := 0.0                   ## m/s
var decel := 9.0
var surface: int = T.Surface.ASPHALT
var view := "chase"


func _ready() -> void:
	TmStadiumEnv.add(self)
	var lib := TmBlockLib.new()
	for k in BLOCKS:
		var road := lib.make("Road/Main/StraightGround", {}, true)
		road.position = Vector3(16.0, -TOP, 32.0 * k - 64.0)    # the road's centre line on x = 0, its top at y = 0
		add_child(road)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	ground.mesh = pm
	ground.position.y = -TOP
	ground.material_override = TmMaterials.get_material("grass")
	add_child(ground)
	speed = float(TestHooks.arg("kmh", 140.0)) / 3.6
	decel = float(TestHooks.arg("decel", 9.0))
	surface = SURFACES.get(String(TestHooks.arg("surface", "asphalt")), T.Surface.ASPHALT)
	view = String(TestHooks.arg("view", "chase"))
	car = TmCar.new()
	add_child(car)
	car.set_physics_process(false)    # moved by hand below (after add_child, which turns it back on)
	var look := TmCarVisual.new()
	look.paint_colour = TmUi.car_colour()
	car.add_child(look)
	car.place(Transform3D.IDENTITY)
	marks = TmTyreMarks.new()          # after the car: it reads each tick's car
	marks.car = car
	add_child(marks)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.current = true


func _physics_process(delta: float) -> void:
	speed = maxf(0.0, speed - decel * delta)
	var xf := car.transform
	xf.origin.z += speed * delta
	car.transform = xf
	var b := car.body
	b.xform = xf
	b.lin_vel = Vector3(0.0, 0.0, speed)
	b.ang_vel = Vector3.ZERO
	for i in 4:
		var w: Vector3 = T.WHEELS[i]
		b.wheel_contact[i] = true
		b.wheel_surface[i] = surface
		b.wheel_hit_n[i] = Vector3.UP
		b.wheel_hit_pos[i] = Vector3(w.x, 0.0, xf.origin.z + w.z)
		car.model.sliding[i] = speed > 1.0
	var at := xf.origin
	if view == "side":
		cam.look_at_from_position(at + Vector3(-7.0, 1.4, 3.0), at + Vector3(0.0, 0.5, -2.0))
	else:
		cam.look_at_from_position(at + Vector3(0.0, 2.3, -6.5), at + Vector3(0.0, 0.7, 4.0))
