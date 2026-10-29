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
## "pos": [x, y, z] (the shot's anchor frame: x left, y up, z ahead; someone standing is dropped onto the
## ground under it), "lift": m over that ground (a film set's apple box, where the feet are out of shot;
## or [[t, m], ...], eased between: hips that come down with bent knees and go up again),
## "face": degrees (0 faces +z,
## 90 faces +x: the anchor's left), "path": [[x, z], ...] walked at "speed" m/s from "walk_at" s
## (default the clip's own speed: Walk 0.98 m/s, Jog_Fwd 5.36; a cast member's scaled by its legs
## over the Mannequin's: StoryCast.stride), "who": a cast member ("dee", ...; none: the Mannequin), "look": "coat"
## (default, near black cloth; a cast member keeps its clothes) | "drowned" (pale, soaked, glossy,
## dripping) | "grey" (the mannequin as it comes), "scale": 1.0 (1.83 m; a cast member its own height),
## "speaker": the name its lines carry (default: the cast member's first name, else the id),
## "gaze": "camera" | "mirror" (the shot's rear-view mirror: eyes on the driver's in the glass; in a
## shot without one, the glass of the cabin the person sits in) | "rear" (the back seat of the car
## the person sits in: a look over the shoulder) |
## "ahead" | a person's id (default: whoever on screen is speaking, else straight ahead), "looks":
## [[from, to, gaze], ...] (s into the shot: the eyes there for that while, a glance), "bend": bones turned
## on top of the clip over time (_bend: a head coming up), "reach": hands put on something over time
## (_reach: two-bone IK, the palm turned to face it; "reach_car": a car's id, the targets in its road
## frame: hands on a car's roof), "breathe": [deg, period s] (the chest rising and falling), "blink": false (a cast member's eyes never
## shut), "shapes": {face shape: value} (held under the rest: {"jawOpen": 0.15}, a slack jaw; or keyed
## [{"t": s, shape: value, ...}, ...]), "hide":
## [role, ...] (a cast member's garments left off by role: ["hivis"], Gus without his vest), "wet": 0..1
## (a cast member's hair damp from the rain: StoryHair; "drowned" soaks it)}
## A cast member has a face (StoryFace): it blinks, says its own lines, looks.

const GLB := "res://assets/anim/ual_standard/Unreal-Godot/UAL1_Standard.glb"
## The clips' own travel speed (docs/ANIMATIONS.md, measured from the _rm file's root track).
const SPEED := {"Walk": 0.98, "Walk_Formal": 0.98, "Jog_Fwd": 5.36, "Sprint": 8.25, "Crouch_Fwd": 0.75}
const CAST_LAYER := 1 << 11         ## the cast's own render layer too: a camera's eye light lights it alone
const PALM_HALF := 0.02            ## m from a hand's bones to its palm's skin ("reach" marks are on the skin)
const FOREARM_ROLL := 0.6          ## the share of a reaching hand's roll the forearm takes (the wrist the rest)

static var _scene: PackedScene
static var _coat: StandardMaterial3D
static var _clips: PackedStringArray = []

var spec := {}
var in_car := ""                   ## seated in this car of the shot (StoryScene moves it with the car)
var who := ""                      ## the cast member (StoryCast), "" for the Mannequin
var face: StoryFace                ## a cast member's face (StoryScene drives it), null for the Mannequin
var crown := Vector3.ZERO          ## seated: the top of the head, hair and all, in this person's frame
var reach_frame: Variant = null    ## "reach_car": that car's road frame now (StoryScene sets it), null: the anchor
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


