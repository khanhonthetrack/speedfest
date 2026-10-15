# Module: scenery (environments and props)

Branch: `module/scenery`. Owner files: `game/tracks/scenery/**`, `game/shaders/env_*.gdshader`,
`game/tests/scenery/**`, this doc.

## What it builds

`SceneryKit.build_environment(theme)` returns a `SceneryEnv` (Node3D) with a WorldEnvironment
(procedural sky shader, fog, glow, ACES tonemap, SSR/SSAO/volumetric fog authored at max quality),
and the key light. It calls `Settings.tune_environment()` / `Settings.tune_sun()` and **re-tunes
itself on `Settings.changed`** (quality switches apply live in the settings menu).

`SceneryKit.build_props(theme, path, seed)` returns a Node3D ("Props") with the ground/terrain
around the road and all props, placed from the `TrackPath` (and its `zones`).

| theme | environment | props |
|---|---|---|
| `city` (Neon Downtown) | rainy night: blue-violet overcast lit from below by the city, magenta horizon glow, fog + height mist, bloom, SSR (wet road), volumetric fog on Ultra | wet ground with sidewalks/curbs/puddles; ~1400 buildings (frontage lots along the road, back-fill blocks, a far skyline ring), procedural lit windows (MultiMesh + window shader), rooftop boxes, antennas with blinking aviation lights, roof-edge neon; ~130 original neon signs (shop signs with frames, vertical blade signs, rooftop signs; flicker/pulse); street lamps with fake light pools on the road and light cones in the rain; overhead sign gantries (posts have collision); animated billboards on poles; puddle decals (Forward+ High+) |
| `arena` (Pulse Arena) | night stadium: deep purple sky with stars, cyan horizon glow, purple haze, strong bloom | glossy floor with a neon grid; a stadium bowl all around the track (tiers with an animated crowd shader incl. a stadium wave and phone flashes, front wall with LED sponsor boards, roof with neon edges); floodlight towers with lamp banks and volumetric beams; 4 jumbotrons (animated) with "PULSE ARENA"/"SPEEDFEST"; neon arches over the road (chasing lights, legs have collision); neon pylons; sweeping searchlights in the sky |
| `coast` (Sunset Coast) | dusk: procedural sunset sky (gradient, sun disk + halo, pink/orange cirrus), warm low sun with long shadows, aerial-perspective fog with sun scatter | terrain that hugs the road (cliffs down to the sea on one side, hills on the other, a bay opening under bridges, sand/surf/foam at the waterline); animated sea; a rock hill with portals over each tunnel zone; palms (3 procedural variants) and shore groves; rocks, boulders and sea stacks; reflector posts; warm street lamps with light pools; a striped lighthouse with a rotating beam; small towns with warm windows; islands and mountain silhouettes |

All three look good on Forward+ and on Compatibility (web). Measured in the demo (driver/chase
view, 1280×720): Compatibility quality 1: city 65 draw calls / 76k primitives, arena 25 / 41k,
coast 138 / 117k, 0 scenery lights. Forward+ quality 2: city ~160 draw calls / 210k primitives.

## File map

