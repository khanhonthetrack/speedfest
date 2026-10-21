# TMNF reverse-engineering toolkit (research only)

Scripts used in session 9 to study TrackMania Nations Forever 2.11.26 (freeware, official installer
`tmnationsforever_setup.exe`, SHA-256 `2f659138…6355`). Findings: `docs/research/tmnf_physics.md`.
**Nothing from the game is committed**: no binaries, no pack data, no decompiled code. These scripts
work on a local install only.

Pipeline (Linux, all in a scratch directory outside the repo):
1. Unpack: the installer is a 7-Zip SFX around an Inno Setup 5.2.3 installer:
   `7z x tmnationsforever_setup.exe` then `innoextract -s TmNationsForever_Setup_Tmp.exe`.
   You get `app/TmForever.exe`, `app/TmForever.map` (linker map with every function name) and
   `app/Packs/*.pak`.
2. Symbols: `python3 -I map2seeds.py TmForever.map seeds.tsv` (63k functions, 43k data labels).
3. Decompiler: REA (`npm i -g rea-agents`, https://github.com/morluto/rea) with Ghidra 12.1.4 and JDK 21.
   `GHIDRA_INSTALL_DIR=… REA_GHIDRA_SEED_FILE=seeds.tsv REA_GHIDRA_STARTUP_TIMEOUT_MS=10800000
   python3 -I rea_bridge.py rea.sock bridge.log &` keeps one `rea --mcp` session (and one Ghidra
   analysis, ~8 min) alive. Then `reacall.py rea.sock open_binary '{"path":"/abs/TmForever.exe","provider_id":"ghidra"}'`,
   `dc.py rea.sock 0x7c3e80 out.c` (pseudocode), `asm.py rea.sock 0x7f3c70` (assembly).
4. Packs: `nadeopak.py list Packs Stadium FileHashes.txt` lists a pack (keys come from
   `packlist.dat`; name hashes from GBX.NET's `Resources/FileHashes.txt`).
   `pak_emulate.py Packs Stadium C2A255EF80618DC714C2B1F7CA68608C60 tunings.gbx` decrypts
   `Vehicles\VehicleTunings\StadiumCar.VehicleTunings.Gbx`. The pack cipher re-keys its IV on every
   node read (the node's parent class id) and after each tuning name (its first 4 bytes); this
   script emulates TmForever's reader buffering (256-byte zlib input blocks, 1024-byte output
   blocks), and zlib's Adler-32 checks the result.
5. `tuning_parse.py tunings.gbx tunings.json` parses all 30 `CSceneVehicleCarTuning` nodes with the
   chunk layout taken from `CSceneVehicleCarTuning::Chunk`. `annotate.py tunings.json in.c out.c`
   rewrites tuning reads in pseudocode as `T[offset]{value}`.

Lighter path (session 11): for **reading one function** you do not need Ghidra or REA at all.
`TmForever.map` gives every function's exact start, and the next symbol bounds it, so
`objdump -d -b pei-i386 -m i386 --start-address=.. --stop-address=..` disassembles it directly.
`fnmap.py TmForever.map <name-substring>` prints matching functions with their start, end and size;
`dis.py TmForever.exe TmForever.map 0xSTART 0xEND` disassembles that range and annotates call targets
and float constants from the map. Ghidra setup is ~8 min of analysis and ~1 GB; this is instant and
objdump is already installed. Pseudocode still needs REA/Ghidra.

The pack scripts need `pycryptodome` (`pip install pycryptodome`) and import each other, so run them
from `tools/research/tmnf/` with absolute paths to the data rather than with `python3 -I`
(isolated mode drops the script's own directory from `sys.path`).

Format knowledge for the packs (salts, Blowfish variant, header layout) comes from GBX.NET
(https://github.com/BigBang1112/gbx-net, `Src/GBX.NET.PAK`); the scripts are a Python reimplementation.

## Cold start: recreate all local data in one go

    apt-get install -y p7zip-full innoextract
    tools/research/tmnf/setup_measurements.sh /tmp/tmnf [--quick]

Downloads the official installer (SHA-256 checked), unpacks it, clones ModTMNF (its
`Analysis/Docs/Generated.zip` class hierarchy) and GBX.NET (`Resources/FileHashes.txt`), builds
`classmap.json` and the Stadium pack listing, decrypts block infos, mobils, materials and solids,
and writes `blocks/blockinfos.json`, `material_surfaces.json`, `campaign_blocks.json` and
`blocks/meas/*.json`. Checked from scratch in session 9 (8 min 20 s plus the 530 MB download; 669
of 671 solids): the meshes come out byte-identical to the ones the block library was measured
against. Everything stays outside the repo.

On Windows (Git Bash, session 12, owner's PC): no 7z or apt needed. Put `innoextract.exe`
(github.com/dscharrer/innoextract releases, 1.9) on PATH and give the script a Python that has
pycryptodome and py7zr (`-I` ignores user site-packages, so use a venv):

    python -m venv C:/dev/pyenv && C:/dev/pyenv/Scripts/python -m pip install pycryptodome py7zr numpy
    PYTHON=/c/dev/pyenv/Scripts/python tools/research/tmnf/setup_measurements.sh /c/dev/tmnf

`sfx7z.py` unpacks the installer's 7-Zip SFX with py7zr. Same 669 meshes; about 18 minutes (one
Python process per pack entry is slower to start on Windows). Pass Windows-style paths to Godot
(`--tmnf=C:/dev/tmnf/tmnf/app`, `--meas=C:/dev/tmnf/blocks/meas`).

Shape-reading helpers (numbers only, on `meas/*.json`): `describe.py`, `section.py`,
`section_loop.py`, `hmap.py` (height bands per cell), `matmap.py` (one material's heights),
`vprofile.py` (heights along a line), `ridge.py`, `hgrid.py`, `center.py` (a road's centre line),
`bank.py` (height and bank along a curve), `zone_heights.py` / `terrain_heights.py` (surveyed
control heights for terrain-like blocks), `sweep_frames.py` (a swept road's frames: centre, lateral
and width per frame, read from the three asphalt vertices each frame leaves; the GT diagonals'
`blocks/data/gt_diag_frames.json`), `material_surfaces.py` (physics surface per material),
`radial_section.py` (a curved piece's section in a vertical plane through its curve's centre, with
an optional slope sheared off: how the slope corners were found to be the flat walls sheared).
`loft_sections.py` (lofts for hand-sculpted pieces: horizontal or across-z slices followed up the
piece and resampled to rings; `sculpt_lofts.sh MEAS` writes `stadium/blocks/data/sculpt_lofts.json`).
`visual_mesh.py SOLID.Gbx out.json` (session 12: a solid's visual meshes, not its collision: walks
the tree with its locations and reads each indexed triangle visual and its material's name, plus
the lights hung in the tree; the stadium surround is `raw/Zone__Square32.Solid.Gbx`, 400 meshes, a
High and a Low level of detail), `vsection.py VIS.json out.png --at CX,CZ --deg A` (a vertical cut
of such a measurement drawn as a PNG, `--y H` for a plan cut, `--print` for the segments).

## Block measurements (session 9, for the Stadium remake's block library)

The remake recreates every Stadium block with our own generators; these scripts measure the
originals on a local install (numbers only, nothing from the game is committed):
1. `campaign_blocks.py CAMPAIGN_DIR out.json`: block types used by the official campaign (242).
2. `decrypt_all.py SCRATCH 'ConstructionBlockInfo'` (or `@list.txt`): decrypts pack entries into
   `raw/`. `pak_generic.py` now also re-keys on typed inline nodes (GBX.NET's "(direct)" reads, e.g.
   CSceneMobil's CHmsItem, CPlugVisualIndexed's index buffer), uses GBX.NET's parent-id exceptions
   (block infos 0x24005000, zones 0x2401C000), only looks for node reads in the body, and requires
   a valid node index before a class id (vertex data holds class-id-like words). TMF packs use the
   plain CBC IV (version < 12): a misplaced re-key corrupts only 8 bytes, so only zlib's Adler-32 at
   the end notices; false positives were the cause, not buffering. All 308 block infos and the
   campaign's 431 solids decrypt with the fast path.
3. `blockinfo_dump.py raw blockinfos.json`: `gbxnode.py` (a small GBX node reader, chunk layouts
   from GBX.NET) reads each CGameCtnBlockInfo: units (offset, dir, clips, pylons), ground/air
   mobils per variant (roads: base, dead end, corner, straight (+A/B/C), T, cross), spawn location,
   waypoint type. 239/242 campaign types parse.
4. `extract_surf.py` (run in the scratch dir): each solid's collision mesh (CPlugSurfaceGeom chunk
   0x0900F004, GmSurf mesh: vertices + cooked triangles, material names from the reference table)
   in block space: the surface's tree location (the first 0x0904F01A after it) composed with the
   root tree's (the last one in the file). `surfmesh.py FILE --tris` prints one mesh.
   Also: the root node's re-key happens at the body start, after the reference table (a large
   table pushed it into another 256-byte refill: the Fabric solids failed); `body_start()` parses
   the table. The backtracking search (`pak_search.py`) is a last resort: on small files Adler-32
   can accept a wrong path, so check its outputs by parsing them.

## Reference renders (session 13): the original's look next to ours

    python3 -I tools/research/tmnf/ref_visuals.py WORK OUT     # after setup_measurements.sh WORK

writes, for local use only (never commit OUT), every decrypted solid's visual meshes with texture
coordinates (`visual_mesh.py --uv`), each material's texture names (`materials.json`) and the
install's `.dds` images as PNG. Started with `--ref=OUT`, the remake draws blocks with them (our
collision stays; `stadium/blocks/tm_ref_visuals.gd`), and `race/map_view.tscn` can put TMNF's car
next to ours (`--car=both --car_ahead=40 --view=car:35:6`). TMNF's v coordinate runs up (flipped
on load). Seen on the first renders: TMNF's own text reads mirrored under our x negation, so the
remake's world may be a mirror image of TMNF's (to verify before relying on it).

## TMNF's own runs: ghosts as physics measurements (session 13, M10)

Every campaign `*.Replay.gbx` holds four ghosts (author, gold, silver, bronze; ghost 0 is the
author's). Each is TMNF's own simulation sampled every 100 ms: position, rotation, velocity and
angular velocity, speed, rpm, steer/gas/brake, turbo, and per wheel the suspension, the surface
id, sliding and on-the-ground flags; plus the run's inputs (events every 10 ms). Numbers only.

    python3 -I ghost_dump.py X.Replay.gbx [--ghost=0] [--samples]      # header, events, samples
    python3 -I ghost_dump.py X.Replay.gbx --json=X.json                # samples + 10 ms controls
    python3 -I ghost_dump.py X.Replay.gbx --inputs=X.txt               # TMInterface-style script
    python3 -I accel_curve.py <install>/GameData/Tracks/Campaigns/Nations [--brake|--coast] [--bin=10]
    python3 -I lateral_grip.py <...>/Nations       # sideways acceleration by surface, slide vs grip
    python3 -I air_check.py <...>/Nations          # gravity, drag and spin decay in the air
    python3 -I ghost_compare.py X.Replay.gbx trace.jsonl [--step=500]  # a whole run, ours vs TMNF

and in the remake (`stadium/`):

    tools/run.sh res://race/ghost_fit.tscn --headless -- --tmnf=<install> --map=X.Challenge.Gbx \
        --ghost=X.json [--horizon=500] [--only=2,6] [--every=1] [--cols=0,2,3,1] [--dump]
    tools/run.sh res://race/race.tscn --headless -- --tmnf=<install> --track=X --inputs=X.txt --trace=trace.jsonl

`ghost_fit` puts our car in the ghost's state at each sample and drives it 0.5 s with the run's own
inputs, then prints how far apart it ends and the speed difference, grouped by the surface under
the wheels (medians: a few runs end in a crash where our terrain differs from TMNF's). Format
notes: the samples are chunk 0x0303F005 (class 0A02B000 version 9, 61 bytes each); the inputs are
the skippable chunk 0x03092019 (its event names are lookback ids into the file's global table).
**The remake's world is TMNF's mirror image** (x negated): a TMNF run's inputs drive our car the
same way with left and right swapped (`ghost_fit` mirrors the states itself; `ghost_dump --inputs`
writes TMNF's own sides). Results so far: asphalt agrees to centimetres over 0.5 s; the surface
table's columns were misread and are fixed (`docs/research/tmnf_physics.md` §3.10); in the air
TMNF's gravity (25), drag (0.03 v) and angular drag match ours.

## Look check, block by block (session 13, M11)
`stadium/tests/block_dump.tscn` writes every block shape we build as triangles with their material
keys and each key's mean albedo; `material_check.py` compares them with TMNF's own meshes (the
local reference visuals from `ref_visuals.py`): it samples TMNF's surfaces, reads TMNF's texture
colour at each point (blurred to the atlas' regions; TMNF's v runs up), finds our surface there
facing the same way, and lists per shape where the colours differ (Lab dE > 25), TMNF surface we
lack (missing) and ours TMNF lacks (extra), ranked by area times campaign use; `--pairs=N` sums
each (TMNF material -> our key) over all shapes with both mean colours, `--missing=N` the missing
and extra area by material and family, `--shape=substr --detail` one family in detail.

    stadium/tools/run.sh res://tests/block_dump.tscn --headless -- --shapes=<list> --out=$W/ours
    python3 -I tools/research/tmnf/material_check.py $W/ours $W/ref stadium/blocks/data/block_catalogue.json --pairs=60

`atlas_rows.py` compares the border atlas' row itself (a band laid a segment off hides from the
colour check when both bands are dark): at each TMNF atlas triangle, our triangle at the same spot
and the row there; per shape the area whose rows differ and what ours has where TMNF uses the
atlas but ours doesn't.

    python3 -I tools/research/tmnf/atlas_rows.py $W/ours $W/ref [shape prefix] [--show=5]

`dirt_furniture.py` measures the dirt pieces' furniture (advert boards and bands, kiosks, logo
bumpers and their rubber ends, LED signs and the way they face, the border atlas' tubes) from the
same reference visuals as placements only
(corners, centre lines, sizes):
`stadium/blocks/data/dirt_furniture.json`, which `blocks/shapes/dirt.gd` builds our own furniture at.

    python3 -I tools/research/tmnf/dirt_furniture.py $W/ref stadium/blocks/data/dirt_furniture.json
