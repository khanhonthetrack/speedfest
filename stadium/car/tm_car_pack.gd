class_name TmCarPack
extends RefCounted
## A car pack: a TMNF car model or skin as players share them (.zip, e.g. from ManiaPark; a server
## checks and repacks the ones its admins upload: stadium/server/lib/content.js). Holds the model
## (MainBody.Solid.Gbx, read by TmSolid), its textures (Diffuse, Details, Illum: DDS, TGA, PNG,
## JPG or BMP) and engine sounds (EngineIdle/Low/Mid/Fast/Rev/Rev2 .wav or .ogg). Loaded once per
## file and shared by every car that drives it (TmCarVisual.pack).
##
## TMNF binds textures by part name: a part's material letter (sBody, dFLWheel, gBody; WheelFLd;
## or the whole word: Skin, Details, Glass) picks Diffuse (s), Details (d, p) or Details as glass
## (g). Wheels (FLWheel, WheelFRs, ...) spin and steer, hubs and guards (dFLHub, sFRGuard) steer;
## Light* and ProjShad nodes are markers (lamp places, the shadow quad), not drawn.
##
## A skin without a model (only its textures: TMNF paints them on its own Stadium car, which we
## don't ship) loads too: skin_only, and our car is painted in its main colour (colour).
##
## body: ArrayMesh in the car's frame (surfaces "pack_skin", "pack_details", "pack_glass");
## wheels: per wheel FL, FR, RL, RR: {} (the model has none: its wheels are part of the body) or
##         {centre: Vector3, spin: ArrayMesh or null, fixed: ArrayMesh or null} (meshes about the
##         wheel's centre); lamps: {name: Vector3}.

const CORNERS := ["FL", "FR", "RL", "RR"]
const TEXTURE_EXT := ["dds", "tga", "png", "jpg", "jpeg", "bmp"]
## The engine's layers (TmCarAudio.LAYERS) from TMNF's engine sounds.
const ENGINE_SOUNDS := {"engine_idle": "engineidle", "engine_low": "enginelow", "engine_mid": "enginemid",
	"engine_high": "enginefast", "engine_coast_low": "enginerev", "engine_coast_high": "enginerev2"}
const SURFACES := {"s": "pack_skin", "d": "pack_details", "p": "pack_details", "g": "pack_glass"}

var error := ""
var path := ""
var solid: TmSolid
var textures := {}              ## "diffuse" / "details" / "illum" -> Texture2D
var sounds := {}                ## TmCarAudio layer name -> AudioStream
var body: ArrayMesh
var wheels: Array = [{}, {}, {}, {}]
var lamps := {}
var skin_only := false          ## textures but no model: our car in the skin's colour
var colour := Color(0.85, 0.08, 0.06)

static var _cache := {}         ## path -> TmCarPack


## The pack at path (a .zip), loaded once.
static func load_zip(zip_path: String) -> TmCarPack:
	if _cache.has(zip_path):
		return _cache[zip_path]
	var p := TmCarPack.new()
	p.path = zip_path
	p._load()
	if p.ok():
		_cache[zip_path] = p
	return p


func ok() -> bool:
	return error.is_empty()


## A pack's material letter for a part name ("" for markers that aren't drawn).
static func material_of(part: String) -> String:
	var n := part.strip_edges()
	while n.length() > 1 and n[-1] >= "0" and n[-1] <= "9":
		n = n.left(-1)
	var low := n.to_lower()
	if low.begins_with("light") or low.begins_with("projshad") or low.begins_with("shadow") or low.is_empty():
		return ""
	if low.begins_with("skin"):
		return "s"
	if low.begins_with("detail"):
		return "d"
	if low.begins_with("glass"):
		return "g"
	if n.length() > 1 and n[0] in ["s", "d", "g", "p"] and n[1] == n[1].to_upper() and n[1] != n[1].to_lower():
		return n[0]
	if n.length() > 1 and n[-1] in ["s", "d", "g", "p"] and n[-2] == n[-2].to_upper():
		return n[-1]
	return "s"


## A part's wheel (0..3 FL, FR, RL, RR) and whether it spins: wheels spin, hubs and guards only
## steer; -1 for the body.
static func wheel_of(part: String) -> Array:
	var low := part.to_lower()
	var spin := low.contains("wheel")
	if not spin and not low.contains("hub") and not low.contains("guard"):
		return [-1, false]
	for i in CORNERS.size():
		if part.contains(CORNERS[i]):
			return [i, spin]
	return [-1, false]


