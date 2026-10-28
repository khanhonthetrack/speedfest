# SpeedFest Stadium: a TMNF Stadium remake in Godot 4.7 (Forward+)

Owner request (session 9, docs/TRANSCRIPT.md): build, in a separate folder, a copy of TrackMania
Nations Forever "as close to the original as possible" (graphics, car feel, textures) on an enhanced
Godot. ManiaPlanet parts are out of scope.

Owner decisions (2026-10-16):
- **Assets: recreate only.** Every model, texture and sound here is our own, made in the TMNF style.
  No Nadeo files (meshes, textures, sounds, packs, decompiled code) are ever committed or shipped.
  One exception the owner chose (20 Oct 2026): city buildings from Blend Swap under open licences
  (CC0, CC BY 3.0), converted by `tools/assets/blend_to_glb.py` into `assets/city/` with their
  credits (`assets/city/CREDITS.md`); anything without a licence stays out. Four humanoid
  animation packs the owner bought joined them on 23 Oct 2026 (owner: "Yes, commit all four
  packs"): `assets/anim/`, 231 clips on three rigs, one of the four CC0 and the rest licensed for
  use in a project but not for resale or for handing on -- `assets/anim/CREDITS.md` states the
  terms, `docs/ANIMATIONS.md` is the study.
- **Tracks:** the game is **standalone** (owner, 2026-10-17): its campaign is our own tracks
  (`tracks/*.json`, built from the recreated blocks; no TMNF needed): 65 in TMNF's five series,
  White A01-A15, Green B01-B15, Blue C01-C15, Red D01-D15, Black E01-E05 (owner, session 13:
  "Only our own A-E"; `docs/research/m9_campaign.md`), and a sixth series of our own, **City**
  F01-F05 (owner, 20 Oct: street circuits between towers on a paved field, three of them at night;
  `"scenery": "city"`, `"mood": "night"` in their specs). The first SpeedFest tracks (SF01-SF11)
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
| `car/` | car body, input, our own cars (`tm_car_visual.gd`: the open-wheeler and the hypercar, whose body `assets/car/hypercar.glb` is made by `tools/assets/hypercar.py` in Blender), `car_lab.tscn` to look at them, chase camera |
| `gbx/` | `.Challenge.Gbx` reader: header, medals, LZO body, blocks |
| `blocks/` | recreated Stadium block library on the 32 × 8 × 32 m grid: catalogue (layout data), placement, map builder, shape families in `blocks/shapes/` |
| `race/` | race rules (`TmRace`), waypoint triggers (`TmTriggers`), race scene + HUD, map viewer, drive test; our tracks: `TmTracks`, `TmTrackBuilder` (piece lists → blocks), the driving bot `TmBot` |
| `tracks/` | our own campaign: one JSON track spec per track (`A01.json` .. `E05.json`; the list and its series in `campaign.json`), see `race/tm_track_builder.gd` |
| `net/`, `server/` | online play: the client (`Online` autoload) and the Node.js time-attack server |
| `env/` | the Stadium around the map (`tm_stadium_build.gd`), Day sky and sun (`tm_stadium_env.gd`) |
| `audio/` | recorded open-licensed sounds (`audio/sfx`), music (`audio/music`, `tm_music.gd`), the race's engine and cues (`tm_car_audio.gd`) |
| `ui/` | the menus in our own look (`tm_menu.gd`, the main scene; `sf_ui.gd` the palette, Montserrat and boxes; `sf_header.gd` the tabs; `sf_tile.gd` the home page's picture panels, whose pictures `tools/icons/menu_art.sh` renders), the race's pause and finish menus in TMNF's glass theme (`tm_glass_box.gd`, `tm_ui.gd`), $-code nicknames (`tm_nick.gd`) |
| `story/` | story mode (PLAN M20): `story.json` the chapters and how their finishes join them, `story_graph.gd` (StoryGraph: routing, the finale's opening, endings, difficulty targets), `story_state.gd` (StoryState: the save, `user://story.json` or `--story_save=`, flags and conditions) |
| `tests/` | headless labs and scene tests |
| `tools/run.sh` | run a scene (100 fps fixed, Forward+ under Xvfb, or `--headless`) |

## Play it
1. Install Godot 4.7.2, clone this repo, check out branch `stadium`, open `stadium/project.godot`
   and press Play (F5): the menu (tabs across the top: Home, Solo, Multiplayer, Garage, Story,
   Community, Editor; you, options and quit at the right). Solo lists our campaign (a row per
   series, your best time and medal on each track); a track's card starts it. Straight into a race: run
   `race/race.tscn` with `-- --track=SF03`. Profile sets your nickname (TMNF's $-codes: `$f00`
   red, `$o` bold, `$i` italic ...), zone, car (the open-wheeler or the Le Mans hypercar) and its colour.
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

### Sky maps (the Sky series, G01-G10: high between the skyscrapers)
`"scenery": "sky"` races the track over the City's streets, 200 m under the field's level
(`env/tm_sky_city.gd`: towers beside the road rising past it, a building under every rooftop and
behind every wall the road rides, a round tower inside every spiral, pylons, traffic far below);
a car that falls 45 m under the lowest road respawns by itself. Beside TMNF's blocks the road can be
our own (`race/tm_sky_track.gd`, built by `env/tm_sky_pieces.gd`), a 3D turtle whose lengths are
blocks of 32 m:
`["sky", n]` straight, `["go", m]` metres (up a face: whole levels), `["sl", k]` / `["sr", k]` a
quarter turn in the road's own plane (radius 32k - 16; upside down, left is the world's right),
`["pu", r]` / `["pd", r]` a quarter pitch up (a quarter pipe, up a tower's face) / down (over an
edge: the car holds only up to sqrt(25 r) m/s), `["twist", "l"|"r", deg, n]` a roll about the line
(90: a wall on that side, 180: upside down; at most 0.025 rad/m, so 3 blocks for 90 and 5 for 180),
`["bank", "l"|"r", k, deg, levels]` a banked, climbing quarter turn (a spiral: a round tower inside),
`["kick", deg, m]` a kicker, `["gap", n, levels]` a flight to a level landing n blocks from the
kicker's foot (`levels` lower), `["drop", n, levels, deg, r]` a ski jump (a landing hill under the
flight; the test prints its design speed), `["roof", w, n]` a rooftop (w odd cells wide),
`["rails", "both"|"none"|"l"|"r"]`. Where the road leans more than 16 degrees it is **mag-road**
(violet chevrons): magnetic, gravity pulls the car to it (`TmBody.mag_surface`), so walls, faces and
upside down drive like the flat. Two finishes: `["split", "l"|"r", [pieces]]` right after a rooftop
3 cells wide (best 6 long: the lane change at speed) leaves its far edge a lane over at full speed;
`["fork", "l"|"r", [pieces]]` a T junction. The track test drives every way, and the fastest sets the
medals; `--write_medals` also writes each way's own set (`"way_medals"`, way 0 the main way, then the
forks and splits in the order they appear, each with its `bot_grip`). The race knows which finish a run
crossed (`race.gd` `finish_way`, `TmChallenge.way_of`): the finish panel says "Finish 2 of 2", and
records and replays keep it (story mode's decisions are those finishes). Lessons from the bot: a 10-degree kicker at 200-210 km/h lands ~105 m on (2 levels down: a
3-block gap); at 360 km/h it flies ~290 m; tighter twists lift two wheels off; layout errors name a
road under a rooftop or through a spiral's tower (their buildings stand from the streets up).

