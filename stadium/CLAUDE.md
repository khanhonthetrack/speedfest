# CLAUDE.md: continuing the Stadium remake (TMNF Stadium in Godot)

You are continuing **SpeedFest Stadium**: TrackMania Nations Forever's Stadium environment rebuilt
in Godot 4.7.2 (Forward+) with our own assets and TMNF's real car physics, a **standalone game**
with its own tracks (`tracks/*.json`), which also loads the player's own TMNF tracks at runtime
(its campaign from an install, any `.Challenge.Gbx`). The repo root `CLAUDE.md` applies too
(persistence, work sequentially, commit format, attribution). This file covers the remake.

## Read first
1. `docs/HANDOFF.md`: the top section is the remake's current state and next steps.
2. `docs/PLAN.md` (milestone M8: what is done and open), `docs/PROGRESS.md` (the log: append to it).
3. `stadium/README.md` (layout, run commands), `docs/research/tmnf_physics.md` (the car physics,
   finished and verified), `tools/research/tmnf/README.md` (the measuring toolkit).
4. Owner decisions, verbatim: `docs/TRANSCRIPT.md`, session 9.

**Work on branch `stadium`**, not `main`. It only touches `stadium/`, `docs/` and `tools/research/`.

## What the repo holds, and what it never holds
In the repo (all you need to build, run and test the remake):
- `core/` TMNF's force model and tuning (verified against the decompiled game), `car/`, `gbx/`
  (the `.Challenge.Gbx` reader), `blocks/` (the block catalogue as layout data, one generator per
  block family in `blocks/shapes/`, surveyed control heights in `blocks/data/`), `race/` (rules,
  checkpoint triggers, HUD, scenes), `tests/`.
- `tools/research/tmnf/`: the reverse-engineering and measuring tools (Python, our own code).

