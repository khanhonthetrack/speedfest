class_name StoryPerson
extends Node3D
## A person in a cutscene (PLAN M20-3): Quaternius' Mannequin (assets/anim/ual, CC0;
## docs/ANIMATIONS.md) playing one of the library's clips, dressed dark so it reads as a figure in
## the night (the shot grammar keeps people in silhouette, backlit, at body distance: no faces);
## or, with "who", a member of the modelled cast (StoryCast, PLAN M20-9) playing the same clips in
## its own clothes, lifted onto the ground per clip (StoryCast.ground), walking at its own stride.
## Everything is a function of the scene's time (pose(t)), so a cutscene can be seeked to any
## frame and plays the same headless.
##
## spec (a scene's "people" entry): {"id", "clip": a UAL clip ("Idle", "Walk", "Idle_Talking",
## "Sitting_Idle", "Driving", ...: the names as Godot imports them, without "_Loop"), "loop": bool
## (default: the clip's own), "start": s into the clip at t = 0, "rate": playback speed,
## "pos": [x, y, z] (the shot's anchor frame: x left, y up, z ahead), "face": degrees (0 faces +z,
## 90 faces +x: the anchor's left), "path": [[x, z], ...] walked at "speed" m/s from "walk_at" s
## (default the clip's own speed: Walk 0.98 m/s, Jog_Fwd 5.36; a cast member's scaled by its legs
## over the Mannequin's: StoryCast.stride), "who": a cast member ("dee", ...; none: the Mannequin), "look": "coat"
## (default, near black cloth; a cast member keeps its clothes) | "drowned" (pale, soaked, glossy,
## dripping) | "grey" (the mannequin as it comes), "scale": 1.0 (1.83 m; a cast member its own height),
## "speaker": the name its lines carry (default: the cast member's first name, else the id),
## "gaze": "camera" | "mirror" (the shot's rear-view mirror: eyes on the driver's in the glass) | a
## person's id (default: whoever on screen is speaking, else straight ahead), "bend": bones turned
## on top of the clip over time (_bend: a head coming up), "blink": false (a cast member's eyes never
## shut), "shapes": {face shape: value} (held under the rest: {"jawOpen": 0.15}, a slack jaw)}
## A cast member has a face (StoryFace): it blinks, says its own lines, looks.

const GLB := "res://assets/anim/ual_standard/Unreal-Godot/UAL1_Standard.glb"
## The clips' own travel speed (docs/ANIMATIONS.md, measured from the _rm file's root track).
const SPEED := {"Walk": 0.98, "Walk_Formal": 0.98, "Jog_Fwd": 5.36, "Sprint": 8.25, "Crouch_Fwd": 0.75}

static var _scene: PackedScene
static var _coat: StandardMaterial3D
static var _clips: PackedStringArray = []

var spec := {}
var in_car := ""                   ## seated in this car of the shot (StoryScene moves it with the car)
var who := ""                      ## the cast member (StoryCast), "" for the Mannequin
var face: StoryFace                ## a cast member's face (StoryScene drives it), null for the Mannequin
var crown := Vector3.ZERO          ## seated: the top of the head, hair and all, in this person's frame
var _body: Node3D
var _player: AnimationPlayer
var _anim: Animation
var _path: Array[Vector3] = []     ## walked points (anchor frame), with their cumulative lengths
var _lengths: Array[float] = []
var _speed := 0.0
var _base := Transform3D()         ## the anchor frame (world) this person stands in
var _ground: Callable              ## (anchor-frame point) -> world point on the ground


## The clips a scene can name: the library's, the standing takes and their aliases (StoryCast.take).
static func clip_names() -> PackedStringArray:
	if _clips.is_empty():
		StoryCast.library()                # adds the standing takes to the library the Mannequin holds
		var n := _load().instantiate()
		var ap := n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		_clips = ap.get_animation_list()
		_clips.append_array(PackedStringArray(["Stand", "Stand_B", "Stand_Talk"]))
		n.free()
	return _clips


static func _load() -> PackedScene:
	if _scene == null:
		_scene = load(GLB)
	return _scene


static func coat() -> StandardMaterial3D:
	if _coat == null:
		_coat = StandardMaterial3D.new()
		_coat.albedo_color = Color(0.035, 0.035, 0.042)
		_coat.roughness = 0.62
		_coat.metallic_specular = 0.6
		_coat.rim_enabled = true          # neon and headlights catch the outline
		_coat.rim = 0.55
		_coat.rim_tint = 0.3
	return _coat


## Soaked: black and glossy, the light running off it (the passenger in the mirror).
static func drowned() -> StandardMaterial3D:
	# the living are dark shapes; the dead one is pale: cold grey skin, soaked, shining
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.19, 0.2)
	m.roughness = 0.4
	m.metallic_specular = 0.7
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.05
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.1
	return m


