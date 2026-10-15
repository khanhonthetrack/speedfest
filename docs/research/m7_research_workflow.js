export const meta = {
  name: 'm7-research',
  description: 'M7 research: Trackmania physics + maps, Godot PC graphics/RTX, and audits of SpeedFest physics/perf/tracks, then a build plan',
  phases: [
    { title: 'Research', detail: '3 web research agents + 3 codebase audits, read-only' },
    { title: 'Plan', detail: 'synthesize an ordered M7 implementation plan, flag gaps and contradictions' },
  ],
}

const OWNER = `The owner (project lead) played the game and wrote, verbatim:
"I had a pass. This game is unplayable.
1. Focus now on making this game run on a PC. I want the engine to run good graphics from Godot. I want optional RTX, as many of us have RTX cards. This game looks like 2005. It's laggy as well.
2. The physics is horrible. There is no feel. Can't you learn or copy from Trackmania (any trackmania) how car behaves?
3. The barriers are super annoying.
4. The wall rides are terrible. It slows you down, pulls you down. These cars don't have any grip? It sucks.
5. The maps are literally copy paste of each other. Rails should not be magnetic to the car. It should stay and its the players job to land there. Can't you get inspiration from 10000+ maps from trackmania? https://trackmania.exchange/mapsearch You could literally copypaste them if you want. I want 30+ HIGH QUALITY, different maps."`

const CTX = `Project: SpeedFest, a Trackmania-style time-attack racer (original names/art, NFSU2 street vibe) built in Godot 4.7.2 (GDScript, static typing), repo checked out at /home/user/speedfest. Read /home/user/speedfest/CLAUDE.md and docs/HANDOFF.md first for orientation (docs/DESIGN.md, docs/ARCHITECTURE.md, docs/PROGRESS.md as needed). The game builds cars and tracks procedurally in code. There are 6 cars (kaze, brute, veloce, kitsune, pixie, goliath) and 10 tracks (game/tracks/defs/*.gd). Web export uses the Compatibility renderer; desktop uses Forward+. Physics is a custom arcade raycast vehicle on a RigidBody3D (Jolt, 60 Hz).

${OWNER}

RULES FOR YOU: this is a READ-ONLY research task. Do NOT edit, create or delete any file inside /home/user/speedfest, do not run git commands that change anything, do not run tools/godot_import.sh or exports. If you need scratch space use /tmp/claude-0/-home-user-speedfest/3a6c6eb2-89ac-59a5-9f14-b5f216db11cb/scratchpad/research/ (create a subfolder named after your topic). For web research load the tools with ToolSearch ("select:WebSearch,WebFetch") if they are not already available; Bash curl also works through the proxy (reddit.com, fandom.com and github.com web pages are blocked; raw.githubusercontent.com, trackmania.exchange incl. its JSON API, donadigo.com, linesight-rl.github.io, openplanet.dev, doc.trackmania.com, docs.godotengine.org and godotengine.org work). Cite sources (URLs) for every factual claim you take from the web, and clearly mark numbers you estimated yourself. Be concrete and quantitative: this report drives an implementation.

OUTPUT: your final answer must be the structured output with a complete markdown report (it will be committed to docs/research/ as-is, so write it for the next engineer: headings, tables, file:line references where relevant) and a short list of the most important findings.`

const REPORT = {
  type: 'object',
  properties: {
    title: { type: 'string', description: 'report title' },
    markdown: { type: 'string', description: 'the complete report in markdown' },
    top_findings: { type: 'array', items: { type: 'string' }, description: '5-12 most important findings / recommendations, one sentence each' },
  },
  required: ['title', 'markdown', 'top_findings'],
}

