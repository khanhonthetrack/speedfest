class_name StoryCast
## The story's modelled cast (PLAN M20-9): people built by tools/cast/build.sh into assets/cast/<id>/
## (MakeHuman's body through MPFB in Blender, on its 53-bone game-engine rig), retargeted at import
## onto Godot's humanoid skeleton (bonemap.tres, the skeleton renamed GeneralSkeleton), dressed by
## cast_import.gd (a material per role), with a sidecar <id>.cast.json (height, eyes, face shapes,
## materials, the assets it is made of). They all play the UAL library's clips: the Mannequin's
## import retargets them onto the same humanoid skeleton, so one AnimationLibrary serves everyone.

const DIR := "res://assets/cast"

static var _lib: AnimationLibrary
static var _meta := {}
static var _scenes := {}
static var _ground := {}
static var _mannequin_scale := 0.0


## The characters there are (a folder with its glTF).
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(DIR):
		if ResourceLoader.exists(path(d)):
			out.append(d)
	return out


static func has(id: String) -> bool:
	return id != "" and ResourceLoader.exists(path(id))


static func path(id: String) -> String:
	return "%s/%s/%s.gltf" % [DIR, id, id]


## The sidecar: {"height", "head", "eyes", "pelvis" (m, standing), "face_shapes", "materials"
## ({name: {"role", "tint"}}), "triangles", "assets" ([kind/asset])}.
static func meta(id: String) -> Dictionary:
	if not _meta.has(id):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/%s.cast.json" % [DIR, id, id]))
		_meta[id] = d if d is Dictionary else {}
	return _meta[id]


## The UAL library (the Mannequin's clips, on the humanoid skeleton).
static func library() -> AnimationLibrary:
	if _lib == null:
		var n := (load(StoryPerson.GLB) as PackedScene).instantiate()
		_lib = (n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation_library("")
		_mannequin_scale = skeleton(n).motion_scale
		n.free()
	return _lib


## How much longer a character's strides are than the Mannequin's in the same clip: the retarget
## scales the clips' motion by the hips' height (Skeleton3D.motion_scale), so legs, not height.
static func stride(root: Node) -> float:
	library()
	var sk := skeleton(root)
	return sk.motion_scale / _mannequin_scale if sk != null and _mannequin_scale > 0.0 else 1.0


## The character with an AnimationPlayer ("Anim") playing the shared library; null if there is none.
static func instance(id: String) -> Node3D:
	if not has(id):
		return null
	if not _scenes.has(id):
		_scenes[id] = load(path(id))
	var root := (_scenes[id] as PackedScene).instantiate() as Node3D
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	ap.deterministic = true            # a bone the clip has no track for goes back to rest, whatever played before
	root.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", library())
	return root


static func player(root: Node) -> AnimationPlayer:
	return root.get_node_or_null("Anim") as AnimationPlayer


static func skeleton(root: Node) -> Skeleton3D:
	return root.find_child("GeneralSkeleton", true, false) as Skeleton3D


## Sets a face shape (eyeBlinkLeft, jawOpen, viseme_aa, ...) on every part that has it.
static func set_shape(root: Node, shape: String, value: float) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var k := mi.find_blend_shape_by_name(shape)
		if k >= 0:
			mi.set_blend_shape_value(k, value)


## How far to lift the character so its soles meet the ground in a standing clip: the lowest
## skinned point of its feet over 8 frames of the clip, measured once per character and clip. The
## clips are the Mannequin's, retargeted: shoes put soles under MakeHuman's bare feet (Dee's boots
## 1.8 cm), and legs of other proportions fold differently (her crouch, 2.6 cm higher than her Idle).
## Seats place seated people themselves: not for them. Seeks the character's player.
static func ground(id: String, root: Node, clip: String) -> float:
	var key := "%s:%s" % [id, clip]
	if not _ground.has(key):
		_ground[key] = -lowest_sole(root, clip, 8)
	return _ground[key]


## The lowest any skinned vertex of the feet (below 15 cm in the first frame of Idle) goes over
## `samples` frames of the clip, in the character's own frame, skinned on the CPU.
static func lowest_sole(root: Node, clip: String, samples: int) -> float:
	var sk := skeleton(root)
	var ap := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var parts := []
	ap.play("Idle")
	ap.seek(0.0, true)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		for i in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(i)
			var part := [mi.skin, arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_BONES], arr[Mesh.ARRAY_WEIGHTS]]
			var at := _skinned(sk, root, part, range((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
			var low := PackedInt32Array()      # (a packed array read out of an Array is a copy)
			for k in at.size():
				if at[k].y < 0.15:
					low.append(k)
			if not low.is_empty():
				part.append(low)
				parts.append(part)
	ap.play(clip)
	var length := ap.get_animation(clip).length
	var lowest := INF
	for n in samples:
		ap.seek(length * n / samples, true)
		for part: Array in parts:
			for p in _skinned(sk, root, part, part[4]):
				lowest = minf(lowest, p.y)
	return lowest


static func _skinned(sk: Skeleton3D, root: Node, part: Array, which: Variant) -> PackedVector3Array:
	var skin := part[0] as Skin
	var frame := (root as Node3D).global_transform.affine_inverse() * sk.global_transform
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if skin.get_bind_name(b) != &"":
			bone = sk.find_bone(skin.get_bind_name(b))
		mats.append(frame * sk.get_bone_global_pose(maxi(bone, 0)) * skin.get_bind_pose(b))
	var verts := part[1] as PackedVector3Array
	var bones := part[2] as PackedInt32Array
	var weights := part[3] as PackedFloat32Array
	var per := bones.size() / verts.size()
	var out := PackedVector3Array()
	for v: int in which:
		var p := Vector3.ZERO
		for k in per:
			var w := weights[v * per + k]
			if w > 0.0:
				p += (mats[bones[v * per + k]] * verts[v]) * w
		out.append(p)
	return out