## Whether a line's speaker is this person: its "speaker", else the cast member's first name, else its id.
func speaks(name: String) -> bool:
	if name.is_empty():
		return false
	var mine := String(spec.get("speaker", ""))
	if mine.is_empty() and who != "":
		mine = String(StoryCast.meta(who).get("name", "")).get_slice(" ", 0)
	if mine.is_empty():
		mine = String(spec.get("id", ""))
	return mine.to_lower() == name.to_lower()


## Between this person's eyes (world): what others look at.
func eyes_point() -> Vector3:
	var sk := StoryCast.skeleton(self)
	if sk == null or sk.find_bone("Head") < 0:
		return global_position + global_basis.y * 1.6
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin + global_basis.y.normalized() * 0.07


## A cast member's own material soaked: darker, shining, the skin gone pale and cold.
static func soaked(src: StandardMaterial3D) -> StandardMaterial3D:
	var m := src.duplicate() as StandardMaterial3D
	var skin := src.resource_name.begins_with("skin__")
	var hair := src.resource_name.begins_with("hair__")
	m.albedo_color = (src.albedo_color.lerp(Color(0.6, 0.68, 0.72), 0.55) if skin else src.albedo_color * 0.55)
	m.albedo_color.a = src.albedo_color.a
	m.roughness = 0.18 if skin else (0.35 if hair else 0.22)
	m.clearcoat_enabled = true
	m.clearcoat = 0.5 if hair else 1.0             # wet hair shines in strands, not one glare under a lamp
	m.clearcoat_roughness = 0.3 if hair else 0.05
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.1
	return m


## Water dripping off a seated, soaked figure.
static func _drips() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.22, 0.25, 0.12)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, -6.0, 0)
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.003, 0.04)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.8, 1.0, 0.25)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	q.material = m
	p.draw_pass_1 = q
	p.amount = 60
	p.lifetime = 0.5
	p.position = Vector3(0, 1.0, 0.05)
	p.local_coords = false
	return p


## A seated person's frame: the car's road frame, which moves (StoryScene calls it each frame).
func rebase(base: Transform3D) -> void:
	_base = base
	_ground = Callable()


## base: the anchor frame in the world; ground: snaps an anchor-frame point to the ground (world).
func setup(s: Dictionary, base: Transform3D, ground: Callable) -> void:
	spec = s
	_base = base
	_ground = ground
	who = String(s.get("who", ""))
	if who != "" and not StoryCast.has(who):
		push_warning("story: no cast member %s, the Mannequin instead" % who)
		who = ""
	var body: Node3D = StoryCast.instance(who) if who != "" else _load().instantiate()
	add_child(body)
	_body = body
	if who != "":
		face = StoryFace.new(body, String(s.get("id", who)).hash())
		face.blinks = bool(s.get("blink", true))
		face.held = s.get("shapes", {})
	_player = body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	StoryCast.library()
	var clip := StoryCast.take(who, String(s.get("clip", "Idle")))
	if not _player.has_animation(clip):
		push_warning("story: no clip %s, Idle instead" % clip)
		clip = "Idle"
	_anim = _player.get_animation(clip)
	# a cast member standing (a ground under it) meets the ground in this clip; anyone seated (in a
	# car, no ground: "pos" or "seat" is where the Mannequin would sit) rests its own seat where the
	# Mannequin's rests in this clip (a body that can't be measured sits as the Mannequin does)
	var lift := StoryCast.ground(who, body, clip) if who != "" and ground.is_valid() else 0.0
	var sits := not ground.is_valid()
	var ref: Dictionary = StoryCast.mannequin_seated(self, clip) if sits else {}
	var own: Dictionary = StoryCast.seated(who, body, clip) if sits and who != "" else ref
	if own.is_empty() or ref.is_empty():
		own = {"seat": Vector2.ZERO, "crown": Vector2(StoryCabin.CROWN.x, StoryCabin.CROWN.y)}
		ref = {"seat": Vector2.ZERO}
	_player.play(clip)
	_player.pause()
	var look := String(s.get("look", "coat"))
	if look in ["coat", "drowned"] and who == "":
		var m := coat() if look == "coat" else drowned()
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				mi.set_surface_override_material(k, m)
	elif look == "drowned":
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				mi.set_surface_override_material(k, soaked(mi.mesh.surface_get_material(k) as StandardMaterial3D))
	if look == "drowned":
		add_child(_drips())
	var sc := float(s.get("scale", 1.0))
	body.scale = Vector3.ONE * sc
	body.position.y = lift * sc
	if sits:
		var seat: Vector2 = (ref["seat"] as Vector2) - (own["seat"] as Vector2) * sc       # (0 for an unscaled Mannequin)
		var top: Vector2 = own["crown"]
		body.position = Vector3(0.0, seat.x, seat.y)
		crown = body.position + Vector3(0.0, top.x, top.y) * sc
	var p: Array = s.get("pos", [0.0, 0.0, 0.0])
	_path = [Vector3(float(p[0]), float(p[1]), float(p[2]))]
	for q: Array in s.get("path", []):
		_path.append(Vector3(float(q[0]), float(p[1]), float(q[1])))
	_lengths = [0.0]
	for i in range(1, _path.size()):
		_lengths.append(_lengths[-1] + _path[i].distance_to(_path[i - 1]))
	# shorter legs take shorter strides: the clip's speed scaled as the retarget scales its motion
	var stride := StoryCast.stride(body) if who != "" else 1.0
	_speed = float(s.get("speed", SPEED.get(clip, 1.0) * float(s.get("rate", 1.0)) * stride))


