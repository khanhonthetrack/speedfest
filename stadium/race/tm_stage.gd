class_name TmStage
extends RefCounted
## Shared set-up of the scenes that show a map: finding a campaign track in the player's TMNF
## install, loading a challenge from the scene's args, and the sky, sun and horizon around it.


## The track named `track` (A01 .. E05) of the official campaign in a TMNF install, or "".
static func campaign_file(tmnf_root: String, track: String) -> String:
	var base := tmnf_root.path_join("GameData/Tracks/Campaigns/Nations")
	for colour in ["White", "Green", "Blue", "Red", "Black"]:
		var d := DirAccess.open(base.path_join(colour))
		if d == null:
			continue
		for f in d.get_files():
			if f.begins_with(track) and f.to_lower().ends_with(".challenge.gbx"):
				return base.path_join(colour).path_join(f)
	return ""


## The official campaign's track names (A01 .. E05) found in a TMNF install, in order.
static func campaign_tracks(tmnf_root: String) -> Array[String]:
	var base := tmnf_root.path_join("GameData/Tracks/Campaigns/Nations")
	var out: Array[String] = []
	for colour in ["White", "Green", "Blue", "Red", "Black"]:
		var d := DirAccess.open(base.path_join(colour))
		if d == null:
			continue
		for f in d.get_files():
			if f.to_lower().ends_with(".challenge.gbx"):
				out.append(f.substr(0, 3))
	out.sort()
	return out


## Where TMNF installs itself (the official installer, Steam), tried when no install is named.
const TMNF_PLACES := [
	"C:/Program Files (x86)/TmNationsForever", "C:/Program Files/TmNationsForever",
	"C:/Program Files (x86)/Steam/steamapps/common/TrackMania Nations Forever",
	"~/.wine/drive_c/Program Files (x86)/TmNationsForever", "~/.wine/drive_c/Program Files/TmNationsForever",
]


## The player's TMNF install: --tmnf=/path, else $TMNF_DIR, else the usual install places; "" if none.
static func find_tmnf() -> String:
	var named := String(TestHooks.arg("tmnf", ""))
	if named.is_empty():
		named = OS.get_environment("TMNF_DIR")
	var places := [named] if not named.is_empty() else []
	for p: String in TMNF_PLACES:
		places.append(p.replace("~", OS.get_environment("HOME")) if p.begins_with("~") else p)
	for p: String in places:
		if DirAccess.dir_exists_absolute(p.path_join("GameData/Tracks/Campaigns/Nations")):
			return p
	return ""


## The challenge named by the args: --map=/path/X.Challenge.Gbx (any TMNF track file), or
## --track=SF01 (our own tracks, TmTracks; the first by default), or --track=A01 for TMNF's
## campaign from a TMNF install (--tmnf=/path, else the one find_tmnf() finds).
static func load_from_args() -> TmChallenge:
	var path := String(TestHooks.arg("map", ""))
	if path.is_empty():
		var track := String(TestHooks.arg("track", ""))
		if track.is_empty() and not TmTracks.ids().is_empty():
			track = TmTracks.ids()[0]
		if TmTracks.has(track):
			return TmTracks.challenge(track)
		var root := find_tmnf()
		if root.is_empty():
			var none := TmChallenge.new()
			none.error = "Track %s is from TrackMania Nations Forever's campaign: install TMNF (free) to race it, or open a .Challenge.Gbx file." % track
			return none
		path = campaign_file(root, track)
	return TmChallenge.load_file(path)


## Sun and sky (TmStadiumEnv) and, around a 32 x 32 map, the Stadium (TmStadiumBuild); around maps
## of other sizes plain grass from the map's edge to the horizon (the map's own ground is built
## with it by TmMapBuilder).
static func add_environment(parent: Node, builder: TmMapBuilder) -> void:
	TmStadiumEnv.add(parent)
	if builder.challenge.size.x == 32 and builder.challenge.size.z == 32:
		if TmRefVisuals.active():
			# research (--ref): TMNF's own surround, from local files (TmRefVisuals)
			var ref := TmRefVisuals.visual("Zone/Square32")
			if ref != null:
				ref.position = Vector3(0.0, TmStadiumBuild.FIELD_Y, 0.0)
				parent.add_child(ref)
				return
		parent.add_child(TmStadiumBuild.build())
		return
	var w := float(builder.challenge.size.x) * 32.0
	var d := float(builder.challenge.size.z) * 32.0
	var gm := TmMaterials.get_material("grass")
	var far := 3000.0
	for r in [Rect2(-far, -far, w + 2.0 * far, far), Rect2(-far, d, w + 2.0 * far, far), Rect2(-far, 0, far, d), Rect2(w, 0, far, d)]:
		var ground := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = r.size
		ground.mesh = pm
		ground.material_override = gm
		# TMNF (x, z) -> Godot (-x, z)
		ground.position = Vector3(-(r.position.x + r.size.x * 0.5), 9.0, r.position.y + r.size.y * 0.5)
		parent.add_child(ground)
