class_name SceneryArenaKit
extends RefCounted
## "arena" theme props (WIP).

var field: SceneryField
var root: Node3D


func build(p_field: SceneryField, _rng_seed: int) -> Node3D:
	field = p_field
	root = Node3D.new()
	return root
