class_name InterpAnchor
extends Node3D
## Holder for world-space particle emitters on a physics-interpolated body (the local Car).
## A world-space emitter under an interpolated parent emits from the drawn pose but converts its
## particles with the newest-tick transform and is drawn at the interpolated one, so the whole
## cloud jitters by up to one tick of travel (~1.3 m at 280 km/h) on 120-240 Hz screens. This node
## is top-level and not interpolated: every frame it copies the parent's drawn pose (times
## `offset`), so emission, conversion and drawing agree. Works under non-interpolated parents too.

var offset := Transform3D.IDENTITY


func _init() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _enter_tree() -> void:
	follow()


func _process(_delta: float) -> void:
	follow()


func follow() -> void:
	var p := get_parent() as Node3D
	if p != null and p.is_inside_tree():
		global_transform = p.get_global_transform_interpolated() * offset