const TOPICS = [
  {
    key: 'tm_physics',
    label: 'research:trackmania-physics',
    prompt: `${CTX}

YOUR TOPIC: How Trackmania cars actually behave, as a quantitative TARGET BEHAVIOUR SPEC for rebuilding SpeedFest's car model with Trackmania feel. Cover TMNF/TMUF Stadium car and TM2020 (CarSport/Stadium car, plus the TM2020 Snow, Rally and Desert cars if you find data), and note where they differ.
Find and report, with numbers wherever possible (cite sources; mark estimates):
- Physics tick rate; top speed cap (1000 km/h); flat-road terminal speed without boosts; acceleration curve (time / distance to 100, 200, 300, 400 km/h), gears, how acceleration falls off with speed; deceleration when coasting; braking deceleration; reverse.
- Steering: keyboard vs analog, max steer angle and how it shrinks with speed, steering response time, turn radius / lateral acceleration at e.g. 100, 200, 300, 500 km/h on road; how much speed a full-lock turn costs on road (TM keeps speed very well).
- Grip and sliding: tarmac/road, tech, dirt, grass, ice/snow, plastic, wood/bobsleigh; what triggers a slide or drift; the TM2020 "speed drift" and the TMNF drift (brake tap + steer); how drifting costs or keeps speed; what "nosebug"/uberbug are and whether to avoid them.
- Slopes, banked turns, loops and WALLRIDES: why the car sticks (downforce? no magnetism, gravity always world-down?), minimum speed needed for a wallride or loop, what happens below it, speed loss on walls. This is critical: the owner says our wall rides "slow you down, pull you down, no grip".
- Air: jump arcs, gravity strength used in TM (is it ~9.81 or stronger?), air control (what inputs do in the air in TMNF vs TM2020, e.g. TM2020 air brake / car rotation), how landings work (flat landing keeps speed, landing on wheels vs nose, suspension), wheelies.
- WALLS/BARRIERS: what happens when you hit a barrier at 10, 30, 60, 90 degrees: speed loss, bounce, slide along, flips. TM is forgiving on glancing hits. The owner says our barriers are "super annoying".
- Boosts and special blocks: turbo (yellow), super turbo (red), reactor boost (TM2020), engine off, no steering, cruise control, slow motion, fragile, no brakes, reset; magnets (TM2020 "magnetic" blocks exist for some surfaces? explain what is magnetic in TM and what is NOT, e.g. rails/grinds don't exist in stadium; there is no magnet on most blocks).
- Respawn behaviour (standing vs flying respawn at checkpoints).
- What makes TM "feel" good, in priority order (responsiveness, grip, predictability, speed retention, determinism...), as design rules we must follow.
Good sources to try: donadigo.com/tminterface (docs, physics notes), linesight-rl.github.io (TMNF RL project docs), openplanet.dev, doc.trackmania.com, trackmania.exchange articles, YouTube video pages via search snippets, wiki.trackmania.io, steam guides, any reverse-engineering writeups of TMNF physics (GitHub raw files are reachable via raw.githubusercontent.com).
End the report with a "Target spec for SpeedFest" table: behaviour, TM value (sourced or estimated), and a concrete measurable test we could write for our car (e.g. "full throttle on flat from 0: 100 km/h in X s", "full lock at 200 km/h keeps >= Y% speed after 2 s", "75 deg wallride at 160 km/h: no slide-down, speed loss < Z%/s", "glancing 15 deg barrier hit at 250 km/h keeps >= W% speed, never flips").`,
  },
  {
    key: 'tm_maps',
    label: 'research:trackmania-maps',
    prompt: `${CTX}

YOUR TOPIC: Trackmania map design, from Trackmania Exchange (TMX, https://trackmania.exchange, JSON API e.g. https://trackmania.exchange/api/meta/tags and https://trackmania.exchange/api/maps?fields=...; also tmnf.exchange for the older game) and community knowledge, turned into 36+ ORIGINAL map concepts for SpeedFest.
Important: TMX maps are their authors' work. Do NOT reproduce specific maps; study styles, mechanics and what makes maps good, then design originals.
1. Survey: the TMX tag list and what each major style means (Race, FullSpeed, Tech, SpeedTech, SpeedFun, Dirt, Offroad, Ice, Water, Bobsleigh, Platform, Trial, LOL, Press Forward, Grass, Plastic, Wood, Transitional, Mini, Nascar, Kacky, etc.); which styles have the most awarded/most-played maps (query the API for counts and top-awarded maps per tag if possible; report numbers); typical lengths of top-awarded maps; what TOTD (track of the day) maps look like.
2. What makes a HIGH QUALITY map: flow, readability (signs, arrows, colour cues), checkpoint placement, consistent speed or deliberate speed changes, landing zones, no blind drops, difficulty curve, a signature moment, length, replayability for time attack, scenery that frames the route. Also common mistakes.
3. Mechanics catalogue: every distinct obstacle/transition/mechanic seen in TM maps (e.g. hairpins, S-bends, chicanes, banked turns, loops, wallrides, half-pipes, bobsleigh tubes, tilted roads, slope transitions, jumps/gaps, drops, kickers, bumps/sausage, water, ice slides, dirt drifts, grass cuts, boosters, reactor boost, engine-off, no-steer, cruise control, fragile, slow-mo, platform precision pieces, ramps onto walls, "round" pipes, tunnels, multilap) and which of those SpeedFest supports today. Read our track builder vocabulary in game/tracks/track_builder.gd (comment header and segment handlers), game/tracks/defs/*.gd (10 maps) and docs/DESIGN.md section 4 to see what exists.
4. Design 36 ORIGINAL maps (more is fine). Each: id, name, environment/theme (existing: neon city at night "city", stunt stadium at night "arena", dusk coast "coast"; you may propose new themes such as desert canyon, snow/ice mountain, rainforest, industrial port, so long as they add variety), TM style tag, target time (spread between ~15 and ~50 s), a section-by-section layout written so an engineer can build it from track segments (lengths in metres, turn angles/radii, banking, heights, gaps, surfaces, boosts, special blocks), the signature moment, difficulty (1-5), and which new pieces/mechanics it needs. Make them genuinely different from each other (different styles, rhythms, surfaces, verticality), no copy-paste boost-turn-loop-wallride-jump template.
5. A prioritized list of NEW track pieces and mechanics SpeedFest needs to build these (with rough implementation notes), and which maps each unlocks.`,
  },
  {
    key: 'godot_pc_rtx',
    label: 'research:godot-pc-graphics-rtx',
    prompt: `${CTX}

YOUR TOPIC: Making SpeedFest look and run like a modern PC racing game on Godot, including OPTIONAL RTX.
Research (cite sources; Godot docs at docs.godotengine.org, release notes at godotengine.org/releases/4.4 .. 4.7 and godotengine.org/article/*):
1. Mainline Godot 4.7 Forward+ feature set relevant to a night/dusk racing game, and what 4.4-4.7 added: SDFGI vs VoxelGI vs LightmapGI (and any newer GI), SSR, SSAO, SSIL, volumetric fog, glow, tonemappers (AgX etc.), TAA, FSR 2.x and other upscalers, SMAA/FXAA/MSAA, reflection probes, decals, shadows (PCSS, cascade settings), mesh LOD/visibility ranges, GPU particles, Compositor/CompositorEffect for custom post (motion blur, chromatic aberration, lens dirt), screen-space reflections on wet roads, physical light units, exposure/auto-exposure, D3D12 vs Vulkan on Windows (default in 4.7?), ubershaders / shader precompilation to avoid stutter, physics interpolation (3D) for smooth motion at high refresh rates, multithreaded rendering, VRS. Give recommended settings per quality preset (Low/Medium/High/Ultra) for a racer at 1080p-1440p on mid to high end GPUs, with expected cost.
2. Ray tracing: does mainline Godot 4.7 have any hardware ray tracing (e.g. a RenderingDevice ray tracing API, RT reflections/GI/shadows)? What is its status and is it usable from a game today?
3. NVIDIA's RTX fork of Godot (path tracing + DLSS): a shallow clone of branch nvidia-pt-dlss is at /home/user/nvidia-rtx/godot (it may still be cloning when you start; if missing, wait a little or use raw.githubusercontent.com/NVIDIA-RTX/godot/nvidia-pt-dlss/<path>). Read its README and docs, and grep the source (e.g. for path tracing project settings, Environment/RenderingServer properties, DLSS / Ray Reconstruction / Frame Generation / Reflex options, how the renderer is selected) to find EXACTLY how a project enables path tracing and DLSS, the hardware/OS requirements, which Godot version it is based on, whether a project made for mainline 4.7 can open/run in it, what features are unsupported under path tracing (e.g. particles, transparency, compatibility renderer), material/light changes needed, licensing/redistribution of DLSS. Also check branches backport/nvidia-pt-dlss-4.6.3, nvidia-pt-dlss-dev and worktree-dlss-fg-reflex via git ls-remote / raw files if useful. Check https://johnlogostini.itch.io/godot-rtx and NVIDIA's pages (developer.nvidia.com/rtx-kit) for prebuilt editors/templates.
4. Concrete integration design for SpeedFest: how the same project can (a) run on mainline Godot with great Forward+ settings and (b) light up an "RTX: Path tracing + DLSS" option automatically when run/exported with the fork (runtime feature detection via ClassDB/ProjectSettings/Engine.get_version_info or similar, with exact property names you found), what to do with things PT doesn't support, and how a player would get an RTX build (build the fork + export templates on Windows? prebuilt binaries?). Include a step-by-step for the owner.
5. Windows/Linux desktop export: what we need (export presets, templates, icons, D3D12/Vulkan choice, embedding PCK, size), plus a CI approach (GitHub Actions) to produce downloadable PC builds automatically.
Also read docs/RENDERING.md (our earlier path tracing investigation), game/autoload/settings.gd (quality presets, tune_environment), game/project.godot and game/tracks/scenery/scenery_env.gd to tailor recommendations to what exists.`,
  },
  {
    key: 'audit_physics',
    label: 'audit:physics-walls-barriers-rails',
    prompt: `${CTX}

YOUR TOPIC: Audit SpeedFest's car physics and its interaction with track geometry, to explain the owner's complaints precisely and prepare a rewrite toward Trackmania feel.
Read: game/cars/car.gd (the vehicle; long file), game/cars/physics/car_physics_defs.gd, game/cars/tuning.gd, game/cars/car_input.gd, game/cars/auto_driver.gd, game/weather/track_surface.gd, game/tracks/track_rail.gd (grind rails), game/tracks/track_builder.gd (barriers/walls collision, wallride and loop geometry, boost pads, jumps, collision shapes), game/race/race.gd and chase camera as relevant, docs/modules/physics.md, docs/DESIGN.md (handling section), and the tests in game/tests/physics/ (what they assert).
Explain with file:line references:
1. Why the handling "has no feel": the force model (tire model, slip curves, steering ramp, stability assist, yaw damping, drift systems: handbrake/brake drift/drift assist/power oversteer, speed-dependent steering limits, keyboard steering smoothing in car_input.gd), drag/rolling resistance, engine/gear model, downforce, and anything that adds latency or damps input (assists, smoothing, rate limits). List every "assist" or hack that fights the player.
2. WALL RIDES and loops: what exactly slows the car and pulls it down on walls (gravity vs downforce, grip as a function of load, any wall-ride-specific code, AutoDriver full-throttle zones, track roll ramps); compute or measure (you may run existing headless tests, e.g. tools/run_scene.sh res://tests/physics/test_wallride.tscn --headless -- --car=kaze, without editing anything) speed loss per second on a wallride and the minimum speed to stay on.
3. BARRIERS: the barrier collision geometry (heights, sloped tops, thickness, physics material, friction/bounce), the car's wall contact handling (WALL_* constants, deflection, _wall_timer), what happens on 15/45/90 degree hits, why they are annoying (snagging on seams? too high friction? bounce back? speed loss? walls everywhere on narrow roads?).
4. RAILS: how TrackRail pulls/snaps the car (magnetism) and what must change so landing on the rail is the player's job.
5. Jumps/landings/air: gravity extras, air pitch follow, landing absorb, and anything that feels fake.
6. What a rewrite must preserve: public API used by race/HUD/audio/remote cars/AutoDriver (signals, getters like get_speed_kmh, get_rpm, flags), tests that encode wanted behaviour vs tests that encode current hacks, the AutoDriver's assumptions (it drives every track in CI; it will need retuning).
7. Recommendation: replace vs refactor; outline a new, simpler Trackmania-like force model (what to keep, what to delete), with the order of work and a test plan.`,
  },
  {
    key: 'audit_perf',
    label: 'audit:rendering-performance-lag',
    prompt: `${CTX}

YOUR TOPIC: Audit why SpeedFest "looks like 2005" and feels "laggy", and what a PC (Forward+) version needs.
Read: game/project.godot (physics ticks, physics interpolation, vsync, max fps, renderer settings, AA, scaling), game/autoload/settings.gd (quality presets, tune_environment, tune_sun, is_compat), game/race/race.gd and the chase camera script(s) in game/race/, game/race/remote_car.gd and ghost playback (interpolation of remote players), game/cars/car.gd (where visuals are updated: _process vs _physics_process), game/cars/visual/car_visual.gd, game/tracks/scenery/*.gd (kits, env, batching), game/tracks/track_builder.gd materials, game/shaders/*.gdshader, game/weather/*.gd (particles), docs/RENDERING.md, tests/integration/perf_probe.gd.
Find, with file:line references:
1. Sources of perceived lag/stutter: physics at 60 Hz without interpolation on high refresh displays (is physics interpolation enabled? are cars/camera moved in _physics_process?), camera smoothing that lags behind, input handling latency, frame pacing settings, per-frame GDScript costs, shader compilation hitches (ubershader settings), particle costs, network interpolation delay for remote cars. Rank by likely impact.
2. Why it looks dated: lighting model (few lights? flat ambient?), materials (vertex colors, procedural textures, roughness), lack of GI/reflections/AO on desktop, shadow settings, LOD/fog/post settings, geometry density, scenery variety. Which Forward+ features are currently on per quality level, which are off, and why (compat compromises applied to desktop too?).
3. If possible, measure: you may run (without editing anything) tools/run_scene.sh res://tests/integration/perf_probe.tscn --headless -- --track=downtown --frames=300 or with --compat to read draw calls / objects / primitives per track (llvmpipe gives no meaningful FPS, but counts are useful). Do not run more than a few of these (CPU is shared).
4. Concrete fix list for a PC build, ordered by impact/effort: smoothness fixes first (exact settings and code changes), then a graphics upgrade plan per quality preset (GI choice, SSR/SSAO/SSIL, volumetrics, TAA/FSR, shadows, reflection probes, material upgrades, post FX like motion blur), with what to keep for the web build.`,
  },
  {
    key: 'audit_tracks',
    label: 'audit:track-system-maps',
    prompt: `${CTX}

YOUR TOPIC: Audit SpeedFest's track system and explain why "the maps are literally copy paste of each other", then propose the architecture to ship 30+ high-quality, genuinely different maps.
Read: game/tracks/track_builder.gd (the segment vocabulary in its header comment, every segment handler, how roads, walls, loops, wallrides, jumps, pipes, rails, buildings, boosts, surfaces, puddles, checkpoints are generated), game/tracks/track.gd, game/tracks/track_path.gd, game/tracks/track_rail.gd, game/tracks/track_buildings.gd, game/tracks/defs/*.gd (all 10 maps), game/tracks/track_defs.gd, game/tracks/scenery/*.gd (theme kits), game/ui/track_select.gd, server/lib/rotation.js (LIVE playlist), docs/DESIGN.md section 4, docs/modules/tracks.md, game/tests/tracks/*.gd.
Report:
1. Inventory of the 10 maps: for each, its section sequence and pieces used; show the repetition concretely (e.g. a table of which piece types appear in which map, typical widths, wall usage, scenery kit). Identify the template they all follow.
2. Limits of the builder: what layouts it cannot express today (e.g. multiple routes/forks, crossings/overpasses, tight technical turns, ramps between decks, platform/precision sections, tubes/bobsleigh, slopes up/down walls, true half-pipes, water/ice, moving or special blocks, start/finish variety, multilap), geometry quality issues (barriers everywhere, narrow decks, same widths, same banking), scenery repetition (3 kits only), and how time-consuming it is to author a map (code lists of segments, no editor, no preview).
3. Rails: how they work today and what changes when rails stop being magnetic (owner request).
4. Architecture proposal for 30+ maps: new segment types/mechanics (prioritized), data format (keep GDScript defs vs JSON resources), authoring tools (a preview/screenshot harness, layout map image, automatic validation: AutoDriver finishes, no overlaps, checkpoints reachable, time within target), theming/scenery variety per map (new environments, palette per map, props), UI changes for 30+ maps (track select pages/filters), LIVE rotation, ghosts/PBs, and testing at scale (CI time per map). Include effort estimates and an order of work, and how to split map authoring across parallel workers (one map per worker) safely (file ownership, shared registries like TrackDefs.IDS, server playlist).`,
  },
]

