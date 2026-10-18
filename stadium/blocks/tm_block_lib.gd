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
	"res://blocks/shapes/fabric.gd", "res://blocks/shapes/sculpt.gd"]


func _init() -> void:
	for path in FAMILIES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			load_errors.append(path)
			continue
		register(script.new())


func register(family: Object) -> void:
	_families.append(family)


## Whether a family recreates this shape (without building it).
func handles(shape: String) -> bool:
	if shape.is_empty():
		return false
	for fam in _families:
		if fam.handles(shape):
			return true
	return false


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
	if made != null and TmRefVisuals.active():
		var ref := TmRefVisuals.visual(shape)    # research: the original's look, our collision
		if ref != null:
			for c in made.get_children():
				if c is MeshInstance3D:
					made.remove_child(c)
					c.free()
			made.add_child(ref)
	_cache[shape] = made
	return null if made == null else made.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for t: Variant in _cache.values():
			if t != null:
				(t as Node3D).free()
		_cache.clear()
