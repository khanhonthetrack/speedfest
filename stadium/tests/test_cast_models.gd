extends Node3D
## The story's modelled cast (StoryCast, PLAN M20-9; built by tools/cast/build.sh): every character in
## assets/cast/ loads on Godot's humanoid skeleton with the bones the UAL clips drive, each surface in
## its role's material (skin with subsurface scattering, hair/brows/lashes blended over a depth
## pre-pass, the rest opaque), the face shapes its sidecar lists on the parts that move with them,
## within the budgets (triangles, megabytes), credited (CREDITS.md names every asset it is made of);
## it stands as tall as built; lifted by StoryCast.ground (a few centimetres: shoes, other legs) its
## soles meet the ground in the standing clips (Idle, Walk, Crouch_Idle: the skinned mesh's lowest
## point, measured as the Mannequin's is), and the shared clips pose it the same whichever order a
## cutscene seeks in.
## Run: stadium/tools/run.sh res://tests/test_cast_models.tscn --headless

const BONES := ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg",
	"RightLowerLeg", "RightFoot", "RightToes"]
const CLIPS := ["Idle", "Walk", "Crouch_Idle"]
const MAX_TRIANGLES := 70000          ## a lead on a strong PC (the owner's target); crowds get a lighter tier
const MAX_MB := 12.0                 ## its mesh and every texture it uses
const FEET_TOLERANCE := 0.015        ## m, the soles off the ground at worst, lifted
const MAX_LIFT := 0.07               ## m either way (a crouch can lower): more means the retarget is broken


func _ready() -> void:
	var ids := StoryCast.ids()
	TestHooks.check(ids.size() >= 1 and ids.has("dee"), "cast_listed", str(ids))
	var mannequin := (load(StoryPerson.GLB) as PackedScene).instantiate() as Node3D
	add_child(mannequin)
	# the soles' measure itself: the Mannequin stands on the ground in Idle
	var m_idle := StoryCast.lowest_sole(mannequin, "Idle", 4)
	TestHooks.check(absf(m_idle) < 0.01, "cast_soles_measured", "the Mannequin's soles at %.4f m in Idle" % m_idle)
	var credits := FileAccess.get_file_as_string(StoryCast.DIR + "/CREDITS.md")
	for id in ids:
		var meta := StoryCast.meta(id)
		var root := StoryCast.instance(id)
		add_child(root)
		var sk := StoryCast.skeleton(root)
		var ap := StoryCast.player(root)
		TestHooks.check(sk != null and ap != null and not meta.is_empty(), "cast_%s_loads" % id,
			"skeleton %s, meta %d keys" % [sk, meta.size()])
		if sk == null or ap == null:
			root.free()
			continue
		var missing := BONES.filter(func(b: String) -> bool: return sk.find_bone(b) < 0)
		TestHooks.check(missing.is_empty(), "cast_%s_humanoid_bones" % id, "missing %s" % [missing])
		# every track of the clips cutscenes use reaches a bone (else that part of the body stays put)
		var lost := {}
		for clip in CLIPS + ["Sitting_Idle", "Driving", "Idle_Talking"]:
			var a := ap.get_animation(clip)
			if a == null:
				lost[clip] = "no clip"
				continue
			for t in a.get_track_count():
				var bone := String(a.track_get_path(t).get_concatenated_subnames())
				if bone != "" and sk.find_bone(bone) < 0 and BONES.has(bone):
					lost[bone] = clip
		TestHooks.check(lost.is_empty(), "cast_%s_clips_reach_bones" % id, str(lost))
		_materials(id, root, meta)
		_shapes(id, root, meta)
		_budget(id, root, meta)
		var unlisted: Array = (meta.get("assets", []) as Array).filter(func(a: String) -> bool:
			return not credits.contains("**%s**" % a.get_slice("/", 1)))
		TestHooks.check(meta.has("assets") and unlisted.is_empty(), "cast_%s_credited" % id, "not in CREDITS.md: %s" % [unlisted])
		# standing height: the head bone in Idle where the build measured it
		var idle_lift := StoryCast.ground(id, root, "Idle")
		ap.play("Idle")
		ap.seek(0.0, true)
		var head := _bone_y(sk, "Head") + idle_lift
		TestHooks.check(absf(head - float(meta.get("head", 0.0))) < 0.04, "cast_%s_stands_as_built" % id,
			"head %.3f m in Idle (lifted), built %.3f m (%.2f m tall)" % [head, float(meta.get("head", 0.0)), float(meta.get("height", 0.0))])
		# feet on the ground through the clips, like the Mannequin's
		# lifted by StoryCast.ground, its soles meet the ground in every standing clip (checked on 16
		# frames, measured on 8); a lift beyond a few centimetres means a broken retarget
		var feet := []
		var feet_ok := true
		for clip in CLIPS:
			var lift := StoryCast.ground(id, root, clip)
			var low := StoryCast.lowest_sole(root, clip, 16) + lift
			feet.append("%s lift %.3f, soles %.3f" % [clip, lift, low])
			feet_ok = feet_ok and absf(low) <= FEET_TOLERANCE and absf(lift) < MAX_LIFT
		TestHooks.check(feet_ok, "cast_%s_feet_on_the_ground" % id, ", ".join(feet))
		# the same pose whichever way a cutscene seeks to it
		ap.play("Walk")
		ap.seek(1.3, true)
		var a := _poses(sk)
		ap.seek(0.2, true)
		ap.seek(2.0, true)
		ap.seek(1.3, true)
		var b := _poses(sk)
		var worst := 0.0
		for i in a.size():
			worst = maxf(worst, a[i].origin.distance_to(b[i].origin))
		TestHooks.check(worst < 1e-4, "cast_%s_seek_order_free" % id, "%.6f m" % worst)
		root.free()
	mannequin.free()
	TestHooks.finish()