Never in the repo (Nadeo's data; the owner chose "recreate only"): the TMNF install, its packs,
decrypted `.Gbx` files, the measured collision meshes, textures, sounds, decompiled code. Our own
numbers taken from measurements (tables in the generators, `blocks/data/*.json`) are fine.
Recreate the local data whenever you need it, from public sources only:

    apt-get install -y p7zip-full innoextract
    tools/research/tmnf/setup_measurements.sh /tmp/tmnf          # W = any dir outside the repo

It downloads the free official installer (checked by SHA-256), unpacks it, clones two public
reference repos (ModTMNF, GBX.NET) and decrypts and measures everything (about 10 minutes, 669 meshes; add
`--quick` to check the pipeline in 3). Results: `$W/tmnf/app` (the install with the official
campaign), `$W/blocks/meas/*.json` (collision meshes), `$W/blocks/blockinfos.json`,
`material_surfaces.json`, `campaign_blocks.json`. The remake runs, and the no-install tests pass,
without any of it. You need it to load official tracks (`--tmnf=$W/tmnf/app`), to recreate new
blocks against measurements, and for the fidelity test.

## Fresh container
- Godot 4.7.2, export templates, `mesa-vulkan-drivers`, `xvfb`: see the root `CLAUDE.md`
  ("Environment setup").
- `godot --headless --path stadium --import` (and again after adding a `class_name`).
- `tools/research/tmnf/setup_measurements.sh /tmp/tmnf` (background it: it takes a while).

## Windows (the owner's PC, Git Bash)
Already set up there (session 12; outside the repo): Godot `C:\dev\godot-4.7.2` (run
`export PATH=/c/dev/bin:$PATH` for the `godot` wrapper, or set `GODOT=`), TMNF and measurements in
`C:\dev\tmnf`, Python venv `C:\dev\pyenv`. Use Windows-style paths in Godot args and
`TMNF_DIR`: `--tmnf=C:/dev/tmnf/tmnf/app`, `--meas=C:/dev/tmnf/blocks/meas`. `run.sh` opens a real
window (no Xvfb) for screenshots. To redo the data: `tools/research/tmnf/README.md` "On Windows".
Gate there with a clean `user://`: `APPDATA="$(cygpath -w <scratch dir>)" TMNF_DIR=... stadium/tools/test_all.sh`
(the PC's own game settings are the owner's: `ghost=false` fails `test_race`). Don't run other
Godot work alongside the gate (`test_online` checks timing against its test servers' clocks).

## Tests (gate every commit on them)
    TMNF_DIR=/tmp/tmnf/tmnf/app stadium/tools/test_all.sh            # STADIUM_TESTS PASS
    stadium/tools/run.sh res://tests/test_race.tscn --headless --timeout 3000 -- \
        --tmnf=/tmp/tmnf/tmnf/app --tracks=all                         # all 65 campaign tracks (~20 min)
    stadium/tools/run.sh res://tests/campaign_coverage.tscn --headless --timeout 1200 -- --tmnf=...
    stadium/tools/run.sh res://tests/test_block_fidelity.tscn --headless -- \
        --meas=/tmp/tmnf/blocks/meas --only=Road/Tilt [--dump=40]      # ours vs measured, per shape
    stadium/tools/run.sh res://race/map_view.tscn -- --tmnf=... --track=A11 \
        --view=near:StadiumRoadDirtHigh[:index[:zoom]] --frames=30 --shot=/abs/out.png  # look (Read the png)
    stadium/tools/run.sh res://race/race.tscn --realtime -- --tmnf=... --track=A01   # play it

Commit like this, so a failing gate never lands:

    OUT=$(TMNF_DIR=... stadium/tools/test_all.sh 2>&1); echo "$OUT" | grep -q "STADIUM_TESTS PASS" && git commit ...

## Where things stand (keep this section current: it is the next agent's to-do list)
Updated 2026-10-24. Details: `docs/PROGRESS.md` (latest entries), `docs/HANDOFF.md`.
- **Story mode (PLAN M20, 23-24 Oct, session 21):** premise A "Previous Owner" (`docs/STORY.md`, the
  bible; the brief `docs/STORY_MODE_PROMPT.md`); night 1 is playable from the Story page (H01-H03, the
  prologue and five scenes, the mirror nightmare) and waits for the owner's sign-off (stills page in
  HANDOFF); every story map is a 7-minute time attack whose best run counts. README "Story mode".
- **The modelled cast (PLAN M20-9, 24 Oct):** Kit (the owner's pick: Kit A, longer hair), Dee and Gus built by `tools/cast/` (MPFB 2 in
  Blender, a licence gate, `build.sh`) into `assets/cast/`; `story/story_cast.gd`, StoryPerson's
  `"who"`, `story/cast_lab.tscn`, `tests/test_cast_models`. Night 1 still uses the Mannequin. The look is
  realistic (owner, 24 Oct, after a side-by-side with a stylised set, set aside: `specs_stylised/`).
  Next: faces in cutscenes, seating per height, the rest of night 1's people. README "The cast".
- **Humanoid animation (23 Oct, session 19):** the first character material in the repo, nothing
  using it yet. All four packs the owner bought are in `assets/anim/` as they shipped (owner:
  "Yes, commit all four packs"): `ual_standard/` (Quaternius, **CC0**, 43 clips on a 65-bone
  Unreal-style rig with a Mannequin -- the one to reach for first, it imports and plays as it is),
  `human_basic_motions/` (118 locomotion clips: walk 2.00 / run 4.00 / sprint 6.00 m/s in 8
  directions, in-place and root-motion pairs) and the two Motifect packs (70 emote and daily-life
  clips). The last three are **not** redistributable: never sell them and never ship them as a
  pack of their own (`assets/anim/CREDITS.md`). Inventories: `tools/anim/manifests/`, rebuilt by
  `tools/anim/update_packs.sh`. **Read `docs/ANIMATIONS.md` before touching any of it** (three
  different skeletons, rig-mapping traps, which clips lie about what they do).
- **Sky City (PLAN M19, 22-23 Oct, branch `ccr-198135bf-7uoo98` from `stadium`):** the campaign's
  seventh series **Sky** (G01-G10, `"scenery": "sky"`): the road 200-440 m over the City's streets
  between towers (`env/tm_sky_city.gd`), our own road beside TMNF's blocks (`race/tm_sky_track.gd`: a
  3D turtle, walls, faces, twists, banks, kickers, ski jumps, rooftops; built by
  `env/tm_sky_pieces.gd`), mag-road (`TmBody.mag_surface`, surface 40: gravity towards the road where
  it leans; TMNF maps unchanged), rooftop splits and forks to a second finish (the track test drives
  every way; the fastest sets the medals), a fall respawns by itself on Sky maps. README "Sky maps".
