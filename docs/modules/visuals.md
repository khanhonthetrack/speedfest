# visuals — car visuals (module doc)

Branch: `module/visuals`. Owner files: `game/cars/visual/**`, `game/shaders/car_*.gdshader`,
`game/tests/visual/**`, this doc.

## What it does
Three procedural, original cars built entirely in code, with NFSU2-style customization:

| car | look |
|---|---|
| `kaze` | JDM wedge coupe: raised pop-up headlights, slot grille, box flares, notchback, full-width tail panel |
| `brute` | muscle: tall flat nose, full-width chrome-ringed grille with quad round lamps, long hood, fastback, wide hips, full-width tail bar, quad tips |
| `veloce` | mid-engine wedge: very low nose with fender humps, swept LED strips, cab-forward glass, side intakes, wide tail, center exhausts |

- **Body**: lofted cross-sections along the length (`CarShape` keyframed profiles → `CarBody`),
  wheel arches cut into the section (with dark wheel-well liners), curved nose/tail (`end_bulge`),
  separate greenhouse loft with glass/pillar/roof material zones, dark interior shell, seats, dash, wheel.
- **Parts** (`CarParts`): hood 0..3 (stock, vented, scoop, twin scoop; carbon via a shader flag, no
  rebuild), front 0..2, rear 0..2, skirts 0..2, spoiler 0..4 (none, lip, ducktail, GT wing, high wing
  with accent endplates), mirrors, door seams + handles, grilles, lamps, exhaust tips, plate.
- **Wheels** (`CarWheels`): tire with tread + sidewall lettering, 5 rim designs (Spoke-5, Mesh, Deep
  dish, Turbine, Split-6), polished lip, hub, lug nuts, slotted brake disc, caliper. All 4 wheels are
  one MultiMesh (1 draw call), calipers another.
- **Shaders**: `car_paint` (gloss, metallic flake with distance fade, pearl fresnel shift, matte,
  chrome; liveries racing_stripes/side_stripe/two_tone/fade(halftone)/checker in car-local space;
  carbon twill; clearcoat on Forward+ only), `car_lights` (head/tail/brake/reverse/indicator by vertex
  alpha), `car_wheel`, `car_glow` (underglow blob: static/pulse/strobe/rainbow), `car_flame` (nitro).
- **Underglow**: additive ground blob + one OmniLight (skipped on Compatibility below quality 2, or
  when `underglow_light_allowed = false`). Light animates with the mode.
- **Nitro**: blue flame cones on every exhaust tip + particles (CPUParticles3D on compat,
  GPUParticles3D on Forward+), world-space so they trail.
- **Ghost**: `set_ghost(a < 1)` swaps body and wheels to one translucent paint-tinted material
  (works on both renderers; `GeometryInstance3D.transparency` does not affect ShaderMaterials on compat).
- **Performance**: ≤ 22.6k triangles per car (worst part combo), ≤ 9 draw calls (body 5 surfaces,
  wheels, calipers, glow, plate). Body/wheel meshes are cached per `car:parts` key and shared between
  cars; materials are per-instance surface overrides. Build ≈ 100 ms native (first time per key);
  paint/finish/livery/carbon/colors/tint/underglow/ride height changes are material/transform-only (0 ms).

## File map
- `cars/visual/car_visual.gd` — `CarVisual` (API, node layout, materials, effects, cache)
- `cars/visual/car_shape.gd` — `CarShape` per-car profiles and surface sampling
- `cars/visual/car_body.gd` — `CarBody` shell + greenhouse lofts
- `cars/visual/car_parts.gd` — `CarParts` details and style parts
- `cars/visual/car_wheels.gd` — `CarWheels` wheel/caliper meshes
- `cars/visual/mesh_kit.gd` — `MeshKit` geometry accumulator (auto winding, mirror, lofts, revolve)
- `shaders/car_paint|car_lights|car_wheel|car_glow|car_flame.gdshader`
- `tests/visual/showcase.tscn`, `test_build.tscn`, `bench.tscn`

## API additions (beyond ARCHITECTURE.md)
```gdscript
var underglow_light_allowed := true            # set before build(); false = blob only (e.g. remote cars on web)
var triangle_count: int
func set_headlights_real(on: bool) -> void       # SpotLights (2 on Forward+, 1 on compat); local car only
func get_exhaust_points() -> Array[Vector3]      # CarVisual space
func get_wheel_transform(i: int) -> Transform3D  # FL, FR, RL, RR, current
func get_triangle_count() -> int
```
Conventions: `set_wheel_state` spin is positive when rolling forward (rotation about +X by −spin).
`ride_height` −1..+1 maps to −3.5 cm..+5 cm body offset. Front calipers sit behind the disc.

## How to test
```bash
tools/run_scene.sh res://tests/visual/test_build.tscn --headless --timeout 900 -- --full=false   # sampled (~30 s)
tools/run_scene.sh res://tests/visual/test_build.tscn --headless --timeout 900                    # all 1620 combos
tools/run_scene.sh res://tests/visual/showcase.tscn [--compat] -- --frames=12 --shot=/abs/x.png \
   --car=kaze|brute|veloce|all --angle=front|rear|side|three_quarter|rear_quarter|close|top|low|wheel \
   --style=default|alt|max|parts:H,F,R,S,SP,RIM|livery:NAME|finish:NAME [--nitro=1 --brake=1 --reverse=1 --ghost=0.5 --lights=1 --steer=0.4]
tools/run_scene.sh res://tests/visual/bench.tscn --headless -- --frames=5                         # build timings
```

## Tuning knobs
- Shapes: keyframes in `CarShape._kaze/_brute/_veloce` (`bot`, `belt`, `crown`, `wmax`, `tuck`, greenhouse t keys, `style_k`).
- Paint: `car_paint.gdshader` finish branch constants; lights energy in `car_lights.gdshader`
  (`head_energy`, `tail_energy`, brake boost); glow `energy`/`inner`.
- Ride range: `CarVisual.RIDE_LOW/RIDE_HIGH`.

## Known issues
- Ghost mode shows interior parts through the body (x-ray look).
- Kaze pop-up pods are simple boxes; mirrors are simple blocks.
- Body build ~100 ms native per new part combo (cached afterwards); on web expect a few hundred ms
  for the first build of each combo.

## Integration requests
- Race/RemoteCar: for remote cars on web set `cv.underglow_light_allowed = false` before `build()` if
  the light budget is tight (blob still shows). Call `set_headlights_real(true)` only for the local car.
- Car (physics): call `visual.set_lights(braking, reversing)`, `visual.set_nitro(active)` and
  `visual.set_wheel_state(steer, spin, susp)` every tick (spin positive forward).
