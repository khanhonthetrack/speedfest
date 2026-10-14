extends Node3D
## STUB: the race module replaces this with the Time Attack run logic.
## See docs/ARCHITECTURE.md "Race". This stub builds the track and a car with a fixed camera.

var track: Track
var car: Car


func _ready() -> void:
	track = Track.build(Game.track_id)
	add_child(track)
	car = Car.create(Profile.get_config())
	add_child(car)
	car.global_transform = track.get_start_transform()
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = car.global_position + Vector3(0, 3, 8)
	cam.look_at(car.global_position)