## The middle of this person's face (world), between the eyes and in front of the head's middle: where
## a close-up aims (a shot's camera "look": the person's id).
func face_point() -> Vector3:
	var sk := StoryCast.skeleton(self)
	var i := sk.find_bone("Head") if sk != null else -1
	if i < 0:
		return eyes_point()
	var turn := (sk.get_bone_global_pose(i).basis * sk.get_bone_global_rest(i).basis.inverse()).orthonormalized()
	return eyes_point() + global_basis.orthonormalized() * (turn * Vector3(0.0, 0.0, 0.085))


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
		face.held = s.get("shapes", {}) if s.get("shapes", {}) is Dictionary else {}
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			mi.layers |= CAST_LAYER
	# "hide": a cast member's garments left off by role (their mesh's name: "<role>__<asset>")
	for role: String in s.get("hide", []):
		for mi: MeshInstance3D in body.find_children(role + "__*", "MeshInstance3D", true, false):
			mi.visible = false
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
				if mi.get_surface_override_material(k) is ShaderMaterial:
					continue                  # the hair keeps its strands (StoryHair), soaked below
				mi.set_surface_override_material(k, soaked(mi.mesh.surface_get_material(k) as StandardMaterial3D))
	if who != "" and (look == "drowned" or s.has("wet")):
		StoryHair.set_wet(body, 1.0 if look == "drowned" else float(s["wet"]))
	if look == "drowned":
		var drips := _drips()
		drips.local_coords = sits         # seated in a moving car the water falls in the car, not behind it
		add_child(drips)
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
	if face != null and spec.get("shapes") is Array:
		face.held = _shapes_at(t)
	var rate := float(spec.get("rate", 1.0))
	var ct := float(spec.get("start", 0.0)) + t * rate
	var loop := bool(spec.get("loop", _anim.loop_mode != Animation.LOOP_NONE))
	ct = fposmod(ct, _anim.length) if loop else clampf(ct, 0.0, _anim.length)
	_player.seek(ct, true)
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
	world += up * _lift_at(t)
	var fwd := (_base.basis * Vector3(sin(face), 0.0, cos(face))).normalized()
	fwd = (fwd - up * fwd.dot(up)).normalized()
	global_transform = Transform3D(Basis(up.cross(fwd), up, fwd), world)
	# the bones on top of the clip, once the body stands where it stands (a hand reaches for a place in the world)
	_bend(t)
	_breathe(t)
	_reach(t)


## "lift" at t: a number, or keys [[t, m], ...] eased between (held before the first, after the last).
## "shapes" keyed over the shot, [{"t": s, "<shape>": value, ...}, ...]: each shape eased between the
## keys (smoothstep), held before the first and after the last; a shape a key leaves out is 0 there
## (the eyes closing in relief, going wide).
func _shapes_at(t: float) -> Dictionary:
	var keys: Array = spec.get("shapes", [])
	if keys.is_empty():
		return {}
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[0]
	var f := 0.0
	for i in keys.size():
		if t >= float((keys[i] as Dictionary).get("t", 0.0)):
			a = keys[i]
			b = keys[mini(i + 1, keys.size() - 1)]
			var span := float(b.get("t", 0.0)) - float(a.get("t", 0.0))
			f = clampf((t - float(a.get("t", 0.0))) / span, 0.0, 1.0) if span > 0.0 else 0.0
	f = StoryScene._ease(f, String(b.get("ease", "inout")))      # the key's "ease": how its segment arrives
	var out := {}
	for k: String in a.keys() + b.keys():
		if k != "t":
			out[k] = lerpf(float(a.get(k, 0.0)), float(b.get(k, 0.0)), f)
	return out


func _lift_at(t: float) -> float:
	var lift: Variant = spec.get("lift", 0.0)
	if not lift is Array:
		return float(lift)
	var keys: Array = lift
	if keys.is_empty():
		return 0.0
	var v := float((keys[0] as Array)[1])
	for i in keys.size():
		var k: Array = keys[i]
		if t >= float(k[0]):
			v = float(k[1])
			if i + 1 < keys.size():
				var n: Array = keys[i + 1]
				var span := float(n[0]) - float(k[0])
				var f := clampf((t - float(k[0])) / span, 0.0, 1.0) if span > 0.0 else 1.0
				v = lerpf(float(k[1]), float(n[1]), f * f * (3.0 - 2.0 * f))
	return v


## "breathe": [degrees, period s]: the chest rises and falls on top of the clip and the bends (a body
## held still, asleep or listening, still alive), about the body's own x as a bend's.
func _breathe(t: float) -> void:
	var br: Array = spec.get("breathe", [])
	if br.size() < 2:
		return
	var sk := StoryCast.skeleton(self)
	var i := sk.find_bone("Chest") if sk != null else -1
	if i < 0:
		return
	var turn := Basis(Vector3.RIGHT, deg_to_rad(float(br[0])) * sin(TAU * t / maxf(float(br[1]), 0.1)))
	var parent := sk.get_bone_parent(i)
	var up := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var g := sk.get_bone_global_pose(i)
	var local := up.affine_inverse() * Transform3D(turn * g.basis, g.origin)
	sk.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())


