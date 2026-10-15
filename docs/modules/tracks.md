# tracks: track builder and layouts

Owner: tracks module agent. Status: M1 (three drivable layouts, tested).

## What it builds

`Track.build(track_id)` loads `res://tracks/defs/<id>.gd`, runs the layout "turtle" in
`TrackBuilder.build_layout()` to get a `TrackPath` plus gameplay data, then builds:

- **Road**: lofted along `TrackPath` frames in ~150 m chunks (one `MeshInstance3D` per chunk
  for frustum culling; surfaces: road shader, slab sides, barrier, neon/reflector strip).
  Trimesh collision per chunk (`ConcavePolygonShape3D`, backface collision on) on layer 1.
  No road in jump gaps.
- **Road shader** (`shaders/road.gdshader`): procedural asphalt grain + patches + worn racing
  lanes, edge lines, dashed lane lines (city) or double yellow (coast), red/white curbs on
  corners (curb amount from horizontal curvature, passed in UV2.y), wet look with puddles
  (`wetness`, downtown), emissive edge lines (arena).
- **Barriers** with collision (box profile 2 m tall, 0.6 m thick) on both sides unless a
  layout says otherwise; skipped in loops and gaps. Styles: `concrete` (jersey barrier +
  amber reflectors, downtown), `neon` (dark wall + cyan neon strip, arena), `guardrail`
  (W-beam rail + posts as MultiMesh, coast).
- **Skirts**: on flat-ground tracks, ramps up to 7 m tall get solid side walls down to the
  ground (they read as structures, not floating ribbons). In the arena they extend into the pits.
- **Supports**: pillars + caps (MultiMesh, box collision) under elevated road (> 6 m above
  ground) and under the coast bridge. Pillars that would stand on another road are skipped.
- **Tunnels** (zone `tunnel`): arched inner shell, outer box (concrete in the city, rock on
  the coast), portal faces, sodium light strips (emissive) and up to 6 OmniLights on
  Forward+ quality >= 2.
- **Ground**: `city` = wet pavement plane with collision; `arena` = dark floor with a glowing
  grid (`shaders/track_floor.gdshader`), with **pits** under the jump gaps (no collision:
  falling in goes below `kill_y` so the race auto-respawns); `terrain` (coast) = chunked
  heightfield that hugs the road, rises into cliffs on the left, falls into the sea on the
  right, drops into the bay under the bridge and rises into a mountain over the tunnel
  (`shaders/track_terrain.gdshader`, no collision; the guardrails keep cars on the road).
- **Gates**: checkpoint arches (cyan neon; orange on the coast) and a start/finish arch
  (magenta + checker banner + label), each with an `Area3D` (layer 3 = value 4, mask 2)
  spanning the road plus the barriers, 8 m high, 4 m deep. Checkered line on the road.
- **Boost pads**: `Area3D` + scrolling chevron shader (`shaders/track_boost.gdshader`);
  calls `car.apply_boost(forward, accel, duration)` for `Car` bodies.
- Then `SceneryKit.build_environment(theme)` and `SceneryKit.build_props(theme, path, seed)`.

## Layouts

| id | length | CPs | features |
|---|---|---|---|
| downtown | 2070 m | 5 | grid corners r=32 (banked 3°), chicane, on-ramp to a 10 m elevated highway (bridge zone) that crosses over the return leg, off-ramp, 130 m tunnel; 16 m wide; wet |
| arena | 1526 m | 4 | 4 boost pads, vertical loop r=20 (13 m wide, shifted 17 m), 180° banked 32°, gap jump (4 m kicker, 20 m gap), final jump (22 m gap) that lands on the start straight; 16 m wide |
| coast | 3033 m | 5 | point to point, starts at 34 m and ends at 6 m, sweepers r=170..260 banked 4..8°, 340 m bridge over a bay (deck ~14 m), rock tunnel ~250 m with a curve; 14 m wide |

Start pose: circuits start 6 m **past** the start/finish line (the car never touches the finish
trigger at spawn; a lap ends when it crosses the line). Point-to-point starts 6 m behind the
start arch (which has no trigger). `get_start_pose_distance()` returns that distance.

