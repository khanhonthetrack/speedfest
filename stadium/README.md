# SpeedFest Stadium: a TMNF Stadium remake in Godot 4.7 (Forward+)

Owner request (session 9, docs/TRANSCRIPT.md): build, in a separate folder, a copy of TrackMania
Nations Forever "as close to the original as possible" (graphics, car feel, textures) on an enhanced
Godot. ManiaPlanet parts are out of scope.

Owner decisions (2026-10-16):
- **Assets: recreate only.** Every model, texture and sound here is our own, made in the TMNF style.
  No Nadeo files (meshes, textures, sounds, packs, decompiled code) are ever committed or shipped.
- **Tracks:** the game is **standalone** (owner, 2026-10-17): its campaign is our own tracks
  (`tracks/*.json`, built from the recreated blocks; no TMNF needed): 65 in TMNF's five series,
  White A01-A15, Green B01-B15, Blue C01-C15, Red D01-D15, Black E01-E05 (owner, session 13:
  "Only our own A-E"; `docs/research/m9_campaign.md`). The first SpeedFest tracks (SF01-SF11)
  stay raceable by id. TMNF's official campaign and
  any `.Challenge.Gbx` (TMX downloads) still load **at runtime** from files the player owns (their
  TMNF install, their downloads) and are drawn with our blocks. They are never committed.
- **Engine:** Godot 4.7 Forward+ with high-end settings (an RTX fork may come later).