## "bend": bones turned on top of the clip at this moment: keys [{"t": s, "<Bone>": [x, y, z]}, ...]
## (degrees about the body's own axes: x nods it forward, y turns it to its left, z tilts it to its
## right), eased between keys (a key's "ease": "inout" (default), "in" (arriving at speed: knuckles
## hitting glass), "out", "linear") and held before the first and after the last; a bone a key leaves
## out is straight there. A head coming up slowly, a spine leaning in.
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
	f = StoryScene._ease(f, String(b.get("ease", "inout")))      # the key's "ease": how its segment arrives
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


## "reach": hands put on something at this moment: keys [{"t": s, "LeftHand": [x, y, z] | {"at": [x, y, z],
## "palm": [x, y, z], "fingers": [x, y, z], "elbow": [x, y, z]}, "RightHand": ...}, ...] in the shot's anchor
## frame (as "pos"), or with "reach_car": a car's id, in that car's road frame: the palm's middle put at "at" (the arm bent to it: two-bone IK on the upper arm and the
## forearm), the palm facing "palm" with the fingers along "fingers" (directions; either left out: the clip's
## hand turned as little as it takes), the elbow bending towards "elbow" (a direction; default: out to the
## side, down and back), "fist": 0-1 (the fingers curled, the thumb across: a knock), "point": true (the index left straight: a point); eased between
## keys as "bend"; a hand a key leaves out hangs as the clip has it there (eased in and out). Hands on
## a car's window ledge, knuckles rapping its glass.
func _reach(t: float) -> void:
	var keys: Array = spec.get("reach", [])
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
	f = StoryScene._ease(f, String(b.get("ease", "inout")))      # the key's "ease": how its segment arrives
	for side: String in ["Left", "Right"]:
		var ka := _hand_key(a.get(side + "Hand"))
		var kb := _hand_key(b.get(side + "Hand"))
		if ka.is_empty() and kb.is_empty():
			continue
		var k := ka if kb.is_empty() else kb if ka.is_empty() else {}
		if k.is_empty():                     # both keys hold the hand: eased from one to the other
			k = {}
			for n: String in ["at", "palm", "fingers", "elbow"]:
				var va: Variant = ka.get(n)
				var vb: Variant = kb.get(n)
				if va != null or vb != null:
					k[n] = va if vb == null else vb if va == null else (va as Vector3).lerp(vb as Vector3, f)
			k["fist"] = lerpf(float(ka.get("fist", 0.0)), float(kb.get("fist", 0.0)), f)
			k["point"] = bool(ka.get("point", false)) or bool(kb.get("point", false))
		var w := lerpf(0.0 if ka.is_empty() else 1.0, 0.0 if kb.is_empty() else 1.0, f)
		_arm_to(sk, side, k, w)


## A "reach" key's hand as {"at", "palm"?, "fingers"?, "elbow"?} (Vector3s), {} for none.
static func _hand_key(v: Variant) -> Dictionary:
	if v is Array and (v as Array).size() >= 3:
		v = {"at": v}
	if not v is Dictionary or not (v as Dictionary).has("at"):
		return {}
	var out := {}
	for n: String in ["at", "palm", "fingers", "elbow"]:
		var q: Array = (v as Dictionary).get(n, [])
		if q.size() >= 3:
			out[n] = Vector3(float(q[0]), float(q[1]), float(q[2]))
	if (v as Dictionary).has("fist"):
		out["fist"] = float((v as Dictionary)["fist"])
	if bool((v as Dictionary).get("point", false)):
		out["point"] = true
	return out


## The hand's frame from its bones (skeleton space): {"wrist", "palm" (the middle of the palm), "fingers",
## "normal" (the way the palm faces)}, or {} for a skeleton without fingers.
static func _hand_frame(sk: Skeleton3D, side: String) -> Dictionary:
	var h := sk.find_bone(side + "Hand")
	var mid := sk.find_bone(side + "MiddleProximal")
	var idx := sk.find_bone(side + "IndexProximal")
	var lit := sk.find_bone(side + "LittleProximal")
	if h < 0 or mid < 0 or idx < 0 or lit < 0:
		return {}
	var wrist := sk.get_bone_global_pose(h).origin
	var knuckle := sk.get_bone_global_pose(mid).origin
	var fingers := (knuckle - wrist).normalized()
	var thumbward := sk.get_bone_global_pose(idx).origin - sk.get_bone_global_pose(lit).origin
	# palm down, fingers ahead: the thumb is to the right of a left hand, the left of a right one
	var normal := fingers.cross(thumbward).normalized() * (1.0 if side == "Left" else -1.0)
	return {"wrist": wrist, "palm": wrist.lerp(knuckle, 0.5), "fingers": fingers, "normal": normal}


