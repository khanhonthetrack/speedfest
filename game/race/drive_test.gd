extends Node3D
## Drivable physics lab: the TestArena, a garage car, the chase camera and a speed readout.
## Keys: arrows/WASD drive, Enter/Backspace = respawn. Test args: --spawn=x,y,z,heading_deg
## --speed=kmh (start speed), plus TmCarInput's --auto_* args and TestHooks' --shot/--frames.

var car: TmCar
var cam: TmCamera
var label: Label
var _spawn := Transform3D()
var _start_kmh := 0.0


func _ready() -> void:
	add_child(TestArena.new())
	car = TmCar.new()
	add_child(car)
	car.configure(String(TestHooks.arg("car", "kaze")), Garage.setup_of(String(TestHooks.arg("car", "kaze"))))
	var rig := CarRig.new(car)
	car.add_child(rig)
	var inp := TmCarInput.new()
	inp.car = car
	add_child(inp)
	var sp := String(TestHooks.arg("spawn", "0,0,0,0")).split(",")
	_spawn = Transform3D(Basis(Vector3.UP, deg_to_rad(float(sp[3]) if sp.size() > 3 else 0.0)),
		Vector3(float(sp[0]), float(sp[1]), float(sp[2])))
	_start_kmh = TestHooks.arg("speed", 0.0)
	_respawn()
	cam = TmCamera.new()
	cam.target = car
	add_child(cam)
	cam.current = true
	cam.snap()
	var cl := CanvasLayer.new()
	add_child(cl)
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 28)
	cl.add_child(label)


func _respawn() -> void:
	car.place(_spawn)
	car.lin_vel = _spawn.basis.z * _start_kmh / 3.6
	if cam:
		cam.snap()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_BACKSPACE):
		_respawn()


func _process(_delta: float) -> void:
	label.text = "%d km/h   sub-steps %d   %s" % [roundi(absf(car.speed_kmh())), car.substeps,
		"ground" if car.wheel_contact.has(true) else "air"]