## Story mode (PLAN M20, in progress)
Ten nights in the neon City, played in any order; three maps a night, the third with 3-5 finishes,
and the finish your accepted run crosses is the night's decision (the brief:
`docs/STORY_MODE_PROMPT.md`). `story/story.json` holds the nights, their maps and where each finish
leads (`StoryGraph`); a save is `user://story.json` (`StoryState`, `--story_save=` in tests).
Cutscenes are data, `story/scenes/<id>.json`, played by `StoryScene` (shots on our tracks: camera
keys in a shot's anchor frame, cars standing or driving along the line, people from the animation
library in silhouette, rain, lights; subtitles, cinema bars, title cards and a phone's texts in the
menus' look). Look at one:

    stadium/tools/run.sh res://story/story_lab.tscn -- --scene=look_test --t=8.5 --set_quality=2 \
        --settings=/abs/scratch/settings.cfg --frames=70 --shot=/abs/out.png
    stadium/tools/run.sh res://story/story_lab.tscn --headless -- --scene=look_test --play --no_stage

(`--flags=a,b` / `--tier=hot` play it as a save that knows more.) A save is played by
`story/story_play.tscn` (StoryFlow: scenes, then each map in the race with `--story=<night>
--story_map=0..2`, whose finish panel shows the time to beat and, on map 3, the decision the finish
makes; CONTINUE writes it into the save). `--story_new=street --story_auto` plays a whole save headless.
The menu's Story page starts one (New story: the difficulty), continues it and keeps its journal;
night 1 (H01-H03, the prologue and five scenes) is playable, the other nights come in batches.
Horror shots: a car with `"cabin": true` gets seats, a dash and its body lined from inside under its
own roof; `"mirror"` puts a rear-view mirror's picture over the shot, its camera at the car's
`"pos": "mirror"`. Sets: a scene's own `"props"` stand in every shot without any (a container
terminal: `"containers"` blocks of stacks drawn as one MultiMesh, `"mast"` floodlights, cranes); a
shot's `"env"` thickens the night air (fog, its colour, height fog, exposure: an aerial's far city
lost in haze); a car's `"finish"` overrides its livery's paint (`"gloss"` for a car shown off); a
person's `"gaze": "rear"` looks over the shoulder at the back seat. A shot without the city, to
check a cabin (`story/lab/cabin_check.json`):

    stadium/tools/run.sh res://story/story_lab.tscn -- --file=$PWD/stadium/story/lab/cabin_check.json \
        --ts=0.6,2.6,4.6 --every=20 --frames=60 --shots=/abs/a.png@19,/abs/b.png@39,/abs/c.png@59

