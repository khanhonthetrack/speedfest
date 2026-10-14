class_name AutoDriver
extends Node
## STUB: the car-physics module implements a path-following bot (tests, demos).
## Add as a child of a Car and set `path`; it fills car.controls each physics tick.

var path: TrackPath
var target_speed_kmh := 160.0


func _physics_process(_delta: float) -> void:
	var car := get_parent() as Car
	if car == null or path == null:
		return
	car.controls["throttle"] = 1.0
