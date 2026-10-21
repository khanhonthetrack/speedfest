extends Node
## TmTextureMod and TmMaterials.use_mod without any downloaded mod: zips written here under the
## games' own texture names. Which game and environment each is for (TMNF Stadium, ManiaPlanet
## Stadium, Coast, Storm and Valley's generic names, a name hint), a BC5 normal map whose mip chain
## stops at 4 x 4 (old exporters; Godot wants it to 1 x 1) decodes, and a Stadium mod dresses our
## materials: the road's asphalt takes its StadiumRoadD region in the block's frame, a key it has no
## texture for keeps ours; null puts our own look back.

var _dir := ""


func _ready() -> void:
	_dir = ProjectSettings.globalize_path("user://test_texture_mods")
	DirAccess.make_dir_recursive_absolute(_dir)
	var stadium := _zip("stadium_tm1.zip", {"Image/StadiumRoadD.png": Color(0.5, 0.2, 0.2), "Image/StadiumGrass1.png": Color(0.1, 0.5, 0.1),
		"Moods/Night/StadiumRoadBorderD.png": Color.BLACK, "readme.txt": "hi"})
	var m := TmTextureMod.load_zip(stadium)
	TestHooks.check(m.ok() and m.environment == "Stadium" and m.game == "tm1" and m.is_stadium() and m.images.size() == 3,
		"mod_tm1_stadium", "%s %s %s %s" % [m.error, m.environment, m.game, m.images.keys()])
	TestHooks.check(m.texture("stadiumroadd") != null and m.texture("StadiumRoadD") == m.texture("stadiumroadd")
		and m.images.has("night/stadiumroadborderd") and m.others.size() == 1, "mod_textures_by_name")
	var mp := TmTextureMod.load_zip(_zip("stadium_mp.zip", {"Image/StadiumGrass_D.png": Color.GREEN, "Image/StadiumRoadD.png": Color.GRAY}))
	TestHooks.check(mp.environment == "Stadium" and mp.game == "maniaplanet", "mod_maniaplanet_stadium", "%s %s" % [mp.environment, mp.game])
	var coast := TmTextureMod.load_zip(_zip("coast.zip", {"Image/CoastRoad.png": Color.GRAY, "Image/CoastVegetation.png": Color.GREEN}))
	TestHooks.check(coast.environment == "Coast" and coast.game == "tm1" and not coast.is_stadium(), "mod_tm1_coast", coast.environment)
	var storm := TmTextureMod.load_zip(_zip("storm.zip", {"image/Floor_D.png": Color.GRAY, "image/Tech_D.png": Color.WHITE}))
	TestHooks.check(storm.environment == "Storm" and storm.game == "maniaplanet", "mod_storm_generic_names", storm.environment)
	var hinted := TmTextureMod.load_zip(_zip("valley.zip", {"DecalsImage/Decals3D_D.png": Color.GRAY}), "Desert Valley")
	TestHooks.check(hinted.environment == "Valley", "mod_name_hint", hinted.environment)
	var bad := TmTextureMod.load_zip(_zip("empty.zip", {"readme.txt": "no textures"}))
	TestHooks.check(not bad.ok() and bad.error == "no textures", "mod_without_textures", bad.error)
	# a BC5 (ATI2) normal map, 8 x 8, its chain stopping at 4 x 4 (2 levels of 4)
	var dds := _bc5_dds(8, 8, 2)
	TestHooks.check(TmTextureMod.decode(dds, "dds") != null, "mod_bc5_short_chain_decodes")
	# worn: the asphalt from the mod's StadiumRoadD (its region, along the block), grass too; the
	# platform (no StadiumPlatformD in it) keeps ours
	TmMaterials.use_mod(m)
	var asphalt := TmMaterials.get_material("asphalt") as ShaderMaterial
	TestHooks.check(asphalt != null and asphalt.get_shader_parameter("albedo_tex") == m.texture("StadiumRoadD")
		and bool(asphalt.get_shader_parameter("local_map")) and bool(asphalt.get_shader_parameter("swap_uv"))
		and (asphalt.get_shader_parameter("atlas") as Vector4).y > 0.3, "mod_asphalt_worn")
	var grass := TmMaterials.get_material("grass") as ShaderMaterial
	TestHooks.check(grass != null and grass.get_shader_parameter("albedo_tex") == m.texture("StadiumGrass1"), "mod_grass_worn")
	var plat := TmMaterials.get_material("platform")
	TestHooks.check(not (plat is ShaderMaterial and (plat as ShaderMaterial).get_shader_parameter("albedo_tex") == m.texture("StadiumRoadD")),
		"mod_missing_texture_keeps_ours")
	TmMaterials.use_mod(coast)
	TestHooks.check(TmMaterials.mod == null, "mod_other_environment_not_worn")
	TmMaterials.use_mod(null)
	var ours := TmMaterials.get_material("asphalt")
	TestHooks.check(not (ours is ShaderMaterial and (ours as ShaderMaterial).get_shader_parameter("albedo_tex") == m.texture("StadiumRoadD")),
		"mod_our_look_back")
	TestHooks.finish()


func _zip(name: String, files: Dictionary) -> String:
	var path := _dir.path_join(name)
	var z := ZIPPacker.new()
	z.open(path)
	for f: String in files:
		z.start_file(f)
		if files[f] is Color:
			var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
			img.fill(files[f])
			z.write_file(img.save_png_to_buffer())
		else:
			z.write_file(String(files[f]).to_utf8_buffer())
		z.close_file()
	z.close()
	TmTextureMod.forget(path)
	return path


## A DDS of BC5 blocks (16 bytes per 4 x 4), `levels` mip levels.
static func _bc5_dds(w: int, h: int, levels: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(128)
	out.encode_u32(0, 0x20534444)        # "DDS "
	out.encode_u32(4, 124)
	out.encode_u32(8, 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000)
	out.encode_u32(12, h)
	out.encode_u32(16, w)
	out.encode_u32(20, w * h)            # a "linear size" old exporters got wrong
	out.encode_u32(28, levels)
	out.encode_u32(76, 32)
	out.encode_u32(80, 0x4)              # DDPF_FOURCC
	out[84] = 65; out[85] = 84; out[86] = 73; out[87] = 50   # "ATI2"
	out.encode_u32(108, 0x1000 | 0x400000 | 0x8)
	for i in levels:
		var blocks := maxi(1, (w >> i) / 4) * maxi(1, (h >> i) / 4)
		for b in blocks * 16:
			out.append(128 if b % 8 < 2 else 0)
	return out