- **Our own menu look (PLAN M16, 22 Oct):** the menus left TMNF's look: `ui/sf_ui.gd` (charcoal,
  red and violet accents, Montserrat), `ui/sf_header.gd` (tabs; Story unlocked since M20-6), `ui/sf_tile.gd`
  (home's picture panels, rendered by `tools/icons/menu_art.sh`), Options as explained rows. The
  race's overlays keep TMNF's look for now (next). With the road cars (M17) and tuning (M18), all
  on `stadium` (22 Oct): a Garage tab and Home panel, the Garage/Tuning pages in SfUi;
  the Garage's and Tuning's turntable in a dark neon city at night (`TmMenu._use_city`: the City
  track F02).
- **`stadium-v0.8` (21 Oct) is `stadium` + the neon City (PLAN M14)**; the zips carry `CREDITS-city.md`.
- **Tuning (PLAN M18, 22 Oct, same branch):** spoilers, rims, underglow, hoods, ten choices each
  for the road cars and the hypercar (`TmRoadCars.TUNING`, `TmCarVisual.tuning`, settings
  `car_tuning`, Garage -> Tuning); kits fitted per car by `tools/assets/tuning_kit.py`
  (`assets/car/<id>_kit.glb`), the rim library by `tools/assets/rims.py` (`rims.glb`), the underglow's
  tubes and baked light too (`<id>_glow_f/_r.png`, manifest `"underglow"`, drawn by `car/tm_underglow.gd`).
- **16 road cars of our own, NFS Most Wanted's Blacklist (PLAN M17, 22 Oct, branch
  `claude/nice-ride-q9yx1h`):** specs in `tools/assets/roadcars/`, built by `tools/assets/roadcar.py`
  (Blender) into `assets/car/<id>.glb/.json`, shaped against public drawings
  (`tools/assets/blueprint_fit.py`; drawings never in the repo, measured lines in
  `roadcars/profiles/`); `car/tm_road_cars.gd` (line-up, 5 liveries each, 5 for the hypercar),
  livery shader mode 4, the menu's Garage page; `tests/test_car_models`.
- **Our own Le Mans hypercar (PLAN M15, 22 Oct):** `tools/assets/hypercar.py` (Blender) ->
  `assets/car/hypercar.glb`, drawn by `TmCarVisual.model = "hyper"` (our materials, wheels, livery
  shader mode 3), picked on the Profile page (`car_model`), carried by replays and online;
  `car/car_lab.tscn`, `tests/test_car_models`. Generic: nothing of any maker's design.
- **The neon City (PLAN M14, 21 Oct, session 16):** City maps only: neon barriers (`tm_neon`,
  `blocks/tm_textured.gdshader`) and lights along them, tubes on buildings and the Stadium
  (`env/tm_neon.gd`), an airship, searchlights, LED screens; City nights wet (`tm_wet`) with AgX,
  glow, fog, SDFGI/SSR tuned (`TmStadiumEnv.city`); no shops on ground floors; far towers dark with
  lit floors. No Stadium on City maps (the city reaches the field, `TmSkyline.build(true)`); City
  nights lit by street lights (shadows), neon, windows, a faint moon (no sky light in SDFGI). The owner's `assets/` folder at the repo root is untracked source material (759 MB):
  never commit it. Gate this PC from a separate worktree (HANDOFF).
- **PC only (owner, 20 Oct: "I dont do browser anymore. Only pc with high graphics card"):** new
  work targets Forward+ on a strong graphics card; the web build is no longer a constraint.
- **A city around the Stadium (PLAN M13, 20 Oct):** our own skyscrapers (`env/tm_tower.gd`: glass
  with rooms behind the windows, masonry, crowns, lights) in a city on the plain below the
  Stadium's edge (`env/tm_skyline.gd`, added on 32 x 32 maps, `--city=false` to leave it out);
  cameras see `TmSkyline.FAR` (9 km); `tests/test_skyline`. Night (20 Oct): `TmStadiumEnv.mood_of`
  (maps' decoration, specs' `mood`, `--mood=night`), the towers lit (`tm_night`). The campaign's
  sixth series **City** (F01-F05, `"scenery": "city"`): towers around the road (`TmSkyline.field`).
  The owner's Blend Swap buildings (CC0 / CC BY, `assets/city/`, `CREDITS.md`; owner-chosen
  third-party assets are allowed there, with a licence): `tools/assets/blend_to_glb.py`,
  `env/tm_city_assets.gd`; Street/Traffic Lights blends wait for their licence.
- **The look work after v0.6 (PLAN M11-2..4, M11-8):** the circuit walls, platform decks and
  plates, roads and junctions, gate arches, grandstands and their wave roofs, camera booths,
  pubs and lights, loops, turbines, sculptures, dirt pieces, inflatables, castles, tube lights,
  terrain zones and the fabric pillars, each measured against TMNF's own blocks
  (`docs/research/m11_check.md`). Next: M11-5..7.
