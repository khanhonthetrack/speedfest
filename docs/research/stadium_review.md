# Independent review: how close is the Stadium remake to Trackmania? (session 14, 2026-10-18)

Owner's request (TRANSCRIPT, session 14): look at REA, reverse engineer Trackmania (2020) "or any
other trackmania" into "a fully functioning version", then look at the `stadium` branch: how to
improve its textures (the checkpoints "with 2 horns at the top look weird", the car "looks weird",
the graphics "look dated"), and give an independent review of how close it is to the real game.

Reviewed: `stadium` @ 9a6ae41 (v0.3), and, for context, the work in progress on
`claude/tmnf-replica-graphics-nb1kcg` @ 77bb43c (session 13, M9 "a 1:1 TMNF replica"; it already
replaces the car, the gate textures, the menus, the engine sound, and adds replays and an editor).
Method: code reading, the committed measurement tables, and our own renders (Godot 4.7.2 Forward+
under Xvfb on llvmpipe, 1280x720, default settings unless noted: quality High, HD on, no RTX
fork). No Nadeo file was used or downloaded for this review.
The renders, side by side with the scorecard: https://claude.ai/artifact/HPV2TcjtfoE2UJRqEvW5Uc
(private to the owner's account; the PNGs themselves are not committed).

## 0. The reverse-engineering request

- **REA** (morluto/rea) is an MCP server that connects an agent to Ghidra/IDA/Hopper, JADX and
  JavaScript analysers. It reads *code*. Session 9 already used it on TMNF (the free client ships a
  linker map, so every function has its name): that is where the remake's physics comes from
  (`docs/research/tmnf_physics.md`, verified by `stadium/tests/test_model_lab`).
- **Trackmania (2020): not done, and it shouldn't be.** It is only distributed through Ubisoft
  Connect / Epic / Steam with an account, it is an online-service game, and a "fully functioning
  version" rebuilt from its decompiled code would be a copy of Nadeo's program. REA's own
  `DISCLAIMER.md` rules out "circumventing DRM, license checks, anti-cheat systems or other
  technical protection measures" and "copying proprietary software or reproducing its protected
  code and assets". The project's rule (stadium/README.md: "recreate only", no Nadeo files, no
  decompiled code) is the right one and this review keeps it.
- **It also wouldn't fix what the owner is unhappy with.** The checkpoints, the car and the dated
  look are art and rendering, not code. Binary analysis can't reveal them. What helps is what
  the project already does: measure shapes, sizes and colours as numbers, then build our own art
  and render it with modern lighting. Section 3 lists what to build.
- What the modern game does show publicly, and what matters here: Trackmania (2020) maps carry
  **baked lighting**. The editor's "Compute Shadows" step writes a lightmap, typically 2048 x 2048,
  into the map file (community docs: blendermania wiki "UV Maps"; Openplanet's Lightmap Priority
  Manager / Batch Compute Shadows plugins). Soft, bounced, occluded light on every block is most
  of what makes TM look "finished", and it is the biggest thing the remake is missing (3.2).

## 1. Verdict

**It drives like TMNF and is built from TMNF's blocks, but it doesn't look like TMNF yet, and
nothing like Trackmania (2020).** Below the surface, the fidelity is high: the reverse-engineered
force model, the 100 Hz body, 100 % block coverage of the campaign, and 97-100 % shape fidelity on
the plain pieces. The surface is what a player sees first, and it is the weak part: flat
procedural materials, sky-only light, hard-edged geometry, a toy-like car and gates whose details
are measured right but built crudely.