## Lowers a seated person whose crown would meet the roof (StoryScene lowers the seat as far).
func sink(by: float) -> void:
	_body.position.y -= by
	crown.y -= by


## The person at scene time t (seconds since the shot began).
func pose(t: float) -> void:
	var rate := float(spec.get("rate", 1.0))
	var ct := float(spec.get("start", 0.0)) + t * rate
	var loop := bool(spec.get("loop", _anim.loop_mode != Animation.LOOP_NONE))
	ct = fposmod(ct, _anim.length) if loop else clampf(ct, 0.0, _anim.length)
	_player.seek(ct, true)
	_bend(t)
	# where along the walk, and facing which way
	var walked := maxf(0.0, t - float(spec.get("walk_at", 0.0))) * _speed
	var p := _path[0]
	var dir := Vector3.ZERO
	for i in range(1, _path.size()):
		if walked <= _lengths[i] or i == _path.size() - 1:
			var seg := _lengths[i] - _lengths[i - 1]
			var u := clampf((walked - _lengths[i - 1]) / seg, 0.0, 1.0) if seg > 0.0 else 1.0
			p = _path[i - 1].lerp(_path[i], u)
			dir = (_path[i] - _path[i - 1]).normalized()
			break
	var face := deg_to_rad(float(spec.get("face", 0.0)))
	if dir.length() > 0.5:
		face = atan2(dir.x, dir.z)
	var world := _ground.call(p) as Vector3 if _ground.is_valid() else _base * p
	var up := _base.basis.y.normalized()
	var fwd := (_base.basis * Vector3(sin(face), 0.0, cos(face))).normalized()
	fwd = (fwd - up * fwd.dot(up)).normalized()
	global_transform = Transform3D(Basis(up.cross(fwd), up, fwd), world)


## "bend": bones turned on top of the clip at this moment: keys [{"t": s, "<Bone>": [x, y, z]}, ...]
## (degrees about the body's own axes: x nods it forward, y turns it to its left, z tilts it to its
## right), eased between keys and held before the first and after the last; a bone a key leaves out
## is straight there. A head coming up slowly, a spine leaning in.
func _bend(t: float) -> void:
	var keys: Array = spec.get("bend", [])
	if keys.is_empty():
		return
	var sk := StoryCast.skeleton(self)
	if sk == null:
		return
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[0]
	var f := 0.0
	for i in keys.size():
		if t >= float((keys[i] as Dictionary).get("t", 0.0)):
			a = keys[i]
			b = keys[mini(i + 1, keys.size() - 1)]
			var span := float(b.get("t", 0.0)) - float(a.get("t", 0.0))
			f = clampf((t - float(a.get("t", 0.0))) / span, 0.0, 1.0) if span > 0.0 else 0.0
	f = f * f * (3.0 - 2.0 * f)
	var bones: Array[int] = []
	for k: String in a.keys() + b.keys():
		var i := sk.find_bone(k)
		if k != "t" and i >= 0 and not i in bones:
			bones.append(i)
	bones.sort()                                   # parents before their children
	for i in bones:
		var name := sk.get_bone_name(i)
		var da: Array = a.get(name, [0.0, 0.0, 0.0])
		var db: Array = b.get(name, [0.0, 0.0, 0.0])
		var deg := Vector3(float(da[0]), float(da[1]), float(da[2])).lerp(Vector3(float(db[0]), float(db[1]), float(db[2])), f)
		var turn := Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))
		var parent := sk.get_bone_parent(i)
		var up := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
		var g := sk.get_bone_global_pose(i)
		var local := up.affine_inverse() * Transform3D(turn * g.basis, g.origin)
		sk.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
