# Night 1's cutscenes: the cinematic bar, the plan and the quality gate

Written 2026-10-27 after the owner's take-four answers (`docs/TRANSCRIPT.md`): "I want cinematics too
look good like in Call of Duty games or Need for Speed cutscenes. This is amateur. ... Why is the
review not picking this up? I want full cinematic style hollywood cutscenes."

Four critics (camera and editing, look, performance, sets) took take four's clips apart frame by
frame against that bar; a planner ranked the fixes. This file is the result and the rule book for
every take from now on. The script itself stays in `docs/NIGHT1_SCRIPT.md`.

## The verdict on take four
Take four looks like an engine blockout with subtitles.
- **Cutting.** The Mirror and the knock each cut between two locked-off cameras at the start of every
  line, like a sitcom (the Mirror: all 15 shots from 2 cameras; the knock: 12 cuts between two that
  drift 1-2 cm). Shots run a steady 3-4.5 s. The "camera moves" are zooms inside the shot: the
  Mirror's `she_is_there` and `head_comes_up` zoom into the ghost for about 5 s (the owner's note).
- **Light.** Nothing is lit on purpose. The yard is a pale, dry, tiled plaza under two flat spots;
  faces get small lavender or blue fills; nothing falls off into darkness. The yard reads as "a city,
  then empty space with containers" because it is containers on a cleared city square (`"bare"`
  hides only the blocks, road decals and neon lights).
- **The intro** spends 15.5 s in the air, two shots looking straight down at bare ground and a
  toy-sized block of containers. The yard wide is a security camera (10 m up, 6.5 s, nobody wants
  anything). Kit is never introduced. The five Lot 47 shots are one shot five times (a slow creep at
  fov 34 to 25, about 4.2 s each).
- **Bodies.** Poses come straight from clips and touch nothing. Dee is folded 76 degrees at the hips
  with her nose 25 cm from Kit's, waving Stand_Talk's arms (the owner: "standing weirdly"); Kit sits
  frozen at rate 0.
- **Finish.** No grain, vignette, grade or motion blur: clean CG.

**Why the reviews missed it:** they checked the clips against the script and the scene data, never
the picture against a bar. The quality gate below fixes that: a per-shot checklist, stills before
renders, and a critic who did not build the scene.

## What this stack cannot reach, and the substitute
- **Performance capture, lip sync, voices.** Faces look like mannequins in close-up. Keep faces at
  medium close-up or wider, half in shadow, held 1.5 s at most; let inserts (hands, eyes in the
  mirror) and sound carry the emotion.
- **Hair and cloth simulation.** Backlight people; use silhouettes.
- **Motion blur** (Godot 4.7 has none). Render moving shots at 96 fps and blend sub-frames with
  ffmpeg `tmix` (a 180-degree shutter), on driving shots only.
- **Real lenses** (anamorphic bokeh, flares). A streak on glow, vignette and a slight barrel
  distortion in a post shader.
- **Hand-dressed sets.** Dress only what the lens sees; long lenses, fog and darkness hide the rest.
- **About 14 s a frame on 4 cores.** Block every shot as stills first; render the final once.

## First pass (in this order, each gated and committed on its own)
1. **Film finish** (high gain, small effort). A full-screen post shader in `story_subtitles.gd`
   under the bars: grain 2-3% seeded by frame number (renders stay deterministic), vignette 0.25,
   halation, colour fringing under 1 px at the edges, a slight barrel distortion, a streak on
   headlights. A scene key `"grade"` builds a 3D LUT for `Environment.adjustment_color_correction`:
   teal shadows, warm highlights, blacks lifted to about 0.02, highlights that roll off.
   Check: before/after stills at the same times; no pure black pixel; edges darker than the centre.
2. **Camera engine** (high, small), in `story_scene.gd`'s camera code: `"handheld": deg` (seeded
   noise rotation 0.2-0.5 degrees at 0.5-1.5 Hz instead of the sine-wave shake), `"dof_near"`
   (foreground blur, so pull focus and soft foregrounds are possible), `"path": "spline"` (one ease
   over the whole shot instead of a stop at every key). Documented in the file header and README.
   Check: `seek(t)` gives the same camera every time; a still pair showing a pull focus.