| file | what |
|---|---|
| `tracks/scenery/scenery_kit.gd` | `SceneryKit` API + dispatch (accepts a theme or a track id) |
| `tracks/scenery/scenery_env.gd` | `SceneryEnv`: per-theme environment, sky parameters, live re-tune |
| `tracks/scenery/city_kit.gd`, `arena_kit.gd`, `coast_kit.gd` | the three prop kits |
| `tracks/scenery/scenery_field.gd` | `SceneryField`: path sampled every 4 m + XZ grid; fast nearest-road queries (clearance, lateral, road height, zones) |
| `tracks/scenery/scenery_terrain.gd` | `SceneryTerrain`: ground heightfield hugging the road (chamfer Voronoi for nearest road sample), holes under sunk roads, chunked meshes |
| `tracks/scenery/scenery_mesh.gd` | `SceneryMesh`: triangle collector (boxes, cylinders, lofts, text arrays) -> ArrayMesh |
| `tracks/scenery/scenery_batches.gd` | `SceneryBatches`: merged static geometry per (material, 300 m chunk); TextMesh cache |
| `tracks/scenery/scenery_instances.gd` | `SceneryInstances`: chunked MultiMeshInstance3D builder with visibility ranges |
| `tracks/scenery/scenery_props.gd` | procedural prop meshes (unit box, lamp, beam cone, rock, palm, flood tower, delineator) |
| `tracks/scenery/scenery_mat.gd` | shared materials / shader cache |
| `tracks/scenery/scenery_rain.gd` | `SceneryRain`: rain streaks around the camera (GPU particles on Forward+, CPU on compat) |
| `tracks/scenery/scenery_rotor.gd` | `SceneryRotor`: spins searchlights / the lighthouse beam |
| `shaders/env_sky.gdshader` | sky for all themes (static -> radiance computed once) |
| `shaders/env_building.gdshader` | facades with lit/unlit windows, shop fronts, curtain walls, ribbon windows, houses |
| `shaders/env_neon.gdshader` | unshaded neon (vertex/instance color × energy), UV2.x = animation (steady/flicker/blink/pulse/chase) |
| `shaders/env_glow.gdshader` | additive fake light: ground pools and volumetric beams |
| `shaders/env_screen.gdshader` | animated LED screens (billboards, gantry panels, jumbotrons, sponsor boards) |
| `shaders/env_crowd.gdshader` | stadium crowd |
| `shaders/env_terrain.gdshader` | ground: city sidewalks/asphalt/puddles, arena neon grid floor, coast grass/rock/sand/surf |
| `shaders/env_sea.gdshader` | animated sea |
| `tests/scenery/scenery_demo.tscn` | showcase |
| `tests/scenery/test_scenery.tscn` | headless test |
| `tests/scenery/demo_paths.gd` | sample paths per theme (stand-ins for the real layouts) + a simple road strip |

## API additions (beyond ARCHITECTURE.md)

```gdscript
SceneryKit.THEMES                                # ["city", "arena", "coast"]
SceneryKit.build_rain(theme) -> Node3D           # add as a child of the active Camera3D (empty node for dry themes)
SceneryKit.has_rain(theme) -> bool
SceneryKit.sea_level(theme) -> float             # coast water height (0.0); -1000 for other themes
# build_environment / build_props accept a track id too ("downtown" -> "city").
# props node metadata: "build_ms", "stats" (counts), "footprints" (used by tests).
```

Inputs read from the `TrackPath`:
- `zones`: props skip `no_props`; lamps/gantries/arches skip `tunnel`, `loop`, `jump` (arches also
  `boost`); the coast terrain opens a bay under `bridge` and builds a rock hill over `tunnel`.
- optional `path.set_meta("sea_side", 1.0)` puts the coast sea on the **right** of the direction of
  travel (default: left).

## How it decides heights

- city/arena: the ground is flat at the 20th/10th percentile of road heights and rises/falls to
  follow at-grade road; roads more than 2.5 m above it (elevated highway) pass over it; roads more
  than 1.2 m below it (underpass/tunnel trench) get a hole in the ground.
- coast: the terrain follows the road shoulder everywhere except bridges, then drops to the sea on
  the sea side and climbs into hills on the land side.
- The ground always stays at least 0.3 m under the lowest road edge near the road.

## Placement rules

Every prop is placed with an XZ clearance from the road (`SceneryField.query`, stricter than
`TrackPath.edge_clearance` because it ignores height) of at least: buildings 4.5 m (back-fill
10 m), lamps/posts 2.2 m, billboards 8 m, pylons 6 m, palms 3 m, rocks 4 m + size. Intentional
road-spanning props: city gantries (beam 7.6 m above the road, posts 2.6 m beyond the edge) and
arena arches (top ~1.5 + 0.9 × (half width + 4.5) m, legs 4.5 m beyond the edge). Posts and arch legs
have box collision on layer 1; nothing else has collision (it is out of reach behind the track's
walls).

