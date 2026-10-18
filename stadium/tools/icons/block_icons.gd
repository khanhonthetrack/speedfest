extends Node
## Renders the track editor's palette icons: every block the editor offers (TmEditor.palette_ids),
## built from the recreated library, seen from above at an angle, lit, on a transparent
## background, into assets/ui/blocks/<block id>.png (our own renders of our own geometry).
## Run under a renderer (Forward+): stadium/tools/run.sh res://tools/icons/block_icons.tscn
## [-- --only=StadiumRoadMain,StadiumPlatformRoad], then python3 stadium/tools/icons/shrink.py

const SIZE := Vector2i(192, 128)
const OUT := "res://assets/ui/blocks"

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE * 2
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.3
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_run.call_deferred()


func _run() -> void:
	var lib := TmBlockLib.new()
	var pal := TmEditor.palette_ids(lib)
	var ids := {}
	for cat: int in pal:
		for id: String in pal[cat]:
			ids[id] = true
	var only := String(TestHooks.arg("only", ""))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0
	for id: String in ids:
		if not only.is_empty() and not only.split(",").has(id):
			continue
		var entry := TmBlockCatalogue.info(id)
		var shape := TmEditor.icon_shape(id)
		var ground := TmBlockCatalogue.shape_name(entry, false, 3 if TmUserTracks.is_road(id) else 0, 0).is_empty()
		var node := lib.make(shape, entry, ground)
		if node == null:
			continue
		for c in _holder.get_children():
			c.free()
		_holder.add_child(node)
		_frame(node)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(OUT.path_join(id + ".png")))
		n += 1
	print("BLOCK_ICONS %d" % n)
	get_tree().quit()


## The camera at a fixed angle (from the front right, above), sized to the block's bounds.
func _frame(node: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var centre := box.get_center()
	var dir := Vector3(-1.0, 0.85, 1.25).normalized()
	_cam.size = maxf(box.size.length() * 0.74, 8.0)
	_cam.near = 0.1
	_cam.far = 2000.0
	_cam.global_transform = Transform3D(Basis(), centre + dir * (box.size.length() + 50.0)).looking_at(centre, Vector3.UP)