- **`stadium-v0.6` (19 Oct) is `stadium` + the community work (PLAN M12) + the look work after
  v0.5**: the circuit ledges' blue and borders as TMNF's, no black tyre smoke, and M11-1..3.
- **Community content (session 15, PLAN M12; released in v0.6):** server admins
  upload TMX tracks and ManiaPark car packs (`server/lib/admin.js`, `/admin`); every block of a
  1113-track TMX sample is built (`tests/test_compat_tracks --dir= --build`); clients download a
  round's track and every player's car pack (`Online.fetch`, SHA-256, `user://content`); TMNF car
  models (`gbx/tm_solid.gd`: binary and text GBX) and skins (`car/tm_car_pack.gd`: DDS quirks,
  wheels by place) draw through `TmCarVisual.pack` (`tests/test_compat_cars`, `test_car_pack`).
  TMNF's car frame is ours as-is (x left; not mirrored, unlike the blocks); every car file keeps
  texture v upwards (flip it); the car is MainBodyHigh (MainBody is the low LOD). TMUnlimiter 2
  tracks stay refused with the reason (owner: "Ignore those"). The menu's Community page (19 Oct):
  `net/tm_community.gd` + `ui/tm_menu.gd` `_page_community` in v0.5's TMNF frame (TMX / ManiaPark by
  their previews, download, drive, play; a downloaded car turns in its own little viewport; the web build through `server/lib/community.js`; `tests/test_community`).
  Texture mods (20 Oct): `blocks/tm_texture_mod.gd` opens any TMNF/TMUF or ManiaPlanet mod;
  Stadium mods are worn through `TmMaterials.MOD_MAP` (each key's region of a TMNF atlas and its
  metres, measured from TMNF's blocks with `ref_visuals.py`) and `use_mod()`; Community → Texture
  Mods; `tools/compat/compat_run.py` checks ManiaPark's whole catalogue in batches (results TSVs).
- **`stadium-v0.5` (19 Oct) is `stadium` + M10** (PLAN.md M10, merged from
  `claude/tmnf-replica-graphics-nb1kcg`, which now equals `stadium`; continue on `stadium`):
  dark circuit screens, tyre marks, surfaces and jumps measured against TMNF's own runs, contacts
  that turn the car at TMNF's 0.55 (its AddVehicleImpulse), and the look/UI/menus/sound side by
  side with TMNF running locally under Wine (HUD, countdown, dialogs, menus, loading screen,
  camera views 1-3, cues, Select Opponent with medal ghosts, track pictures on the cards, the top
  bar). Open: the rest of TMNF's wheelie after nose-down landings (owner's call), the engine's
  layers' pitch curves (not read).
- **M9 ("a 1:1 TMNF replica") is complete** (in `stadium` since v0.4). The look of the blocks the campaign shows most follows TMNF's
  measured materials (`docs/research/m9_look.md`): decks, platform and circuit walls, dirt roads,
  control booths, grandstand trusses and boards, raised grandstands at raised gates; Ultra keeps
  the fabric roofs lit. Compare with TMNF locally: `docs/research/m9_look.md`, "How to compare".