## A frame with `fwd` first and `up` made square to it (columns: side, up, fwd).
static func _frame(fwd: Vector3, up: Vector3) -> Basis:
	var z := fwd.normalized()
	var y := (up - z * up.dot(z)).normalized()
	return Basis(y.cross(z), y, z)


## Sets a bone's rotation so its pose in the skeleton's space has this basis.
static func _set_global_basis(sk: Skeleton3D, i: int, basis: Basis) -> void:
	var parent := sk.get_bone_parent(i)
	var up := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var local := up.basis.inverse() * basis
	sk.set_bone_pose_rotation(i, local.orthonormalized().get_rotation_quaternion())


## One arm to a "reach" key, w of the way (0: the clip's arm): solved whole, then each bone eased from
## the clip's turn to the solved one by w (so a hand let go comes back to the clip's arm without a jump).
func _arm_to(sk: Skeleton3D, side: String, k: Dictionary, w: float) -> void:
	var ua := sk.find_bone(side + "UpperArm")
	var la := sk.find_bone(side + "LowerArm")
	var hd := sk.find_bone(side + "Hand")
	var hf := _hand_frame(sk, side)
	if ua < 0 or la < 0 or hd < 0 or hf.is_empty() or w <= 0.0:
		return
	var bones: Array[int] = [ua, la, hd]
	var fist := float(k.get("fist", 0.0))
	if fist > 0.0:
		bones.append_array(_finger_bones(sk, side))
	var clip: Array[Quaternion] = []
	for b in bones:
		clip.append(sk.get_bone_pose_rotation(b))
	# the targets' frame (the anchor, or "reach_car"'s road frame) -> skeleton space
	var frame: Transform3D = reach_frame if reach_frame is Transform3D else _base
	var to_sk := sk.global_transform.affine_inverse() * frame
	var dir := func(v: Vector3) -> Vector3: return (to_sk.basis * v).normalized()
	# the hand turned to its palm and fingers
	var normal: Vector3 = hf["normal"]
	var fingers: Vector3 = hf["fingers"]
	var want_n: Vector3 = dir.call(k["palm"]) if k.has("palm") else normal
	var want_f: Vector3 = dir.call(k["fingers"]) if k.has("fingers") else fingers - want_n * fingers.dot(want_n)
	if want_f.length() < 0.01:
		want_f = fingers
	var turn := (_frame(want_f, -want_n) * _frame(fingers, -normal).inverse()).orthonormalized()
	var hand_basis := turn * sk.get_bone_global_pose(hd).basis
	# the wrist where the palm's skin lands on the mark: its middle, the hand's half thickness off it
	var wrist0: Vector3 = hf["wrist"]
	var target := to_sk * (k["at"] as Vector3) - turn * ((hf["palm"] as Vector3) - wrist0) - turn * normal * PALM_HALF
	# two bones: the elbow on the circle where both reach, towards the pole
	var s := sk.get_bone_global_pose(ua).origin
	var e := sk.get_bone_global_pose(la).origin
	var la_len := s.distance_to(e)
	var lb_len := e.distance_to(wrist0)
	var to_t := target - s
	var d := clampf(to_t.length(), absf(la_len - lb_len) + 0.001, la_len + lb_len - 0.001)
	var n := to_t.normalized()
	var body := global_transform.basis.orthonormalized()
	var out := body.x * (1.0 if side == "Left" else -1.0)
	var pole_world: Vector3 = frame.basis * (k["elbow"] as Vector3) if k.has("elbow") else out * 0.8 - body.y * 0.5 - body.z * 0.3
	var pole := (sk.global_transform.basis.inverse() * pole_world)
	var m := pole - n * pole.dot(n)
	if m.length() < 0.001:
		m = (e - s) - n * (e - s).dot(n)
	m = m.normalized()
	var cos_a := clampf((la_len * la_len + d * d - lb_len * lb_len) / (2.0 * la_len * d), -1.0, 1.0)
	var elbow := s + la_len * (n * cos_a + m * sqrt(1.0 - cos_a * cos_a))
	var up_basis := sk.get_bone_global_pose(ua).basis
	_set_global_basis(sk, ua, Basis(Quaternion((e - s).normalized(), (elbow - s).normalized())) * up_basis)
	var e2 := sk.get_bone_global_pose(la).origin
	var w2 := sk.get_bone_global_pose(hd).origin
	if (w2 - e2).length() > 0.001 and (target - e2).length() > 0.001:
		_set_global_basis(sk, la, Basis(Quaternion((w2 - e2).normalized(), (target - e2).normalized())) * sk.get_bone_global_pose(la).basis)
	# the forearm takes most of the hand's roll about it (it turns the palm; a wrist only bends), so
	# the skin at the wrist doesn't wring
	var axis := (sk.get_bone_global_pose(hd).origin - e2).normalized()
	var r := (hand_basis * sk.get_bone_global_pose(hd).basis.inverse()).orthonormalized().get_rotation_quaternion()
	var along := Vector3(r.x, r.y, r.z).project(axis)
	var twist := Quaternion(along.x, along.y, along.z, r.w)
	if twist.length() > 0.000001:
		twist = twist.normalized()
		if twist.w < 0.0:
			twist = -twist
		_set_global_basis(sk, la, Basis(Quaternion.IDENTITY.slerp(twist, FOREARM_ROLL)) * sk.get_bone_global_pose(la).basis)
	_set_global_basis(sk, hd, hand_basis)
	if fist > 0.0:
		_curl(sk, side, fist, bool(k.get("point", false)))
	if w < 1.0:
		for b in bones.size():
			sk.set_bone_pose_rotation(bones[b], clip[b].slerp(sk.get_bone_pose_rotation(bones[b]), w))


