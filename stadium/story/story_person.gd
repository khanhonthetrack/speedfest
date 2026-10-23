class_name StoryPerson
extends Node3D
## A person in a cutscene (PLAN M20-3): Quaternius' Mannequin (assets/anim/ual, CC0;
## docs/ANIMATIONS.md) playing one of the library's clips, dressed dark so it reads as a figure in
## the night (the shot grammar keeps people in silhouette, backlit, at body distance: no faces).
## Everything is a function of the scene's time (pose(t)), so a cutscene can be seeked to any
## frame and plays the same headless.
##
## spec (a scene's "people" entry): {"id", "clip": a UAL clip ("Idle", "Walk", "Idle_Talking",
## "Sitting_Idle", "Driving", ...: the names as Godot imports them, without "_Loop"), "loop": bool
## (default: the clip's own), "start": s into the clip at t = 0, "rate": playback speed,
## "pos": [x, y, z] (the shot's anchor frame: x left, y up, z ahead), "face": degrees (0 faces +z,
## 90 faces +x: the anchor's left), "path": [[x, z], ...] walked at "speed" m/s from "walk_at" s
## (default the clip's own speed: Walk 0.98 m/s, Jog_Fwd 5.36), "look": "coat" (default, near
## black cloth) | "grey" (the mannequin as it comes), "scale": 1.0 (1.83 m)}

const GLB := "res://assets/anim/ual_standard/Unreal-Godot/UAL1_Standard.glb"
## The clips' own travel speed (docs/ANIMATIONS.md, measured from the _rm file's root track).
const SPEED := {"Walk": 0.98, "Walk_Formal": 0.98, "Jog_Fwd": 5.36, "Sprint": 8.25, "Crouch_Fwd": 0.75}

static var _scene: PackedScene
static var _coat: StandardMaterial3D
static var _clips: PackedStringArray = []

var spec := {}
var _player: AnimationPlayer
var _anim: Animation
var _path: Array[Vector3] = []     ## walked points (anchor frame), with their cumulative lengths
var _lengths: Array[float] = []
var _speed := 0.0
var _base := Transform3D()         ## the anchor frame (world) this person stands in
var _ground: Callable              ## (anchor-frame point) -> world point on the ground


static func clip_names() -> PackedStringArray:
	if _clips.is_empty():
		var n := _load().instantiate()
		var ap := n.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		_clips = ap.get_animation_list()
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


## base: the anchor frame in the world; ground: snaps an anchor-frame point to the ground (world).
func setup(s: Dictionary, base: Transform3D, ground: Callable) -> void:
	spec = s
	_base = base
	_ground = ground
	var body := _load().instantiate()
	add_child(body)
	_player = body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var clip := String(s.get("clip", "Idle"))
	if not _player.has_animation(clip):
		push_warning("story: no clip %s, Idle instead" % clip)
		clip = "Idle"
	_anim = _player.get_animation(clip)
	_player.play(clip)
	_player.pause()
	if String(s.get("look", "coat")) == "coat":
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				mi.set_surface_override_material(k, coat())
	var sc := float(s.get("scale", 1.0))
	body.scale = Vector3.ONE * sc
	var p: Array = s.get("pos", [0.0, 0.0, 0.0])
	_path = [Vector3(float(p[0]), float(p[1]), float(p[2]))]
	for q: Array in s.get("path", []):
		_path.append(Vector3(float(q[0]), float(p[1]), float(q[1])))
	_lengths = [0.0]
	for i in range(1, _path.size()):
		_lengths.append(_lengths[-1] + _path[i].distance_to(_path[i - 1]))
	_speed = float(s.get("speed", SPEED.get(clip, 1.0) * float(s.get("rate", 1.0))))


## The person at scene time t (seconds since the shot began).
func pose(t: float) -> void:
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
	var fwd := (_base.basis * Vector3(sin(face), 0.0, cos(face))).normalized()
	fwd = (fwd - up * fwd.dot(up)).normalized()
	global_transform = Transform3D(Basis(up.cross(fwd), up, fwd), world)