func _materials(id: String, root: Node, meta: Dictionary) -> void:
	var bad := []
	var roles := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or not m.resource_name.contains("__"):
				bad.append("%s/%d: %s" % [mi.name, i, m])
				continue
			var role := m.resource_name.get_slice("__", 0)
			roles[role] = true
			var want := BaseMaterial3D.TRANSPARENCY_DISABLED
			if role in ["hair", "brow", "lash"]:
				want = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			elif role == "eye":
				want = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			if m.transparency != want or (role == "skin" and (not m.subsurf_scatter_enabled or m.albedo_texture == null)):
				bad.append("%s: %s transparency %d" % [mi.name, m.resource_name, m.transparency])
			if not (meta.get("materials", {}) as Dictionary).has(m.resource_name):
				bad.append("%s not in the sidecar" % m.resource_name)
	for need in ["skin", "eye", "teeth", "cloth"]:
		if not roles.has(need):
			bad.append("no " + need)
	TestHooks.check(bad.is_empty(), "cast_%s_materials_by_role" % id, str(bad) if not bad.is_empty() else str(roles.keys()))


func _shapes(id: String, root: Node, meta: Dictionary) -> void:
	var body := root.find_child("skin__body", true, false) as MeshInstance3D
	var lash := root.find_children("lash__*", "MeshInstance3D", true, false)
	var eyes := root.find_children("eye__*", "MeshInstance3D", true, false)
	var shapes: Array = meta.get("face_shapes", [])
	var missing := shapes.filter(func(s: String) -> bool: return body == null or body.find_blend_shape_by_name(s) < 0)
	# the lids carry their lashes, the gaze turns the eyes
	if lash.is_empty() or (lash[0] as MeshInstance3D).find_blend_shape_by_name("eyeBlinkLeft") < 0:
		missing.append("lashes: eyeBlinkLeft")
	if eyes.is_empty() or (eyes[0] as MeshInstance3D).find_blend_shape_by_name("eyeLookUpLeft") < 0:
		missing.append("eyes: eyeLookUpLeft")
	TestHooks.check(shapes.size() >= 30 and missing.is_empty(), "cast_%s_face_shapes" % id,
		"%d shapes, missing %s" % [shapes.size(), missing])


func _budget(id: String, root: Node, meta: Dictionary) -> void:
	var tris := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(i) / 3
	var bytes := 0
	var dir := "%s/%s/" % [StoryCast.DIR, id]
	var g: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + id + ".gltf"))
	if g is Dictionary:
		for b: Dictionary in g.get("buffers", []):
			bytes += _size(dir + String(b["uri"]))
		for im: Dictionary in g.get("images", []):
			bytes += _size(dir + String(im["uri"]))
	var mb := bytes / 1048576.0
	TestHooks.check(tris <= MAX_TRIANGLES and mb > 0.5 and mb <= MAX_MB, "cast_%s_budget" % id,
		"%d triangles (built %s), %.1f MB with its textures" % [tris, meta.get("triangles", "?"), mb])


func _size(path: String) -> int:
	var f := FileAccess.open(path.simplify_path(), FileAccess.READ)
	return f.get_length() if f != null else 0


func _bone_y(sk: Skeleton3D, bone: String) -> float:
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone))).origin.y


func _poses(sk: Skeleton3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(i))
	return out
