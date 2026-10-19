class_name SceneryKit
extends RefCounted
## Environments and prop kits per theme ("city", "arena", "coast").
## API (docs/ARCHITECTURE.md "Scenery & environment"):
##   build_environment(theme) -> Node3D   WorldEnvironment + key light + sky + fog (SceneryEnv)
##   build_props(theme, path, seed) -> Node3D   ground/terrain, buildings, lamps, neon, stands...
## Additions (docs/modules/scenery.md): build_rain(theme), has_rain(theme), sea_level(theme).

const THEMES: Array[String] = ["city", "arena", "coast"]


## WorldEnvironment + key light + sky + fog for a theme. Re-tunes itself on Settings.changed.
static func build_environment(theme: String) -> Node3D:
	return SceneryEnv.create(_norm(theme))


## Decorative props along the track (buildings, lamps, stands, palms...), plus the ground or
## terrain around the road. Props keep path.edge_clearance(p) > 2 except intentional overhead
## gantries/arches (their posts stand > 2 m off the road edge).
static func build_props(theme: String, path: TrackPath, rng_seed: int) -> Node3D:
	var t0 := Time.get_ticks_msec()
	var field := SceneryField.new(path, 4.0)
	var node: Node3D
	match _norm(theme):
		"arena":
			node = SceneryArenaKit.new().build(field, rng_seed)
		"coast":
			node = SceneryCoastKit.new().build(field, rng_seed)
		_:
			node = SceneryCityKit.new().build(field, rng_seed)
	node.name = "Props"
	node.set_meta("build_ms", Time.get_ticks_msec() - t0)
	return node


## Rain around the camera. Add the returned node as a child of the active Camera3D; it emits
## in world space, so streaks stay put while the car moves. Empty Node3D for dry themes.
static func build_rain(theme: String) -> Node3D:
	if not has_rain(theme):
		var n := Node3D.new()
		n.name = "NoRain"
		return n
	return SceneryRain.create()


static func has_rain(theme: String) -> bool:
	return _norm(theme) == "city"


## Water level of the coast sea (other themes: -1000).
static func sea_level(theme: String) -> float:
	return SceneryCoastKit.SEA_LEVEL if _norm(theme) == "coast" else -1000.0


## Accepts a theme or a track id ("downtown" -> "city").
static func _norm(theme: String) -> String:
	if THEMES.has(theme):
		return theme
	if TrackDefs.DEFS.has(theme):
		return TrackDefs.theme(theme)
	return "city"
