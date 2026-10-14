class_name SceneryKit
extends RefCounted
## STUB: the scenery module replaces this with full environments and prop kits.
## API fixed by docs/ARCHITECTURE.md "Scenery & environment". Themes: "city", "arena", "coast".


## WorldEnvironment + key light + sky + fog for a theme.
static func build_environment(theme: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Environment"
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.1) if theme != "coast" else Color(0.9, 0.5, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.45)
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Settings.tune_environment(env)
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 0.6 if theme != "coast" else 1.2
	Settings.tune_sun(sun)
	root.add_child(sun)
	return root


## Decorative props along the track (buildings, lamps, stands, palms...).
static func build_props(_theme: String, _path: TrackPath, _rng_seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Props"
	return root