- **Standalone** (owner, 2026-10-17): our campaign (M9-8, session 13) is TMNF's structure with
  our own 65 tracks, `tracks/A01..E05.json` in five series (`tracks/campaign.json`: White, Green,
  Blue, Red, Black), laid out by `race/tm_track_builder.gd` with TMNF's surfaces
  (`race/tm_track_areas.gd`: circuit, platform, dirt, joins, borders, walls; lap races), listed by
  `race/tm_tracks.gd`. `tests/test_tracks` (in the gate) lays out and builds every track and has
  the bot (`race/tm_bot.gd`) drive each series' first one within gold (`--series=Red`,
  `--tracks=all` for the rest: the bot drives at about real time). New track: write the JSON,
  then `tools/run.sh res://tests/test_tracks.tscn --headless -- --tracks=<ID> --write_medals`
  (README "Make a track": the layout rules the bot taught us). The old SF01-SF11 stay raceable
  by id (the road-gate tests use SF01). Earlier (session 12, the SF tracks):
  released as `stadium-v0.1` (GitHub Release). Loops work (SF11 Full Circle has two; PROGRESS
  "loops fixed"). Quality pass done (HANDOFF): gates, driver, decoration (`race/tm_track_decor.gd`),
  adverts (`env/tm_adverts.gd`), finish run-off. The campaign is the list in `tracks/campaign.json`.
  The review's open items are done (PROGRESS, 17 Oct): the tracks span the field (66-82% of its
  box, 2.8-4.1 km, up to level 6; `climb`/`dive` pieces; the bot slows for crests), Fabric stands
  at the start and finish, inflatable billboard walls outside curves, camera booths by
  checkpoints, seats in the stands, a result panel at the finish.
  The bot steers in the road's frame over 100 km/h (no more weave); medals re-set; v0.3 released.
  `stadium-v0.4` (18 Oct) is `stadium` + M9 (online, the A-E campaign, the review's fixes): the M9
  branch is merged into `stadium`; `stadium-v0.5` (19 Oct) adds M10 (above). Next: whatever the owner asks after playing v0.5. Screenshots with `--bot`: add
  `--records=<scratch dir>` (a finish is recorded like the player's).
- Playable: `race/race.tscn` (the main scene) races any campaign track or `.Challenge.Gbx`. All 65
  campaign tracks pass `test_race --tracks=all` (421 checks); every checkpoint block is built.
- Block library: **campaign coverage 100%** (41523 blocks, 0 placeholders, 0 unknown).
  **Every drivable campaign shape is built** (session 12 finished them: Circuit slope turns,
  Stretch, turbo gates and variants, ramps, zone clips, loops, diagonal/curved tilt transitions);
  plain pieces score 97-100% in the fidelity test. The Fabric grandstands are built too
  (`blocks/shapes/fabric.gd`, 14 shapes), and every Sculpt piece (sculptures, bridges, arch rings)
  as lofts (`blocks/shapes/sculpt.gd`), the airship, camera lights/pubs, inflatable tube/advert
  pillars: every block of the 65 campaign tracks is recreated. What is left is polish (below)
  and M8-6.
- Hand-sculpted pieces: loft them. `tools/research/tmnf/loft_sections.py` (slices + rings, `:z` for
  leaning pieces, `:flat` for flat tops), add the shape's line to `sculpt_lofts.sh`, regenerate
  `blocks/data/sculpt_lofts.json`; `sculpt.gd` builds every shape found there (mirrored pieces via
  `MIRRORED`). Check the tube count per shape: a tube that breaks into many short ones means the
  slices lost the loop (open sections, merging parts): change the axis or the material set.
- Next, in order (counts = campaign uses; `campaign_coverage` prints the live list):
  1. (done) drivable shapes. Optional polish: the dead end's rounded curb ends (Deadend, Ramp,
     99%), the loop's internal struts, the platform turbo's underside (94.5-97.4%).
  2. (done) decorations. Polish when time allows (fidelity in brackets): the inflatable castles
     and palm tree (14-66%: rough shapes, loft them), the camera light base (83%), the bump (81%),
     the Sculpt pillars' heads (81%), the In Fabric pillar corners (86.7-93.4%), Fabric trusses,
     screens and spotlights, the bridges' rails and awnings; dirt fences/signs/awnings.
  3. M8-6, in the owner's order: (done) ghosts and best times (`race/tm_ghost.gd`,
     `race/tm_records.gd`, HUD record and split differences; `tests/test_ghost`); (done) the
     stadium environment: Day sky and sun (`env/tm_stadium_env.gd`, `env/tm_sky.gdshader`) and the
     Stadium around the map (`env/tm_stadium_build.gd`, our own tables measured from TMNF's
     surround `Zone/Square32.Solid.Gbx` with `visual_mesh.py` + `vsection.py`); (done) our own car
     model (`car/tm_car_visual.gd`: TMNF's proportions, our lofted shapes and livery); (done)
     menus (`ui/menu.tscn` is the main scene; `ui/tm_race_menu.gd` pause/finish; `tests/test_menu`);
     (done) sounds (`audio/tm_sounds.gd` synthesized, `audio/tm_car_audio.gd`; `tests/test_sound`);
     (done) HD materials (`blocks/tm_surface.gdshader`, `car/tm_car_surface.gdshader`).
  4. (done) The owner's list (TRANSCRIPT, session 12): polish; menus with fonts; online play
     (`stadium/server`, `net/tm_online.gd`, `race/tm_race_online.gd`) and the official server
     (`stadium/server/run_official.ps1`, address in `official.json`); RTX (`stadium/RTX.md`);
     music (`audio/tm_music.gd`, `audio/music`); recorded sounds (`audio/sfx`); exports
     (`tools/export.sh`, CI `.github/workflows/stadium.yml`; README "Share it with friends").
     Open: a permanent host for the official server (it runs on the owner's PC through a
     Cloudflare quick tunnel; the address changes if it restarts: `run_official.ps1 -Publish`). Stadium polish: outer roads, forecourts
     and parking, roof light panels, textures.
- Open questions: grass surface id (see Gotchas); water has no physics yet.
- Lessons that saved the most time: TMNF's curves are polygons with fixed segment counts (count the
  vertex angles in the measurement before choosing a step); swept pieces leave three asphalt vertices
  per frame (`sweep_frames.py` reads the frames exactly); symmetric pieces are one half clipped
  (`TmGeo.clip`) plus its mirror (`add_mirror_x`); sloped/tilted variants are usually the flat piece
  sheared (fit the plane of one material with a few lines of numpy first), turned pieces the flat
  one turned (`TmGeo.turn_y`; `radial_section.py --shear` checks it), but round parts (turbo pods)
  stay round and move with the road; a fidelity "hole" exactly on a triangle edge (x.5 samples on
  a diagonal) is a ray artifact, not missing geometry.