3. **A dark, wet docks set** (high, medium). `"bare": "set"` also hides the field city and the map's
   ground. New `StoryProps` kinds: `quay` (world-space wet asphalt, albedo 0.06-0.10, roughness 0.05
   in puddles, yellow bay lines, a concrete edge, bollards), `water` (near black, 2 m below the edge,
   so screen-space reflections smear the lights across it), `sts_crane`, `stage`/`truss`,
   `portacabin` ("PELL SALVAGE"), `fence`, `barrel` (a fire with a flickering light), fog. Masts go
   sodium (`#ff9d3c`) with black between the pools; one soft cool backlight over the auction. The
   same ground under the arch. Check: no tower within 150 m of the yard unless across water; unlit
   ground under 0.05 brightness; lamps reflected in the ground.
4. **The Mirror re-cut** (high, small), `c01_close.json`. `she_is_there` 1.4 s at a fixed fov 26,
   the ghost only in its last 0.5 s, half lost in glare; `head_comes_up` deleted. Then Kit's eyes in
   extreme close-up (0.8 s), the look back as a body move (spine to head, a hand off the wheel), the
   empty seat (0.8 s), the hit (0.5 s). New angles: tracking outside the car, Kit in profile through
   the passenger window, headlights growing in the rear window, the white coupe low on a long lens.
   Shots shorten towards the whiteout (3.5, 2.5, 1.5, 0.8 s); exposure ramps 1 to 8 over 0.4 s with
   the 2D flash for the last 2 frames only. The ghost unlit but for passing sodium sweeps, 2-3 stops
   darker than Kit, never face to face with Kit in one frame. Check: the ghost on screen 1.5 s or
   less in total; no zoom inside a shot; at least 6 camera setups.
5. **The knock re-blocked and re-lit** (high, small to medium). Dee crouches (or hinges 25 degrees
   at the hips with a forearm on the roof), eyes at Kit's eye height, head outside the window line;
   a `_splice(lower, upper, bones)` in `story_cast.gd` so the crouch can carry talking arms. Kit
   breathing (Sitting_Idle at rate 0.5), a hand off the wheel, a start on waking. An insert of the
   knock from inside (knuckles sharp, Kit soft). Coverage: a two-shot at fov 40 for the first two
   lines, singles tightening from 32 to 26, a 0.1 m push on "I saw her in the mirror", cuts to the
   listener 0.4 s before a line ends, about 4 fewer cuts. Dawn ("Gone six"): blue hour, a cool key
   from the arch's mouth, a warm rim on Dee, a kicker on Kit, the underglow dimmed. The pins insert
   at fov 22, the screen three times brighter, a 3 s push; the arch shot craning from 6 m to 1.4 m.
6. **The intro re-cut** (high, medium), `c01_open.json`, to about 32 s: the city 4 s skimming a
   rooftop edge (roll 4 to 0, title in the left third, never straight down); a 3.5 s pass down a
   container canyon 6-8 m up at fov 30 in height fog; the yard wide at 1.6 m with the crowd's backs
   soft in the foreground; Gus in medium close-up (2 s) on the stage; Kit in medium close-up (2 s);
   Lot 47 in four different moves of 1.5-2.5 s (a low slide along the flank, a wheel close-up with a
   pull focus, a 25-degree orbit, a hero push-in under a sweeping spot), with a reflection probe and
   softbox strips the camera cannot see; a crowd of 10-12 in groups with heads turning to the bidder.