phase('Research')
const reports = await parallel(TOPICS.map(t => () =>
  agent(t.prompt, { label: t.label, phase: 'Research', schema: REPORT }).then(r => r ? { key: t.key, ...r } : null)))
const ok = reports.filter(Boolean)
log(`${ok.length}/${TOPICS.length} research reports done: ${ok.map(r => r.key).join(', ')}`)

phase('Plan')
const bundle = ok.map(r => `\n\n===== REPORT ${r.key}: ${r.title} =====\n${r.markdown}`).join('')
const plan = await agent(`${CTX}

You are the lead engineer. Below are research reports on the owner's complaints (Trackmania physics, Trackmania maps, Godot PC graphics/RTX, and audits of our physics, rendering/performance and track system). Write the M7 IMPLEMENTATION PLAN that will be executed next, one work package after another (the owner wants work saved/pushed after every step; parallel agents are allowed for clearly independent packages such as authoring individual maps, each on its own branch).

Requirements for the plan:
- Ordered work packages (WP1, WP2, ...) covering ALL owner points: PC build + graphics + optional RTX + no lag; Trackmania-feel physics; barriers; wall rides/loops; non-magnetic rails; new track pieces/mechanics; 30+ distinct high-quality maps (with the concrete map list to build, drawing on the map research), track select/LIVE changes for 30+ maps; web build kept working.
- For each WP: goal, exact files/modules touched, design decisions (pick one; justify briefly using the reports), acceptance criteria that are MEASURABLE (tests to add/change, numbers from the target spec, screenshots to review), dependencies, risks, effort (S/M/L), and whether it can be parallelized.
- Call out contradictions or gaps between the reports (e.g. a number one report assumes and another refutes, missing research) and how to resolve them.
- Keep the AutoDriver/CI working through the physics change (plan its retune).
- Be realistic about what can be verified in this container (no GPU, llvmpipe software rendering, CPU 4 cores, no RTX hardware): what is verified here vs what the owner must test on their RTX PC.
Return the plan as the markdown report.
${bundle}`, { label: 'plan:m7', phase: 'Plan', schema: REPORT })

return { reports: ok, plan }
