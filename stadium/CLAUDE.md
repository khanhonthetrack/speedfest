# CLAUDE.md: continuing the Stadium remake (TMNF Stadium in Godot)

You are continuing **SpeedFest Stadium**: TrackMania Nations Forever's Stadium environment rebuilt
in Godot 4.7.2 (Forward+) with our own assets, TMNF's real car physics, and the player's own TMNF
tracks loaded at runtime. The repo root `CLAUDE.md` applies too (persistence, work sequentially,
commit format, attribution). This file covers the remake.

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

## Tests (gate every commit on them)
    TMNF_DIR=/tmp/tmnf/tmnf/app stadium/tools/test_all.sh            # STADIUM_TESTS PASS
    stadium/tools/run.sh res://tests/test_race.tscn --headless --timeout 1800 -- \
        --tmnf=/tmp/tmnf/tmnf/app --tracks=A01,A02,...,E05             # all 65 campaign tracks
    stadium/tools/run.sh res://tests/campaign_coverage.tscn --headless --timeout 1200 -- --tmnf=...
    stadium/tools/run.sh res://tests/test_block_fidelity.tscn --headless -- \
        --meas=/tmp/tmnf/blocks/meas --only=Road/Tilt [--dump=40]      # ours vs measured, per shape
    stadium/tools/run.sh res://race/map_view.tscn -- --tmnf=... --track=A11 \
        --view=near:StadiumRoadDirtHigh --frames=30 --shot=/abs/out.png  # look at it (Read the png)
    stadium/tools/run.sh res://race/race.tscn --realtime -- --tmnf=... --track=A01   # play it

Commit like this, so a failing gate never lands:

    OUT=$(TMNF_DIR=... stadium/tools/test_all.sh 2>&1); echo "$OUT" | grep -q "STADIUM_TESTS PASS" && git commit ...

## How a block family gets recreated
1. Pick by campaign use: `campaign_coverage` prints the MISSING shapes with their counts.
2. Read the measurement (`$W/blocks/meas/<Shape>.json`, the shape's name with `/` as `__`):
   `describe.py` (faces by material and normal), `section_loop.py` (closed cross-sections as
   tables), `hmap.py` / `matmap.py` / `vprofile.py` / `center.py` / `bank.py` / `ridge.py` (height
   maps, profiles, centre lines, banks). All print numbers only.
3. Find how TMNF built it. So far every piece has been one of: a measured section swept along a
   path (`TmGeo.wall_sweep`, `sweep`), revolved, extruded (`extrude_y`), a flat piece sheared into
   a slope or bank (`TmGeo.shear_y`), or, for hand-sculpted terrain, a bicubic surface through
   surveyed control heights (`zone_heights.py`, `terrain_heights.py` -> `blocks/data/*.json`).
   Fit planes and curves to the measurement before assuming a formula.
4. Write the generator in `blocks/shapes/<family>.gd` (`handles(shape)`, `make(shape, ...)`);
   register a new family in `blocks/tm_block_lib.gd` `FAMILIES`.
5. Check: `test_blocks` (mesh, collision ids, footprint), fidelity (plain pieces 95-100%), a
   screenshot, `test_race` on the whole campaign, coverage.
6. Commit (gated), push to `stadium`, append `docs/PROGRESS.md`, update `docs/HANDOFF.md` and
   `docs/PLAN.md`.

## Gotchas
- Faces are authored in TMNF block-local coordinates (x right, y up, z forward); Godot = x negated.
- Godot re-enables `_physics_process` when a node enters the tree: switch it off after `add_child`.
- Race waypoints come from the catalogue's waypoint type and `race/tm_triggers.gd` (measured gate
  slabs), not from the block geometry.
- The measured material table maps Stadium grass to surface 0; the remake uses grass = 2 (open
  question in PROGRESS).
- SpeedFest's own TMNF handling (branch `tmnf-physics`) waits for the owner's approval.
