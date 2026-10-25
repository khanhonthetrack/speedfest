class_name StoryCast
## The story's modelled cast (PLAN M20-9): people built by tools/cast/build.sh into assets/cast/<id>/
## (MakeHuman's body through MPFB in Blender, on its 53-bone game-engine rig), retargeted at import
## onto Godot's humanoid skeleton (bonemap.tres, the skeleton renamed GeneralSkeleton), dressed by
## cast_import.gd (a material per role), with a sidecar <id>.cast.json (height, eyes, face shapes,
## materials, the assets it is made of). They all play the UAL library's clips: the Mannequin's
## import retargets them onto the same humanoid skeleton, so one AnimationLibrary serves everyone.

const DIR := "res://assets/cast"
const HBM := "res://assets/anim/human_basic_motions/Animations/"
## How people stand: Human Basic Motions' idles and talk (Kevin Iglesias; retargeted onto the humanoid
## skeleton at import through bonemap_hbm.tres), feet together, weight shifting; the UAL library's Idle
## stands ready for a fight (the owner, 25 Oct: "they are not planning to fight").
const STAND := {
	"Stand_F": HBM + "Female/Idles/HumanF@Idle01.fbx", "Stand_M": HBM + "Male/Idles/HumanM@Idle01.fbx",
	"Stand_B_F": HBM + "Female/Idles/HumanF@Idle02.fbx", "Stand_B_M": HBM + "Male/Idles/HumanM@Idle02.fbx",
	"Stand_Talk_F": HBM + "Female/Social/Conversation/HumanF@Talk01.fbx",
	"Stand_Talk_M": HBM + "Male/Social/Conversation/HumanM@Talk01.fbx",
}
const ARMS_IN := 13.0           ## degrees the idles' upper arms turn in (_arms_in)
const TALK_ARMS := 0.5          ## how much of the talk's arm gestures is kept (_calm)

static var _lib: AnimationLibrary
static var _meta := {}
static var _scenes := {}
static var _ground := {}
static var _seated := {}
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


## The UAL library (the Mannequin's clips, on the humanoid skeleton), with Human Basic Motions'
## standing takes added (STAND). The Mannequin's own player holds the same library, so it has them too.
static func library() -> AnimationLibrary:
	if _lib == null:
		var n := (load(StoryPerson.GLB) as PackedScene).instantiate()
		_lib = (n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation_library("")
		_mannequin_scale = skeleton(n).motion_scale
		n.free()
		for clip: String in STAND:
			if _lib.has_animation(clip) or not ResourceLoader.exists(STAND[clip]):
				continue
			var s := (load(STAND[clip]) as PackedScene).instantiate()
			var ap := s.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var a := ap.get_animation(ap.get_animation_list()[0])
			a.loop_mode = Animation.LOOP_LINEAR
			if clip.contains("Talk"):         # (after the idles: STAND lists them first)
				_calm(a, _lib.get_animation(clip.replace("Talk_", "")), TALK_ARMS)
			else:
				_arms_in(a, ARMS_IN)
			_lib.add_animation(clip, a)
			s.free()
	return _lib


## The takes hold the upper arms about 20 degrees out from the sides (24 on our bodies: an A-pose);
## turned in about each upper arm's own x (the humanoid profile's axes, the same for both sides).
static func _arms_in(a: Animation, degrees: float) -> void:
	var q := Quaternion(Vector3.RIGHT, deg_to_rad(degrees))
	for t in a.get_track_count():
		var bone := String(a.track_get_path(t).get_concatenated_subnames())
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or not bone in ["LeftUpperArm", "RightUpperArm"]:
			continue
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Quaternion) * q)


## The talk take throws both arms wide, palms up, every 2.3 s: on a loop under every line, a shrug
## that never stops. Its arms and hands are brought `keep` of the way from the idle's first pose
## towards their own (the head and the body talk as they do; the face does the rest).
static func _calm(talk: Animation, idle: Animation, keep: float) -> void:
	for t in talk.get_track_count():
		var bone := String(talk.track_get_path(t).get_concatenated_subnames())
		if talk.track_get_type(t) != Animation.TYPE_ROTATION_3D or not (bone.contains("Arm") or bone.contains("Hand")
				or bone.contains("Shoulder") or bone.contains("Thumb") or bone.contains("Index") or bone.contains("Middle")
				or bone.contains("Ring") or bone.contains("Little")):
			continue
		var it := idle.find_track(talk.track_get_path(t), Animation.TYPE_ROTATION_3D)
		if it < 0:
			continue
		var rest := idle.rotation_track_interpolate(it, 0.0)
		for k in talk.track_get_key_count(t):
			talk.track_set_key_value(t, k, rest.slerp(talk.track_get_key_value(t, k) as Quaternion, keep))


