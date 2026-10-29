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

## Third pass (the owner, 28 Oct: "Work on cutscenes until reviews get to at least 7/10")
Planned by a read-only scope round (one agent per asset and scene, sequential), built in
`tools/story/pass3_open.py` and `pass3_close.py` (they edit the committed scenes in place and run
twice to the same result):
- **The city across the harbour** (the opening's first image): clear air (`"env"` fog 0.0003,
  `"vol_fog"`), no shot lights, low over the water past the quay cranes, a quick fade up; the far
  city's storefront LED lines and neon avenues off round a set (globals `tm_city_led`,
  `tm_city_lit`: 0 and 0.42 on `"bare": "set"`, back to 1 and 0.3 on leaving); no stars over rain
  (StoryScene `_set_sky`: an overcast lit from under); the city in the harbour (`"reflect"`: a
  planar reflection, a mirrored camera rendering the city's layer into the water's shader).
- **The auction:** four more in the crowd between the camera and the cars; the yard wide over Kit's
  shoulder craning down behind the heads; Gus points the gentleman out (`"reach"` with `"point"`);
  the coat man reversed from the stage over the crowd, nodding, keyed by a sodium lamp; Gus keyed
  from the far side at 3:1; Kit's close-up in her close-up's light, no blink on the cut; the orbit on
  the cameras' side of the line; "Engine's sweet" over a bonnet insert; the hero framed so the
  stage's lamp hides behind the roof; Lot 47 on deep-dish rims; a sodium lamp in the canyon and a rim
  on Kit.
- **The Mirror:** the coupe on high beams (`"lights": "high"`: a hard key 50 m on, and a glare at
  every lit lamp that blazes as it faces the lens) as the chase's key; the mirror's inserts at fov 13
  a stop brighter (`"mirror"` `"exposure"`); the empty road a match cut of the rear-window shot; the
  ghost revealed in a few frames of the dome's flicker (`"flicker"` `"from"`/`"to"`) under a cold top
  light; the eyes shot aimed at her face (camera `"look"`: a person's id); the empty seat's dead air
  cut; no lavender fill from the dash; trims. Then the scene agent's scare ("scarier still"): a
  glimpse of her in the rear window, a dark road where every rhythm stops, the false calm in which she
  rises behind Kit and lays a hand on the headrest, the mirror reveal by the dome's light, the turn
  back to safety in dead silence, the hit at Kit's ear; sound mixed per shot (levels, pitch, loops
  that stop), new cues (engine, wipers, ring, creak, sub), keyed lights and face shapes, passing
  street lamps.
- **The knock:** first light (a dawn sky gradient, `"sky"` `"zenith"`/`"horizon"`; the city's rooms
  mostly dark, `"city_lit"`; the arch's lamp a hard warm key behind Dee; the sky a cool fill; no
  lavender fills); re-cut to 15 shots with none of the dialogue over about 3 s: a frontal Kit single
  from the dash, Dee singles framed higher, an exterior over-the-shoulder two-shot, the empty back
  seat, the mirror at dawn, the pins from one pin out to nine, the ending craned up to the ARCH 9
  lettering from the side that keeps Dee screen right; the knock, the glass down and the lean in that
  order; soot-dark wet brick on the viaduct. Then the scene agent's body work: a knuckle insert (a
  standing knock, the elbow low), Dee bending down into the window with a hand on the roof, a living
  lean (a rounded back, breathing, weight shifts, head beats on her lines), the push-off at the end;
  per-key easing; beaded wet glass.
