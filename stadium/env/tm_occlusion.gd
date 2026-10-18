class_name TmOcclusion
extends Node
## The map's sky occlusion, TM's "Compute Shadows" done our way: when a map is in the scene, one
## ray straight down per CELL m over its field finds the highest collision surface; the heights go
## to a float texture that every surface shader samples (env/tm_occlusion.gdshaderinc,
## tm_sky_visibility) to darken ambient light and reflections under bridges, roofs, loops and
## gates. About 0.6 s for a 32 x 32 map. Off again when the node leaves the scene (menus).

const CELL := 2.0
const TOP := 420.0                  ## rays start here (above the highest block) ...
const BOTTOM := -20.0               ## ... and end here
const NONE := -1000.0               ## the height where nothing was hit

var size := Vector2(1024.0, 1024.0)    ## the field in metres (TMNF x, z)
var texture: ImageTexture
var heights: Image


## The occlusion of a built map, under `parent`; it bakes after the next physics frame (the
## blocks' collision must be in the physics space).
static func add(parent: Node, builder: TmMapBuilder) -> TmOcclusion:
	var o := TmOcclusion.new()
	o.name = "Occlusion"
	o.size = Vector2(builder.challenge.size.x, builder.challenge.size.z) * 32.0
	parent.add_child(o)
	return o


func _ready() -> void:
	if String(TestHooks.arg("occlusion", "1")) == "0":   # comparisons: --occlusion=0 leaves it off
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake()


func bake() -> void:
	var t0 := Time.get_ticks_msec()
	var nx := int(ceil(size.x / CELL)) + 1
	var nz := int(ceil(size.y / CELL)) + 1
	heights = Image.create(nx, nz, false, Image.FORMAT_RF)
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = TmCar.WORLD_MASK
	for j in nz:
		for i in nx:
			# texel i covers Godot x from -size.x (i = 0) towards 0: TMNF x is negated
			var x := -size.x + i * CELL
			var z := j * CELL
			q.from = Vector3(x, TOP, z)
			q.to = Vector3(x, BOTTOM, z)
			var hit := space.intersect_ray(q)
			heights.set_pixel(i, j, Color((hit["position"] as Vector3).y if not hit.is_empty() else NONE, 0, 0))
	texture = ImageTexture.create_from_image(heights)
	RenderingServer.global_shader_parameter_set(&"tm_occl_tex", texture)
	# texel centres on the rays: the rect starts half a cell before the first one
	RenderingServer.global_shader_parameter_set(&"tm_occl_rect",
		Vector4(-size.x - CELL * 0.5, -CELL * 0.5, 1.0 / (nx * CELL), 1.0 / (nz * CELL)))
	RenderingServer.global_shader_parameter_set(&"tm_occl_on", 1.0)
	print("OCCLUSION %dx%d cells in %d ms" % [nx, nz, Time.get_ticks_msec() - t0])


## The baked height at a world point (x, z): the highest collision surface over it, NONE if none.
func height_at(x: float, z: float) -> float:
	if heights == null:
		return NONE
	var i := clampi(roundi((x + size.x) / CELL), 0, heights.get_width() - 1)
	var j := clampi(roundi(z / CELL), 0, heights.get_height() - 1)
	return heights.get_pixel(i, j).r


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"tm_occl_on", 0.0)
