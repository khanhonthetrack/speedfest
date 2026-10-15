# tracks: track builder and layouts

Owner: tracks module agent. Status: M1 (three drivable layouts, tested).

## What it builds

`Track.build(track_id)` loads `res://tracks/defs/<id>.gd`, runs the layout "turtle" in
`TrackBuilder.build_layout()` to get a `TrackPath` plus gameplay data, then builds:

- **Road**: lofted along `TrackPath` frames in ~150 m chunks (one `MeshInstance3D` per chunk
  for frustum culling; surfaces: road shader, slab sides, barrier, neon/reflector strip).
  Collision is **one seamless** `ConcavePolygonShape3D` (road top, slab edges, barriers;
  backface collision on) on layer 1: per-chunk bodies left seams the car snagged on at the
  loop crown.
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
- **Corner boards**: glowing chevron boards (`shaders/track_chevron.gdshader`) on the outside
  of corners tighter than `sign_radius` (default 75 m), pointing in the turn direction.
- **City sidewalks**: raised 5 m sidewalks behind the barriers where the road is at street level.
- **Arch bridge** (coast bridge zone): two orange steel arches with hangers and top bracing;
  pillars only near the bridge ends.
- **Jump dressing**: hazard stripes (`shaders/track_stripes.gdshader`) on the last 7 m of each
  kicker and first 5 m of each landing, glowing bars along the lip and landing edges.
- **Loop gantry** (arena): two neon towers outside the entry/exit roads and a beam over the
  loop's crown with hangers (towers have collision).
- **Night readability**: lane paint has a faint retro-reflective glow (`paint_glow`), and tunnels
  get fake sodium bounce light on the road and walls (stronger on Compatibility / quality < 2,
  where there are no real tunnel lights).
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
| arena | ~1530 m | 4 | 3 boost pads, vertical loop r=20 (13 m wide, shifted 17 m), 180° banked 32°, gap jump (4 m kicker, 20 m gap), final jump (3.2 m kicker, 20 m gap) that lands on the start straight; 16 m wide |
| coast | 3254 m | 5 | point to point, starts at 34 m and ends at 6 m, sweepers r=220..260 banked 7..8°, 340 m arch bridge over a bay (deck ~14 m), rock tunnel ~250 m with a curve; 15 m wide |

Banked turns are lifted by `(width/2 + 1) * sin(bank)` so the low edge stays at the original
height (otherwise the inner edge would sink into the ground).

Start pose: circuits start 6 m **past** the start/finish line (the car never touches the finish
trigger at spawn; a lap ends when it crosses the line). Point-to-point starts 6 m behind the
start arch (which has no trigger). `get_start_pose_distance()` returns that distance.

### Layout format (`res://tracks/defs/<id>.gd`)

A script with `func layout() -> Dictionary`:
```
width, circuit, start_pos, start_yaw (deg), walls ("both"), wall_style (concrete|neon|guardrail),
ground (city|arena|terrain|none), ground_y, ground_visual (default true; false = collision only),
road_depth, sign_radius, wet, kill_y (optional), segments: [...]
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
`build_terrain`, `build_corner_signs`, `loft`, `material(key)`, `road_material(style, wet)`, `path_bbox`, `in_ranges`.

`TrackPath`: API unchanged. Added `loop_axes` + `set_loop_axes(axes)`: inside a loop the road's
right vector is the loop's fixed lateral axis, so laterally shifted loops have no twist (plain
parallel transport accumulated ~53° of roll and snapped back at the exit: a 53°/m kink).

Gate triggers are 40 m tall (`Track.GATE_TRIGGER_H`) so a car flying over an arch after a jump
still counts. Barrier collision is 2.6 m tall (`TrackBuilder.WALL_COLLISION_H`), taller than the
visual barrier, so fast cars can't climb over.

## Tests

- `tools/run_scene.sh res://tests/tracks/test_tracks.tscn --headless -- [--track=id]`
  (71 checks): length and CP-count ranges, CP order, continuity (≤ 1.3 m/m, ≤ 4.5°/m),
  surface twist (≤ 4.5°/m of the road normal), circuit closure, no self-intersections outside loops (bridges cross > 6.5 m apart), kill_y,
  spawn poses 0.6 m above the road by raycast and facing forward, gates span the road, loop
  radius and shape, jump min speed (< 110 km/h), run-out straight for a 210 km/h flight,
  landing reached at 150 km/h, and a frozen probe `Car` pushed along the path triggers every
  checkpoint in order and then the finish (nothing else).
- `tools/run_scene.sh res://tests/tracks/drive_test.tscn --headless -- --track=id [--car=kaze] [--max_s=120] [--trace=true]`
  drives the real `Car` with the physics module's `AutoDriver` (needs `module/physics` merged),
  respawning at the last checkpoint below `kill_y` or when the bot reports stuck. Results with
  `module/physics` as of 00:58 UTC (kaze, AutoDriver): **arena 43.2 s, downtown 60.4 s,
  coast 57.0 s, 0 respawns on all three** (targets 45 / 60 / 60 s). brute: 41.7 / 60.3 / 56.8 s,
  veloce: 40.6 / 58.7 / 53.1 s, also 0 respawns.
- `tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=id --views="overview;drive:120;chase:300;orbit:870;side:500" --out=/abs/dir --tag=x`
  screenshots (prints draw calls / primitives per view).
- `tools/run_scene.sh res://tests/tracks/layout_map.tscn --headless -- --out=/abs/dir`: top-down
  PNG map per layout (height-colored, gaps grey, tunnels orange, CPs white).

## Known issues / notes

- Coast terrain has no collision (cars can't reach it past the guardrails; a car that somehow
  gets over falls to `kill_y` = -3 and respawns).
- The sea itself is the scenery module's (expected at y = 0). Arena/city ground is at y = -0.12.

## Integration requests

- **scenery / integrator**: the scenery city kit also builds a ground at `ground_y - 0.3`, under
  the track's city ground (y = -0.12, wet pavement with collision). If the scenery ground looks
  better, set `"ground_visual": false` in `defs/downtown.gd` (keeps the collision). The coast
  terrain (cliffs, bay, mountain over the tunnel) is the track's; the scenery coast kit should
  only add the sea, palms, rocks, etc.
- **scenery**: sea plane at **y = 0** for `coast`. Until scenery provides one, `Track.build`
  adds a fallback sea (`TrackSeaFallback`, `shaders/track_sea.gdshader`) for terrain tracks
  when no environment/props node has "sea" in its name. Name your sea node e.g. `Sea` and the
  fallback disappears automatically. Ground (city pavement, arena floor, coast
  terrain) is built by the track; don't add another ground plane under the road. Use
  `path.zones` (`tunnel`, `bridge`, `loop`, `jump`, `boost`) and `edge_clearance()`.
- **race**: circuits start past the line (see above). Pits under arena jumps rely on the
  `kill_y` auto-respawn.
- **physics** (from `drive_test` with the AutoDriver): (1) the bot rides the barriers at speed on
  downtown corners and coast sweepers (lateral offset ±6 m on a 16 m road) and sometimes spins
  (signed speed flips to −40..−70 km/h, e.g. downtown off-ramp at ~150 km/h, arena after the
  first jump landing); (2) after landing a long jump the car sometimes yaws 180°. The track
  geometry there is smooth (continuity and twist tests pass), so this looks like bot speed
  planning / landing stability.
