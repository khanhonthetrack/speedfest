class_name SceneryRoot
extends Node3D
## Root of SceneryKit.build_props(). When added under a Track that draws its own visible ground,
## avoids two overlapping grounds:
## - city/arena: frees the scenery ground (the track's ground has collision and jump pits);
## - coast: keeps the scenery terrain (palms, rocks, lighthouse and towns sit on it) and hides the
##   track's visual-only "Terrain" node and fallback sea.
## Nodes that are scenery ground carry the meta "scenery_ground".

var theme: String = "city"


func _ready() -> void:
	var track := get_parent()
	if track == null or not ("layout" in track):
		return
	var layout: Dictionary = track.get("layout")
	var ground := String(layout.get("ground", "none"))
	if ground == "none" or not bool(layout.get("ground_visual", true)):
		return
	if theme == "coast":
		var terr := track.get_node_or_null("Terrain")
		if terr is Node3D:
			(terr as Node3D).visible = false
	else:
		for c in get_children():
			if c.has_meta("scenery_ground"):
				c.queue_free()
