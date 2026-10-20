# TrackMania United Forever: can the Stadium remake's method recreate it? (feasibility probe)

2026-10-20, cloud session on branch `claude/stoic-planck-cjsw08`. Owner's question (TRANSCRIPT,
20 Oct): recreate TMUF by downloading it and proceeding as on the `stadium` branch. This page is
a probe, not a start: what TMUF contains, what of the `stadium` toolchain works on it unchanged,
and what is new. Same rule as the Stadium remake: **numbers and descriptions only, nothing from
the game in the repo**. Everything below was measured in a scratch directory with the `stadium`
branch's `tools/research/tmnf/` scripts, which were not changed.

## The installer
- `http://files.trackmaniaforever.com/tmunitedforever_setup.exe`: 1,211,926,014 bytes,
  SHA-256 `f8a4d09c64d65be271c0346f5b0e41529cb25eb8c605d4602d0f34f27fb1355f` (2012-09-19). It's
  the same 7-Zip SFX around Inno Setup as TMNF's: `7z x`, then
  `innoextract -s TmUnitedForever_Setup_Tmp.exe`.
- `Nadeo.ini`: Version 2.11.26, `Key=Ask`: **the game asks for a paid CD key on first launch**
  (TMNF is freeware; TMUF isn't). Reading the packs doesn't need the key (below). Running TMUF
  under Wine for side-by-side screenshots, as M10-5 did with TMNF, would need the owner's key.
  Without it, `ref_visuals.py` renders TMUF's own meshes and textures in our engine locally.
- **No `TmForever.map` in TMUF**, and its `TmForever.exe` (2010-03-15 build, SHA-256 `4b6a7b31…d2d4`)
  isn't byte-identical to TMNF's (2011-01-28, `3847cf9f…c84f`), though both say 2.11.26. TMNF's
  exe is the shared Forever client and holds every car's code, so **read TMNF's exe with TMNF's
  map** (what `stadium` already does), and take TMUF only for its packs and tracks.

## The packs: all seven environments open with the existing reader
`packlist.dat` gives a key for every pack (`nadeopak.parse_packlist`, no CD key involved):
Resource, Game, Alpine (Snow), Speed (Desert), Rally, Island, Coast, Bay, Stadium, patch1.
GBX.NET's `FileHashes.txt` names the entries. Listing per pack (`nadeopak.py list`):

| Pack (environment) | entries | block infos | solids (09005000) | car tuning file |
|---|---|---|---|---|
| Stadium | 1932 | 308 | 671 | StadiumCar.VehicleTunings.Gbx |
| Island | 1510 | 251 | 646 | Sport.VehicleTunings.Gbx |
| Bay | 1738 | 205 | 885 | BayCar.VehicleTunings.Gbx |
| Coast | 1277 | 226 | 507 | CoastCar.VehicleTunings.Gbx |
| Speed (Desert) | 1185 | 170 | 523 | American.VehicleTunings.Gbx |
| Rally | 1476 | 193 | 721 | Rally.VehicleTunings.Gbx |
| Alpine (Snow) | 1294 | 209 | 585 | Buggy.VehicleTunings.Gbx |

The six new environments: **1,254 block types (4.1x Stadium) and 3,867 solids (5.8x)**. Island,
Bay and Coast keep their blocks under `ConstructionBlockInfo` like Stadium. Speed, Rally and
Alpine use TrackMania Original's `TrackManiaElementDesc` (`*.TMEDClassic.Gbx`, class 03051000).
`blockinfo_dump.py` will need those older chunks.

## The cars: three of six already run on our ported code
All seven tuning files decrypt with `pak_emulate.py` (Adler-32 OK) and parse with
`tuning_parse.py` unchanged (80 chunks, 193 fields each). The selected tuning's field
**[0x354]** chooses the force model. `CSceneVehicleCar::ComputeForces` (0x7c69e0, TMNF's exe)
dispatches: 3 -> `ComputeForcesModel4`, 4 -> `ComputeForcesModel5`, 5 -> `ComputeForcesModel6`,
anything else -> `ComputeForcesModel3`.

| Car | selected tuning | [0x354] | force model | top speed [0x02c] m/s | gravity x ground / air [0x160/0x164] |
|---|---|---|---|---|---|
| StadiumCar | 20juin2006 | 5 | Model6 (10,672 B; ported) | 277.8 | 3.0 / 2.5 |
| IslandCar ("Sport") | 16septembre | 5 | Model6 | 277.8 | 2.5 / 4.0 |
| BayCar | 23septembre2005 | 5 | Model6 | 277.8 | 3.0 / 3.0 |
| CoastCar | 23septembre2005 | 5 | Model6 | 277.8 | 2.0 / 1.75 |
| DesertCar ("American") | 09Sept2006 (sound) | 1 | **Model3** (3,712 B) | 277.8 | 4.0 / 4.0 |
| RallyCar | 09sept2006 (sound) | 1 | **Model3** | 416.7 | 3.0 / 4.0 |
| SnowCar ("Buggy") | 09sept2006 (sound) | 1 | **Model3** | 694.4 | 4.0 / 4.0 |

So Island, Bay and Coast need only their numbers in `stadium/core/tm_car_model.gd`. `TmTuning` holds Stadium's values as
constants, each with its offset, so making it a per-car table is mechanical. Check which Model6
branches Stadium's tuning never takes but these do. Desert, Rally and Snow need one new function
ported (`ComputeForcesModel3`, about a third of Model6's size) plus whatever helpers it calls.

## Reference runs for the physics: plenty
`GameData/Tracks/Campaigns` has 429 `.Challenge.Gbx` and 381 `.Replay.Gbx`: United Race 147
tracks (21 per environment) with 147 replays, Puzzle 21, Platform 21, Stunts 21 (+21 replays),
StarTrack 21 replays per environment, and Nations' 65. `ghost_dump.py` reads them unchanged
(e.g. StarDesertC4, StarSnowC2, StarCoastC3: four ghosts each, 100 ms samples, input events),
so `ghost_fit` / `ghost_compare` can check each new car the way M10-3 checked Stadium's.

## What is new work (not covered by `stadium`)
- Six block libraries (1,254 types). They're more organic than Stadium's: Island's cliffs
  and sea, Coast's hills and water, Bay's buildings and harbour, Desert/Rally/Snow's hill terrain.
- Six looks (sky and light moods, materials, decorations), six car bodies (our own), six engine
  sound sets (shaped to TMUF's, as M9-3 did).
- Game modes TMNF lacks: Puzzle (limited block sets), Platform (fewest respawns), Stunts (figure
  scoring).
- Content: our own campaign per environment (as M9-8 did for Stadium), or TMUF's tracks read at
  runtime from the player's own install (as `stadium` reads `.Challenge.Gbx`).
- Scale reference: the Stadium remake to v0.6 was sessions 9-15 (16-19 Oct), 168 commits, about
  1.2 MB of GDScript (328 KB of it the block library), and M11 is still open.

## Suggested order, if the owner says go
1. Physics, cheapest first: `TmTuning` data-driven; Island, Bay and Coast cars on Model6,
   checked against their StarTrack and United replays; then port Model3 for Desert, Rally and Snow.
2. Then one environment per release on top of `stadium`: Coast, Island, Bay (cars already
   working), then Desert, Rally, Snow (after Model3 and the TMED block reader).
