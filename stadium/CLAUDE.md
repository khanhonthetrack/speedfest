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
Updated 2026-10-19 (session 15). Details: `docs/PROGRESS.md` (latest entries), `docs/HANDOFF.md`.
- **Community content (session 15, PLAN M10, branch `ccr-1ce252fc-wl7p3m`):** server admins
  upload TMX tracks and ManiaPark car packs (`server/lib/admin.js`, `/admin`); every block of a
  1113-track TMX sample is built (`tests/test_compat_tracks --dir= --build`); clients download a
  round's track and every player's car pack (`Online.fetch`, SHA-256, `user://content`); TMNF car
  models (`gbx/tm_solid.gd`: binary and text GBX) and skins (`car/tm_car_pack.gd`: DDS quirks,
  wheels by place) draw through `TmCarVisual.pack` (`tests/test_compat_cars`, `test_car_pack`).
  TMNF's car frame is ours as-is (x left; not mirrored, unlike the blocks); every car file keeps
  texture v upwards (flip it); the car is MainBodyHigh (MainBody is the low LOD). Open:
  TMUnlimiter 2 tracks (refused with the reason). The menu's Community page (19 Oct):
  `net/tm_community.gd` + `ui/tm_menu.gd` `_page_community` (TMX / ManiaPark by their previews,
  download, drive, play; the web build through `server/lib/community.js`; `tests/test_community`).
- **Standalone** (owner, 2026-10-17): our campaign is `tracks/SF01..SF11.json`, laid out by
  `race/tm_track_builder.gd`, listed by `race/tm_tracks.gd`; `tests/test_tracks` (in the gate)
  drives each with the bot (`race/tm_bot.gd`) within gold. New track: write the JSON, then
  `tools/run.sh res://tests/test_tracks.tscn --headless -- --tracks=<ID> --write_medals`
  (README "Make a track"). `tests/tmp/track_dump` (untracked; recreate: prints an ASCII map) helps.
  Released as `stadium-v0.1` (GitHub Release). Loops work (SF11 Full Circle has two; PROGRESS
  "loops fixed"). Quality pass done (HANDOFF): gates, driver, decoration (`race/tm_track_decor.gd`),
  adverts (`env/tm_adverts.gd`), finish run-off. The campaign is the list in `tracks/campaign.json`.
  The review's open items are done (PROGRESS, 17 Oct): the tracks span the field (66-82% of its
  box, 2.8-4.1 km, up to level 6; `climb`/`dive` pieces; the bot slows for crests), Fabric stands
  at the start and finish, inflatable billboard walls outside curves, camera booths by
  checkpoints, seats in the stands, a result panel at the finish.
  The bot steers in the road's frame over 100 km/h (no more weave); medals re-set; v0.3 released.
  Next: whatever the owner asks after playing v0.3. Screenshots with `--bot`: add
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
   terrain, a bicubic surface through surveyed control heights (`zone_heights.py`,
   `terrain_heights.py` -> `blocks/data/*.json`).
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
