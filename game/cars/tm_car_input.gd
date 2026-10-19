class_name TmCarInput
extends Node
## Player controls for a TmCar: keyboard (arrows / WASD) and gamepad, TMNF style. Keyboard steering is
## digital (-1/0/+1); the car model slews it at 20/s. Pad: left stick (analog), triggers or A/X.
## Scripted input for tests: --auto_gas=1 --auto_steer=0.3 --auto_brake=0 --auto_boost=1 (user args).

@export var car: TmCar

var _auto := false
var _auto_gas := 0.0
var _auto_brake := 0.0
var _auto_steer := 0.0
var _auto_boost := false


func _ready() -> void:
	add_to_group("car_input")
	process_physics_priority = -10   # before the car's tick
	if TestHooks.has_arg("auto_gas") or TestHooks.has_arg("auto_steer") or TestHooks.has_arg("auto_brake"):
		_auto = true
		_auto_gas = TestHooks.arg("auto_gas", 0.0)
		_auto_brake = TestHooks.arg("auto_brake", 0.0)
		_auto_steer = TestHooks.arg("auto_steer", 0.0)
		_auto_boost = bool(TestHooks.arg("auto_boost", false))


func _physics_process(_delta: float) -> void:
	if car == null:
		return
	if _auto:
		car.gas = _auto_gas
		car.brake = _auto_brake
		car.steer = _auto_steer
		car.boost_input = _auto_boost
		return
	var gas := 0.0
	var brake := 0.0
	var steer := 0.0
	car.boost_input = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE)
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		gas = 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		brake = 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		steer -= 1.0
	for pad in Input.get_connected_joypads():
		var sx := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		if absf(sx) > 0.12:
			steer = -sx
		gas = maxf(gas, Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT))
		brake = maxf(brake, Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT))
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_A):
			gas = 1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_X):
			brake = 1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_B) or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER):
			car.boost_input = true
	car.gas = gas
	car.brake = brake
	car.steer = clampf(steer, -1.0, 1.0)
