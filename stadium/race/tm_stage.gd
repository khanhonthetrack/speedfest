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


## The challenge named by the args: --map=/path/X.Challenge.Gbx (any TMNF track file) or
## --map=/path/X.sftrack (a track made in our editor, TmUserTracks), or
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
	if path.to_lower().ends_with(TmUserTracks.EXT):
		return TmUserTracks.challenge_file(path)
	return TmChallenge.load_file(path)


## The Stadium's four floodlight heads at night (TmStadiumBuild.TOWER_HEAD), each lighting the
## field from its corner: spot lights without falloff over the field (their range's edge beyond it).
static func _floodlights(parent: Node, energy := 0.55) -> void:
	var c := TmGeo.g(TmStadiumBuild.CENTRE)
	var h := TmStadiumBuild.TOWER_HEAD
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var spot := SpotLight3D.new()
			spot.name = "Floodlight"
			var at := c + Vector3(sx * h.x, h.y, sz * absf(h.z))
			spot.transform = Transform3D(Basis.looking_at(c + Vector3(-sx * 120.0, 0.0, -sz * 80.0) - at, Vector3.UP), at)
			spot.light_color = Color(0.95, 0.97, 1.0)
			spot.light_energy = energy
			spot.spot_range = 1800.0
			spot.spot_angle = 48.0
			spot.spot_attenuation = 0.0
			spot.spot_angle_attenuation = 0.6
			spot.light_specular = 0.6
			spot.light_cull_mask = 0xFFFFF & ~TmSkyline.LAYER     # the field, not the city around
			parent.add_child(spot)


## One reflection probe over the whole field, captured once from 20 m up when the map is in the
## scene: the car's paint, the gates' metal and glass reflect the Stadium around them instead of
## only the sky (Environment reflections are the sky's alone). Ambient is left to the sky and
## the map's occlusion (TmOcclusion).
static func field_probe(builder: TmMapBuilder) -> ReflectionProbe:
	var w := float(builder.challenge.size.x) * 32.0
	var d := float(builder.challenge.size.z) * 32.0
	var probe := ReflectionProbe.new()
	probe.name = "FieldProbe"
	probe.size = Vector3(w + 160.0, 400.0, d + 160.0)
	probe.position = Vector3(-w * 0.5, 9.0 + 20.0, d * 0.5)    # TMNF x negated; 20 m over the ground
	probe.origin_offset = Vector3.ZERO
	probe.box_projection = false
	probe.max_distance = 2000.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.intensity = 1.0
	return probe


## Sun and sky (TmStadiumEnv, in the map's mood) and, around a 32 x 32 map, the Stadium
## (TmStadiumBuild; at night its floodlights on), the city around it (TmSkyline; not with
## --city=false) and a city track's towers on the field (TmSkyline.field); around maps of other
## sizes plain grass from the map's edge to the horizon (the map's own ground is built with it by
## TmMapBuilder).
static func add_environment(parent: Node, builder: TmMapBuilder) -> void:
	var we := TmStadiumEnv.add(parent, TmStadiumEnv.mood_of(builder.challenge))
	var city_map := builder.challenge.scenery == "city"
	TmNeon.setup(city_map, TmStadiumEnv.night)
	if city_map:
		TmStadiumEnv.city(we, TmStadiumEnv.night)
	TmOcclusion.add(parent, builder)
	parent.add_child(field_probe(builder))
	if builder.challenge.size.x == 32 and builder.challenge.size.z == 32:
		if TmRefVisuals.active():
			# research (--ref): TMNF's own surround, from local files (TmRefVisuals)
			var ref := TmRefVisuals.visual("Zone/Square32")
			if ref != null:
				ref.position = Vector3(0.0, TmStadiumBuild.FIELD_Y, 0.0)
				parent.add_child(ref)
				return
		parent.add_child(TmStadiumBuild.build())
		if city_map:
			parent.add_child(TmStadiumBuild.neon(TmStadiumEnv.night))
			var ship := TmAirshipOrbit.make(TmStadiumEnv.night)
			if ship != null:
				parent.add_child(ship)
		if TmStadiumEnv.night:
			_floodlights(parent, 0.14 if city_map else 0.55)     # a City night is the neon's and the street lights'
		if city_map:
			parent.add_child(TmSkyline.field(builder))
			parent.add_child(TmNeon.track_lights(builder.challenge.path, TmStadiumEnv.night))
		if String(TestHooks.arg("city", "true")) != "false":
			# built on a worker thread: the race doesn't wait for it (TmSkyline.build_async)
			var city := Node3D.new()
			city.name = "City"
			city.position = TmGeo.g(TmStadiumBuild.CENTRE) + Vector3(0.0, TmStadiumBuild.BOTTOM, 0.0)
			parent.add_child(city)
			TmSkyline.build_async(city)
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