func _load() -> void:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		error = "not a zip file"
		return
	var files := {}             ## lower-case name (no folder, except Engine/) -> path in the zip
	for f in zip.get_files():
		if f.ends_with("/"):
			continue
		var low := f.to_lower()
		var key := low.get_file()
		if low.contains("engine/"):
			key = "engine/" + key
		if not files.has(key):
			files[key] = f
	for t in ["diffuse", "details", "illum"]:
		for ext: String in TEXTURE_EXT:
			if files.has(t + "." + ext):
				var tex := _texture(zip.read_file(files[t + "." + ext]), ext)
				if tex:
					textures[t] = tex
					break
	for layer: String in ENGINE_SOUNDS:
		for ext in ["wav", "ogg"]:
			var k: String = ENGINE_SOUNDS[layer] + "." + ext
			if files.has(k):
				var s := _sound(zip.read_file(files[k]), ext)
				if s:
					sounds[layer] = s
					break
	# the model TMNF drives (MainBody), else its menu version (MainBodyHigh) if that one reads
	var errors: PackedStringArray = []
	for k in ["mainbody.solid.gbx", "mainbodyhigh.solid.gbx"]:
		if not files.has(k):
			continue
		var s := TmSolid.load_bytes(zip.read_file(files[k]))
		if s.ok():
			solid = s
			break
		errors.append("%s: %s" % [String(files[k]).get_file(), s.error])
	zip.close()
	if solid != null:
		_build()
	elif errors.is_empty() and textures.has("diffuse"):
		skin_only = true
		colour = _main_colour(textures["diffuse"])
	elif errors.is_empty():
		error = "no car in the pack (MainBody.Solid.Gbx or a Diffuse texture)"
	else:
		error = "; ".join(errors)


## A skin's main colour: the mean of its texture's colours, brightened like car paint.
static func _main_colour(tex: Texture2D) -> Color:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return Color(0.85, 0.08, 0.06)
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var sum := Vector3.ZERO
	for y in 16:
		for x in 16:
			var c := img.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
	sum /= 256.0
	return Color(sum.x, sum.y, sum.z)