## How a block family gets recreated
1. Pick by campaign use: `campaign_coverage` prints the MISSING shapes with their counts.
2. Read the measurement (`$W/blocks/meas/<Shape>.json`, the shape's name with `/` as `__`):
   `describe.py` (faces by material and normal), `section_loop.py` (closed cross-sections as
   tables), `hmap.py` / `matmap.py` / `vprofile.py` / `center.py` / `bank.py` / `ridge.py` (height
   maps, profiles, centre lines, banks). All print numbers only.
3. Find how TMNF built it. So far every piece has been one of: a measured section swept along a
   path (`TmGeo.wall_sweep`, `sweep`), revolved, extruded (`extrude_y`), a flat piece sheared into
   a slope or bank (`TmGeo.shear_y`), half a symmetric piece clipped and mirrored (`TmGeo.clip`,
   `add_mirror_x`), swept through TMNF's own frames (`sweep_frames.py`), or, for hand-sculpted
   terrain, a surface through surveyed heights (`zone_heights.py`: a 1 m grid, a quad between
   each four, as TMNF's hills have sharp creases; `terrain_heights.py`: bicubic) -> `blocks/data/*.json`.
   Fit planes and curves to the measurement before assuming a formula.
4. Write the generator in `blocks/shapes/<family>.gd` (`handles(shape)`, `make(shape, ...)`);
   register a new family in `blocks/tm_block_lib.gd` `FAMILIES`.
5. Check: `test_blocks` (mesh, collision ids, footprint), fidelity (plain pieces 95-100%), a
   screenshot, `test_race` on the whole campaign, coverage.
6. Commit (gated), push to `stadium`, append `docs/PROGRESS.md`, update `docs/HANDOFF.md` and
   `docs/PLAN.md`.

## Gotchas
- Loops: TMNF's loop drifts ~25 deg sideways from its first frame (a helix on a cylinder), so the
  car must be steered into it; a wheel on the curb brings TMNF's wall slow-down (~60 m/s^2 for
  500 ms), which reads like "the car loses 9 g". The bot's line eases into it
  (`TmTrackBuilder.ease_loops`). Debug speed losses by tallying each velocity change by cause
  (model force, gravity, wheel and chassis impulses) per tick before blaming the contacts.
- A measurement can sit under a location `extract_surf.py` doesn't apply (seen once:
  YShaped/Diag2SlopeUpAir is offset by (40, 0, 80)); if a fidelity score is absurdly low, check the
  mesh's bounds against the block's footprint first.
- Faces are authored in TMNF block-local coordinates (x right, y up, z forward); Godot = x negated.
- Godot re-enables `_physics_process` when a node enters the tree: switch it off after `add_child`.
- Screens ("screen", "led"; billboards "screen_on") show one fitted ad each and need its layout in
  their UVs (`TmGeo.SCREENS`):
  build them with `screen_box` / `screen_rect` (or a sweep / `extrude_y`, which lay them out
  themselves); a screen face made with plain `quad`/`tri` shows an unlit panel, and
  `tests/test_blocks` fails when a shape's screens show no ad at all.
- Race waypoints come from the catalogue's waypoint type and `race/tm_triggers.gd` (measured gate
  slabs), not from the block geometry.
- The measured material table maps Stadium grass to surface 0; the remake uses grass = 2 (open
  question in PROGRESS).
- SpeedFest's own TMNF handling (branch `tmnf-physics`) waits for the owner's approval.