## Second pass
The critic's rounds on take five put these first (they cap every shot near 4-5 of 10): Gus's hi-vis
vest (a balloon: refit it to the hoodie, or a dark rain shell with two reflective bands), Lot 47's
livery (pixel camouflage, which the dialogue calls hand-painted: organic brush shapes, a pinstripe),
the underglow (a slab poking out of the bumper: inset it and pool the light on the ground), the number
plate, the container walls (corrugation, doors, rust, stencilled codes), the towers seen from the air
(no stars over rain; more lit windows, aviation lights), the ghost's hair (rough, clumped, not a
glossy helmet). Then:
Fear blend shapes in `tools/cast/blender/gen_char.py` (`eyeWide*`, `browOuterUp*`, `mouthStretch*`,
`mouthPress*`) and `build.sh`; motion blur on driving shots (96 fps + `tmix`); 1080p renders; the
Halloran bridge for the aerial and the dream, a moored ship; the car's interior (headrests, visors,
belts, the satnav's bezel); Arch 9 dressed as a workshop (pit, bench, pegboard, engine stand); hair
(SpringBoneSimulator3D, an anisotropic shader); container detail (door rods, corner castings, grime).

## Calls made (the owner's standing rule: "just write it")
- **Voices.** Not now: the picture has to pass first. Lines are cut short and long ones play over
  the listener. A voice later means a text-to-speech model with a clear commercial licence or
  recorded actors, with lip sync from the audio (Rhubarb, MIT). The owner picks the voice source.
- **Textures.** A small, listed set of CC0 PBR textures (Poly Haven, ambientCG: asphalt, concrete,
  steel) is allowed under the licence rule (CC0 / CC BY, credited in a `CREDITS.md` beside them),
  only where a procedural shader looks worse. Procedural first.
- **New motion.** Try the crouch/hinge with contact first; markerless capture only if Dee still
  reads wrong.
- **Render budget.** 1080p and motion blur on the driving shots only (2-4 times their cost).
- **Night 1 ships only after every shot passes the gate below.**

## The quality gate (every take, every shot)
Each item passes or fails; the scorecard goes with the take.
1. The subject reads within 0.5 s.
2. Foreground, middle and background layers.
3. The light has a source in the scene; faces key-to-fill 3:1 or more; the background falls off.
4. The camera moves for a reason; no zoom inside a shot (fov change over 3 with the camera moving
   less than 0.1 m).
5. The shot is no longer than its beat; shot lengths in a scene vary (standard deviation 1 s or more
   where the scene has more than 4 shots).
6. No more than 4 cuts in a row between the same two cameras.
7. Eye lines meet; hands, feet and seats touch what they should; nothing passes through.
8. No track pieces show (barrier neon, the tile grid, checkpoints) and no set edge.
9. Faces in close-up held 1.5 s or less; the ghost on screen 1.5 s or less in total.
10. Blacks at 0.02 or above; highlights roll off.

Procedure:
1. **Lint.** `stadium/tools/story_lint.py <scene.json>` flags shot lengths, zooms inside a shot,
   setups, alternating cuts and the ghost's screen time.
2. **Stills first.** Every shot as story_lab stills (first, middle and last frame) before a render.
3. **Fresh critic.** A read-only critic agent that did not build the scene scores each shot 1-10
   against this bar and the checklist, harshly; under 7 goes back.
4. **Render** only once every shot passes the stills review.
5. **Second review.** The critic again, on a 1 fps contact sheet and full-size key frames side by
   side with the last take.
6. **The owner** gets the take with the scorecard.

## Status
| Item | State |
|---|---|
| Audit and plan | done 27 Oct |
| 1 film finish and grade | done 27 Oct (`StorySubtitles` FILM, `"grade"`) |
| 2 camera engine | done 27 Oct (`"handheld"`, `"path": "spline"`, `"dof_near"`, `"exposure"`, softboxes, probes, sweeps) |
| 3 docks set | done 27 Oct (the opening on it) |
| Lint (`stadium/tools/story_lint.py`) | done 27 Oct |
| 4 the Mirror | blocked and lit 27 Oct; critic round 1: 4.1/10 (notes in PROGRESS) |
| 5 the knock | re-blocked 27 Oct (Dee crouched, coverage from inside, dawn) |
| 6 the intro | re-cut 27 Oct; critic round 1: 4.1/10 |
| Take five: stills, critic, render, page | two critic rounds (4.1 both: the structure passes, the assets hold it down); the render next |