const FINGERS := ["Index", "Middle", "Ring", "Little"]
## A fist's bend at each joint of a finger (degrees: knuckle, middle, tip) and of the thumb.
const FIST := [80.0, 95.0, 60.0]
const FIST_THUMB := [15.0, 35.0, 30.0]


## A hand's finger bones, knuckles first (the thumb's last).
static func _finger_bones(sk: Skeleton3D, side: String) -> Array[int]:
	var out: Array[int] = []
	for f: String in FINGERS + ["Thumb"]:
		for j: String in (["Metacarpal", "Proximal", "Distal"] if f == "Thumb" else ["Proximal", "Intermediate", "Distal"]):
			var i := sk.find_bone(side + f + j)
			if i >= 0:
				out.append(i)
	return out


## Curls a hand's fingers into a fist, `amount` of the way (1: closed), on top of the clip's: each
## finger about the hinge square to it and the palm's facing (towards the palm), the thumb across it.
static func _curl(sk: Skeleton3D, side: String, amount: float, point := false) -> void:
	var hf := _hand_frame(sk, side)
	if hf.is_empty():
		return
	var fingers: Vector3 = hf["fingers"]
	var normal: Vector3 = hf["normal"]
	var hinge := fingers.cross(normal).normalized()        # a turn about it takes the fingers to the palm's side
	for f: String in FINGERS + ["Thumb"]:
		if point and f == "Index":
			for j in ["Proximal", "Intermediate", "Distal"]:      # a pointing hand: the index straight
				var ix := sk.find_bone(side + "Index" + j)
				if ix >= 0:
					sk.set_bone_pose_rotation(ix, sk.get_bone_rest(ix).basis.get_rotation_quaternion())
			continue
		var joints: Array = ["Metacarpal", "Proximal", "Distal"] if f == "Thumb" else ["Proximal", "Intermediate", "Distal"]
		var degs: Array = FIST_THUMB if f == "Thumb" else FIST
		var axis := fingers if f == "Thumb" else hinge          # the thumb rolls in across the palm
		var sign := (1.0 if side == "Left" else -1.0) if f == "Thumb" else 1.0
		for j in joints.size():
			var i := sk.find_bone(side + f + String(joints[j]))
			if i < 0:
				continue
			var turn := Basis(axis, deg_to_rad(float(degs[j]) * amount) * sign)
			_set_global_basis(sk, i, turn * sk.get_bone_global_pose(i).basis)


## Where a hand's palm is now (world): its middle, between the wrist and the knuckles ("Left" / "Right").
func palm_point(side: String) -> Vector3:
	var sk := StoryCast.skeleton(self)
	var hf := _hand_frame(sk, side) if sk != null else {}
	return sk.global_transform * (hf["palm"] as Vector3) if not hf.is_empty() else Vector3.INF
