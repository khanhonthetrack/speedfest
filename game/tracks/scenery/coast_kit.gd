class_name SceneryCoastKit
extends RefCounted
## "coast" theme props (WIP).

const SEA_LEVEL := 0.0

var field: SceneryField
var root: Node3D


func build(p_field: SceneryField, _rng_seed: int) -> Node3D:
	field = p_field
	root = Node3D.new()
	return root
