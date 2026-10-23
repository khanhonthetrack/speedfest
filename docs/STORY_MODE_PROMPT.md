# Prompt: build Story mode for SpeedFest Stadium

> Give this whole file to a fresh agent session on `khanhonthetrack/speedfest`, branch `stadium`.
> It is written to be self-contained: every path, command and known gap in it was checked against
> the repo on 2026-10-23 (commit `d29f8e4`, `stadium-v0.9`).

---

## 0. Who you are and where you work

You are continuing **SpeedFest Stadium**: a TrackMania Nations Forever-style time-attack racer
rebuilt in Godot 4.7.2 (Forward+), with its own tracks, its own 16 road cars + hypercar, TMNF's
real car physics, a neon night City and a Sky series. Work in `stadium/`, on branch **`stadium`**.
Target is the owner's PC (Forward+, strong GPU); the web build is no longer a constraint.

**Read before you write a line of code or story:**

1. `CLAUDE.md` (repo root) and `stadium/CLAUDE.md` — rules, gates, "work sequentially", commit format.
2. `docs/HANDOFF.md` (top section) — current state; `docs/PLAN.md` — milestones; `docs/PROGRESS.md` — the log, append to it.
3. `stadium/README.md` — layout, "Make a track", "Sky maps", run commands.
4. `docs/TRANSCRIPT.md` — the owner's words, verbatim. **Session 11 is the story-mode pitch.**
5. **`docs/STORY.md` on the unmerged branch `origin/ccr-be8add6f-thdbey`** — a complete 671-line
   story draft ("Rear View") written for this exact request and never built:
   `git show origin/ccr-be8add6f-thdbey:docs/STORY.md`. Read it in full. It already solves the
   cast, the twist, the decision model and the ending. It is docs-only; nothing of it is in code.
6. `docs/ASSETS.md`, `stadium/assets/city/CREDITS.md` and `stadium/assets/anim/CREDITS.md` — the
   licence rules you must obey.
7. `docs/ANIMATIONS.md` — the four humanoid animation packs the owner gave the project on 23 Oct
   (the first character material in a repo where everything else is procedural).

This is the owner's biggest feature request so far. Expect it to take many sessions. Work one item
at a time, commit and push after every meaningful step (the owner has lost unpushed work to usage
limits before), and leave `docs/HANDOFF.md` good enough that another agent can take over mid-chapter.

---

## 1. The owner's request, verbatim

