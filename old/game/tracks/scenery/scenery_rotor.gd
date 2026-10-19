class_name SceneryRotor
extends Node3D
## Spins its children around the world Y axis (searchlights, lighthouse beam).

var speed: float = 0.3      # turns per second
var phase: float = 0.0


func _process(delta: float) -> void:
	phase += speed * TAU * delta
	rotation.y = phase