- **Everywhere:** the cabin's lining shaded as facing in (it was lit by lights outside the car); the
  cast's hair in a strand shader (StoryHair: the shells' colours were a few thousandths of white, so
  only their gloss showed); an eye light on close-ups (`"eye_light"`, the cast's own layer); no blink
  round a cut.

## Fourth pass (29 Oct: the third pass's stills critic, 5.5 and 5.0 for the opening)
Round two of stills showed three faults the critic would have kept finding, fixed at the root first:
- **Hair that read lavender, pink or blonde** was the scalp: the strand shells are about half
  see-through (their texture's alpha) and the head's lit skin showed through them. StoryHair now
  draws an opaque cap under the strands (the same shell 2 mm in, opaque where the strands cover well,
  the hair's own colour; it casts the hair's shadow), and the sheen came down another quarter. Under
  a hat no hair is drawn (the coat man's fedora: the hair's shell stood out through its crown).
- **The cars' insides were boxes.** `story/story_cabin_kit.gd` (StoryCabinKit) builds them from
  rounded, pillowed parts in leather, alcantara, satin and piano black with a fine grain in their
  normals: bucket seats (a pleated centre, bolsters, a shell, a headrest), a rear bench of three,
  a dash sculpted to the windscreen's foot a quarter of a metre under the driver's eyes (a binnacle
  over a glowing cluster, the centre stack with the satnav set in it, vents, a glovebox line), door
  cards and rear quarters, a console with the shifter, a three-spoke wheel tilted the right way (it
  leaned the wrong way), visors, a black headlining. StoryCabin keeps its layout and its seat API.
- **The containers strobed** (a 0.7 m sine rib under grazing floods, clean saturated paint): now
  0.28 m trapezoid ribs that flatten where a rib is under a few pixels, faded and dirty paint,
  rust along the rails and in streaks.

Then the critic's notes on the opening, in `tools/story/pass4_open.py` (after `pass3_open.py`, the
same idempotent way):
- the city low over the quay's edge (a sodium lamp, the bollards and the deck slide past the lens),
  haze laying the far towers back, a glow band on the horizon, fewer and brighter windows (global
  `tm_city_glow`, a shot's `"env"` `"city_glow"`);
- the canyon in behind Kit, a cool rim, the sodium down, the auction's light coming back down the lane
  with two figures in it;
- the yard's crane starting among the heads, Gus keyed from the truss and rimmed (the brightest face
  in the wide), the crowd edged from the stage side; the truss's lamp heads aimed down their beams
  and the truss black (bare aluminium glinted blue);
- Gus's point seen 55 degrees off its line (it pointed down the lens and read as a fist), the coat
  man's reverse from Gus's side of the line (the eyelines meet), tighter and keyed from above;
- Kit keyed warm from the stage's side (the violet omni under her chin gone), her eyes coming up to
  Gus on "Lot forty-seven"; `kit_eyes` her eyes' view of the car past the heads, Gus's "Engine's
  sweet" over it;
- the car shots lit by the stage (the studio softbox orbs out, a warm truss spot behind, blue rims),
  the bonnet's insert cut (the truss lamps' reflections stayed discs), the underglow dimmed per shot
  (a car's `"glow"`), the run quicker (2.5-3 s inserts), Lot 47's hand-painted grey camouflage brought out (its thresholds sat at the top
  of the noise: almost nothing showed) with a red pinstripe, its plate lettered (a car's `"plate"`).

The Mirror's fourth pass (29 Oct: its critic on round two's stills, 5-6 a shot; then round three's
stills with the interior kit and the hair's cap) in `tools/story/pass4_close.py` (after
`pass3_close.py`), and its root fixes first:
- **Hair greyed under a light near the lens**, with dark "ink" strand lines: under a coaxial light
  every strand faces its Kajiya-Kay highlight, and the sheen was capped at 3 % of the light, two to
  three times the diffuse of hair this dark. Capped at about 1 % now, the primary lobe lower, the
  painted strands' detail softer and the back faces lighter.
- **The drowned passenger looked like Kit and like plastic**: soaked skin is grey-green and wet-matt
  now (no glazed clear coat, no light under it), and no drips off someone seated in a car (in a dark
  cabin they read as rain falling inside it).
- **Rain fell through the roof**: a cabin carries a `RainShield` (a particle collision box); the
  scene's rain vanishes where it meets one.
- **The wet deck read as a black-and-white zebra** under the coupe's beams: its ripples are broad and
  shallow now, and its puddles fade in at their edges (they were mirrors cut out of matt tarmac).
- **Rain on the glass drew rings**: the film's drops are clear by their mask (they were by their
  offset's length, which is nothing at a drop's middle); fewer pin drops, a fainter lift.
- **A white slab and a blue balloon** in the cabin's close shots: the bench's leather mirrored the
  sky at a glancing look (now a softer sheen) and the rear-view mirror's housing was lit satin
  plastic a few centimetres from the lens (now near-black matt; the cameras keep clear of it).
- An env's `"ssr": false` (a long lens's puddles without their stair-steps).

Every interior camera was checked first with a ray-cast map of Lot 47's cabin (seats, bench, dash,
satnav, console, the mirror and its stem, visors, doors, the wheel, Kit's head, the ghost's): of the
critic's proposals, a front close-up from the passenger dash was 98 % mirror and an eye-height
three-quarter 30 % mirror. Then the shots:
- every face keyed by a light the scene has: a sodium streetlight through Kit's window while she
  sleeps (her head fallen against the headrest), the coupe's beams a hard back rim growing over
  profile and closer, the mirror's slash across her eyes in glare and in eyes, the dome from above in
  the false calm, the instruments from below in the look back; the lens's fill down to a catchlight;