> This is a big project - the goal will be to implement a story mode (currently locked). IT should
> be based in the city, at night, dark, neon (basically the city maps
>
> 1. Generate a script, a story. I want it to be cinematics, with cinematic cutscenes. I imagine 10
> Chapters. But just like non-linear books, we want the story to make sense whatever the order,
> chosen by the player. HOW? as follows.
> 2. In each chapter there will be three tracks from Trackmania, a players has to beat gold (the
> gold time is set based on difficulty level picked by the player at the beginning) to move
> forwards. IN the third track, the map has a few finish lines ( 3 or 5 or whatever), which dictates
> to which chapter to go into.
> 3. IN-between tracks, or when chapter starts or ends, design game cutscenes which tell the story.
> it should be cinematic. should be dialogue-based, not just a few sentences. ( we start with
> subtitles, no voices).
> 4. technicalities: I know you suck doing cutscenes, humans etc. So, first: look for realistic
> assets. BlendSwap, itch.io, or if we already have assets in the repo.

Append this to `docs/TRANSCRIPT.md` if it is not already there, and treat it as the spec of record.

---

## 2. What already exists — build on it, do not reinvent it

**The night city is built.** `"scenery": "city"`, `"mood": "night"` in a track spec gives you towers
around the road (`env/tm_skyline.gd` `TmSkyline.field`), real buildings from Blend Swap
(`stadium/assets/city/`, `env/tm_city_assets.gd`), neon barriers and tubes (`env/tm_neon.gd`),
street lights, searchlights, LED screens, an airship, wet asphalt + AgX + glow + fog + SDFGI/SSR
(`TmStadiumEnv.city`), traffic streaks (`env/tm_traffic.gdshader`). Existing City tracks:
`stadium/tracks/F01..F05.json`. The Garage/Tuning turntable already stands in that city
(`TmMenu._use_city`, `CITY_PAGES`).

**Tracks are JSON piece lists.** `stadium/tracks/<ID>.json`, pieces documented at the top of
`race/tm_track_builder.gd` and in README "Make a track". Medals are written by the bot:
`tools/run.sh res://tests/test_tracks.tscn --headless -- --tracks=<ID> --write_medals`
(it sweeps grips, takes the best, writes `"medals"` + `"bot_grip"` into the JSON). Today's ratios,
in `tests/test_tracks.gd` `medals()`: **gold = author × 1.06**, silver × 1.2, bronze × 1.5.

**Multiple finishes already half-exist.** `["fork", "l"|"r", [pieces]]` (a T junction, a second way
to its own finish after the last checkpoint) and `["split", "l"|"r", [pieces]]` (a second line off a
wide rooftop at speed) build alternate ways; `TmChallenge.alt_paths` carries them; `tests/test_tracks`
drives every way and the fastest sets the medals (Sky maps G06, G08, G10 use this).

**Cutscene staging already half-exists.** `tools/icons/menu_art.gd` + `menu_art.tscn` is a working
cinematic rig: it builds any track with its mood, stands any number of cars (model, livery, tuning,
underglow, ghost) on the road at a fraction `--at` of the racing line, then places a camera in the
lead car's frame with `--cam`, `--look`, `--fov`, `--roll`, `--dof=far,transition,amount` and a
`--sun=azimuth,elevation`, and screenshots it. `tools/icons/menu_art.sh` already contains a
**Story** shot: the Nemesis GT in Black Ops, wet City night, F04. That is your cutscene camera
system's starting point — generalise it into something that animates over time instead of posing
one frame. Also read `race/replay.gd` (chase/close/cockpit/trackside/free cameras, seek, speed) and
`race/tm_stage.gd`.

**Cars as actors.** `car/tm_car_visual.gd` (`TmCarVisual`) draws the open-wheeler, the hypercar and
the 16 road cars (`car/tm_road_cars.gd`), each with 5 liveries, tuning (spoiler/rims/hood) and
underglow (`car/tm_underglow.gd`). `car_lab.tscn` previews one.

**The Story tab exists and is locked.** `ui/sf_header.gd` (`TABS`, `LOCKED := ["story"]`, tooltip
"Story mode is on its way"), `ui/tm_menu.gd` (`LOCKED_NOTE`, `_page_main`'s story tile, badge
"Coming soon", `PAGES`), picture `assets/ui/menu/story.jpg`. `tests/test_menu.gd` asserts it is
locked — that test must be updated in the same commit that unlocks it.

**Saving.** `user://settings.cfg` (`TmUi.SETTINGS_PATH`), `user://records` (`TmRecords`),
`user://replays`, `user://tracks`. Tests override them with `--settings=`, `--records=` etc. Follow
that pattern for story saves so the gate never touches the owner's own progress.

**Characters are now possible (new, 23 Oct).** `stadium/assets/anim/ual/` holds Quaternius'
**Universal Animation Library** under CC0: 43 clips on a 65-bone Unreal-style rig, plus a
13,744-triangle Mannequin 1.83 m tall, in two builds (`ual_standard.glb` on the spot,
`ual_standard_rm.glb` with root motion baked). It loads in Godot 4.7.2 as it is: no retargeting, no
Blender. The owner also has three more packs (188 clips: Human Basic Motions, Motifect Emotes &
Social, Motifect Daily Life) which **may be used in the game but not committed to this public
repo** — `tools/anim/stage_packs.sh <dir with the zips>` puts them back on any machine, and
`tools/anim/manifests/*.json` holds their full inventories so you can plan without them.
**Read `docs/ANIMATIONS.md` before you touch any of it**: it is the study of all four packs (which
clips are usable, which lie about what they do, the three rigs' bone maps, and the traps — e.g.
Motifect's `LeftLeg` is the thigh, not the calf). What is missing: any clothed character mesh of
our own, any facial rig, any lip sync. The Mannequin is a grey stand-in, not a cast.

**Look and sound.** `ui/sf_ui.gd` (charcoal, red + violet accents, Montserrat) is the menu look —
subtitles and chapter cards must wear it. `audio/tm_music.gd` (playlists, fades),
`audio/tm_sounds.gd`, `audio/tm_car_audio.gd`, `audio/music/CREDITS.md`.

### Known gaps you will have to close (verified, not guesses)

| Gap | Where | What is needed |
|---|---|---|
| A finish does not say **which** finish | `race/tm_race.gd` emits `finished(time_ms)` only; `race/tm_triggers.gd` has no gate identity | `TmRace` must record which finish gate was crossed (index/name), pass it through `race.gd` `_on_finished`, the result dict, the record and the replay header |
| One medal set per track | `gbx/tm_challenge.gd` (`gold_ms` …), `tracks/*.json` `"medals"` | Per-finish medal times for branching maps (`test_tracks` already drives every way — extend `_write_medals` to write a set per branch) |
| No difficulty | nothing in the codebase | A difficulty chosen once at the start of a story save, scaling the gold target off the bot's author time |
| No dialogue / subtitle / cutscene system | — | A new `stadium/story/` module (below) |
| No story save | — | `user://story.json` (or a `--story_save=` override for tests) |

---

## 3. Step one: the script. Write it before you build anything.

Deliver `docs/STORY.md` (replacing/absorbing the "Rear View" draft from
`origin/ccr-be8add6f-thdbey`) and get the owner's sign-off **before** authoring 30 tracks.

### Constraints from the owner

- **Setting:** the city, at night, dark, neon, wet. Everything happens on City-style maps. (The old
  draft ended on a golden coast road at sunset — that is now out of setting; either move the finale
  into the city or put the change to the owner explicitly.)
- **10 chapters**, 3 time-attack maps each.
- **Non-linear:** the story must make sense in any order the player reaches the chapters.
- **Cinematic, dialogue-based.** Not a few sentences — write real scenes: 20-40 spoken lines per
  scene, 3-6 scenes per chapter (chapter open, between map 1 and 2, between 2 and 3, chapter close,
  plus a decision scene on the branching map). Subtitles only, no voices — but write it as if it
  will be voiced, with speaker names and line IDs, so voice can be added later.

### How to make ten chapters read in any order (the hard part — solve it explicitly in the doc)

Use a **knowledge-flag model**, not a timeline:

1. **Every chapter is one self-contained night.** It has its own location, its own antagonist or
   confidant, its own three maps, and it ends on a decision. Nothing in it depends on having played
   any other chapter.
2. **No chapter may say "earlier" or "later" about another chapter.** Dialogue never references
   another chapter's events as sequence — only as *knowledge*. Internally every revelation is a
   flag (`knows_twin`, `knows_lena_is_wife`, `pushed_hammer`, …).
3. **Facts are commutative.** Each chapter delivers exactly one hard fact and one new ambiguity.
   Any 10! ordering still assembles the same complete picture, because the facts never contradict,
   only accumulate. Write the fact table first (10 rows: chapter → fact given → flags required: none).
4. **Three-tier dialogue.** Author each beat in three variants selected by *how much the player
   already knows* (count of flags / specific flags), never by chapter index: **cold** (knows
   nothing), **warm** (knows some), **hot** (knows most). The same scene plays as introduction or as
   confirmation depending on where the player arrives from. This is what actually makes the
   non-linearity work; budget for it in the writing (it roughly doubles the line count).
5. **A frame that licenses the shuffle.** Pick one and state it in the doc: a night-radio host
   telling the city's story out of order; a police impound interview; the main character's own
   memory, which refuses to run in a line. (The old draft's Memento conceit survives here: it is
   shuffled memory rather than strict reverse.)
6. **A gated finale.** One chapter (the last night) is not reachable by branching: it unlocks when
   N of the other chapters are done (propose N = 8 or 9, ask the owner), and reads the flags to pick
   the ending. The owner's original ending stands: you beat the final boss, a cutscene where you
   push them, they crash, you walk over, they are dead, you take car X and drive away — and which
   of the three endings you get (collector / family / lost everything) comes from the decisions.
7. **The decision model from the old draft is good; keep it.** "The dark line is the fast line":
   wherever the branch means hurting someone, that line is shorter, tighter and more dangerous, so
   the temptation sits in the stopwatch. Decisions never change what you have already seen — they
   decide what it *meant*.

### The branching map (map 3 of each chapter)

- 3 to 5 finish gates on the third map. The gate your accepted run crosses is both **the decision**
  and **which chapter you go to next**.
- Design the graph so that: every chapter is reachable, there are no dead ends, no chapter is
  forced twice, and a player who has already seen the destination chapter is routed to an unseen one
  (fall back to a "chapter select" when every exit of a map is exhausted). **Write an automated test
  that proves this for all orderings** (see §6).
- Each gate needs its own gold time, so no branch is free.

Also decide and write down: how the player picks a chapter when the graph runs out, whether the
Story page shows a map of what they have seen ("the board"), and what carries over between chapters
(car X, cars won from bosses, the journal of known facts).

---

## 4. Difficulty

Chosen once when a story save is created (ask the owner whether it can be changed later):

- gold target = bot author time × a multiplier per difficulty. Today's campaign gold is author × 1.06.
  Proposed, for the owner to approve: **Cruise ×1.30, Street ×1.18, Racer ×1.08, Saint ×1.00**
  (the last meaning you must match the bot's author run).
- Medals for a story track are generated once by the bot, per finish gate
  (`test_tracks --write_medals`); the difficulty multiplier is applied at runtime against the stored
  author time, so difficulty costs nothing to add later and nothing to re-render.
- The HUD must show the target you are chasing and the delta to it, as the campaign already does
  against the record ghost. The medal ghost (`race/tm_medal_ghost.gd`) is the obvious opponent to
  put on a story map.

---

## 5. Cutscenes: how to build them with no human characters

The owner's warning ("I know you suck doing cutscenes, humans etc.") predates the animation packs
that landed on 23 Oct, so the honest position is now: **full-body human acting is on the table,
faces are not.** You have 43 CC0 clips and a Mannequin in the repo, 188 more clips the owner can
stage, a city, cars, rain, neon, lights and text. What you do not have is a face rig, lip sync, or a
character mesh that looks like a person in this game's world. So: stage people in full body and in
silhouette, and let the subtitles carry every word. The reference is the NFS Underground 2 intro,
*Drive*, *Collateral*, *Blade Runner* — bodies, headlights and rain, not close-ups of faces.

### Shot grammar (write the scenes so they are shootable with what exists)

- The car is the character: idling, arriving, leaving, refusing to start, a door closing, a rival
  pulling alongside, headlights filling a mirror.
- Cameras do the acting: slow dolly along a wet flank, a crane up from the road to the skyline,
  a long lens through rain on glass, a reflection in a puddle, a security-camera angle with its
  timestamp, a dash view with wipers.
- People act with their bodies, never their faces: someone walking away from a car in the rain,
  leaning on a door, throwing keys, turning their back, sitting on a kerb, a crowd at a start line.
  Keep the camera at body distance or further, backlit, in rain, behind glass or in silhouette;
  cut **on** a gesture, never hold on a head. The UAL clips cover idle, walk, run, sit, point, wave,
  cheer, die and more (see `docs/ANIMATIONS.md`); the owner's staged packs add daily-life and
  social emotes. **Lines appear as subtitles with the speaker's name** — that is the owner's
  accepted convention, so a speaker whose face you never see is the style, not a compromise.
- Where a body would hurt the shot, use what the city gives you: a silhouette behind a lit window, a
  phone screen filling the frame, a message thread, a voicemail waveform, a photo on a dashboard,
  the headlights of a car that drives away.
- Let environment carry emotion: rain intensity, neon colour, fog, the city's traffic streaks,
  music cues (`audio/tm_music.gd`), the wet shader, the moon.

### The system to build (`stadium/story/`)

Suggested shape — adjust to taste, but keep it **data-driven, deterministic and headless-testable**:

- `story/story_graph.gd` (`StoryGraph`): chapters, their 3 tracks, their exits (gate → chapter),
  unlock rules; loads `stadium/story/story.json`.
- `story/story_state.gd` (`StoryState`): the save (`user://story.json`, `--story_save=` override):
  difficulty, chapters completed, decisions, flags, times, which car you drive.
- `story/story_scene.gd` (`StoryScene`): plays one cutscene from data.
- `story/scenes/<chapter>_<beat>.json`: a scene = ordered **shots** (track + `at` or a free world
  position, camera keyframes with position/look/fov/roll/dof over time, easing, environment
  overrides: mood, rain, fog, neon, time of night; actors = cars with model/livery/tuning/underglow
  and a motion (parked, drive-by along the line at speed v, arrive, leave); **characters** (mesh,
  clip from the library, loop or one-shot, position and facing, root motion on or off); props;
  music cue) and
  **lines** (`id`, `speaker`, `text`, `at_ms`, `hold_ms`, optional `if` flag conditions, optional
  `set` flags). Keep text in one place per scene so a translation/voice pass is a file swap.
- `story/story_subtitles.gd`: SfUi-styled subtitle plate (speaker in accent colour, generous size,
  safe-area margins, letterbox bars), skip (hold a key), replay-from-the-journal, and a
  "cinematic" letterbox + DOF + no-HUD mode.
- `story/story_lab.tscn`: preview one shot or one scene and screenshot it
  (`tools/run.sh res://story/story_lab.tscn -- --scene=c01_open --t=4.2 --shot=/abs/out.png`),
  so you can *look* at every shot with the Read tool before the owner ever sees it.
- `tools/story/render_scene.sh`: render a scene to a sequence or a short video for the owner.

Rules that keep it maintainable: cutscenes never block on physics; a scene must be skippable at any
frame and resume the flow correctly; nothing in a cutscene may change the race's deterministic
simulation; every scene must play headless at `--fixed-fps 60` for the test gate.

---

## 6. Assets: look first, record the licence always

The owner asked you to look for realistic assets before building anything by hand. **Licence
discipline is a hard rule in this repo** (`docs/ASSETS.md`, `stadium/assets/city/CREDITS.md`):
CC0 / CC BY / owner-given only, every file listed with source + author + licence **in the same
commit that adds it**, nothing from Nadeo, and the owner's untracked `assets/` folder at the repo
root is never committed.

Where to look, in this order:

1. **Already in the repo** — 50+ city buildings (`assets/city/`: sky, sky2, hotel, rt, blade sets),
   street lamps and traffic lights (`assets/city/props/`), CC0 PBR scans from ambientCG, CC0 HDRIs
   from Poly Haven, 16 road cars + hypercar, the fonts. Most of a night city is already there.
2. **BlendSwap** — this session has MCP tools (`search_assets`, `get_asset`, `download_asset`; 7
   free downloads a day, then credits). Licences there are *declared by the uploader and not
   verified*, so read and show the licence before relying on a file, and put it in CREDITS.md.
   `tools/assets/blend_to_glb.py` already converts .blend → per-object .glb (it is how the city
   buildings got in).
3. **itch.io, Kenney, Quaternius, Poly Haven, ambientCG, Sketchfab (CC0/CC-BY filter)** — for props,
   signage, interiors, rain and light textures.

What is worth looking for: **clothed character meshes on a rig the UAL clips can drive** (the
cast: a mechanic, a woman in a coat, four rival drivers, a child — Quaternius' own character packs
are CC0 and share the rig's lineage, which makes them the first place to look), wet-asphalt and
puddle materials, rain/droplet and dirty-glass textures, neon sign alphabets and shop fronts, a
garage/workshop interior, a bar interior, dumpsters, fences, cables, fire escapes, parked city cars
for background traffic, and night-city HDRIs. A character mesh that does not look right is worse
than no character: if you cannot find one, keep the people in silhouette and shadow, which the shot
grammar above is built for. Decimate to the budgets `blend_to_glb.py` already uses, dress with our
own materials where it helps, and keep the PC/Forward+ frame budget in mind.

---

## 7. Build order — one milestone at a time, each gated, committed and pushed

Open it as **PLAN M20** with these steps (renumber if the plan has moved on):

1. **M20-1 Script.** `docs/STORY.md`: premise, cast, the fact table, the 10 chapters with their 3
   maps and their exits, the decision graph, the three endings, every scene listed with its beats.
   Plus `docs/STORY_SCENES.md` or the scene JSONs themselves with the **full dialogue**. Show the
   owner; get sign-off before M20-4.
2. **M20-2 Data + save.** `StoryGraph`, `StoryState`, `stadium/story/story.json`, difficulty;
   `tests/test_story_graph.gd`: every chapter reachable, no dead ends, no orphan exits, the finale
   gates correctly, a 10,000-random-walk simulation always finishes.
3. **M20-3 Cutscene player.** `StoryScene`, subtitles, letterbox, skip, `story_lab.tscn`; one real
   scene (chapter 1 opening) rendered and screenshotted at Ultra. Show the owner the stills early —
   the look needs their verdict before you write 40 scenes.
4. **M20-4 Branching plumbing.** `TmRace` reports the finish gate; per-gate medals in the track
   JSON and in `TmChallenge`; `test_tracks --write_medals` writes a set per branch; records and
   replays carry the gate; the finish menu shows which decision the held run makes, and CONTINUE
   locks it in.
5. **M20-5 Chapter 1, end to end.** Three city-night maps (`tracks/H01..H03.json`, ~20-45 s each,
   `"scenery": "city"`, `"mood": "night"`), bot medals, 4-5 cutscenes, a 3-way branching map 3, the
   decision saved, the next chapter chosen. This is the vertical slice: play it, screenshot it,
   show the owner, adjust the formula **before** mass production.
6. **M20-6 Story menu.** Unlock the tab (`sf_header.gd` `LOCKED`, `tm_menu.gd`), a Story page in
   SfUi: new save / continue, difficulty picker, the chapter board (what you have seen, what it
   told you), the journal of known facts, replay a cutscene, your times per map. Update
   `tests/test_menu.gd` in the same commit.
7. **M20-7 Chapters 2-9**, in batches of two or three: tracks → medals → scenes → exits → gate →
   commit → push → PROGRESS. Keep a running screenshot gallery for the owner.
8. **M20-8 The finale and the endings:** the final boss, the push-and-crash cutscene, the three
   endings from the flags, the secret ending if you keep it, credits, and a full-game headless
   playthrough test (every ordering class, every ending reachable).

Track IDs: use **`H01..H30`** (A-G are taken). Keep them **out of `tracks/campaign.json`** so Solo
and the online rotation are unchanged; list them in `stadium/story/story.json` instead, and set
`"online": false`. The bot must be able to drive every one of them, including every branch — that is
what generates the medals and what proves the map is finishable.

---

## 8. Definition of done for every commit

```bash
# the gate (must print STADIUM_TESTS PASS)
OUT=$(TMNF_DIR=/tmp/tmnf/tmnf/app stadium/tools/test_all.sh 2>&1); echo "$OUT" | grep -q "STADIUM_TESTS PASS" && git commit ...
# a new story track, laid out, built, driven, medals written
stadium/tools/run.sh res://tests/test_tracks.tscn --headless -- --tracks=H01 --write_medals
# look at it (screenshots are your eyes)
stadium/tools/run.sh res://race/map_view.tscn -- --track=H01 --view=path:0.3:14:5 --frames=60 --shot=/abs/out.png
stadium/tools/run.sh res://story/story_lab.tscn -- --scene=c01_open --t=4.2 --shot=/abs/out.png
```

New tests to add to the gate: `test_story_graph` (reachability, no dead ends, endings),
`test_story_scenes` (every scene loads, every line has a speaker, every flag referenced is set
somewhere, every scene plays headless to its end, no missing asset), `test_story_save` (save/load
round-trip, difficulty applied, decisions persisted), and the branching cases in `test_tracks`.

Every commit: `story: <what>` (or `tracks:` / `ui:` as the module demands), gated, pushed to
`stadium`, with `docs/PROGRESS.md` appended and `docs/HANDOFF.md` + `docs/PLAN.md` updated. Record
new owner messages verbatim in `docs/TRANSCRIPT.md`. Do not open a pull request unless the owner
asks. Do not run parallel sessions or parallel subagents (owner's rule).

---

## 9. Put these to the owner early — they change the work

1. **Reuse "Rear View"?** The unmerged `docs/STORY.md` is a finished 10-chapter thriller built for
   this request (twin brothers, the stolen identity, car X, pink slips, three endings). Adapt it to
   the city-at-night setting and the any-order structure, or start a new story?
2. **The ending's setting.** The old draft ends on a coast road at sunset. The owner now says the
   whole mode is the night city. Move the finale into the city, or keep one non-city map as the
   exception?
3. **How free is the order?** Pure branching (the gate you cross is the only route), branching plus
   a chapter board you can pick from once a chapter is cleared, or fully free from the start?
4. **The finale.** Unlock after how many chapters — 8, 9, or all 10 others?
5. **Difficulty names and multipliers**, and whether it can be changed after a save is started.
6. **Branch count:** 3 gates per branching map everywhere, or 3 in some and 5 in others?
7. **Carry-over:** do cars won from bosses change which car you drive in later chapters (it affects
   every medal time), or is the car fixed per chapter for fairness?
8. **Characters:** may the three non-CC0 animation packs ship inside the build (the two Motifect
   ones are the easy case)? And do they want a proper cast modelled, or people kept in silhouette?
9. **Scope check:** 30 new maps + ~40 cutscenes is many sessions of work. Confirm the order of
   delivery (vertical slice first) and whether the owner wants to play chapter 1 before the rest is
   written.

---

## 10. The bar

The owner's taste, from the whole transcript: dark, neon, wet asphalt, violet and red, minimal
panels, real cars, no fake sponsors, no placeholder slop. They look at screenshots and they say when
something is "really just a coloured rectangle". So: look at every shot you make before you ship it,
show stills early, and make the cutscenes feel like the opening of a film — a camera that knows what
it is looking at, a city that is doing something in the background, and dialogue with enough room to
breathe that a player reads it and wants the next chapter.