| Area | `stadium` (v0.3) | with M9 WIP | Notes |
|---|---|---|---|
| Car handling (physics) | **9/10** | 9 | TMNF force model 6, real tuning `20juin2006`, 100 Hz, sub-steps; 44/44 lab checks against our reconstruction. Not yet checked against real TMNF replays (3.5). Water, a few edge cases open |
| Block shapes / grid | **9/10** | 9 | 32 x 8 x 32 grid, 100 % of the campaign's blocks, plain pieces 97-100 % in the fidelity test; some decorations 14-93 % |
| Race rules, ghosts, medals, respawn | 7/10 | 8 | CP respawn keeps speed like TMNF; result panel; M9 adds TMNF's 3-2-1-GO and replays |
| Tracks / campaign | 4/10 | 4 | 11 own tracks, bot-authored medals; TMNF has 65 hand-designed A-E tracks. M9-8 plans 65 originals (not started) |
| Stadium layout | 6/10 | 7 | measured surround (stands, roof, masts, boards, flags) reads as TMNF's from above |
| Gates (start / CP / finish) | **3/10** | 5 | measured arch, but crude sign boards (the "horns") and neon bands; 2.1 |
| Car model | **3/10** | 6 | soap-bar lofts, star rims, loose parts on `stadium`; M9 rebuilt it; 2.2 |
| Surfaces / textures | **3/10** | 5 | world-space noise everywhere on `stadium`; M9 has authored road/gate/advert/stadium textures, other families still flat; 2.3 |
| Light, shadows, reflections | **3/10** | 3 | no GI or baked shade at the default setting, sky-only reflections: nothing darkens under bridges, gates or the car; unchanged on M9; 2.4 |
| Menus / HUD | 4/10 | 7 | M9-4 rebuilt them on TMNF's structure |
| Sound | 5/10 | 7 | M9-3: TMNF's six-layer engine model, our own synthesis |
| Editor, replays, online ladder | 1/10 | 5 | M9-5/6 done, M9-7 in progress |

