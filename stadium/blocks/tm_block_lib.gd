class_name TmBlockLib
extends RefCounted
## The recreated Stadium blocks: shape name (as in the catalogue, e.g. "Road/Main/StraightAir") ->
## a generated Node3D in block-local space (Godot coordinates: x = -TMNF x, origin at the block's
## unit (0, 0, 0) corner; one unit = 32 x 8 x 32 m). Collision bodies carry per-face surface ids
## (meta "surfaces") for TmBody. Families live in blocks/shapes/; unknown shapes return null.

var _families: Array = []          ## objects with handles(shape) -> bool and make(shape, entry, ground)
var _cache := {}                   ## shape name -> PackedScene-like template (Node3D), duplicated
var load_errors: Array[String] = []  ## family scripts that failed to load (a parse error)


const FAMILIES := ["res://blocks/shapes/circuit.gd", "res://blocks/shapes/tube.gd",
	"res://blocks/shapes/platform.gd", "res://blocks/shapes/road.gd", "res://blocks/shapes/zone.gd",
	"res://blocks/shapes/control.gd", "res://blocks/shapes/inflatable.gd", "res://blocks/shapes/dirt.gd",
	"res://blocks/shapes/fabric.gd"]


func _init() -> void:
	for path in FAMILIES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			load_errors.append(path)
			continue
		register(script.new())


func register(family: Object) -> void:
	_families.append(family)


func make(shape: String, entry: Dictionary, ground: bool) -> Node3D:
	if shape.is_empty():
		return null
	if _cache.has(shape):
		var t: Node3D = _cache[shape]
		return null if t == null else t.duplicate()
	var made: Node3D = null
	for fam in _families:
		if fam.handles(shape):
			made = fam.make(shape, entry, ground)
			break
	_cache[shape] = made
	return null if made == null else made.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for t: Variant in _cache.values():
			if t != null:
				(t as Node3D).free()
		_cache.clear()