### Layout format (`res://tracks/defs/<id>.gd`)

A script with `func layout() -> Dictionary`:
```
width, circuit, start_pos, start_yaw (deg), walls ("both"), wall_style (concrete|neon|guardrail),
ground (city|arena|terrain|none), ground_y, wet, kill_y (optional), segments: [...]
```
Segments (driven in order, turtle-style):
- `{"s": L, "dy": climb, "w": end_width}` straight (climb eased with smoothstep)
- `{"t": deg, "r": radius, "bank": deg, "dy": climb}` arc; + = right; bank eases in/out
- `{"loop": radius, "shift": lateral}` vertical loop
- `{"jump": {"ramp", "h", "gap", "land"}}` kicker `y = h(x/ramp)^2`, gap (path follows the
  min-speed parabola, no road), landing `y = h(1 - x/land)^2`
- `{"hermite": [Vector3, yaw_deg]}` smooth connector to a pose; `{"close": true}` back to start
- markers: `{"cp": true}`, `{"start": true}`, `{"finish": true}`, `{"boost": len}`,
  `{"zone": kind, "on": bool}`, `{"walls": mode}`; any segment may carry `"zone": kind`.

The dense turtle points become a Curve3D with Catmull-Rom handles (2.5 m spacing). Marker
distances are rescaled from polyline length to the baked curve length.

Zones on `path.zones`: `loop`, `jump`, `tunnel`, `bridge`, `boost` (and the jump gaps are in
`track.data["gaps"]`).

## API additions (beyond ARCHITECTURE.md)

`Track`:
- `static func build(track_id, with_scenery := true)`, `static func build_data(track_id) -> Dictionary`
  (path + gameplay data, no meshes), `static func load_layout(track_id)`
- `checkpoint_distances: Array[float]`, `start_distance`, `finish_distance`, `is_circuit`,
  `theme`, `layout`, `data` (gaps, loops, jumps, boosts), `gates`, `finish_gate`, `boost_pads`
- `get_start_pose_distance() -> float`

`TrackBuilder` (static): `build_layout`, `build_road`, `build_supports`, `build_flat_ground`,
`build_terrain`, `loft`, `material(key)`, `road_material(style, wet)`, `path_bbox`, `in_ranges`.

`TrackPath`: unchanged.

## Tests

- `tools/run_scene.sh res://tests/tracks/test_tracks.tscn --headless -- [--track=id]`
  (68 checks): length and CP-count ranges, CP order, continuity (≤ 1.3 m/m, ≤ 4.5°/m),
  circuit closure, no self-intersections outside loops (bridges cross > 6.5 m apart), kill_y,
  spawn poses 0.6 m above the road by raycast and facing forward, gates span the road, loop
  radius and shape, jump min speed (< 110 km/h), run-out straight for a 210 km/h flight,
  landing reached at 150 km/h, and a frozen probe `Car` pushed along the path triggers every
  checkpoint in order and then the finish (nothing else).
- `tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=id --views="overview;drive:120;chase:300;orbit:870;side:500" --out=/abs/dir --tag=x`
  screenshots (prints draw calls / primitives per view).
- `tools/run_scene.sh res://tests/tracks/layout_map.tscn --headless -- --out=/abs/dir`: top-down
  PNG map per layout (height-colored, gaps grey, tunnels orange, CPs white).

## Known issues / notes

- Coast terrain has no collision (cars can't reach it past the guardrails; a car that somehow
  gets over falls to `kill_y` = -3 and respawns).
- The sea itself is the scenery module's (expected at y = 0). Arena/city ground is at y = -0.12.

## Integration requests

- **scenery**: sea plane at **y = 0** for `coast`. Ground (city pavement, arena floor, coast
  terrain) is built by the track; don't add another ground plane under the road. Use
  `path.zones` (`tunnel`, `bridge`, `loop`, `jump`, `boost`) and `edge_clearance()`.
- **race**: circuits start past the line (see above). Pits under arena jumps rely on the
  `kill_y` auto-respawn.