## Lights and performance

- Real lights: city spot lights under lamps, `min(light_budget/2, lamps)` on Forward+, none on
  Compatibility below Ultra; arena up to `min(budget/4, 12)` coloured omnis at arches (none on
  compat Low/Medium); coast none. All other light is faked: emissive neon/windows + bloom, additive
  light pools and beams. Lights use distance fade.
- MultiMesh chunks (250–400 m) with visibility ranges for small props; merged static meshes per
  material per 300 m chunk; ground in chunks. Few materials (one neon material for all signs).
- Rain: 600/1400/2600/4000 GPU particles (Forward+), 300/700/1100/1500 CPU particles (compat).
- Decals (puddles) only on Forward+ High/Ultra.

## How to test

```bash
tools/run_scene.sh res://tests/scenery/test_scenery.tscn --headless -- --frames=5
tools/run_scene.sh res://tests/scenery/scenery_demo.tscn -- --theme=city --cam=chase --d=300 --frames=30 --shot=/abs/city.png
tools/run_scene.sh res://tests/scenery/scenery_demo.tscn --compat -- --theme=coast --cam=chase --d=400 --frames=30 --quality=1 --shot=/abs/coast.png
# --cam=driver|chase|overview|high  --d=<m>  --lat=<m>  --yaw=<deg>  --fly=<m/s>  --norain  --quality=0..3
```
The demo prints `SCENERY_STATS` (draw calls, primitives, objects, nodes, lights) at `--stats_frame`.

Headless test (24 checks): environment nodes per theme, build time, every prop footprint has
`path.edge_clearance > 2` (except intentional gantries/arches), lights within the budget, no
duplicate instances, rain helper.

## Tuning knobs

- Window brightness: `window_energy` in `city_kit.gd` (`SceneryMat.shader_mat("building", …)`),
  lit fraction per building in `_add_building`.
- Neon energy: `SceneryMat.neon(energy)` per kit; glow in `scenery_env.gd` (`glow_*`).
- Sky colours per theme in `scenery_env.gd` (`_city/_arena/_coast`).
- Coast cliff/hill shapes: `SceneryCoastKit._far_height`.

## Notes and known issues

- Custom shaders keep `vertex()` trivial and compute world/local positions in `fragment()`.
  A `vertex()` that derives varyings from `MODEL_MATRIX` caused depth-prepass vs colour-pass
  mismatches (speckled z-fighting) on Forward+ (seen on lavapipe).
- TextMesh: Orbitron glyphs fail Godot's triangulation (0, 4, 8, 9, A… depending on weight), so signs use
  Rajdhani Bold; Rajdhani's "Z" fails, so words with Z use Orbitron 500 (or "2" if they also contain a
  failing Orbitron glyph).
- SSR: at quality 2 (Forward+) I could not get visible road reflections under the software renderer,
  even with more SSR steps; at quality 3 they show. The wet look mostly comes from the road shader
  (tracks module), the fake light pools and the bloom.
- At exit Godot reports a few leaked shaders/materials: the static material/mesh caches. Harmless.
- No collision on buildings, stands, palms or rocks: the track's walls keep cars on the road.

## Integration requests

- **tracks**: call `SceneryKit.build_environment(TrackDefs.theme(id))` and
  `SceneryKit.build_props(TrackDefs.theme(id), path, seed)`; fill `path.zones` (`tunnel`, `bridge`,
  `loop`, `jump`, `boost`, `no_props`) so props avoid stunts and the coast terrain opens bays and
  builds tunnel hills. If the coast sea should be on the right, set `path.set_meta("sea_side", 1.0)`.
  Don't build your own ground plane under the scenery ground (it sits 0.3 m under the road edge).
  For "no_props" use it around checkpoint gates if a prop ever clashes visually.
- **race**: for the city, add `SceneryKit.build_rain(theme)` as a child of the chase camera
  (it is world-space and follows the camera). Camera `far` ≥ 3000 m so the skyline/islands show.
