class_name TmTextureMod
extends RefCounted
## A TrackMania texture mod (TMNF/TMUF or ManiaPlanet, e.g. from ManiaPark): a zip of an
## environment's textures under the game's own names (Image/StadiumRoadD.dds, Moods/...). Read here:
## the game and environment it is for, every texture it ships (decoded on demand), and for a Stadium
## mod the maps our block materials take from it (TmMaterials.use_mod, TmMaterials.MOD_MAP).
##
##   var mod := TmTextureMod.load_zip(path)     # cached per path
##   mod.ok(), mod.error, mod.game ("tm1", "maniaplanet" or ""), mod.environment ("Stadium", ...)
##   mod.texture("StadiumRoadD")                  # a Texture2D (any of its names, case-insensitive)

## The environments by their textures' prefixes (TMNF/TMUF: Stadium, Island, Bay, Coast, Desert
## (Speed), Rally, Snow (Alpine); ManiaPlanet: Stadium, Canyon, Valley, Lagoon, Storm).
const PREFIXES := {"stadium": "Stadium", "island": "Island", "bay": "Bay", "coast": "Coast", "speed": "Desert",
	"desert": "Desert", "rally": "Rally", "alpine": "Snow", "snow": "Snow", "canyon": "Canyon", "valley": "Valley",
	"lagoon": "Lagoon", "storm": "Storm"}
## ManiaPlanet's environments that name their textures without a prefix: names seen only there.
const GENERIC := {"Storm": ["tech_d", "floor_d", "wallpxz_d", "baseground_x2", "floor2_d"],
	"Canyon": ["rocks3d_d", "canyongrass_d", "canyonroad_d"],
	"Valley": ["forest_d", "lakerocks_d", "lakeshore_d", "farmobjects_d", "trees2_d", "concreteroad2way_d", "roaddirtlake_d"]}
## A mod's name, when its textures don't tell: these words first (ManiaPlanet's "Desert Valley" is a
## Valley mod).
const HINT_ORDER := ["stadium", "canyon", "valley", "lagoon", "storm", "island", "bay", "coast", "rally", "alpine",
	"snow", "speed", "desert"]
const IMAGE_EXT := ["dds", "tga", "png", "jpg", "jpeg", "bmp", "exr"]
const MAX_FILES := 4000

static var _cache := {}

var path := ""
var error := ""
var game := ""             ## "tm1" (TMNF/TMUF), "maniaplanet", or "" (not told by its names)
var environment := ""      ## "Stadium", "Canyon", ... or "" (not told by its names)
var images := {}           ## texture name (lower case, no extension) -> zip entry
var others: Array = []     ## the other files (readme, .gbx, ...)
var _zip: ZIPReader
var _decoded := {}         ## texture name -> Texture2D (null: didn't decode)


## The mod in a zip (hint: its name, e.g. ManiaPark's, used when its textures don't name their
## environment: "Canyon No Grass").
static func load_zip(zip_path: String, hint := "") -> TmTextureMod:
	if _cache.has(zip_path):
		return _cache[zip_path]
	var m := TmTextureMod.new()
	m.path = zip_path
	m._open(hint)
	_cache[zip_path] = m
	return m


func ok() -> bool:
	return error.is_empty()


## Drops a mod from the cache (its decoded textures with it): a test going through hundreds.
static func forget(zip_path: String) -> void:
	_cache.erase(zip_path)


## True for a mod our Stadium can wear (its textures are the Stadium's).
func is_stadium() -> bool:
	return ok() and environment == "Stadium"


## A texture by name (case-insensitive, without extension), decoded once; null if the mod doesn't
## have it or it doesn't decode.
func texture(name: String) -> Texture2D:
	var key := name.to_lower()
	if _decoded.has(key):
		return _decoded[key]
	var tex: Texture2D = null
	if images.has(key) and _zip:
		var entry: String = images[key]
		tex = decode(_zip.read_file(entry), entry.get_extension().to_lower())
	_decoded[key] = tex
	return tex


## The first of several names the mod has (TMNF and ManiaPlanet name some textures differently).
func first(names: Array) -> String:
	for n: String in names:
		if images.has(n.to_lower()):
			return n
	return ""


## An image file as a texture (DDS with the old exporters' quirks fixed, TGA, PNG, JPG, BMP, EXR).
static func decode(bytes: PackedByteArray, ext: String) -> Texture2D:
	if bytes.is_empty():
		return null
	if ext == "exr":
		var img := Image.new()
		if img.has_method("load_exr_from_buffer") and img.call("load_exr_from_buffer", bytes) == OK and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
		return null
	return TmCarPack._texture(bytes, ext)


func _open(hint: String) -> void:
	_zip = ZIPReader.new()
	if _zip.open(path) != OK:
		var head := FileAccess.get_file_as_bytes(path).slice(0, 8).get_string_from_ascii()
		error = "a ManiaPlanet pack (.Pack.Gbx, Nadeo's encrypted format), not a zip" if head == "NadeoPak" else "not a zip"
		_zip = null
		return
	var files := _zip.get_files()
	if files.size() > MAX_FILES:
		error = "too many files (%d)" % files.size()
		return
	var votes := {}
	for f in files:
		if f.ends_with("/"):
			continue
		var ext := f.get_extension().to_lower()
		if not ext in IMAGE_EXT:
			others.append(f)
			continue
		var base := f.get_file().get_basename().to_lower()
		var rel := f.to_lower()
		# Moods/<mood>/X keeps its mood (a sky per time of day); the first copy of a name wins
		var key := base if not rel.contains("moods/") or rel.get_base_dir().get_file() == "moods" else "%s/%s" % [rel.get_base_dir().get_file(), base]
		if not images.has(key):
			images[key] = f
		for p: String in PREFIXES:
			if base.begins_with(p):
				votes[PREFIXES[p]] = int(votes.get(PREFIXES[p], 0)) + 1
				break
		for env: String in GENERIC:
			if base in GENERIC[env]:
				votes[env] = int(votes.get(env, 0)) + 3
	if images.is_empty():
		var video := others.filter(func(f: String) -> bool: return f.get_extension().to_lower() in ["webm", "ogv", "bik"])
		error = "only video textures (%s), which the game can't play" % String(video[0]).get_extension().to_upper() if not video.is_empty() else "no textures"
		return
	var best := ""
	for env: String in votes:
		if best.is_empty() or int(votes[env]) > int(votes[best]):
			best = env
	if best.is_empty():
		var h := hint.to_lower()
		for p: String in HINT_ORDER:
			if h.contains(p):
				best = PREFIXES[p]
				break
	environment = best
	# ManiaPlanet names some maps with an underscore (StadiumGrass_D, _N, _X2); TMNF never does
	var mp := false
	for k: String in images:
		if k.ends_with("_d") or k.ends_with("_n") or k.ends_with("_s") or k.contains("_x2"):
			mp = true
			break
	if environment in ["Canyon", "Valley", "Lagoon", "Storm"] or mp:
		game = "maniaplanet"
	elif not environment.is_empty():
		game = "tm1"


## Every texture decoded (the compatibility test): [names that didn't decode]. A file the mod
## ships empty (0 bytes) isn't counted: there is no image to decode (TMNF keeps its own there too).
func check_all() -> Array:
	var bad: Array = []
	for k: String in images:
		if texture(k) == null and not _zip.read_file(String(images[k])).is_empty():
			bad.append(String(images[k]).get_file())
	return bad