- the dream's road reframed so the pursuer has clean air, Kit's lamps down so its beams read first,
  her head shown against the windscreen; the low reverse with our flank soft at the edge and our
  tail light red on the road, the coupe nearer;
- the mirror's inserts framed by the header and the visors, the street round them a stop down
  (vignette, far blur), the coupe's lamps the brightest thing; the whiteout grown from two lamps
  that eat the glass, the cabin flooded on the hit;
- the glimpse a black head against the glare (the lamps bloom instead of clipping); the empty road
  dark with one streetlight's pool where the coupe was; the dark road from the ghost's own place,
  Kit's head a soft shape on the left;
- the false calm 2.6 s, she rises out of the dark in her own cold light (a rim that lit her hair
  white gone); in the mirror her face in the gap beside Kit's head, lit by her own light, Kit's eyes
  on hers; the hit with Kit's eyes already sliding to her and the ghost a dark shape with a cold edge;
- the scene 22.9 s (was 25.9), the ghost on screen 1.4 s.

The knock's fourth pass (its critic on round three's stills: 4.5 and 4.5; the same file, after the
Mirror's section) and its engine pieces:
- **Where everyone really is:** `story_lab --probe=t1,t2` prints each person's eyes, head and hands in
  the followed car's frame. Kit's eyes as she sits are a quarter of a metre behind the layout's
  `driver_head` (the Mirror's narrow slash spots had been aimed at the empty air in front of her face;
  now at her eyes). Dee's eyes in the knock are inside the window's opening only from a camera low
  on the passenger's side: from eye height the visor and the roof's rail cut her at the chin.
- The knock seen from outside on beaded glass (a car's `"rain_glass"`), a closed fist; the
  geography (the two-shot) third; shot and reverse broken up by Dee's profile outside, Kit
  three-quarter from the dash, an over-the-shoulder from behind Dee, Kit from the passenger's seat
  with her eyes going to the mirror, Dee's own eyes for the plea; Kit's eyes never down the lens (a
  new gaze, `"road"`: off down the road at no one).
- First light: a cold low sun over the street (a light's `"kind": "sun"`), the arch's lamp a warm rim
  behind Dee, the arch's bulb down (the viaduct's `"bulb"`) so the background sits under the faces,
  the grade's blue a third less; the arch has its own floor (the map's tiles read as a game grid),
  its number painted and lit by a bracket lamp; a warehouse behind the car closes the street (the
  mirror showed a park).
- Dee's mouth narrower (a person's `"mouth"`: her visemes bared the lower teeth, every line a snarl),
  her overalls a worn navy (a person's `"tint"`), her hair deep brown; teeth ivory for the whole cast;
  Kit's mouth shut but on the scare lines, with sleepy, defensive, afraid, haunted and pleading faces.
- The wet patch on the back seat (a car's `"wet_seat"`) shown as Dee names it, the rear glass's light
  raking it, and in the mirror at dawn; Lot 47 matt with dew at first light (the gloss mirrored the
  sky: a silver car), its pinstripe a deeper red; dark brushed trim and a soft-touch satnav bezel (bright
  aluminium and piano black mirrored the dawn: white pills and a cream frame).
- The end a slow pull back that keeps the car, Dee and her lit arch; 17 shots, 27 setups.

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
| 5 the knock | re-blocked 27 Oct (coverage from inside, dawn); Dee leaning in on the window's ledge, the window wound down (owner's note, 27 Oct) |
| 6 the intro | re-cut 27 Oct; critic round 1: 4.1/10 |
| Take five: stills, critic, render, page | two critic rounds on stills (4.1 both); clips rendered and reviewed (4.5/10 each scene, better than take four in all three); with the owner 28 Oct: https://claude.ai/artifact/W8dnTULoXhWQpbsF6DYBoW |
| Third pass | built 28-29 Oct (`pass3_*.py`); stills round two: the opening 5.5 and 5.0 |
| Fourth pass | 29 Oct: the hair's cap, the interior kit, the containers, the opening's notes (`pass4_open.py`); the Mirror's (`pass4_close.py`: faces keyed by the scene's own lights, cabin cameras ray-checked, the hair's sheen, the drowned skin, the rain shield, the deck, the drops); the knock's (4.5/4.5 from its critic): Dee's face in the glass, the two-shot third, first light, the wet patch, `--probe` |
| Next | stills of all three scenes after their fourth passes (`m6`, `k6`, `o9`), their critic; iterate to 7; clips once every scene reaches 7 |
