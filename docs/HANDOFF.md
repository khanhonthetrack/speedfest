# HANDOFF: start here

## Latest (18 Oct, session 13 continued, cloud): M10, the owner's five requests after M9
- Branch `claude/tmnf-replica-graphics-nb1kcg` (M9 is complete there; not merged into `stadium`
  until the owner says so). Plan: PLAN.md M10 (steps 1-5, the owner's order); owner's words in
  TRANSCRIPT (session 13, after M9). STADIUM_TESTS PASS at every commit.
- Done: M10-1 dark circuit screens and the wall foot (blue kerb, logo bumper, blue trim);
  M10-2 tyre marks (`race/tm_tyre_marks.gd`, in races and replays; `tests/test_tyre_marks`);
  M10-3 the surfaces off asphalt (below).
- M10-3, the physics off asphalt against TMNF's own runs. Tools: `ghost_dump.py` (a
  Replay.Gbx's ghosts: samples every 100 ms with each wheel's surface and sliding flag, and the
  run's inputs; `--json=` for the harness, `--inputs=` a TMInterface-style script),
  `race/ghost_fit.tscn` (puts our car in a ghost's state, drives it 0.5 s with the run's own
  inputs, prints how far apart it ends by surface), `accel_curve.py`, `lateral_grip.py`,
  `ghost_compare.py` (a whole run: `race.tscn --inputs=... --trace=...` against the ghost).
  Our world is TMNF's mirror image (x negated): feed a TMNF run's inputs with left and right
  swapped. Asphalt agrees to centimetres over 0.5 s. **Fixed**: the surface table's columns
  were misread; TMNF's runs say column 1 is the grip, 2 the drive, 3 the brakes (grass and dirt
  now follow TMNF to ~0.3 m over 0.5 s; `docs/research/tmnf_physics.md` §3.10, PROGRESS M10-3).
  A ghost's position is the car's model origin: the centre of mass is 0.4385 above and 0.288
  ahead of it (`ghost_fit.gd` OFFSET).