Against **Trackmania (2020)** the gap is bigger, but it's a different target: TM2020 has a different
car (not reverse engineered here; the remake is TMNF's), a different Stadium, many more surfaces
and blocks, and a modern renderer (PBR, baked lightmaps per map, reflections, optional motion
blur). If "not dated" is the goal, take **TMNF's shapes and colours and TM2020's way of rendering
them**. A 1:1 copy of TMNF's look would itself look like 2008.

## 2. What the renders show, and why

### 2.1 The checkpoint "horns"
- The two slanted boards are where TMNF's gate has its two inclined sign panels: the shape is
  measured (`blocks/shapes/road.gd` `GATE_SIGN`: a 0.3-0.45 m thick slab from (6.96, 8.17) up to
  (10.3, 11.4), mirrored, 4.5 m deep). So the *position* is faithful. What makes them read as
  horns is how they are built:
  1. each is a **solid prism** with the advert "screen" material on every face, no frame, no
     back and no bracket to the arch, so it looks bolted on and as thick as a door;
  2. on `stadium`, a **START / CHECKPOINT banner on two thin posts** sits between them over the
     crown (`blocks/tm_gate_dress.gd`, not TMNF's): head, two horns, two legs;
  3. the boards carry **loud, multicolour adverts** that compete with the gate's colour;
  4. the arch is a **flat, hard-edged extrusion** in light grey with a **neon band** under it
     (emission 0.3 plus 2.2 strips), so the only detail is at the top.
- M9 (`claude/tmnf-replica-graphics-nb1kcg`) removes the banner, puts the word on the arch's faces
  as a rubber band and darkens the underside with lit strips. But `_gate` still builds the
  `GATE_SIGN` slabs the same way, so the horns stay (see the renders).

### 2.2 The car
- `stadium`: every body part is a loft of superellipse sections with roundness 2.4-3.6
  (`car/tm_car_visual.gd` `TUB`, `ENGINE`, `PODS`): soap-bar volumes with no crease or character
  line. Sidepods read as a separate capsule under the body, the rear as an egg. Rims are a
  cylinder plus five box spokes inside a lathed tyre (`_rim`: the barrel ends at 0.66 r, nothing
  reaches the bead), hence "the rims don't touch the wheel". Wings, end plates and brackets are
  separate boxes without fillets, hence "parts not connected". One glossy paint material reflects
  only the sky, so it reads as plastic.
- M9-1 rebuilt the car to TMNF's measured proportions (rims seated in the tyre bead, hub, disc,
  caliper, tub with a U cockpit, angular sidepods, roll hoop, wings with pylons, live suspension
  links). That fixes the modelling. What it doesn't fix is the lighting the car sits in (2.4).

### 2.3 Surfaces
- `stadium`: `blocks/tm_surface.gdshader` draws every surface in world space from two noise
  textures (a ~3 m grain, a coarse blotch) plus line patterns. Up close the road reads as sandpaper,
  from afar as a flat grey. Concrete walls get the same blotches. No joints, wear, skid marks,
  paint, dirt in corners or edge darkening, and no normal detail beyond a derivative bump.
- M9-2 is replacing this with authored texture sets generated by our own scripts
  (`stadium/tools/texgen/*.py` -> albedo / normal / ORM): road, curbs, shoulders, gates,
  adverts, fabric, stadium facades. Still flat: platform, dirt, circuit, tube, control, airship.

### 2.4 Why it looks dated (both branches: `env/tm_stadium_env.gd`, `env/tm_rtx.gd`)
1. **No bounced or occluded light at the default setting.** SDFGI, SSR and SSIL are Ultra only.
   On High the only ambient is a uniform sky term (`ambient_light_energy` 0.75, sky contribution
   0.6) and SSAO, so under bridges, inside loops, under the arch and under the car, everything is
   lit almost as brightly as open road. Both TMNF and TM2020 bake shadows per map.
2. **A high, uniform ambient** (0.75 against a sun of 1.1) makes shade grey. But a stronger sun
   and weaker ambient alone (sun 1.7-2.0, ambient 0.4-0.45, exposure re-set) mostly dimmed the
   frame in this review's car and gate renders without adding depth: the darkening has to be
   *local* (point 1), not global.
3. **Linear tonemapping with saturation 1.25 and contrast 1.12** clips highlights, but it is not
   the problem to fix first. Session 12 found filmic/AgX worse, and this review's renders agree:
   AgX at three sun/exposure settings (sun 1.8-2.2, exposure 0.6-0.85) turned the sky grey and
   the whole frame overcast and dull next to the current grade. Keep the grade; fix depth.
4. **Reflections come from the sky only** (`REFLECTION_SOURCE_SKY`, no ReflectionProbe anywhere).
   The car's paint and the arch metal never show the stadium, which is why the car looks like
   plastic on a blank backdrop.
5. **Hard edges everywhere.** `TmGeo.box` and the sweeps make perfect 90-degree edges with flat
   normals, so no edge catches a highlight. Small bevels are the cheapest "not 2005" cue there is.
6. **No decals**: no wear, tyre marks, paint lines, stains or seams breaking up big surfaces.

Rendered at Ultra (SDFGI, SSR, SSIL, haze), the `stadium` gate mostly turns bluer (sky bounce on
the arch's underside and the road), and the M9 car view turns dark overall, with some welcome
darkening under the car and reflections in the rims (40 frames: SDFGI may not have settled).
GI as it is tuned now is not the answer by itself.

## 3. How to improve it (ranked by what the renders showed, then by effort)

A scratch copy of M9 tried the cheap ideas first (`stadium_review_prototype.diff`): removing or
rebuilding the gate boards made the clearest difference; global light changes (sun/ambient
balance, AgX, a reflection probe) made small or no difference on their own. So the list leads
with the gates, then with *local* depth.

### 3.1 The gates
Two directions, rendered from the driver's approach (`--gate_signs=screen|none`):
- **B. No boards, a screen in the crown (recommended):** drop the `GATE_SIGN` boards. The arch
  then reads as one clean silhouette (the `--gate_signs=none` render is the most "finished"
  gate of all the variants). Put the gate's content in a curved LED screen flush with the crown:
  START / CHECKPOINT n / FINISH, and your split time after you pass (a small SubViewport or a
  digit shader per gate). Closer to TM2020, less faithful to TMNF. (S)
- **A. TMNF's boards, built as screens (if 1:1 matters more):** keep `GATE_SIGN`'s outline as a
  thin panel (12 cm dark bezel, inset screen on the road side, ribbed back) on two struts down to
  the arch, showing the gate's content instead of adverts. Prototyped: the boards read as screens
  instead of slabs, but the tilted silhouette is still there. It helps, but it doesn't remove the
  "horns". (S-M)
- Either way: bevel the arch section (4-6 cm chamfers on `GATE_ARCH`'s corners, smoothed
  normals), give the shell a trim-sheet material (painted metal, panel seams, bolts, a little
  grime at the feet), light the road under the gate with a lamp in the kind's colour instead of
  only a glowing band, and keep the road paint (M9's pads and lines) as the second cue for
  start/finish.
- Small M9 bug seen on the way: the curb's *outer* face, seen from outside the road, shows its
  lettering mirrored ("STADIUM" reads "MUIDATS", the SF emblem after the word). The u reversal
  that makes the text read from the road seems to apply to the outer faces too. (Fixed later in
  session 14: it was turned 180 degrees, u and v; `TmGeo.sweep` turns outward faces round.)

### 3.2 Local depth: what TM's baked shadows give and we don't have
1. **A contact shadow and AO under the car** (a soft projected blob, or SpeedFest's look plan step
   4 on `main`), so it sits on the road at any sun angle. (S) (Correction, session 14 later: in
   the M9 car renders the car also floated because `map_view` stood it on the spawn point, 0.87 m
   above the road; fixed with the contact shadow.)
2. **A baked occlusion volume per map, TM's "Compute Shadows" done our way**: the map is a block
   grid built at load, so cast sky-visibility rays against the collision once
   (`PhysicsDirectSpaceState3D`, a 3D texture at about 2 m over the 1024 m field and its height
   range) and sample it in `tm_surface.gdshader` and the car shader to scale ambient and specular.
   That gives soft darkening under bridges, in loops, under stands' roofs and gates, and it costs
   one texture fetch on Low/web/Switch too. Once it is in, re-try the sun/ambient balance: it
   should then read as sun and shade instead of a dimmer frame. (M)
3. **Bevels**: a chamfer option in `TmGeo.box`, `wall_sweep` and `sweep` (2-5 cm, normals smoothed
   across it), used by gates, curbs, pillars, stands and booths. Visual meshes only. (M)
4. **Decals** (`Decal` nodes or a decal pass in the shader): skid marks in curves and before
   checkpoints, rubber at the start, seams and stains on concrete, scuffs on curbs. (M)
5. **Reflection probe** over the field (box-projected, captured once after the build): cheap, and
   in the prototype it darkens the rims and lower body a little, so keep it, but don't expect
   much from it alone. (S)
6. **SDFGI on High** only after tuning it (energy, sky contribution, more frames to settle): as
   it stands it tints the gate blue and darkens the car scene. (S-M)
7. Keep the current tonemap and grade (2.4.3).

### 3.3 The car (on top of M9-1)
1. Bake AO and curvature into the car's textures (or vertex colours), so seams, inlets and the
   cockpit go darker and edges catch a highlight.
2. Paint: clearcoat over a base with low metallic, black-chrome trim; with the probe (3.2.5).
3. A livery as decals: a number board, our sponsors, sidewall lettering (M9 has moulded text),
   a carbon floor with wear.
4. If code-built lofts keep hitting their limit, write the car in Blender through a committed
   `bpy` generator script (the repo's "generator scripts in the repo" rule allows it) that exports
   a `.glb` with creased subdivision surfaces. That gives a far crisper body than
   superellipse lofts.

### 3.4 Surfaces (continues M9-2)
- Every texture set gets two scales: macro variation over a 32 m block (patches, drying, tyre
  rubber in the racing line) and tiling detail, blended by distance, so neither the "sandpaper"
  close-up nor the flat grey far away remains.
- Finish the remaining families (platform, dirt, circuit, tube, control, airship) the same way,
  in the order the campaign uses them.

### 3.5 Fidelity checks to add (beyond looks)
1. **Physics against real runs**: read TMNF `Replay.Gbx` ghosts (their input events) from the
   player's own files, drive our `TmCar` with the same inputs on the same map, and report the
   position drift over time. It's the only test that proves "drives like TMNF" end to end (it's
   how the community's tools validate TMNF determinism). Local files only, never committed.
2. **Handedness**: session 13 saw TMNF's own text read mirrored under our x negation ("START
   reads TRATS"): the remake's world may be TMNF's mirror image. Check before relying on .Gbx
   tracks (a left turn in TMNF must be a left turn here).
3. **Look tests**: fixed-camera renders of the gate, car and an overview, compared to the
   previous run (`tests/tmp/review_view` used for this review: map_view's `car:`/`gate:` views).

## 4. Order of work suggested
1. Gates, direction B (or A if the owner prefers TMNF's boards), with the bevel and trim sheet.
2. Contact shadow under the car, then the occlusion volume; then re-try the light balance.
3. Bevels and decals; car AO, paint and livery; the reflection probe.
4. The remaining surface families (M9-2's list), in campaign order.
5. Replay-based physics check and the handedness check.

All of this fits M9's step 2 ("open: light and atmosphere, RTX preset"): it should be done on the
M9 branch (or after it is merged into `stadium`), not in parallel with it.