## Physics
The car is TMNF's force model 6 with the real tuning `20juin2006`, from our reverse engineering
(docs/research/tmnf_physics.md; numbers and behaviour only):
- `core/tm_tuning.gd` (`TmTuning`): every constant and curve, with its tuning offset.
- `core/tm_car_model.gd` (`TmCarModel`): one 10 ms tick of the handling (steering, side grip, yaw,
  drive/brake, slopes, walls, turbo, dirt, air), engine independent. SpeedFest's car uses the same
  model (task: TMNF handling as SpeedFest's default).
- `core/tm_body.gd` (`TmBody`) and `car/tm_car.gd` (`TmCar`): a custom 100 Hz body (not RigidBody3D)
  with collision sub-steps of at most 0.3 m, ellipsoid wheels and chassis, and TMNF's contact
  impulses; Jolt is used for queries only.

## Layout
| dir | contents |
|---|---|
| `core/` | tuning + car model (shared with SpeedFest) |
| `car/` | car body, input, our own car model (`tm_car_visual.gd`), chase camera |
| `gbx/` | `.Challenge.Gbx` reader: header, medals, LZO body, blocks |
| `blocks/` | recreated Stadium block library on the 32 × 8 × 32 m grid: catalogue (layout data), placement, map builder, shape families in `blocks/shapes/` |
| `race/` | race rules (`TmRace`), waypoint triggers (`TmTriggers`), race scene + HUD, map viewer, drive test; our tracks: `TmTracks`, `TmTrackBuilder` (piece lists → blocks), the driving bot `TmBot` |
| `tracks/` | our own campaign: one JSON track spec per track (`A01.json` .. `E05.json`; the list and its series in `campaign.json`), see `race/tm_track_builder.gd` |
| `net/`, `server/` | online play: the client (`Online` autoload) and the Node.js time-attack server |
| `env/` | the Stadium around the map (`tm_stadium_build.gd`), Day sky and sun (`tm_stadium_env.gd`) |
| `audio/` | recorded open-licensed sounds (`audio/sfx`), music (`audio/music`, `tm_music.gd`), the race's engine and cues (`tm_car_audio.gd`) |
| `ui/` | menus in TMNF's structure (`tm_menu.gd`, the main scene: Solo, Online, Profile, Options), the race's pause and finish menus, the glass theme (`tm_glass_box.gd`, `tm_ui.gd`), $-code nicknames (`tm_nick.gd`) |
| `tests/` | headless labs and scene tests |
| `tools/run.sh` | run a scene (100 fps fixed, Forward+ under Xvfb, or `--headless`) |

## Play it
1. Install Godot 4.7.2, clone this repo, check out branch `stadium`, open `stadium/project.godot`
   and press Play (F5): the menu. Solo > Campaign lists our campaign (a tab per series, your best
   time and medal on each track); Race starts the selected one. Straight into a race: run
   `race/race.tscn` with `-- --track=SF03`. Profile sets your nickname (TMNF's $-codes: `$f00`
   red, `$o` bold, `$i` italic ...), zone and car colour.
2. TrackMania tracks: Solo > "Open a track file" races any `.Challenge.Gbx`
   (or `race/race.tscn -- --map="C:/path/X.Challenge.Gbx"`).
3. Keys: arrows / WASD (or a pad) to drive, Enter respawns at the last checkpoint,
   Backspace / Delete restarts, Escape pauses (resume, restart, menu); after the finish: retry,
   replay (watch the run), save replay, next track or menu.
4. Replays: every run is recorded; your best run on each track is kept by itself, Save replay keeps
   any other (Godot's user folder, `replays/`). Solo > Replays lists them; watching one
   (`race/replay.tscn -- --replay=<file>`): Space pause, Left / Right 5 s, Up / Down speed, C or 1-5
   the camera (chase, close, cockpit, trackside, free: WASD, Q / E, right mouse), H hides the bar.
5. Your best time per track and its ghost are saved (Godot's user folder, `records/`; another
   folder with `-- --records=<dir>`). From the next attempt the record's ghost races with you,
   and every checkpoint shows the difference to the record (blue ahead, red behind). Options:
   fullscreen, graphics quality, HD textures, shadows, sound, music, the ghost, clear all records.

## Make a track
A track is a list of pieces laid end to end (`tracks/A01.json`; pieces in
`race/tm_track_builder.gd`): `["start"]`, `["s", 3]`, `["gt", 3, "r"]`, `["cp"]`, `["up"]`,
`["climb", 2]` / `["dive", 2]` (long hills: 4 levels over 6 blocks), `["jump", 1]`, `["loop", "r"]`,
`["turbo"]`, `["finish"]`, ... and TMNF's surfaces: `["circuit", 1]`, `["platform", 3, "walls"]`
(lanes; on them s, l, r, gt, cp on a one-cell lane, turbo, up, down, climb, dive), `["dirt"]`,
`["road"]` (`race/tm_track_areas.gd` lays the plates, borders and walls). A lap race: `"laps": 3`,
the pieces ending with `["close"]` back onto the start line. `"online": false` keeps a long one off
the servers' rotation. A loop needs a straight block (or a turbo, a checkpoint) before and
after it and about 300 km/h in (a turbo and two straights before it; never straight off a join or
a landing). Give a jump's landing a few
straight blocks (at 400 km/h a low ramp flies 200 m), and a hill's crest some road after it (over
~315 km/h the car takes off there; the bot slows for crests): no gate within ~4 blocks after a
crest (the car flies over it) and no tight turn just after one. The field is 32 x 32 blocks: our
tracks use most of it (`tests/tmp/track_dump`, untracked, prints a map; recreate it from PROGRESS).
Save it as `tracks/<ID>.json`, then

    stadium/tools/run.sh res://tests/test_tracks.tscn --headless -- --tracks=<ID> --write_medals

lays it out (errors name the piece that collides or leaves the map), builds it, lets the driving
bot race it at a few grips and writes the medals (author = the bot's best) into the file. Add its
id to `tracks/campaign.json` to put it in the campaign (the menu and the server's rotation). The
builder dresses it by itself (`race/tm_track_decor.gd`; `"decorate": false` turns that off) and
puts road to stop on after the finish line. Look at
it with `race/map_view.tscn -- --track=<ID> --shot=/abs/out.png`.

## The track editor
Editors (main menu) lists the tracks you made; NEW TRACK opens the editor (`editor/editor.tscn`;
`-- --edit=<file.sftrack>` opens one). TMNF's Stadium blocks sit in a palette by family (roads,
platform, dirt, circuit, tubes, decoration, waypoints; icons rendered by
`tools/run.sh res://tools/icons/block_icons.tscn` into `assets/ui/blocks/`). Left click places the
block on the cursor's cell (the ghost is green where it fits), right drag turns the view, the wheel
zooms, Shift + wheel or Page Up / Down changes the level, R / Q turn the block, X erases, I picks
the block under the cursor, Ctrl+Z / Ctrl+Y undo / redo, Ctrl+S saves, F5 (TEST) drives it. Roads
join their neighbours by themselves (dead ends, corners, T's, crossings) and raised road gets
pillars. A track needs a start and a finish (or a start/finish line); finishing it in a test drive
validates it (sets its medals from your time; any change clears them). Tracks are saved as
`user://tracks/<name>.sftrack` (our own JSON: `race/tm_user_tracks.gd`); Solo > Open a track file
races any `.sftrack` too.

## Check the physics against TrackMania (and the world's handedness)
A run's inputs drive our car as text, in the style of TMInterface's input scripts (the community
tool TMNF players use to write and record inputs; format in `race/tm_input_script.gd`):

    stadium/tools/run.sh res://race/race.tscn --headless --timeout 600 -- \
        --tmnf=/path/to/TmNationsForever --track=A01 --inputs=/path/to/your_A01_run.txt

prints `INPUTS_RUN splits=[...] finish=...` (ms). Drive the same script in TMNF and compare the
checkpoint and finish times: equal to the 10 ms tick means our physics is TMNF's on that track. If
the car leaves the road at the first corner, turning the wrong way, our world is TMNF's mirror image
(the open handedness question; first check the steer sign: TMInterface's +65536 is full right).
`--record_inputs=/path/out.txt` writes a run here in the same format (`tests/test_tracks`
input_script_replays_the_run: the bot's run, replayed from its script, gives the same splits).

## Share it with friends
Builds: `stadium/tools/export.sh all` (Godot 4.7.2 export templates installed) writes
`build/stadium/SpeedFestStadium-windows.zip` (~52 MB) and `-linux.zip` (~42 MB): one portable
executable (no installer needed: unzip and run) with `PLAYING.txt` and the credits. Every push to
`stadium` also builds them on GitHub (Actions → "Stadium builds" → the run's artifacts).
- **Easiest:** send the zip through Google Drive / OneDrive / Dropbox / WeTransfer.
- **A permanent download link:** tag a release, e.g. `git tag stadium-v0.1 && git push origin
  stadium-v0.1`; the workflow attaches both zips to a GitHub Release
  (https://github.com/khanhonthetrack/speedfest/releases), the link to send.
- Nothing else to install: the game has its own tracks. (Friends with TrackMania Nations Forever
  installed also get its campaign.) Windows SmartScreen warns about the unsigned exe:
  "More info" → "Run anyway".
- Online: "Join the official server" works while the server runs (`stadium/server/README.md`).

## Continue the work
Agents: read `stadium/CLAUDE.md`. The TMNF install and measurements are recreated locally with
`tools/research/tmnf/setup_measurements.sh` (never committed).

## Run
```bash
godot --headless --path stadium --import                         # once, and after a new class_name
stadium/tools/run.sh res://tests/test_model_lab.tscn --headless  # car model vs the reference (44 checks)
TMNF_DIR=/path/to/TmNationsForever stadium/tools/test_all.sh     # every lab (STADIUM_TESTS PASS)
stadium/tools/run.sh res://race/race.tscn --realtime -- --track=SF01       # play one of our tracks
stadium/tools/run.sh res://race/race.tscn --realtime -- --tmnf=/path/to/TmNationsForever --track=A01
                                         # a TMNF campaign track (or --map=/path/X.Challenge.Gbx)
stadium/tools/run.sh res://race/race.tscn --realtime -- --track=SF01 --bot  # watch the bot drive
stadium/tools/run.sh res://race/map_view.tscn -- --tmnf=/path/to/TMNF --track=A01 --shot=/abs/out.png
```
Race keys: arrows/WASD (or a pad) drive, Enter respawns at the last checkpoint, Backspace/Delete
restarts.