- M10-4 jumps measured (tmnf_physics.md §3.7b): flight identical to 2 cm, take-offs agree,
  landings agree in the median; open: TMNF's wheelie (rear wheels, 12-20 deg nose-up for 0.3-0.5 s)
  after nose-down landings, which ours doesn't do. The mechanism is in TMNF's contact code; reading
  the decompiled code was blocked by the session's safety check, so the owner decides whether to
  continue that way. (Ghidra 11.4.2 headless works locally: `/opt/ghidra`, a script that labels
  TmForever.map's functions; nothing of it in the repo.)
- M10-5 (look, UI, menus, sound side by side with TMNF; session 13 continued, 19 Oct): TMNF runs
  locally under Wine (9.0, 32-bit prefix, an offline profile, its network cut with `unshare -n`,
  shader quality PC2) for reference screenshots; nothing of it in the repo. Done, one commit each
  (PROGRESS has the details): the race HUD and countdown (`race/tm_race_hud.gd`, `ui/tm_seg_text.gd`,
  -2.60 s start), the race menu and finish card in TMNF's dialog style, the menus in TMNF's frame
  (`ui/tm_menu.gd`: globe, icon-row column, green-titled panels, the campaign grid of cards), the
  loading screen with the keyboard (`ui/tm_loading.gd`) and the three camera views (keys 1-3), the
  cues shaped to TMNF's measured ones (`tools/sfxgen/cues.py`, numbers in `research/m9_sound.md`),
  Select Opponent with medal ghosts (`race/tm_medal_ghost.gd`: the bot's run slowed to each medal),
  pictures of our tracks on the campaign cards (`tools/icons/thumbs.sh` -> `assets/ui/thumbs`).
- Note: session 14 (another branch, below) merged M9 into `stadium`; this branch's M10 work goes
  into `stadium` when the owner says so (expect conflicts in docs only, maybe `race/race.gd`).
  Also the race menu's Select Opponents. M10 is done but for the owner's decisions:
- M10-6 (owner): TMNF's top bar (`ui/tm_top_bar.gd`): volumes, display, clock, window; always up in
  the menus, sliding down at the top edge in races and replays. The wheelie (M10-4b) was looked into
  and stopped by the owner (tmnf_physics.md §3.7b: what was read and measured).
- Open (owner's call): TMNF's wheelie after nose-down landings (M10-4: needs TMNF's contact code);
  the engine's layers' pitch curves (TMNF's SoundEngine definition: reading it was blocked by the
  session's safety check; our engine is brighter than TMNF's samples, which sit lower: TMNF's
  strongest partial is the 3rd order of a low fundamental); TMNF's padlocks on later campaign
  tracks (would change play). Side-by-side sheets: render ours with the commands in PROGRESS,
  TMNF under Wine locally (never commit its frames).

## Also 19 Oct (a parallel session, branch `claude/sleepy-albattani-o7ygr1`): the wheelie is NOT the contact layer

Owner approved reading TMNF's code for the wheelie-after-nose-down-landing question. Re-read
`WheelAbsorbContact` from the binary (no Ghidra needed — see below). **The "bottomed" flag means
exactly what we assumed**: it is set only where the suspension cannot swallow the whole penetration,
and the full-impulse-at-the-contact-point branch needs it. `stadium/core/tm_body.gd::_collide`
already matches TMNF branch for branch. Written up as **§3.2a** of `docs/research/tmnf_physics.md`.
So the contact layer is exonerated and the wheelie has to come from somewhere else.

**Found on the way (a real bug, worth fixing on its own):** `AddVehicleImpulse` scales the angular
`r x j` of *every* contact impulse by **0.55 [0x0ec]** and then clamps `|w|` to 100 rad/s [0x14c];
linear is unscaled. Our `_apply_impulse` applies the full `r x j`, so **our contacts over-rotate by
~1.8x**. New §3.2b and three rows in the §5 table. Fix this in `tm_body.gd` before tuning the
wheelie — it changes every landing. It needs the stadium lab re-run
(`stadium/tools/test_all.sh`, 22 body + 44 model tests are calibrated against the old behaviour),
which needs Godot installed (see CLAUDE.md "Environment setup"); this container had no Godot.

**Next candidates for the wheelie:** the spring force and where it is applied during compression
(§3.2), the ground/air gravity switch 3.0 ↔ 2.5 [0x160/0x164] at touchdown, and the load-transfer
torque [0x228–0x23c] (already implemented in `tm_car_model.gd`).

**RE pipeline is now cheap:** `tools/research/tmnf/fnmap.py` (name → address range from
`TmForever.map`) + `dis.py` (objdump + call/constant annotation). No Ghidra, no REA, no JDK — they
are only needed for pseudocode. Installer, `7z`, `innoextract`, `pip install pycryptodome` and the
existing pack scripts do the rest; README has the commands.

## Earlier (18 Oct, owner's Windows PC): `stadium-v0.4` released = `stadium` + M9
- Owner: "release the most up to date version ... of the stadium", choosing "stadium + M9 branch"
  (TRANSCRIPT "Release"). `claude/tmnf-replica-graphics-nb1kcg` (M9-7 online, the M9 review's 42
  fixes, M9-8 the 65-track A-E campaign) is **merged into `stadium`** on top of session 14's v0.4
  work and the rotating adverts; only docs conflicted. STADIUM_TESTS PASS on the merge (Windows).
  `stadium/PLAYING.txt` (the zips' how-to-play, also the release notes) rewritten for the new game.
- **Released `stadium-v0.4`** on that merge (pushed from the PC; cloud sessions can't push tags):
  https://github.com/khanhonthetrack/speedfest/releases/tag/stadium-v0.4 (CI "Stadium builds"
  attaches the Windows and Linux zips). Next release: tag `stadium-v0.5` the same way.
- Both branches are now contained in `stadium`: continue M9 on `stadium` (or keep the M9 branch and
  merge `stadium` into it first). Session 15's `ccr-1ce252fc-wl7p3m` (community tracks and car
  packs on admins' servers; unfinished) is **not** in the release: it forked before the Green..Black
  series, so merge `stadium` into it before it goes back.
- **The official server runs again on the owner's PC** with M9-7's server (master `/api` + one
  Time Attack server `/ws/main` over the A-E campaign; accounts in the gitignored
  `stadium/server/data/`): it had been down (no node / cloudflared), so the owner said "Yes, start
  the official server on this PC with run_official.ps1 -Publish". New quick-tunnel address
  published in `stadium/server/official.json` (b150220); checked through the tunnel (`/`,
  `/api/servers`, a WebSocket join on `/ws/main`). If the PC restarts, run it again with
  `-Publish`; the permanent home is still the Pi (Docker + named tunnel, `stadium/server/README.md`).

## Earlier (18 Oct, session 14, cloud): the review's fix list, real flags, Polish adverts; v0.4
- **Merged into `stadium`; the `stadium-v0.4` tag is still to push** (owner: "merge it into stadium
  and tag stadium-v0.4"): `stadium` was fast-forwarded to `claude/trackmania-stadium-review-lds3no`
  = `stadium` + session 13's M9 branch (merged in at 9ee8237) + session 14, so `stadium` has M9 too
  (CI build of e73901a: success, zips in run 39134618740's artifacts). The cloud session may push
  branches but not tags (HTTP 403 on refs/tags), so push the tag from the PC:
  `git fetch origin && git tag -a stadium-v0.4 origin/stadium -m "SpeedFest Stadium v0.4" && git push origin stadium-v0.4`
  (or GitHub > Releases > Draft a new release, tag `stadium-v0.4` on `stadium`); the workflow then
  makes the Release with the zips. Continue on `stadium` (M9's branch is fully contained in it).
  STADIUM_TESTS PASS at every commit (test_tracks 52 checks now).
- Review: `docs/research/stadium_review.md` (scorecard, causes, ranked list; its §3 was re-ranked
  by prototype renders: gates first, then local depth; AgX, a global light re-balance and SDFGI
  were tried and rejected). Owner then said "go with option B and implement the fix list", then
  flags of real countries, then Polish brands (TRANSCRIPT session 14). Done, one commit each
  (PROGRESS "Session 14: the review's fix list"):
  gates option B (`blocks/tm_gate_screen.gd`: crown LED screen with your time and split, a
  spotlight in the gate's colour; no sign boards); contact shadow under the car; the map's sky
  occlusion baked at load (`env/tm_occlusion.gd`, TM's "Compute Shadows" our way; textured
  materials moved to `blocks/tm_textured.gdshader`); smooth shading on swept sections, chamfered
  free-standing boxes, curb lettering upright from outside; road decals (tyre marks on the racing
  line, scuffs, burnout, stains); car body AO, glossier paint, livery decals; a reflection probe
  over the field; grass/dirt/platform/steel/wall textures with macro variation; the physics check
  harness (`race.tscn --inputs=<TMInterface-style script>`, README "Check the physics against
  TrackMania"); 24 real national flags waving on the masts (Poland in each corner); the adverts
  as 16 Polish brands under parody names (`tools/texgen/brands.py`), ORLAN on the car.
- After v0.4, the adverts (owner: "like in football stadiums ... changin on rotation", then "Just
  show 1 (by nicely adjusting sizes) and let them rotate"): every screen shows one ad, fitted to
  its size (centred on a long board with the ad's background carried to its ends; never stacked
  or side by side); all boards change to the next ad together every 8 s, billboards (big screens,
  inflatable advert walls) every 12 s each at its own moment (PROGRESS; a new screen gets its
  layout from `TmGeo.SCREENS`). Merged into `stadium` (owner: "Merge"), after the v0.4 commit:
  a tag pushed on `stadium` now includes it (tag 737f8a1 for v0.4 exactly as it was).
- Open: run the input harness against TMNF with a player's install and runs (physics times and the
  world's handedness); SDFGI on Ultra needs tuning on a real GPU; M9's own next steps (M9-7
  online, M9-8 the A-E campaign) are unchanged.
- Not done, by design: rebuilding Trackmania (2020) from its code (review §0).

## Latest (18 Oct, session 13 continued, cloud): M9 "a 1:1 TMNF replica" on `claude/tmnf-replica-graphics-nb1kcg`
- Owner (TRANSCRIPT, session 13): the remake looks cheap (gates, billboards, stadium, "2005");
  wants TMNF's graphics (or better, RTX), TMNF's menus, online, a campaign like TMNF's, a better
  engine sound, a car whose rims sit in the tyres. Answers: our own A-E campaign (65 originals),
  Track Editor + replays, accounts + ladder, the Pi hosts the master/official servers.
- Work branch `claude/tmnf-replica-graphics-nb1kcg` (from `stadium` @ 9a6ae41). Plan: PLAN.md M9
  (steps 0-8, in order). Merge it into `stadium` when a step is done and checked.
- Done (pushed): M9-1 the new car (`car/tm_car_visual.gd`, `car/tm_mesher.gd`); M9-2 first pass:
  textured road, gates, adverts, fabric roofs, stadium facades (PROGRESS 18 Oct; textures from
  `stadium/tools/texgen/*.py` into `stadium/assets/tex/`, regenerate with `python3 <script>.py`;
  needs numpy, pillow, fonttools, brotli); M9-3 the engine (TMNF's six layers and gear model,
  synthesized by `stadium/tools/sfxgen/engine.py`); M9-4 the menus (TMNF's structure and look:
  `ui/tm_menu.gd`, `ui/tm_glass_box.gd`, `ui/tm_nick.gd` $-codes, `ui/tm_track_map.gd`, icons by
  `tools/texgen/ui.py` in `assets/ui/`, the countdown figures in the race HUD); M9-5 replays
  (`race/tm_replay.gd` recording and files, `race/replay.tscn` the viewer, Solo > Replays,
  REPLAY / SAVE REPLAY after the finish; `tests/test_replay`); M9-6 the track editor
  (`editor/editor.tscn`, `editor/tm_editor_model.gd`, `race/tm_user_tracks.gd` .sftrack files,
  Editors page, palette icons from `tools/icons/`; `tests/test_editor`).
- M9-7 online done too (PROGRESS "M9-7"): `stadium/server` (master `/api` + official servers
  `/ws/<id>` in one process; Docker + named tunnel for the Pi: README there), `net/tm_master.gd`,
  the Online page, modes/votes/spectating in `race/tm_race_online.gd`. The owner deploys it.
- Session 14's work (review fixes, flags, Polish adverts, v0.4) is merged into this branch
  (from `claude/trackmania-stadium-review-lds3no`; gate PASS). This branch is ahead of `stadium`
  by M9-7: merge it into `stadium` when the owner says so.
- The session-13 code review's 42 findings (`docs/research/m9_review_findings.md`) are all
  fixed, in four batches (PROGRESS "the M9 code review's findings"): testing mode only from the
  command line, list selection, the editor's ground-only blocks, replays (laps, the roll after the
  finish, keys, sound, back to the finish menu), menus, the music toast, guest names.
- M9-8 the A-E campaign is done: 65 tracks of our own in TMNF's five series (research and the
  list with times: `docs/research/m9_campaign.md`; PROGRESS "the White series" onward). The
  builder lays TMNF's surfaces (`race/tm_track_areas.gd`: circuit lanes with their borders,
  walled or open platforms, dirt roads, the joins; lap races with `["close"]`); README "Make a
  track" has the layout rules the bot taught us (loops need a turbo run-up; nothing tight or a
  gate right after a fast crest). The gate drives each series' first track; `tests/test_tracks
  --series=<name>` drives a whole series (the bot drives at about real time: White ~6 min, Red
  ~25 min with D15's 10 laps; D15 and E05 are off the online rotation, `"online": false`).
  Untracked planning helpers (recreate if needed): `tests/tmp/ascii.tscn` (a track's top view),
  `layout_all.tscn` (lay out many), `bot_probe.tscn` (where the bot is, every second).
- M9-2 second pass done (PROGRESS "M9-2: the decks, walls and dirt roads"): decks (steel plate per
  block + a tread detail map), dark platform walls, circuit walls in TMNF's layout (white, blue
  band with our name, black rubber, truss), dirt roads (packed track blending into loose berms).
  Compare with TMNF locally: `map_view --ref=<dir>` (tools/research/tmnf ref_visuals; normal maps
  now read right). Views that worked: `--view=gate:StadiumCircuitBorderStraight:2:30:3 --gz=22`
  (a circuit wall from outside; `:-25:12` from the lane), `--view=path:0.4` on A01/A06,
  `--view=gate:StadiumRoadDirt:3:24:2.5 --gz=24` on A02.
  Then the control booths (dark roofs, white sides, smoked windows) and the grandstands' truss
  arches and advert boards. TMNF's "fences" along dirt roads are grass blades (shell layers).
  Ultra (SDFGI) no longer leaves the fabric roofs black underneath (a membrane glow,
  `TmRtx.MEMBRANE`). Compare quality presets with `--set_quality=1|2` on the same view.
  Raised gates get raised grandstands on fabric pillars (TMNF's A07 way).
- M9-0's research notes are all written (`docs/research/m9_look.md`, `m9_menus.md`,
  `m9_sound.md`, with `m9_online.md` and `m9_campaign.md`). **M9 is complete** (steps 0-8).
- Next: whatever the owner asks after trying it; merge this branch into `stadium` when the owner
  says so. Polish left (PLAN M9-2): dressing for raised tracks (TMNF: control rows at deck height,
  inflatable towers, B05/A12), grass tufts along dirt roads, SDFGI tuned on a real GPU.
  Merge this branch into `stadium` when the owner says so.

## Latest (17 Oct, session 12): quality pass after the owner's complaints and an independent review
- **Released `stadium-v0.2`** (owner-approved): https://github.com/khanhonthetrack/speedfest/releases/tag/stadium-v0.2 (the quality pass, loops,
  11 tracks); the link to send to friends. Next release: tag `stadium-v0.3` the same way.
- Owner (TRANSCRIPT): bare tracks, cheap checkpoints, start and finish indistinguishable, no
  driver, parts not connected, blur while driving; "Run an indpeendent review of the game" and
  fix both. Done (PROGRESS "quality pass"): gates dressed per kind (`blocks/tm_gate_dress.gd`), the
  driver and a reworked car, the blur (double interpolation + TAA), track decoration
  (`race/tm_track_decor.gd`), adverts on every screen (`env/tm_adverts.gd`), graded light, SMAA,
  run-off after the finish with a trackside finish camera, speed FOV, respawn keeping the
  checkpoint speed, records keyed by layout, `tracks/campaign.json`.
- **Bigger tracks done** (PROGRESS "bigger tracks"): all 11 re-laid across the field (66-82% of
  its box, 2.8-4.1 km, up to level 6, bridges and crossings, pillars under raised curves), new
  `climb`/`dive` pieces, the bot slows for crests, 3-4 checkpoints each, medals re-set (38-59 s).
- **The rest of the review done** (PROGRESS, the four entries after "bigger tracks"): Fabric
  grandstands framing the start and the finish, an inflatable wall with a billboard beyond each
  ground curve, camera booths and light rigs by the checkpoints (`race/tm_track_decor.gd`; TMNF's
  inflatable variant rule is written down there), seats in the stands (the LED face cut to a
  ribbon so the rake shows; `tm_surface` pattern 7), a result panel at the finish
  (`TmRaceMenu.show_finish(result)`). The official server was restarted on the new tracks.
- The bot's weave is fixed (road-frame steering on ordinary road over 100 km/h; PROGRESS) and the
  medals re-set; released as `stadium-v0.3` (owner: "continue and incorporate in v0.3"). After a track or server change:
  `stadium/server/restart_server.ps1` (keeps the address). Screenshots with `--bot`: pass
  `--records=<scratch dir>` (its finishes are recorded like the player's).

## Latest (17 Oct, session 12, owner's Windows PC): the remake is a standalone game
- **Owner (verbatim in TRANSCRIPT):** "No, I want this to be a standalone game!!" and "But still,
  in the end if someeone wants to load trackmania maps, such as gbx, then it should be doable in
  this game". Done: our own campaign `stadium/tracks/SF01..SF10.json` (piece lists laid out by
  `race/tm_track_builder.gd` from the recreated blocks), the driving bot `race/tm_bot.gd` that
  proves each track finishable and sets its medals (`tests/test_tracks`, in the gate), menu / race
  / online server on our tracks by default. TMNF's campaign (from an install) and any
  `.Challenge.Gbx` (Open a track file) still load. PROGRESS has the details.
- **Released `stadium-v0.1`** (owner-approved, held until the game was standalone):
  https://github.com/khanhonthetrack/speedfest/releases/tag/stadium-v0.1: the Windows and Linux zips CI built from the tag; that
  link is what to send to friends. Next release: tag `stadium-v0.2` the same way.
- **Loops fixed** (PROGRESS, "loops fixed"): the ~9 g was TMNF's wall slow-down. The measured
  loop drifts ~25 deg sideways from its first frame, so a car going straight meets the curb. The
  bot's line now eases into and out of the drift (`TmTrackBuilder.ease_loops`), and on loops the bot
  steers in the road's frame for the yaw rate the car has at speed (`TmBot._loop_steer`). It gets
  round from ~280 km/h in (the car needs >= 129 km/h at the top). A contact bug found on the way is
  fixed too (`TmBody._contacts`: a block seam's end cap could give a wheel a backwards normal,
  -20% speed in one tick). New track **SF11 Full Circle** (two loops). Players steer into a loop's
  drift themselves, in TMNF's tracks (B13, C04) too: the model has no force that would carry the
  car sideways.
- **Next:** the bot weaves at 250+ km/h on ordinary road (its old 2.2 steering gain), so flights
  off slope crests (Kickoff) take off with a yaw rate; give STEER points the road-frame steering
  too, then re-run `--write_medals` on every track. Then more tracks (loops: a straight block before
  and after, enter at 300+ km/h).
- The official server (owner's PC, Cloudflare quick tunnel, address in
  `stadium/server/official.json`) runs the new code; after pulling server or track changes run
  `stadium/server/restart_server.ps1` (keeps the address).

## Earlier (~19:00 UTC 16 Oct, session 12, owner's Windows PC): remake continues on `stadium`

- **The remake now builds, tests and measures on the owner's Windows PC** (Git Bash): Godot at
  `C:\dev\godot-4.7.2` (`export PATH=/c/dev/bin:$PATH` for the `godot` wrapper), TMNF unpacked and
  measured in `C:\dev\tmnf` (`--tmnf=C:/dev/tmnf/tmnf/app`, `--meas=C:/dev/tmnf/blocks/meas`;
  `TMNF_DIR=C:/dev/tmnf/tmnf/app`), Python venv `C:\dev\pyenv`. Windows notes:
  `tools/research/tmnf/README.md` ("On Windows") and `stadium/CLAUDE.md`. Nothing from `C:\dev` is
  in the repo.
- Done this session: **every drivable campaign shape is now built**: Circuit slope turns (24
  shapes: the flat walls turned and sheared), Road/Main Stretch (4), road turbo gate rebuilt (91 ->
  99.7%) plus its Up/Down/Left/Right variants, platform turbo slopes, ramps (4), zone clips (2),
  loops (4), diagonal and curved tilt transitions (8). Then the **Fabric grandstands** (new family
  `blocks/shapes/fabric.gd`, 14 shapes: the white wave roofs, straights, corners, pillars), and
  every Sculpt piece as lofts (`blocks/shapes/sculpt.gd`, data from the new
  `tools/research/tmnf/loft_sections.py`): sculptures, bridges, arch rings; **A01 has no
  placeholder left**; then the last decorations (airship, camera lights/pubs, inflatable tube and
  advert pillars, the 3 x 3 Fabric roofs, the bump): **campaign coverage 100%** (0 placeholders on
  all 65 tracks). PROGRESS has the numbers.
- **M8-6 ghosts and best times done** (owner: "Start M8-6: ghosts and best times first, then the
  stadium environment, our own car model, menus and sounds."): `race/tm_ghost.gd`,
  `race/tm_records.gd`, the record's ghost in `race/race.gd`, record and split differences in the
  HUD; `tests/test_ghost`. Records live in Godot's user folder (`records/`).
- **M8-6 stadium environment done:** TMNF's Day sky and sun from the mood's numbers
  (`env/tm_stadium_env.gd`, `env/tm_sky.gdshader`) and the Stadium around the map rebuilt from our
  own measurements of TMNF's surround (`env/tm_stadium_build.gd`: grandstands, roofs, masts,
  terraces, big screens, flags, floodlight towers, the ground and its edge). Research tools for it:
  `tools/research/tmnf/visual_mesh.py`, `vsection.py`.
- **M8-6 our own car model done:** `car/tm_car_visual.gd` (an open-wheel racer with TMNF's
  measured proportions, our own lofted shapes and livery; the ghost uses it too).
- **M8-6 menus done:** `ui/menu.tscn` is the main scene (main, campaign with records and medals,
  options, no-TMNF help), the race's pause and finish menus (`ui/tm_race_menu.gd`); `tests/test_menu`.
- **M8-6 sounds done:** `audio/tm_sounds.gd` (all synthesized: engine loops, skid, wind, cues),
  `audio/tm_car_audio.gd` (engine pitched by virtual gears, cues); `tests/test_sound`. The owner's
  list for this session (ghosts and best times, stadium, car, menus, sounds) is complete.
- **M8-6 HD graphics (textures and materials) done:** `blocks/tm_surface.gdshader` (procedural
  world-space surfaces per material key), `car/tm_car_surface.gdshader`; TMNF's light concrete road.
- **The owner's list (TRANSCRIPT, session 12, verbatim), being worked through in order:** polish
  all steps; menu polish + fonts + online servers with one official server (5-min rounds, time
  trial, random campaign maps); RTX graphics from the RTX branch; downloaded open-licensed dark
  trap / hip-hop music; better sounds from open-licensed packs; export and how to share with friends.
- **Done from that list:** polish (TMNF's outer ground, roof lamps, brake lights); menus restyled
  with fonts; **online play** (`stadium/server`, `net/tm_online.gd`, `race/tm_race_online.gd`);
  **the official server runs on the owner's PC** through a Cloudflare quick tunnel
  (`stadium/server/run_official.ps1`; address in `stadium/server/official.json`; if the PC
  restarts, run it again with `-Publish`); RTX (`stadium/RTX.md`: Ultra preset; DLSS and path
  tracing on NVIDIA's fork, tested on the RTX 2060).
- **Also done:** music (8 open-licensed trap / hip-hop instrumentals, `audio/tm_music.gd`), recorded
  sounds (`audio/sfx`), exports (`stadium/tools/export.sh`, `stadium/export_presets.cfg`, CI
  `.github/workflows/stadium.yml`; Godot 4.7.2 templates installed on this PC; how to share:
  `stadium/README.md` "Share it with friends"). The owner's list is complete.
- **Next (live list: `stadium/CLAUDE.md` "Where things stand"):** the owner's next requests; a
  permanent host for the official server (it runs on the owner's PC through a quick tunnel); polish of the weakest decorations
  (inflatable castles, camera light base, bump) and the stadium's outer roads/parking when time
  allows.
- The `m7-rtx` checkout's `.import` line-ending noise is in `git stash` on this PC (harmless).

## Earlier (16 Oct, session 9, cloud): Stadium remake first; SpeedFest TMNF port PAUSED

- **Another agent continuing the remake: start with `stadium/CLAUDE.md`** (read order, rules, setup,
  tests, the block-family workflow). The local TMNF data (install, measurements) is never in the repo;
  `tools/research/tmnf/setup_measurements.sh /tmp/tmnf` recreates it from public sources.

- Owner (TRANSCRIPT, session 9): "Focus on the TMNF port first. After that, port car physics to
  speedfest after my approval." So the **Stadium remake (`stadium/`) comes first**. SpeedFest's
  TMNF handling stays on branch **`tmnf-physics`, not merged into main until the owner approves**
  (its HANDOFF top section lists its state: AutoDriver 34/34, open per-car test_tm items; it has
  m7-maps through bd65cbc). Main keeps the M7 car.
- The remake works on branch **`stadium`** (only `stadium/` and the research docs) and is merged into
  main per milestone; it never touches SpeedFest's game/. The shared core now includes `TmBody`
  (stadium/core/tm_body.gd: TMNF's sub-stepped integrator, contacts with face normals for shallow
  pairs). Stadium tests: `stadium/tools/test_all.sh` (lab 44, body 22, shapes 11, gbx 3/8 with
  TMNF_DIR, blocks 4, race 37); `TMNF_DIR=<install>` also races A01.
- **Play it:** `race/race.tscn` is the main scene (press Play in the editor): it finds TMNF in its
  usual install folders (or `--tmnf=<install>`, `TMNF_DIR`) and races A01; `--track=B05` or
  `--map=<file.Challenge.Gbx>` for others. Enter respawns, Backspace restarts.
- **M8-6 step 1 done (race flow):** countdown, 10 ms clock, checkpoints/laps/finish through TMNF's
  measured trigger slabs (`race/tm_triggers.gd`), respawn and restart, TMNF-layout HUD with medals.
  `tests/test_race -- --tmnf=<install> --tracks=A01,B05,...` races any campaign tracks; all 65 pass
  and every checkpoint block is built (none taken by hand).
- **M8-5 nearly done for drivable blocks (block library):** families in `stadium/blocks/shapes/`
  (circuit, tube, platform, road, zone, control, inflatable, dirt). Road/Main is complete: straights,
  slopes, junctions, GT curves (TMNF's own segment counts), tilted roads and transitions, GT diagonals
  (TMNF's own sweep frames, `blocks/data/gt_diag_frames.json`), holes and hole pillars, Y junctions;
  plain pieces 97-100% vs measurements. Campaign coverage 96.8% built or empty (1309 placeholders,
  0 unknown), almost all of the rest decoration. Terrain-like pieces (zones, dirt) are bicubic
  surfaces through surveyed control heights (`blocks/data/*_heights.json`). Measurements stay out of
  the repo: `tools/research/tmnf/setup_measurements.sh <dir>` recreates them from public sources.
- **Next (in order; `stadium/CLAUDE.md` "Where things stand" keeps the live list):** the last drivable
  shapes (Circuit/Slope GTCurve 2out*Top and Corner InAirLeftTop, Zone dirt/grass clips, Road/Main
  Stretch and Turbo/UpAir, Ramp/Air, Platform/Turbo/UpAir); then decorations by campaign use: Fabric
  grandstands (~550), Sculpt (~350, incl. the suspended bridge pairs on A01), inflatable tube/advert
  pillars, airship, dirt fences/signs; then the rest of M8-6 (ghosts and best times, environment,
  car model, menus, sounds, HD graphics).
- Known approximations: pool tiles (coarse survey), decorated gates and light/sound tubes, start
  block (from its ground variant), inflatable decorations and castles; water is visual only (no
  water physics yet); grass is surface 2 although TMNF's material table says 0 (open question).

## Latest (~08:00 UTC 16 Oct, session 8 auto-continue on the Pi): m7-maps follow-up for tmnf-physics

- **`m7-maps` has one commit after the one merged into `tmnf-physics`: bd65cbc** (weather puddles
  for the 24 new maps). Without it `tests/weather/test_weather` fails `*_puddle_counts` on 23 maps
  (it needs >= 2 rain pools and a storm-only one per map). On `m7-maps`: test_weather 193/193,
  test_tracks 649/649. **Session 9: merge `origin/m7-maps` into `tmnf-physics` once more** (additive
  lines after checkpoint markers in `game/tracks/defs/*.gd`; icepipe/zigzag/fullsend have them in
  their loops / before a checkpoint).
- The Pi session's map lane is otherwise done (24 maps, surfaces, special pads, private-room track
  chips scroll). It won't merge `m7-maps` into main itself: that happens through `tmnf-physics`.
- **Deploying stays a Pi job:** when `main` gets a new `server/public` export, the Pi session (it
  auto-continues after usage-limit resets) pulls and restarts the container.

## Latest (~12:30 UTC 16 Oct, session 9, cloud): work continues on branch `tmnf-physics`

- SpeedFest's TMNF handling (M8-3) lives on branch **`tmnf-physics`** = the Pi's finished `m7-maps`
  (24 new maps, 34 tracks) + main + the port; its HANDOFF/PROGRESS have the details. AutoDriver
  finishes 34/34 tracks there. Merge it into main when its remaining checks pass (listed there).
  The Stadium remake (`stadium/`) is on main and on the branch.

## Latest (~04:45 UTC 16 Oct, session 9, cloud): TMNF port + Stadium remake started (M8)

- Owner said "Yes" to porting TMNF's model into SpeedFest and asked for a separate TMNF remake in
  Godot (TRANSCRIPT session 9; answers in PLAN M8). New Godot project **`stadium/`**
  (stadium/README.md): `core/tm_tuning.gd` + `core/tm_car_model.gd` = TMNF force model 6 as one
  engine-independent 10 ms tick; `tests/test_model_lab` drives it on ideal flat ground and matches
  `tools/research/tmnf/tmnf_model.py` (44/44: accel, turn radii, response, brakes, drift, coast,
  surfaces, turbo, walls, air). The damper grip factor is decompiled and applied
  (tmnf_physics §3.5).
- **Next (in order):** M8-2 the remake's 100 Hz car body; then M8-3 the SpeedFest port on branch
  `tmnf-physics`, merged after the Pi's `m7-maps` (it touches car.gd and every map, so wait for
  m7-maps to land, then retune all maps with the AutoDriver).
- Still open in the RE (small): reverse-switch threshold, turbo pad-direction scaling, burnout/donut.

## Latest (~02:50 UTC 16 Oct, session 8 auto-continue on the Pi): M7-6 maps claimed

- The owner asked this Pi session to auto-continue after the usage limit. At 02:45 UTC it found
  sessions 9 (TMNF reverse engineering) and 10 (physics merged, then "next: PC build") had moved on.
- **Deployed on the Pi:** `main` @ bccc69f, server restarted on 1f4fbcb's export (M7 handling,
  non-magnetic rails). /health OK.
- **Progress on `m7-maps` (~04:10 UTC):** dirt/ice/plastic surfaces, special pads (engine off, no steer, cruise, reactor, reset; TM lab 366/366), map plan `docs/research/m7_maps.md`, 16 of 24 new maps done and verified (batches 1-4: frost, dust, blackout, glide, techlab, fullsend, cruise, plastic, sausage, mixer, platform, snake, nosteer, canyon, icepipe, grassland; AutoDriver 6 cars, 0 respawns). Next: batches 5-6, then merge + export + deploy.
- **This session now works on M7-6 (new track pieces + 30+ maps) on branch `m7-maps`** so it doesn't
  collide with session 10's PC build (M7-1, rendering/export files). Map work touches
  `game/tracks/**`, `game/weather/track_surface.gd`, `server/lib/rotation.js`, track tests.
- Still the owner's call: port TMNF's real model (`TM_FAITHFUL`, session 9). Map jumps are validated
  by the AutoDriver, so they'll be re-checked if the physics changes.

## Latest (~00:15 UTC 16 Oct, session 9, cloud): TMNF reverse engineered, port not started

- Owner asked to study ModTMNF + REA and reverse engineer TrackMania Nations Forever (TRANSCRIPT
  session 9). **Done:** `docs/research/tmnf_physics.md` describes the real Stadium car (force model 6,
  tuning `20juin2006`, geometry, surfaces, walls, turbo, air) with numbers;
  `tools/research/tmnf/tmnf_model.py` is our runnable reconstruction (0-100 1.74 s, full-lock radius
  16 m @ 100 km/h / 48 m @ 200, 30/25 m/s² gravity ground/air, wheel-to-wall 500 ms slow-down...).
  Pipeline and scripts: `tools/research/tmnf/README.md` (nothing from the game is committed).
- Parallel session 10 merged its own M7 handling (guessed targets, docs/research/m7_physics.md) and
  moved on to the PC build. **Open decision for the owner:** port TMNF's model into `car.gd`
  (a `TM_FAITHFUL` mode, test_tm targets from `tmnf_model.py`) — it changes how every map plays
  (heavier gravity, staircase acceleration without drag, much tighter turning, wheel-wall penalty).
  §6 of tmnf_physics.md lists the differences one by one.
- To redo the analysis in a fresh container: install Ghidra 12.1.4 + `npm i -g rea-agents`, download
  the TMNF installer (README step 1), unpack, `map2seeds.py`, start `rea_bridge.py` (~8 min Ghidra
  analysis), then `dc.py`/`asm.py`. Decrypting packs needs only Python + pycryptodome.

## Earlier (~23:00 UTC, session 8, Pi): STOPPED on owner request. M7 physics done on branch `m7-physics`

- **Branch `m7-physics` (87a4543, NOT merged):** M7 items 2-4 (Trackmania handling, barriers,
  wall rides) are implemented in `game/cars/car.gd`, `car_input.gd`, `tuning.gd`,
  `auto_driver.gd` and `car_physics_defs.gd` (Veloce and Goliath traction). Design, diagnosis and
  numbers: `docs/research/m7_physics.md` (on `main` too).
  - Handling: the steering sets the yaw rate (v*tan(angle)/wheelbase, capped by grip: no spins, no
    understeer); a lateral force cancels sideways velocity in the road plane up to
    grip * GRIP_SCALE(1.15) * spring load (the same rule on banks, wall rides and loops); drift
    mode on brake tap/handbrake + steer (the steering sets the slide angle 12-28 deg). Removed:
    slip-curve tires, friction circle, stability assist, drift stabilizer/speed-keep, power
    oversteer, the steep-road "stick" force.
  - GROUND_STICK_MAX 0.6 m/s: while >= 2 wheels touch, the car can't spring away from the road
    (velocity redirected along the car's up axis, speed kept). ROAD_ALIGN 14, ROLL_DAMP 8.
  - Barriers: speed into the wall removed, 12% bounce (cap 1.5 m/s), small friction, the nose
    yaws along the wall in ~0.15 s (feeds the yaw controller; steering away still wins).
  - Keyboard steering: one ramp (12/s, centre 16/s), no lock cap at speed. Power x1.35 with drag
    calibrated from it (top speeds unchanged). AutoDriver plans with GRIP_SCALE.
  - Tests: new `tests/physics/test_tm` (Trackmania lab, all 6 cars) **312/312**;
    `tests/physics/run_all.sh` **PHYSICS_ALL_OK** (tests that encoded the old feel were updated:
    0-100 range, input ramp, tuning ranges; the tuning trade-off check is now a note).
- **Before merging into `main` (next steps, in order):**
  1. `tools/run_scene.sh res://tests/tracks/test_tracks.tscn --headless -- --track=all`, then
     AutoDriver on every track and car (`tools/run_scene.sh res://race/race.tscn --headless --
     --track=<id> --autodrive --car=<id>`, or `game/tests/physics/run_real_tracks.sh`, also with
     `KB=true` keyboard emulation). Retune the AutoDriver where it now goes off (corners are faster).
  2. Rails non-magnetic (M7-5): `game/tracks/track_rail.gd` captures from 1.8 m away; make it
     catch only a car actually coming down onto the rail, then re-run `tests/tracks/test_rail`.
  3. `tools/integration/check_all.sh`, merge to `main`, `tools/export_web.sh`, commit
     `server/public`, then on the Pi `git pull && docker restart speedfest`.
- Then M7-1 (PC build: physics interpolation, Forward+ presets, Windows/Linux exports, optional
  RTX path) and M7-6 (new track pieces, 30+ maps), per PLAN.md "M7".
- The Pi serves `main`'s ce4dc66 export (interiors, liveries). A duplicate Pi-side cabin attempt
  sits on the local, unpushed branch `wip/pi-cabin-duplicate`; ignore it.

## Latest (~21:40 UTC, session 7): STOPPED on owner request. M7 not started, continue here

**Priority: M7 (PLAN.md "M7").** The owner played it and called it "unplayable". The verbatim
request is the last entry in TRANSCRIPT session 7:
1. PC build with good Godot graphics + optional RTX, no lag ("looks like 2005", "laggy").
2. Trackmania-feel physics (learn from how TM cars behave).
3. Barriers are super annoying.
4. Wall rides slow you down and pull you down (no grip).
5. Maps are copy-paste: 30+ high-quality, different maps (inspired by TMX styles, original
   designs). Rails must not be magnetic: landing on the rail is the player's job.

**State at the stop:** nothing implemented for M7 yet. A read-only research workflow was running
and was stopped when the owner said "STOP WHAT YOU'RE DOING AND WRITE DOWN HANDOFF". Only 2 of
its 6 agents had started (this container runs 2 at a time), and neither finished, so there are no
reports. Its raw downloads were left in the container scratchpad and are not in the repo.

**How to continue:**
1. Research first. The full plan is in `docs/research/m7_research_workflow.js`, a Workflow
   script with six topics, then a planning agent:
   - tm_physics: a quantitative Trackmania car-behaviour target spec;
   - tm_maps: TMX styles plus 36 original map concepts;
   - godot_pc_rtx: Godot 4.7 Forward+, the NVIDIA RTX fork, PC export and CI;
   - audit_physics, audit_perf, audit_tracks.
   Re-run it with the Workflow tool, or work through the six prompts one at a time if parallel
   agents are not wanted. The owner's earlier rule is "no parallel agents"; they opted into
   workflows for M7. Save each report to `docs/research/` and push as soon as it exists.
2. Then implement in order: physics rewrite (TM feel; retune the AutoDriver) → barriers, wall
   rides and loops, non-magnetic rails → PC smoothness (physics interpolation, frame pacing) and
   graphics presets, Windows/Linux export (+ CI) and the optional RTX path → new track pieces
   → 30+ maps (one per worker/branch) → track select / LIVE for 30+ maps. Measurable tests for
   each step; keep the web build working.
- Research access from cloud containers: trackmania.exchange (incl. JSON API
  `/api/meta/tags`, `/api/maps?fields=...`), donadigo.com, linesight-rl.github.io,
  openplanet.dev, doc.trackmania.com, docs.godotengine.org, godotengine.org and
  raw.githubusercontent.com all work. reddit, fandom and github.com web pages return 403.
- NVIDIA RTX fork: branches `nvidia-pt-dlss` (path tracing + DLSS), `nvidia-pt-dlss-dev`,
  `backport/nvidia-pt-dlss-4.6.3`, `worktree-dlss-fg-reflex`. It's public, and the git proxy
  serves reads: `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --branch nvidia-pt-dlss
  https://github.com/NVIDIA-RTX/godot /home/user/nvidia-rtx/godot` (~5 min). This session's
  clone dies with the container.
- **Still pending from earlier today:** the Pi runs an older build. Everything up to ce4dc66
  (new cars, skies, 16 liveries, interiors + driver, air-steer fix) needs
  `cd ~/speedfest && git pull && docker restart speedfest` on the Pi.

## Latest (~20:45 UTC, session 7, cloud session)

- Owner (TRANSCRIPT session 7): "Put more patterns for cars to choose. Interiors suck, they look
  weird. Put effort, put a driver inside as well." **Both done and on `main`:** 16 liveries (10
  new) on a new garage VINYL tab, and real cabins with a driver in all six cars (PROGRESS ~20:20
  and ~20:50 UTC, docs/modules/visuals.md "Cabin and driver"). `server/public` re-exported with
  both (menu checked in Chromium, 0 errors). **The Pi still needs** `cd ~/speedfest && git pull &&
  docker restart speedfest`.
- Visual checks: `tools/run_scene.sh res://tests/visual/showcase.tscn -- --car=<id>
  --angle=cabin|cabin_r|cockpit --style=livery:<name> --frames=30 --shot=/abs/x.png`.

## Earlier (~19:20 UTC, session 7)

- Fixed the inverted **air steering** (car.gd, `test_feel` direction checks) and the
  **test_weather** failures on the session-6 maps (PROGRESS ~17:20 UTC).
- **M6-3 done (~17:50 UTC):** Kitsune R4, Pixie S and Goliath HD are merged into `main` (PROGRESS
  ~17:50 UTC). The session-6 step list below for `wip/m6-cars` is finished; that branch is now
  merged.
- **M6-4 step 1 done (~19:15 UTC):** photographed CC0 skies for city/stadium/coast (PROGRESS
  ~19:15 UTC, ASSETS "Sky panoramas"). This cloud environment reaches polyhaven.com and ambientcg.com.
- **M6-5 export done (~19:35 UTC):** `server/public` has everything above, browser-checked (PROGRESS
  ~19:35 UTC). **Deploy is pending:** on the Pi run `cd ~/speedfest && git pull && docker restart
  speedfest` (restarting drops anyone playing).
- Open: further M6-4 polish (an overcast photo sky for rain/storm rounds, lighting/post), the
  keyboard-emulation matrix for the new cars (`KB=true CARS="kitsune pixie goliath"
  game/tests/physics/run_real_tracks.sh ...`), and the adversarial review that never ran.

## Latest (~16:00 UTC, session 6, orchestrating session on the Pi): STOPPED for the usage limit

Owner request (TRANSCRIPT session 6): better graphics, a server that rotates maps (no lobby/waiting),
more 10–30 s maps, different car types; "keep it fun, and clever". Plan: PLAN.md "M6".
- **Done on `main`:** M6-1 LIVE rotation room (server `lib/rotation.js` + `lobby.js`, `Net.join_live()`,
  menu ONLINE · LIVE / PRIVATE ROOM, lobby JUMP IN, results NEXT UP; ARCHITECTURE "LIVE room").
  M6-2 four new maps: Rooftop Rush, Cliff Hanger, Twister, Pipe Dream (14–20 s, AutoDriver 0
  respawns), side boost pads (`"x"`, `"pw"`), track select carousel, LIVE playlist = all 10 tracks.
  Tests: server 16/16, live_smoke_test PASS, net_smoke PASS, test_tracks 203/203, test_rail 33/33.
- **In progress, branch `wip/m6-cars` (bec01f3, NOT merged):** M6-3 three new car types: Kitsune R4
  (AWD rally hatch, new physics param `loose_grip` = 0.75 wins back off-asphalt grip/drag), Pixie S
  (light kei roadster: most grip, sharpest steering, lowest top speed), Goliath HD (2.25 t AWD pickup,
  biggest nitro, soft springs). Defs, physics, `loose_grip` in Car/Tuning, body shapes
  (car_shape.gd) and front/rear parts (car_parts.gd) are written and compile; NOTHING tested yet.
  To finish: (1) look at them: `tools/run_scene.sh res://tests/visual/showcase.tscn --compat -- --car=all
  --frames=90 --shot=/abs/cars.png` and fix the shapes (Goliath's bed = crown dipping below belt);
  (2) engine sounds: add kitsune (turbo I4), pixie (high-rev I3), goliath (deep V8) to
  `tools/audio/gen_engines.py` CARS + `_crackles` counts, then `tools/audio/build.sh --only engines`
  (EngineAudio falls back to kaze until then); (3) `Tuning` stat ranges (TOP_KMH_RANGE etc.) may need
  widening (tests/physics/test_tuning.gd prints observed ranges); (4) run physics tests
  (game/tests/physics/run_all.sh), test_rail (all cars), AutoDriver on every track with each new car
  (`--car=<id>`), garage screenshots; (5) merge into `main`.
- **Not started:** M6-4 better graphics (idea: Poly Haven CC0 HDRI skies, low-res for web too), M6-5
  export + deploy.
- **Pi deploy (done ~16:05 UTC):** `server/public` re-exported from `main` (LIVE + 4 maps) and the
  container restarted, so the live site runs LIVE and the new maps. Before that it served 5236df9. The Pi clone (`~/speedfest`) is on
  `main`; to ship LIVE + the new maps: `tools/export_web.sh`, commit `server/public`, push, then
  `docker restart speedfest` (the container runs `~/speedfest/server`, so the LIVE server code goes
  live with that restart). Node 20 is installed on the Pi now (server tests, smoke tests run there).
- nav_test's 2 menu-focus failures predate session 6 (fresh profile shows the name prompt).

## Latest (~13:50 UTC, session 5, orchestrating session on the owner's Raspberry Pi)

- **Textures are now CC0 scans from ambientCG** (Asphalt031, Concrete034, Metal038, Rock022),
  fetched by `tools/textures/fetch_cc0.py` (same file names; calibrated to the tuned means). 2K
  desktop sets in `game/assets/hd/textures/` (Forward+, quality ≥ 2; excluded from web). Details:
  docs/ASSETS.md, PROGRESS ~13:50 UTC. Cloud environments can't reach ambientcg.com: re-run the
  fetch script on the Pi (or anywhere with open internet).
- `server/public` re-exported with the scans (pck 8.4 MB) and live on the Pi. Verified in headless
  Chromium through the public URL: AutoDriver finishes Rail Rush at 6.55 s, 0 errors.
- Cloud session for this round is finished (idle). The orphan `web-build` branch (2133bb7) is an
  extra static copy of an older build; deleting it is the owner's call.
- The Pi can push to `main` (deploy key) and has Godot 4.7.2 arm64 + web templates.
- Still open from below: the compat brightness quirk (1×1-mip normalization), M5 visual tracks.
  Poly Haven HDRI skies for desktop (`assets/hd/hdri/`) would be the next "high quality" step.

## Latest (~13:30 UTC, session 5)

- **Done (on `main`):** M4.6-1 downtown rework around real buildings (`TrackBuildings`), generated
  PBR textures (asphalt/concrete/metal/rock, `tools/textures/gen_textures.py`), new short stadium
  map **Rail Rush** (`rails`: ledge jump → grind rail → finish platform; `TrackRail`,
  `tests/tracks/test_rail`), static web build on the orphan branch **`web-build`**
  (`tools/publish_web_build.sh --push`, docs/HOSTING.md "Static web build").
- **`server/public` re-exported (M4.6-4 done)** with everything above, per the orchestrating
  session: the owner's Raspberry Pi runs the repo's Node server from `main` (docs/HOSTING.md
  "D. Raspberry Pi"; update = `git pull && docker restart speedfest`). Verified: CHECK_ALL PASS,
  `online_browser_test.js` 2 clients PASS on this build, static build WEB_STATIC_PASS.
- The repo is PUBLIC: never commit secrets, hostnames or URLs of the Pi.
- `web-build` branch = static build of main@eac62e7 (2133bb7).
- Open: textures could be swapped for real CC0 scans (ambientCG/Poly Haven are blocked here; keep
  the file names). Why compat rendered textured albedo brighter in the full scene is unexplained
  (worked around with the 1×1-mip normalization). Rail Rush has no ghost-specific handling (ghosts
  replay transforms, fine). Online play on the static build needs the Node server.
- Next: M5 visual tracks (docs/M5_SPECS.md), sequentially.

## Latest (~11:30 UTC, session 4): STOPPED for the usage limit, continue here

- Done today (all pushed): M4.5 (all six owner items), M4.6-3 dark-trap music, M4.6-2 two ground
  sprints (Infield Rush, Dune Dash) with grass/gravel/sand physics, 5-card track select, lobby fix.
- **server/public is the safe build from 339825c** (no sprints, no music changes after it). It
  is still what's deployed; the sprints need a new export (M4.6-4).
- **Next: downtown rework (M4.6-1)**, only started: the builder parses `{"building": ...}` markers.
  The full plan is in docs/PROGRESS.md (~11:30 UTC entry). Then export (M4.6-4).
- Work sequentially (owner rule). Commit and push after every step.

## Latest (2026-10-15 ~10:30 UTC, orchestrator #4, session 4)

**Rule from the owner: no parallel sessions or subagents.** Work one item at a time and push
after each step (CLAUDE.md "Work sequentially").

**Done today on `main`** (owner feedback list = PLAN.md "M4.5"; details in PROGRESS.md):
1. Bumpy road fixed (twisting full-width deck quads made a washboard; deck now 8 cells across with
   finer rings on twists and 1 m rings in loops). `tests/tracks/test_road_smooth`.
2. HUD minimap removed. 3. Small checkpoint feedback + solid Trackmania-style checkpoint gates.
4. Compact tachometer; NOS is a fixed tank per run (no refill).
5. Stadium lawn instead of the neon grid, static menus (no grid, no spinning car), Rocket
   League-style live car lineup in the online lobby (`LobbyLineup`).
6. Tuning removed (garage + Profile). **Easy handling**: drift only when asked + hands-off stability
   assist, per-car character (`power_oversteer`, `yaw_damp`), `tests/physics/test_easy`.
Also fixed two regressions from session 3's handling pass (self-righting, fast wall-ride exits).

**Next:** re-run `tools/integration/check_all.sh`, export the web build (`tools/export_web.sh`),
run the browser online test, commit `server/public`. Then M5 (docs/M5_SPECS.md), sequentially.

- **Game night is tonight.** If the host uses Render with Auto-Deploy on, every push to `main`
  redeploys. Re-export `server/public` only with verified changes, and not late in the day.
- Web export now excludes `assets/hd/*` (desktop-only large assets).
- Still open: web frame rate on a real GPU, downtown length (~26 s), adversarial review.

---|---|---|
| cars | `visual/cars` | session_01U5u2g2MGdocygvQu5vrKc2 |
| world | `visual/world` | session_01VVtY7M5SnVMaLCbswNq3ku |
| frontend | `visual/frontend` | session_01CxwrXhBdpNbub4Uzv8brw7 |
| orchestrator #4 | `main` | session_01B2557cfMsCmUR7NCyj37k8 |

- The orchestrator merges `visual/*` into `main` after checks (order world → cars → frontend), and
  re-exports `server/public` only after the upgrade is verified on both renderers.
- **Game night is tonight.** If the host uses Render with Auto-Deploy on, every push to `main`
  redeploys. Don't push `server/public` changes to `main` late in the day unless they're verified.
- Web export now excludes `assets/hd/*` (desktop-only large assets).

Open items from session 3 (below) still apply: keyboard-emulation falls, downtown length, web
frame rate on a real GPU, and the adversarial review.

---

## Session 3 (2026-10-15 ~08:00 UTC, orchestrator #3)

**State:** branch `ccr-49301774-b5a4ns` has the **Trackmania-style rework of all three tracks**
merged (tracks + physics + scenery module branches). It also has the new **weather** system:
dry / rain / storm rounds with stage-designed puddles that cut grip (owner request; DESIGN §4.1,
docs/modules/weather.md). The web build in `server/public` is re-exported from this state.

- Gate: `tools/integration/check_all.sh`. Weather: `tests/weather/test_weather.tscn` (38 checks).
  Matrix: `[WEATHER=storm] game/tests/physics/run_real_tracks.sh` (analog bot 9/9 clean in default
  and storm weather; keyboard emulation 13/18).
- Online: `game/tests/race/online_round_test.sh 3 40 --autodrive --track=downtown --weather=storm` PASS.
- Lobby host picks track + length + **weather** (picking a track selects its signature weather;
  downtown = rain). Solo: AUTO/DRY/RAIN/STORM chips on the track select. PBs are per (track, weather).
- **`main` now has everything** (owner asked, ~08:10 UTC; fast-forwarded from `ccr-49301774-b5a4ns`).
  Work on `main` from here (or a branch merged back into it). Deploy from `main`.

**Open items (priority order):**
1. Keyboard-emulation falls (5/18 runs need 1–2 respawns). They're mostly at wall-ride exits and
   jumps entered at ~250+ km/h after boosts (outside physics' 140–215 km/h wall-ride envelope).
   Options: move or trim the boost before each wall ride, add a slight climb before the wall
   ride, or lower roll. `"clothoid": true` on a wallride segment was tried and was worse.
2. Downtown runs ~26–28 s, below the 35–45 s target (DESIGN §4). Add a piece (e.g. a second
   rooftop jump).
3. Real-GPU web frame rate is still unmeasured. The weather adds rain particles (CPU on web),
   spray and puddle meshes. Check with the perf probe on `--compat`.
4. Adversarial review of race/physics/tracks/weather never ran.
5. Housekeeping: the remote branch `integration/weather-trial` is a leftover backup (an ancestor of
   this branch). It's safe to delete; this environment's git proxy refused the delete.

---

# Earlier handoff (orchestrator #2, ~06:35 UTC), kept for history


The owner is near the account usage limit, so all agents stopped and recorded their state. This page
is the entry point for the next agent. Read it first, then `CLAUDE.md`, `docs/PLAN.md`, the end of
`docs/PROGRESS.md`, `docs/TRANSCRIPT.md` (owner requests, verbatim) and `docs/M1_SPECS.md` (all module
specs, plus the **"M3 rework"** section at the bottom).

## 1. What works right now (playable)

Branch **`ccr-49301774-b5a4ns`** is the integration branch. Every module is merged, and the web
build is committed in `server/public/`.
- Game: menus, garage (tuning + NFSU2 styling), 3 cars, 3 tracks, solo time attack (PB + ghosts +
  splits), online rooms (2–8 players, countdown, live leaderboard, results), HUD, synthesized audio.
- Tests: `tools/integration/check_all.sh` → **CHECK_ALL PASS** (compile, 24 suites, server 12/12,
  AutoDriver finishes all tracks, net smoke, 3-client online round). `game/tests/ui_menus/lobby_smoke.sh`
  PASS. The keyboard-player emulation finishes all 3 tracks with all 3 cars (0 respawns).
- Hosting: `docs/HOSTING.md` (Render.com step by step, `render.yaml` blueprint; or PC + Cloudflare
  tunnel). Deploy from this branch. **Turn off Render Auto-Deploy during game night** (a push
  redeploys and drops players).
- `main` is NOT updated (this session may only push to `ccr-49301774-b5a4ns`). Ask the owner before
  merging into `main`.

## 2. In progress: Trackmania-style track rework (NOT merged yet)

The owner wants **all three tracks Trackmania-style**, with the themes kept as the setting: floating
platform roads with open edges, big gap jumps, loops and wall rides, turbo pads (yellow boost, red
super boost), short 30–45 s tracks. Spec: `docs/DESIGN.md` §4 and `docs/M1_SPECS.md` → "M3 rework".
The current (old-style) tracks on the integration branch are the playable fallback until the new
ones pass.

State per module branch (each one's `docs/modules/<key>.md` has a "Handoff" section at the top with
details; check `git log origin/module/<key>` for the latest commit):

| branch | state at handoff |
|---|---|
| `module/tracks` | **New Pulse Arena** done (start-tower dive, yellow turbo, walled banked turn, red super boost into a loop, 75° wall ride, gap jump, half-pipe 180, final jump through the finish arch, ~1.47 km point-to-point). AutoDriver 31–39 s, 0 respawns, all cars. **Open:** the keyboard emulation falls off at the wall-ride exit for brute/veloce (roll ramp 62 m vs ~245 km/h entry after the super boost). The fix per physics' envelope is a roll ramp ≥ 100 m and entry ≤ ~215 km/h. **Update 06:42: tracks pushed new downtown and coast layouts too ("part 2", de1b225 or later).** Physics measured all 9 car×track runs: the analog AutoDriver finishes with 0 respawns (arena 32–37 s, downtown 25–27 s, coast 31–33 s). The keyboard emulation is clean on 4/9 and needs 1–2 respawns on the rest, mainly the wall-ride geometry (62 m roll ramp with the curve at full curvature from roll 0; exact spots and fixes in docs/modules/physics.md and tracks.md). Matrix script: `game/tests/physics/run_real_tracks.sh`. Downtown at 25–27 s is shorter than the 30–45 s target. New API: `track.kill_y_at(pos)` (race already uses it). Must also set `path.set_meta("ground_y", …)` and mark the "elevated" and "wallride" zones for scenery. |
| `module/physics` | Rework support done (wall rides, super boost capped at ≤ 60 m/s² for ≤ 4 s with a 450 km/h hard cap and no tunnelling, big jumps, AutoDriver full throttle in wallride zones). `game/tests/physics/run_all.sh` → PHYSICS_ALL_OK; new `test_wallride`. |
| `module/scenery` | Elevated-deck support done (props on the ground, nothing inside the deck or pillar volume, downtown towers above and below the deck, coast cliffs and sea under the deck). Needs a screenshot check on the new layouts. |

### How to finish the rework (next agent)
1. Resume the sessions with `send_message` (they keep their context; IDs below) or do it yourself.
   Tracks: fix the arena wall-ride exit, then build the new downtown and coast per DESIGN §4.
2. Integrate on a local scratch branch:
   ```bash
   git fetch origin
   git checkout -B trial ccr-49301774-b5a4ns
   git merge origin/module/physics origin/module/scenery origin/module/tracks
   tools/godot_import.sh && tools/integration/check_all.sh            # must print CHECK_ALL PASS
   for t in arena downtown coast; do for c in kaze brute veloce; do
     tools/run_scene.sh res://tests/physics/test_real_tracks.tscn --headless -- --track=$t --car=$c --keyboard | grep -E "RESULT|TEST_"
   done; done                                                          # 0 respawns everywhere
   tools/run_scene.sh res://tests/integration/perf_probe.tscn --compat -- --track=downtown --autodrive --frames=420 --shot=/abs/dt.png
   ```
   Look at the screenshots on both renderers (drop `--compat` for Forward+). On web, keep about
   ≤ 400 draw calls (perf_probe prints PERF lines).
3. If everything passes: `git checkout ccr-49301774-b5a4ns && git merge --ff-only trial`, then
   `tools/export_web.sh`, commit `server/public`, push. Update PLAN/PROGRESS.

## 3. Other open items
- An adversarial review of race, physics and tracks never ran: the workflow died on the usage limit.
  Two earlier reviews (networking; ui/audio/visuals) found and fixed 9 bugs, all covered by tests
  (`server/test`, `game/tests/integration/test_review_fixes`).
- Web frame rate is unmeasured on a real GPU (the containers have none). Compat render stats: arena
  ~165 draw calls, downtown ~190, coast ~310 at quality 1.
- Nice to have: README screenshots; merge to `main` (owner decision).

## 4. Sessions (all spawned by orchestrator #2; resume with send_message, they keep their context)
| module | session |
|---|---|
| orchestrator #2 | session_01FScTiQ4vwQQ8wktXzQJ6Ey |
| physics | session_01DrvZUyYAM3oczRVDW1o8Nf |
| visuals | session_012FyHiPM6GP1ACSFBLqmWJV |
| tracks | session_01XWgKiHbRtgKdaQBXSuzZm7 |
| scenery | session_019ZpoTQnjd2NsrKfAdGeECh |
| ui_menus | session_018sRqzobba64dP5Ld7SByiE |
| ui_hud | session_015JD5jMrvZQVTcVqfNyySq9 |
| audio | session_018yYJrBdZh6uuXVdUQqViJH |
| race | session_01UXTHDb9Svwh7v9CKVysey7 |

Module sessions push only to `module/<key>`. The orchestrator merges into `ccr-49301774-b5a4ns`.
Environment notes: `downloads.godotengine.org` may be blocked, so use the GitHub release mirror (CLAUDE.md).
Containers have only 4 CPUs (local workflows run 2 agents at a time), which is why modules ran as
separate cloud sessions.