## A scene's clip for this person: "Stand", "Stand_B" and "Stand_Talk" are a woman's or a man's take
## (the cast's sidecar "sex"; the Mannequin a man's); any other name as it is.
static func take(id: String, clip: String) -> String:
	if not clip in ["Stand", "Stand_B", "Stand_Talk"]:
		return clip
	return clip + ("_F" if id != "" and String(meta(id).get("sex", "m")) == "f" else "_M")


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


## A seated character's body in a clip, in its own frame (it faces +z), skinned on the CPU in the
## clip's first frame: "seat" (y: the lowest point of what it sits on, the hips and thighs under the
## hip joints and behind the knees (the shins and a jacket's front hem over the knees are not sat on),
## what hangs free left out (loose); z: the back of it, against the seat's back)
## and "crown" (the top of its head, hair and all, and how far along). Measured once per character and clip (id "": the Mannequin); {} (and a
## warning) for a body that can't be measured (no humanoid skeleton, nothing under the hips): its
## callers then sit it as the Mannequin sits. Seeks the character's player.
static func seated(id: String, root: Node, clip: String) -> Dictionary:
	var key := "%s:%s" % [id, clip]
	if _seated.has(key):
		return _seated[key]
	var sk := skeleton(root)
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if sk == null or sk.find_bone("Hips") < 0 or players.is_empty():
		push_warning("story: %s can't be measured seated (no humanoid skeleton)" % (id if id != "" else "the Mannequin"))
		_seated[key] = {}
		return _seated[key]
	var ap := players[0] as AnimationPlayer
	ap.play(clip)
	ap.seek(0.0, true)
	var sits := {}
	for b in ["Hips", "LeftUpperLeg", "RightUpperLeg"]:
		if sk.find_bone(b) >= 0:
			sits[sk.find_bone(b)] = true
	var frame := (root as Node3D).global_transform.affine_inverse() * sk.global_transform
	var hip_y := (frame * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin.y
	var knee_z := INF
	for b in ["LeftLowerLeg", "RightLowerLeg"]:
		if sk.find_bone(b) >= 0:
			knee_z = minf(knee_z, (frame * sk.get_bone_global_pose(sk.find_bone(b))).origin.z)
	var seat := Vector2(INF, INF)
	var crown := Vector2(-INF, 0.0)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		for i in mi.mesh.get_surface_count():
			var free := loose(id, mi.mesh.surface_get_material(i))
			var arr := mi.mesh.surface_get_arrays(i)
			var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var part := [mi.skin, verts, arr[Mesh.ARRAY_BONES], arr[Mesh.ARRAY_WEIGHTS]]
			var at := _skinned(sk, root, part, range(verts.size()))
			var bones := part[2] as PackedInt32Array
			var weights := part[3] as PackedFloat32Array
			var per := bones.size() / verts.size()
			for v in at.size():
				if at[v].y > crown.x:
					crown = Vector2(at[v].y, at[v].z)
				if free or at[v].y > hip_y or at[v].z > knee_z - 0.15:
					continue
				var best := 0
				for k in per:
					if weights[v * per + k] > weights[v * per + best]:
						best = k
				if sits.has(_bone_of(sk, mi.skin, bones[v * per + best])):
					seat = Vector2(minf(seat.x, at[v].y), minf(seat.y, at[v].z))
	if not (seat.is_finite() and crown.is_finite()):
		push_warning("story: %s can't be measured seated (nothing under its hips)" % (id if id != "" else "the Mannequin"))
		_seated[key] = {}
		return _seated[key]
	_seated[key] = {"seat": seat, "crown": crown}
	return _seated[key]


## The Mannequin seated in a clip (seated), measured on one made for it under `parent` (in the tree):
## where everyone's seat rests, the seats being laid out for it (StoryCabin).
static func mannequin_seated(parent: Node, clip: String) -> Dictionary:
	if not _seated.has(":" + clip):
		var m := (load(StoryPerson.GLB) as PackedScene).instantiate()
		parent.add_child(m)
		seated("", m, clip)
		m.free()
	return _seated[":" + clip]


## Whether a material of a character hangs free (its spec's "loose": a long coat's skirt draped between
## the thighs is pressed flat by a seat, so it is not what the character sits on).
static func loose(id: String, m: Material) -> bool:
	if id == "" or m == null:
		return false
	return bool(((meta(id).get("materials", {}) as Dictionary).get(m.resource_name, {}) as Dictionary).get("loose", false))


static func _bone_of(sk: Skeleton3D, skin: Skin, bind: int) -> int:
	return sk.find_bone(skin.get_bind_name(bind)) if skin.get_bind_name(bind) != &"" else skin.get_bind_bone(bind)


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
		mats.append(frame * sk.get_bone_global_pose(maxi(_bone_of(sk, skin, b), 0)) * skin.get_bind_pose(b))
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