Cinematics (owner, 27 Oct: "full cinematic style hollywood cutscenes"; the bar, the plan and the
quality gate: `docs/CINEMATICS.md`). Every cutscene has a film finish (StorySubtitles' post shader:
grain seeded by the frame, vignette, halation, a lens's slight distortion and fringing, the grade;
rain on the windscreen in the same pass): a scene's or a shot's `"grade"` picks a look
(`StorySubtitles.GRADES`: `"film"` by default, `"night"` teal shadows and warm lights, `"dawn"`,
`"dream"`, `"none"`) or tunes one (`{"preset": "night", "lift": 0.03}`); `story_lab --grade=none`
shows the bare picture for a before and after. The camera: `"handheld": deg` (a shoulder camera's
slow, seeded wander), `"path": "spline"` (one smooth move through every key, eased once), a key's
`"dof_near"` (blur before the focus: soft foregrounds, pulls of focus) and `"exposure"` (a flare
whiting out). A person's `"breathe": [deg, period]` keeps a still body alive. Sets: `"bare": "set"`
hides the field's towers too and stands the shot on a level deck 2 m up (`StoryScene.SET_DECK`),
where props build the place: `"quay"` (wet asphalt with painted lines and puddles, walls into the
water, bollards, the water round it), `"sts_crane"`, `"warehouse"`, `"portacabin"` (a `"sign"`),
`"stage"` (a lit truss, its lamps' lenses lit), `"barrel"` (a fire), `"fence"`; `story/lab/docks_check.json`
shows them. A street's lamp posts take `"shadow": false`; a title card `"align": "left"` sits low in
the left third over an establishing shot; a person's `"lift"` raises them off the ground they'd stand
on (a crouch at a low car's window, feet out of shot). A person's `"reach"` puts their hands on
something (`[{"t": 0, "LeftHand": {"at": [x, y, z], "palm": [0, -1, 0], "fingers": [-1, 0, 0]}}, ...]`:
two-bone IK, the palm turned to face it, eased between keys; `"reach_car": "kit"` gives the points in
that car's road frame), and a cabin car's `"windows_down": ["driver"]` (or `{"driver": [3.1, 4.6]}`,
wound down over that time) lowers its door glass into the door: the knock's Dee leans in on the window's
ledge (owner, 27 Oct). Take five's scenes are generated by
`tools/story/take5_*.py` (from take four's files in git), so their numbers can be read and redone.
Before stills, lint a scene's camera work against the gate (shot lengths, zooms inside a shot,
setups, cuts back and forth, the ghost's screen time):

    python3 stadium/tools/story_lint.py c01_close [path/to/scene.json ...]     # LINT_OK or LINT_FAIL n

### The cast (PLAN M20-9)
Modelled people for the cutscenes: MakeHuman's body through MPFB 2 in Blender, dressed from the
MakeHuman community's packs (CC0 and CC BY only), one spec each in `tools/cast/specs/<id>.json`
(height in metres, phenotype, face targets, skin, eyes and their colour, brows, lashes, hair, clothes,
tints, `"desaturate"` for grey hair, `"vest"` for a generated hi-vis vest, `"hair_veil"` for hair
turned down over the face (the passenger; its `"part": {"width", "at"}` cuts the hair down a line
and pulls it apart, so one eye and the corner of the mouth show: a face behind wet hair, not the
back of a head), `"loose"` for garments that hang free and are not sat on
(a long coat), `"tier": "crowd"` for the lighter tier: blinks only, low-poly eyes, no teeth, no
normal maps, 1024 textures, at most 32k triangles and 5 MB). Built into
`assets/cast/<id>/` (glTF + sidecar `<id>.cast.json`), textures shared in `assets/cast/tex/`:

    stadium/tools/cast/setup.sh                  # once: Blender 4.5.15, MPFB 2.0.18, the packs (~3 GB, CAST_CACHE)
    stadium/tools/cast/build.sh [id ...]         # licence gate, build, textures, import; CREDITS.md rewritten
    python3 -I stadium/tools/cast/licences.py $CAST_CACHE/zips --spec stadium/tools/cast/specs/x.json
    stadium/tools/run.sh res://story/cast_lab.tscn -- --who=kit,dee,gus,mannequin --frames=40 --shot=/abs/out.png
    stadium/tools/run.sh res://story/cast_lab.tscn -- --who=dee --mode=face --shapes=eyeBlinkLeft:1,jawOpen:0.6 ...

A scene's person takes `"who": "<id>"` (StoryPerson plays the same UAL clips on it: both imports
retarget onto Godot's humanoid skeleton through `assets/cast/bonemap.tres`). `StoryCast` loads them
(`instance`, `meta`, `set_shape` for the 35 face shapes, `ground` for the per-clip lift).
Standing, people use `"clip": "Stand"`, `"Stand_B"` or `"Stand_Talk"`: Human Basic Motions' idles
and talk (retargeted through `assets/anim/human_basic_motions/bonemap_hbm.tres`), a woman's or a
man's take by the sidecar's `"sex"` (`StoryCast.take`), the arms brought in, the talk calmed; the
UAL `Idle` is a fighter's stance (owner, 25 Oct: "they are not planning to fight"). A person can
also take `"bend"` (bones turned on top of the clip over time: `[{"t": 1.0, "Head": [28, 0, 0]},
...]`, degrees about the body's axes, eased between keys: a head coming up), `"blink": false`,
`"shapes": {"jawOpen": 0.12}` (held), `"gaze": "mirror"` (eyes on the shot's rear-view mirror, or
the cabin's own glass) and `"looks": [[1.0, 2.2, "mirror"]]` (a glance, then back).
A cabin's rear-view mirror is a real one: a shot's `"mirror": {"glass": true, "follow": "kit"}` shows
on the glass what the driver sees in it (`StoryCabin.reflection`: the driver's eyes mirrored in the
glass), from any camera, so a shot can frame Kit's face and the mirror together
(`story/lab/mirror_glass.json`). A shot's light with `"car": "kit"` rides in that car. Props now
include Arch 9's railway viaduct (`"viaduct"`, with `"train": [from s, m/s]`).
Seated in a car (`"car"` with `"seat"` or a `"pos"`), everyone sits by their own body:
`StoryCast.seated` measures, in the clip, the seat (the lowest of the hips and thighs behind the
knees, `"loose"` garments left out, and the back of it) and the crown (hair and hat and all); the
cabins are laid out for the Mannequin, so a cast member's seat goes where the Mannequin's rests in
that clip, and a seat whose sitters' crowns would come within 5 cm of the roof goes down as far as
its tallest needs, everyone on it with it (`StoryCabin.lower`: cushion, back, headrest, the driver's
wheel; Gus driving the corrida, 7.6 cm; over 10 cm it warns). StoryScene measures everyone when a
scene is set up. `tests/test_cast_seats` sits everyone in every seat of every road car;
`story/lab/seat_check.json` shows them (the car a ghost).
Clips for the owner (owner, 25 Oct: "i want to see clips, not just stills"): `tools/clip.sh` records
a scene with Godot's Movie Maker at a fixed frame rate, with its sound, into an H.264 MP4:

    stadium/tools/clip.sh /abs/mirror.mp4 res://story/story_lab.tscn --fps 24 --skip 1 --seconds 26.8 \
        -- --scene=c01_close --t=6 --play --hold=24 --set_quality=2

(from the drive to the black: `--hold` holds the first frame while the city's light settles,
`--skip` cuts it, and `--seconds` counts the held second; at Ultra a frame
with the mirror's second camera takes about 10 s in the container, so a 25 s clip is over an hour.)
The stylised cast (set aside: the owner chose realistic, 24 Oct; `"style": "stylised"` specs in
`tools/cast/specs_stylised/`, `build.sh kit_s` rebuilds one: Quaternius' Ultimate Modular Women/Men, CC0,
fetched by `setup.sh`) is built by `blender/gen_stylised.py` from parts (`{"file", "mesh",
"colours", "drop", "drop_behind"}`), sized (`height_m`, `width`), with an optional hanging hair
panel (`"hair"`), and retargeted through `bonemap_quaternius.tres` (no fingers: the UAL curls make
claws of those hands). `tests/test_cast_models` checks each one. Traps: an asset's pack list can claim CC0 while its own
file says AGPL (the gate reads both); MakeHuman's strand brows and lashes cost ~47k triangles (use
the card ones); boots taller than the trousers' cuffs poke through; a texture's `.import` must come
from `post.py` (headless import leaves it uncompressed without mipmaps); a garment mesh can hold
several layers (rays must pass through all of them); a high heel puts the soles under the feet (the
character stands on tiptoe: flat shoes); a tint is applied at import, so `post.py` hashes the
materials into the glTF (a tint change alone would otherwise not reach Godot).

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
- Community tracks and cars: a server's admins upload TrackMania Exchange tracks and ManiaPark car
  models and skins (`stadium/server/README.md` "Admins"); players' games download them when a
  round or a car needs them, and **C** in an online race picks a car among the server's.
- **The Community page** (main menu): browse ManiaPark's car models and skins and TrackMania
  Exchange's tracks (top, new, popular; search by name) by their previews, **Download** one, then
  **Drive this car** (races, online and the profile use it until Drive our own car; a downloaded
  car turns beside its preview, as the game draws it) or **Play** a track. Downloads are kept in
  `user://community` (My Cars, My Tracks); a modded track is kept but says why it can't be raced.
  The web build goes through its server (`/api/community`, `stadium/server/README.md`).
- **Texture mods** (Community → Texture Mods: ManiaPark's for TMNF/TMUF and for ManiaPlanet): any
  mod opens (`blocks/tm_texture_mod.gd`: every texture decodes, the game and environment are
  read from its names); a **Stadium** mod (TMNF's or ManiaPlanet's) can be worn: **Wear this mod**,
  and the next race's Stadium takes its textures (`TmMaterials.use_mod`, the measured `MOD_MAP`:
  which region of which TMNF texture each of our materials repeats, and over how many metres).
  Mods for environments the game doesn't have (Canyon, Valley, Lagoon, Storm; Island, Bay, Coast,
  Desert, Rally, Snow) open and show their textures, and say so. `--mod=<zip>` wears one for a run.

## Check ManiaPark and TrackMania Exchange (and keep your own copy)
`tools/compat/compat_run.py` runs ManiaPark's whole catalogue and a large TrackMania Exchange sample
through the game, a batch at a time: it downloads a batch, has the game open each item (the
compatibility tests), records the outcome and deletes the files, so it never needs much disk. The
outcomes are in `tools/compat/results/` (ids, names, authors, checksums, what the game made of each);
the files themselves never go in this repository (they are their authors' works, and the cars
alone are ~70 GB). To keep a copy for yourself, give `--keep=<a folder of yours>`: each tested
batch is moved there instead of deleted. On the Windows PC (Git Bash, `export PATH=/c/dev/bin:$PATH`
for Godot):

    python -I stadium/tools/compat/compat_run.py mods   C:/dev/community/work --keep=C:/dev/community/mods
    python -I stadium/tools/compat/compat_run.py cars   C:/dev/community/work --keep=C:/dev/community/cars
    python -I stadium/tools/compat/compat_run.py tracks C:/dev/community/work --keep=C:/dev/community/tracks

Re-running continues where it stopped (the work folder remembers what is done); the folders in
`--keep` are plain zips and `.Challenge.Gbx` files the game opens (Community, OPEN A TRACK FILE).

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
stadium/tools/run.sh res://race/race.tscn --realtime -- --track=SF01 --car_pack=/path/car.zip  # drive a ManiaPark car
python3 -I stadium/tools/compat/fetch_tmx.py /tmp/tmx         # community samples (outside the repo)
python3 -I stadium/tools/compat/fetch_maniapark.py /tmp/cars
stadium/tools/run.sh res://tests/test_compat_tracks.tscn --headless --timeout 7000 -- --dir=/tmp/tmx --build
stadium/tools/run.sh res://tests/test_compat_cars.tscn --headless --timeout 3000 -- --dir=/tmp/cars
```
Race keys: arrows/WASD (or a pad) drive, Enter respawns at the last checkpoint, Backspace/Delete
restarts.