static func _texture(bytes: PackedByteArray, ext: String) -> Texture2D:
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match ext:
		"dds": err = img.load_dds_from_buffer(_dds_fixed(bytes))
		"tga": err = img.load_tga_from_buffer(bytes)
		"png": err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg": err = img.load_jpg_from_buffer(bytes)
		"bmp": err = img.load_bmp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	if not img.has_mipmaps():
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Old DDS exporters (Photoshop's NVIDIA plugin) store a wrong pitch / linear size, or stop the
## mipmap chain before 1 x 1, both of which Godot's loader refuses: drop those header flags (the
## size follows from the format and dimensions) and complete a block-compressed chain with blank
## blocks for its last tiny levels.
static func _dds_fixed(bytes: PackedByteArray) -> PackedByteArray:
	if bytes.size() < 128 or bytes.slice(0, 4).get_string_from_ascii() != "DDS ":
		return bytes
	var out := bytes.duplicate()
	out.encode_u32(8, out.decode_u32(8) & ~0x80008)   # DDSD_LINEARSIZE, DDSD_PITCH
	out.encode_u32(20, 0)
	var h := out.decode_u32(12)
	var w := out.decode_u32(16)
	var mips := maxi(1, out.decode_u32(28))
	var fourcc := out.slice(84, 88).get_string_from_ascii()
	var block := 8 if fourcc == "DXT1" else (16 if fourcc in ["DXT2", "DXT3", "DXT4", "DXT5"] else 0)
	if block == 0 or w == 0 or h == 0 or (out.decode_u32(8) & 0x20000) == 0:
		return out
	var full := 1
	while (w >> (full - 1)) > 1 or (h >> (full - 1)) > 1:
		full += 1
	if mips >= full:
		return out
	var have := 0
	for i in mips:
		have += maxi(1, ((w >> i) + 3) / 4) * maxi(1, ((h >> i) + 3) / 4) * block
	if out.size() < 128 + have:
		return out
	out.resize(128 + have)
	for i in range(mips, full):
		var extra := PackedByteArray()
		extra.resize(maxi(1, ((w >> i) + 3) / 4) * maxi(1, ((h >> i) + 3) / 4) * block)
		out.append_array(extra)
	out.encode_u32(28, full)
	return out


static func _sound(bytes: PackedByteArray, ext: String) -> AudioStream:
	if ext == "ogg":
		var o := AudioStreamOggVorbis.load_from_buffer(bytes)
		if o:
			o.loop = true
		return o
	var w := AudioStreamWAV.load_from_buffer(bytes)
	if w == null:
		return null
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	var frame := (1 if w.format == AudioStreamWAV.FORMAT_8_BITS else 2) * (2 if w.stereo else 1)
	w.loop_end = w.data.size() / frame if w.format != AudioStreamWAV.FORMAT_IMA_ADPCM else int(w.get_length() * w.mix_rate)
	return w


## Sorts the model's parts into the body and the wheels, merged into one surface per material.
func _build() -> void:
	var groups := {}            ## "body" / "spin<i>" / "fixed<i>" -> {surface: [part, transform]}
	var centres := [null, null, null, null]
	# a wheel's centre: the middle of its spinning parts' box in the car (else of its hub's), so
	# models that keep their wheels' vertices in the car's frame spin them about their axle too
	for spin_pass in [true, false]:
		var boxes := [null, null, null, null]
		for p: Dictionary in solid.parts:
			var w := wheel_of(String(p["name"]))
			var i := int(w[0])
			if i < 0 or bool(w[1]) != spin_pass or centres[i] != null or material_of(String(p["name"])) == "":
				continue
			var xf: Transform3D = p["xform"]
			for v: Vector3 in p["verts"]:
				var q := xf * v
				boxes[i] = AABB(q, Vector3.ZERO) if boxes[i] == null else (boxes[i] as AABB).expand(q)
		for i in 4:
			if centres[i] == null and boxes[i] != null:
				centres[i] = (boxes[i] as AABB).get_center()
	for p: Dictionary in solid.parts:
		var name := String(p["name"])
		var mat := material_of(name)
		if mat.is_empty():
			continue
		var w := wheel_of(name)
		var key := "body"
		var xf: Transform3D = p["xform"]
		if int(w[0]) >= 0:
			key = ("spin%d" if w[1] else "fixed%d") % int(w[0])
			xf = Transform3D(Basis.IDENTITY, -(centres[int(w[0])] as Vector3)) * xf
		var surf: String = SURFACES[mat]
		if not groups.has(key):
			groups[key] = {}
		if not (groups[key] as Dictionary).has(surf):
			groups[key][surf] = []
		groups[key][surf].append([p, xf])
	body = _mesh(groups.get("body", {}))
	if body == null:
		body = ArrayMesh.new()
	var slot := _slots(centres)
	for i in 4:
		if centres[i] == null:
			continue
		wheels[slot[i]] = {"centre": centres[i], "spin": _mesh(groups.get("spin%d" % i, {})),
			"fixed": _mesh(groups.get("fixed%d" % i, {}))}
	for name: String in solid.points:
		if name.to_lower().begins_with("light"):
			lamps[name] = (solid.points[name] as Transform3D).origin
	for p: Dictionary in solid.parts:
		if String(p["name"]).to_lower().begins_with("light"):
			lamps[String(p["name"])] = (p["xform"] as Transform3D).origin


## Which of the car's wheels (TmTuning.WHEELS: FL, FR, RL, RR in our frame) each named wheel is,
## by where it sits (TMNF's "FL" is our front right once mirrored, and a few models name theirs the
## other way round); by name (mirrored) when that is ambiguous.
static func _slots(centres: Array) -> Array:
	var found := centres.filter(func(c: Variant) -> bool: return c != null)
	var zmin := INF
	var zmax := -INF
	for c: Vector3 in found:
		zmin = minf(zmin, c.z)
		zmax = maxf(zmax, c.z)
	var out := [1, 0, 3, 2]
	var by_place := []
	for i in 4:
		if centres[i] == null:
			by_place.append(-1 - i)
			continue
		var c: Vector3 = centres[i]
		var front := c.z > (zmin + zmax) * 0.5 if zmax - zmin > 0.5 else i < 2
		if absf(c.x) < 0.05:
			return out
		by_place.append((0 if c.x > 0.0 else 1) + (0 if front else 2))
	for i in 4:
		for j in range(i + 1, 4):
			if by_place[i] == by_place[j]:
				return out
	return by_place.map(func(k: int) -> int: return k if k >= 0 else out[-1 - k])


## One ArrayMesh with a surface per material from [part, transform] lists (null if empty).
static func _mesh(surfaces: Dictionary) -> ArrayMesh:
	if surfaces.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for surf: String in surfaces:
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var all_normals := true
		for e: Array in surfaces[surf]:
			if (e[0]["normals"] as PackedVector3Array).is_empty():
				all_normals = false
		for e: Array in surfaces[surf]:
			var p: Dictionary = e[0]
			var xf: Transform3D = e[1]
			var base := verts.size()
			var pv: PackedVector3Array = p["verts"]
			var pn: PackedVector3Array = p["normals"]
			var pu: PackedVector2Array = p["uvs"]
			var nb := xf.basis.inverse().transposed()
			for i in pv.size():
				verts.append(xf * pv[i])
				if all_normals:
					normals.append((nb * pn[i]).normalized())
				uvs.append(pu[i] if not pu.is_empty() else Vector2.ZERO)
			for k: int in p["indices"]:
				idx.append(base + k)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = idx
		if all_normals:
			arrays[Mesh.ARRAY_NORMAL] = normals
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		else:
			var st := SurfaceTool.new()
			st.create_from_arrays(arrays)
			st.generate_normals()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		mesh.surface_set_name(mesh.get_surface_count() - 1, surf)
	return mesh


## A material for one of the pack's surfaces (a ghost's is see-through).
func material(surface: String, ghost := false, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex: Texture2D = textures.get("details" if surface != "pack_skin" else "diffuse")
	m.albedo_texture = tex
	m.albedo_color = tint if tex == null else Color.WHITE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match surface:
		"pack_skin":
			m.metallic = 0.35
			m.roughness = 0.3
		"pack_glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.6
			m.roughness = 0.08
			if tex == null:
				m.albedo_color = Color(0.1, 0.12, 0.15, 0.55)
		_:
			m.roughness = 0.55
			if textures.has("illum"):
				m.emission_enabled = true
				m.emission_texture = textures["illum"]
				m.emission = Color.WHITE
				m.emission_energy_multiplier = 0.8
	if ghost:
		m.albedo_color = Color(m.albedo_color, 0.38)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = false
	return m
