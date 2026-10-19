<!-- M7 look plan (session 10, 2026-10-16): three art-direction reviewers (lighting/materials,
atmosphere/post, geometry/detail) read the screenshots and the code; a judge checked every proposal
against the code and merged them into this ranked plan. Screenshots referenced live in the session
scratchpad (not committed). Implement one step at a time with before/after screenshots. -->

# M7 look plan: why SpeedFest PC still looks like 2005, and the fixes in order

## Summary

I checked all three panels against the code on m7-look and the 12 screenshots. They agree on the cause. Emission, wide additive bloom and a volumetric fog lit everywhere are doing the work that lighting should do, so almost no light lands on any material. On top of that, the city facades are flat window stickers on black boxes. The plan puts those tells first: the arena veil and the pink start wash (fog, then bloom), then the Tetris facades. After that it is ordered by impact per hour.

Facts from the code that change some of the proposals:
- Desktop defaults to High (quality 2), so the owner saw volumetric fog. City fog is 0.012 over 160 m, which lets through only about 15% (arena: 0.006 over 200 m, about 30%). volumetric_fog_sky_affect is left at 1.0, so the fog also covers the sky.
- 5 of the 10 tracks use the arena theme, 3 coast and 2 city (downtown, rooftop). Every track is a platform, so every barrier is the neon style with a cyan strip and every curb uses track_stripes.gdshader (render_mode unshaded, energy 0.9). The concrete and guardrail barrier variants are not used by any current track.
- City buildings use window_energy 1.25, not 2.2.
- The only tunnels are HOTEL ORBIT (56 m) and SKYLINE (50 m). _build_tunnel makes mini(6, int(len/30)) = 1 OmniLight, and only at quality 2 or higher. On Medium the orange soup is pure fake emission (material "tunnel" 0.25 and road tunnel_fake 0.9).
- Every light already scatters into the fog at the default light_volumetric_fog_energy of 1.0. Changing those energies costs nothing.
- There is no ReflectionProbe, no FogVolume, no CameraAttributes and no light_volumetric_fog_energy anywhere in game/.
- CarParts info has "headlights" but no "taillights" key.

Two rules for every step:
1. SceneryEnv.retune() runs again on every Settings.changed signal. Derive every new value from the authored base values: store them in _authored or a sibling dictionary. Never write "fog_density *= 0.6", because it would compound on every settings change.
2. TrackBuilder._mat_cache is static and its keys only include compat. material("tunnel") and road_material() already depend on Settings.quality, so after a quality switch in the menu the next race reuses the old material. Any material whose values depend on quality must put quality in its key.

Work method: one step at a time. Take before and after screenshots with $OUT=<a scratch folder> against the reference PNGs. Every step also needs a --compat --quality=1 run, so the web build is either unchanged or deliberately changed, plus tools/check_scripts.sh (SCRIPT_ERRORS=0). Then update PROGRESS.md and HANDOFF.md, commit and push, as CLAUDE.md requires.

Estimated cost on an RTX 3060-class card at 1440p:
- Steps 1-2: about 0 ms.
- Steps 3-7: about 1.0-1.6 ms together.
- Step 9 (probes): about 0.3 ms at runtime, plus a one-time capture during the countdown.

All steps together are about 26 hours.

## Steps

### 1. Re-light the volumetric fog: lights, not the moon, light the air, and keep the fog off the sky

*impact 5/5 · ~2h · GPU: About 0 ms: same froxel grid, and every light already injects at the default energy 1.0. · from: R1 lighting (part of proposal 1) + R2 atmosphere (P1), merged*

**Files:** `game/tracks/scenery/scenery_env.gd`, `game/tracks/scenery/city_kit.gd`, `game/tracks/scenery/arena_kit.gd`, `game/tracks/track.gd`, `game/tracks/track_builder.gd`

**Presets:** High and Ultra on Forward+ (where volumetric fog is on). Exponential-fog changes apply only while volumetric fog is enabled. Low, Medium and the web stay as they are.

**Implementation:**

scenery_env.gd: add _pc_atmosphere(), called from retune() after _quality_extras() when not Settings.is_compat(). Add "fog_density" and "fog_sky_affect" to the authored snapshot, so the function always starts from the authored values.

1. Volumetric values, set directly in the theme functions. Compatibility ignores volumetric fog, so these are inert on the web.
   _city():
   - volumetric_fog_density 0.012 -> 0.005
   - volumetric_fog_sky_affect 1.0 (default) -> 0.1
   - volumetric_fog_ambient_inject 0.4 -> 0.08
   - volumetric_fog_albedo (0.6,0.55,0.75) -> (0.8,0.8,0.85), so the fog takes the colour of the neon instead of a violet tint
   - volumetric_fog_anisotropy 0.0 -> 0.5 (halos when looking toward lights)
   - volumetric_fog_temporal_reprojection_amount 0.9 -> 0.8 (less smear at speed)
   _arena():
   - density 0.006 -> 0.0022
   - sky_affect 0.1
   - ambient_inject 0.3 -> 0.05
   - albedo (0.8,0.8,0.85) -> (0.65,0.67,0.72)
   - anisotropy 0.5
   _coast(): sky_affect 0.3. Nothing else changes; the dusk god rays are wanted.

2. _sun_extras(): sun.light_volumetric_fog_energy = 1.0 for coast and 0.15 otherwise. The moon or key light should no longer light the whole fog volume.

3. _pc_atmosphere(), only when env.volumetric_fog_enabled after tune_environment(): fog_density = authored * 0.6 and fog_sky_affect = authored * 0.5. Otherwise restore the authored values. Today the two fogs stack and flatten the skyline.

4. Set Light3D.light_volumetric_fog_energy where each light is created:
   - city_kit._neon_lights() OmniLight3D: 2.0
   - city_kit._real_lights() lamp SpotLight3D: 3.0
   - arena_kit._real_lights() arch omnis: 1.5
   - track.gd _make_gate() GateLight: 0.4. Lower, not higher: the gate fills the start frame, and that is the pink wash in linux_build_arena.
   - track_builder._build_tunnel() OmniLight3D: 0.3

5. Optional look-dev arguments in _quality_extras(): --vfog=<density multiplier> and --vsky=<sky_affect>, for quick sweeps.

**Web:** Nothing to do. Volumetric properties are ignored on Compatibility, and the exponential-fog changes are gated by not is_compat(). The web look is unchanged.

**Verify:**

1. Arena: tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=arena --quality=2 --views="chase:300;drive:520" --out=$OUT --tag=ar_fog. Compare with ar_aces_0/1:
   - the sky is navy with visible stars and the moon gradient instead of flat lavender-grey;
   - the stands and towers separate from the sky;
   - halos stay tight around the chevrons and the loop arch.
2. Downtown: --track=downtown --quality=2 --views="cp:0;drive:180;chase:300" --tag=dt_fog. Compare with dt2_0/1/2: the panorama clouds show and the tunnel haze is thinner.
3. Start view: tools/run_scene.sh res://race/race.tscn -- --track=arena --quality=2 --no_intro --frames=90 --shot=$OUT/start_fog.png. Compare with linux_build_arena.png: less pink fog in front of the car.
4. --quality=1 and --compat --quality=1 runs must look unchanged.
5. Optional: if PIL is installed, the mean luma of the top 15% of rows in ar_fog_0 should drop from about 0.45 to under 0.15.

**Risks:** The arena may read too clear and black until step 5 adds real flood shafts. Keep the density tunable through --vfog. If you skip the authored-value snapshot, every settings change compounds the fog values.

### 2. Modern bloom on Forward+: no whole-frame bloom, threshold above 1.0, short tail, luminance cap

*impact 4/5 · ~1h · GPU: 0 ms (bloom 0 may save about 0.05 ms). · from: R1 lighting (part of proposal 1) + R2 atmosphere (P2), merged; lens dirt dropped*

**Files:** `game/tracks/scenery/scenery_env.gd`

**Presets:** Forward+ Medium, High and Ultra (glow runs from Medium up). The web keeps its current glow.

**Implementation:**

In _pc_atmosphere() (Forward+ only), apply from the authored values each retune():

1. env.glow_bloom = 0.0. Today it is city 0.05, arena 0.08, coast 0.03, and glow_bloom blooms every pixel regardless of the threshold.
2. env.glow_hdr_threshold: city 0.9 -> 1.25, arena 0.85 -> 1.2, coast 1.1 -> 1.4.
   - Curbs (0.855 linear) and most windows (window_energy 1.25 x tint x dim) stop blooming.
   - Neon (3.2-9) keeps its punch.
3. env.glow_hdr_luminance_cap = 8.0 (default 12), so the start gate and signs keep their shape.
4. glow_intensity: city 0.9 -> 0.75, arena 1.1 -> 0.85.
5. _glow_levels(), shifting weight from the wide levels 4-6 to levels 1-3:
   - city [0,0.6,1,0.9,0.6,0.3,0] -> [0,0.85,1.0,0.6,0.25,0.06,0]
   - arena [0,0.5,1,1,0.8,0.4,0.1] -> [0,0.75,1.0,0.65,0.3,0.08,0]
   - coast [0,0.4,1,0.8,0.5,0.2,0] -> [0,0.5,1.0,0.6,0.3,0.1,0]
6. Keep GLOW_BLEND_MODE_ADDITIVE and ACES (the owner liked the neon punch).
7. Look-dev switch --glow=old restores the authored values for A/B shots to show the owner.

**Web:** Unchanged (gated by not is_compat()). A later, separate A/B can try bloom 0 on the web.

**Verify:**

1. Start view: tools/run_scene.sh res://race/race.tscn -- --track=arena --quality=2 --no_intro --frames=90 --shot=$OUT/start_bloom.png. Compare with linux_build_arena.png: the magenta stays on the gate pillars and strips; the loop, stands, track and car are readable.
2. Downtown: tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=downtown --quality=2 --views="drive:180;chase:300" --out=$OUT --tag=dt_bloom. Compare with dt2_1: the SPEEDFEST letters are readable, not a white blob, and the window tiles no longer halo.
3. Run the same views with --glow=old for a side-by-side.
4. --compat --quality=1 must be unchanged.

**Risks:** The neon can feel tamer. If the owner wants more glow, raise glow_intensity or the neon energies; don't bring back glow_bloom or the wide levels.

### 3. Facades with depth: recessed windows, interior-mapped rooms, frames, lighter walls

*impact 5/5 · ~4.5h · GPU: 0.2-0.4 ms at 1440p in downtown (ALU only; the aa gate limits it to buildings within about 150 m). · from: R3 geometry (proposal 1) + R1 lighting (proposal 7), merged*

**Files:** `game/shaders/env_building.gdshader`, `game/tracks/scenery/scenery_mat.gd`, `game/tracks/scenery/city_kit.gd`, `game/tracks/track_buildings.gd`, `game/tests/visual/road_lookdev.gd`

**Presets:** Relief on Forward+ at quality 1 and up, and on Compatibility at quality 2 and up. Wall lift on Forward+ only. The far (aa) path is unchanged everywhere.

**Implementation:**

All changes are in the wall branch of env_building.gdshader fragment() (abs(ln.y) <= 0.5). The shader is shared by city_kit, track_buildings (wall-ride facades, Hotel Orbit) and the coast town, so one change covers all of them.

1. New uniforms relief (0/1) and wall_lift. SceneryMat.shader_mat() injects relief when shader_name == "building": 1.0 if (not compat and quality >= 1) or (compat and quality >= 2), else 0.0.
2. Move today's window mask into float win_mask(vec2 f, float style, float v, float fh), keeping the shop-front rule.
3. Ray into the box in local metres:
   - vw = normalize(wp - CAMERA_POSITION_WORLD); vl = vec3(dot(vw,ax), dot(vw,ay), dot(vw,az)).
   - T = the direction of increasing u (x faces (0,0,sign(ln.x)), z faces (-sign(ln.z),0,0)); N = the outward face normal.
   - r = vec3(dot(vl,T), vl.y, -dot(vl,N)); r.z > 0 points into the wall.
4. Recess: depth 0.25 m for punched windows (style < 0.2), 0.06 for curtain wall, 0.15 for ribbon windows.
   - Glass point: fg = f + vec2(r.x/cw, r.y/fh) * depth / max(r.z, 0.05).
   - Where win_mask(f) = 1 and win_mask(fg) = 0, the ray hits the jamb, sill or head: albedo wall*0.45, roughness 0.6, no emission.
5. Interior, only for lit cells with aa > 0.02 and relief > 0.5.
   - Room box cw x fh x D (D = 0.9*cw). p0 = (fg.x*cw, fg.y*fh, 0).
   - tb = (step(0.0, r) * vec3(cw, fh, D) - p0) / r, with r clamped away from 0. t = min(tb.x, min(tb.y, tb.z)); the smallest axis tells which surface was hit.
   - Ceiling: lit_col*1.3 plus a centre panel hotspot.
   - Back wall: lit_col*0.75 with the existing furniture blob and a per-room hash tint.
   - Side walls: *0.5. Floor: *0.3.
   - Unlit rooms 0.02, so the glass reflection dominates.
   - Blinds stay on the glass plane at fg. This replaces today's inner/blob on the near path.
6. Frames: a 4 cm border at fg, plus a mullion at fg.x = 0.5 when cw > 3.4. Albedo 0.08, METALLIC 0.6, ROUGHNESS 0.3, so they catch the sign OmniLights and SSR.
7. Walls, Forward+ only: city_kit and track_buildings pass wall_color (0.13,0.13,0.15) and wall_color2 (0.2,0.18,0.18) (today 0.07 and 0.12). Add a floor ledge at f.y < 0.05 (albedo*0.7, NORMAL tilted up) and rain streaks albedo *= 1 - 0.3*wetness*vnoise(vec2(u*2.5, v*0.12)). Add a vnoise() helper.
8. city_kit._add_building(): lit fraction randf_range(0.18, 0.5) -> (0.12, 0.4).
9. No PBR texture fetches: keep it ALU-only.
10. Optional: road_lookdev.gd --buildings=1 places 8 SceneryInstances unit_box buildings with the real material, for about 1 minute per iteration.

**Web:** Same GLSL ES 3.0 code, enabled only at web quality 2 and up through relief. The web default is quality 1, which keeps today's flat path. Web walls stay dark (no SSR or probes there).

**Verify:**

1. tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=downtown --quality=2 --views="drive:180;drive:183;chase:300" --out=$OUT --tag=fac. Compare with dt2_1/dt2_2:
   - lit windows show a ceiling, side walls and a floor that shift between drive:180 and drive:183 (parallax);
   - jambs are visible at oblique angles and frames glint near signs;
   - walls read as surfaces, not black voids;
   - towers past about 150 m look the same as before.
2. --track=rooftop --views="chase:300" and --track=coast --views="chase:300" (the coast town).
3. --compat --quality=1 must match before (relief off). --compat --quality=2 must compile under GLES3 and show relief.
4. tools/check_scripts.sh.

**Risks:** Lighter walls can turn grey under the city sky ambient (1.6). If they do, lower the lift, not the ambient. Ray artefacts at grazing angles: clamp r.z. Check the coast's daylight 0.25 look. Watch for branch divergence cost on the near path.

### 4. Ground the car: contact shadow, tail and brake light on the road, headlight beams in the fog, less self-lit rim

*impact 4/5 · ~2.5h · GPU: Contact blob about 0.02 ms; tail OmniLight about 0.03 ms; headlight scattering in the fog about 0.1 ms (High+). · from: R1 lighting (proposal 4); Ultra projector and shadow parts dropped*

**Files:** `game/cars/visual/car_visual.gd`, `game/shaders/car_contact.gdshader`, `game/race/race.gd`, `docs/modules/visuals.md`

**Presets:** Contact shadow on every preset and both renderers. Tail light and headlight fog energy on Forward+ at quality 1 and up; the beams only show from High, where volumetric fog is on. Rim change on Forward+ at quality 1 and up.

**Implementation:**

car_visual.gd:

(a) Contact shadow: new _build_contact(), called after _build_glow() in build().
- MeshInstance3D "ContactShadow": PlaneMesh of (width+0.3, length+0.2) at y = -wheel_radius + 0.008, just under the underglow blob at +0.015. cast_shadow OFF.
- New car_contact.gdshader: render_mode blend_mul, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled; ALBEDO = vec3(1.0 - strength*f). f = the car_glow rounded-rectangle falloff plus 4 tighter blobs at the wheel contacts (a uniform built from shape.g wheelbase and track). strength 0.55.
- Give its material render_priority = -1, so it always sorts before the additive underglow on the same plane. Otherwise the transparent sort order flips and the glow flickers.
- set_wheel_state(): fade strength toward 0 as the mean suspension offset reaches full extension (airborne). set_ghost(): hide it when ghosted.

(b) Tail light, created next to the head spots in set_headlights_real(). That method is already local-car only (race.gd:148).
- OmniLight3D at the rear centre. There is no info["taillights"], so use z = +length*0.5 + 0.1 (the rear; headlights sit at -z) and y about 0.5.
- light_color (1, 0.05, 0.02), omni_range 5, omni_attenuation 1.2, light_specular 1.0 (a red streak on the damp road), light_energy 0.35.
- set_lights(): braking -> 2.2, reversing -> white at 1.2.
- Forward+ only.

(c) set_headlights_real() on Forward+: sp.light_volumetric_fog_energy = 1.5, light_specular 0.6, spot_angle_attenuation 1.5.

(d) race.gd:138: on Forward+ at quality 1 and up, CarVisual.night_rim = {"city": 0.35, "arena": 0.2}. Compatibility keeps 1.0 / 0.5.

Update the node-layout comment at the top of car_visual.gd and docs/modules/visuals.md (ContactShadow, TailLight).

**Web:** The contact blob works unchanged on Compatibility. The tail OmniLight is skipped there, because Compatibility pays an extra pass per light per object.

**Verify:**

1. tools/run_scene.sh res://race/race.tscn -- --track=downtown --quality=2 --frames=60 --shot=$OUT/car_dt.png. Compare with base60.png: darkening under the sills and tyres, and the paint no longer glows like plastic.
2. tools/run_scene.sh res://race/race.tscn -- --track=arena --quality=2 --no_intro --frames=90 --shot=$OUT/car_ar.png. Compare with linux_build_arena.png: a red pool on the road behind the car.
3. tools/run_scene.sh res://tests/visual/showcase.tscn -- --car=veloce --angle=rear --brake=1 --lights=1 --frames=30 --shot=$OUT/brake.png: a red pool and reflection on the floor.
4. Repeat 1 with --compat --quality=1: the blob is present, the rim unchanged, no tail light.

**Risks:** The blend_mul plane can show a hard edge on steep banking or in loops (it is on the car, so it banks with it). Tune the falloff. Tail lights count against light_budget (8 lights are already kept free for cars).

### 5. Arena floodlights become real SpotLights (pools, specular streaks, fog shafts) instead of additive cones

*impact 4/5 · ~2.5h · GPU: 6-12 large unshadowed spots, about 0.4-0.8 ms at 1440p (they cover most clusters). Fog injection about 0.1 ms. · from: R1 lighting (proposal 5) + R2 atmosphere (P4, arena part), merged; Ultra shadowed floods dropped*

**Files:** `game/tracks/scenery/arena_kit.gd`, `game/tracks/scenery/scenery_env.gd`

**Presets:** Pools from Forward+ Medium, and shafts in the fog from High. Covers all 5 arena-theme tracks (arena, infield, twister, pipes, rails).

**Implementation:**

arena_kit.gd:

1. _towers(): for each tower, append [src, dir, dl] to a new flood_spots array (src, dir and dl are already computed there).
   - On Forward+ at quality 2 and up, add the two beam cones with vertex alpha 0.02 instead of 0.07: volumetric fog now draws real shafts.
   - Medium and the web keep 0.07.
2. _real_lights(): on Forward+ at quality 1 and up, before the arch omnis and counted against Settings.light_budget(), add one SpotLight3D per flood_spots entry:
   - position = src; basis = Basis.looking_at(dir, Vector3.UP) (a SpotLight3D shines along -Z)
   - spot_range = dl*1.3
   - spot_angle 24. This is the half-angle. 24 gives separate pools; 40 would just make a second flat key light.
   - spot_angle_attenuation 1.5, spot_attenuation 0.5
   - light_energy about 6. Tune it so the deck under a pool reads about 0.2-0.3 sRGB while the gaps stay dark.
   - light_color (0.9, 0.94, 1.0), light_specular 1.0, light_volumetric_fog_energy 2.0
   - shadow_enabled false, no distance fade
3. scenery_env.gd: arena on Forward+ at quality 1 and up, sun.light_energy 0.9 -> 0.5 (set in _sun_extras from the authored value). It keeps its shadow; the floods now carry the deck. Check that the lawn still reads green.
4. Optional if time remains (R1): 2 downward SpotLight3D per city gantry in city_kit._gantries()/_real_lights(): range 12, angle 60, energy 5, cool white, taken from the neon share of the budget.

**Web:** Unchanged: key light 0.9, additive beam cones and pools. Compatibility pays per light per object, so no flood spots there.

**Verify:**

1. tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=arena --quality=2 --views="overview;chase:300;drive:520" --out=$OUT --tag=flood. Compare with ar_aces_0/1:
   - overlapping pools with darker gaps on the lawn and the deck;
   - specular streaks on the damp deck pointing at the towers;
   - a visible shaft from each tower in the fog;
   - the stands are lit under the towers.
2. The same with --quality=1 (pools, no shafts).
3. --track=twister and --track=infield with --views="chase:300".
4. --compat --quality=1 must be unchanged.
5. On a real GPU, compare the GPU ms in the Show FPS overlay before and after.

**Risks:** Large spots that overlap can flatten the lighting again: keep the angle narrow and tune the energy by screenshot. The shafts depend on step 1's fog density; retune them together. Medium budget is 48 lights: 12 floods + 12 arch omnis + car lights fits.

### 6. Lit, wet, retro-reflective curbs and hazard stripes, lane paint that fades with distance, chamfered barrier with LED modules, mounted chevrons

*impact 4/5 · ~3h · GPU: Under 0.05 ms. · from: R1 lighting (proposal 2) + R3 geometry (proposal 2), merged; joints and cat-eyes deferred*

**Files:** `game/shaders/track_stripes.gdshader`, `game/shaders/road.gdshader`, `game/shaders/track_neon.gdshader`, `game/tracks/track_builder.gd`, `game/tracks/track.gd`

**Presets:** Every preset on both renderers; self_lit is set per renderer.

**Implementation:**

1. track_stripes.gdshader: remove render_mode unshaded.
   - New uniforms: wetness, self_lit (0.1 on Forward+, 0.35 on Compatibility), retro (0.5), profile_len (1.34 for the curb).
   - ALBEDO = mix(color_a, color_b, m) at paint albedo (curb white 0.75, red (0.55,0.03,0.04)), times wear noise.
   - Base AO: albedo *= mix(0.55, 1.0, smoothstep(0.0, 0.1, min(UV.x, profile_len - UV.x))). Use both ends because mirror_profile() reverses the left curb's point order.
   - ROUGHNESS = mix(0.45, 0.12, wetness); SPECULAR 0.5.
   - Retro-reflection: EMISSION = ALBEDO * (self_lit + retro * pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * 25.0 / (25.0 + length(VERTEX))).
   - Keep the #if defined(RT) branch with albedo and real emission only.
2. track_builder.gd: today build_road() line 1003 makes a new curb ShaderMaterial for every chunk. Cache it in _mat_cache as "curb_stripes_<compat>_<quality>", and the jump stripes (build_jump_dressing, line 1783) as "hazard_stripes_<neon>_<compat>_<quality>" with self_lit 0.2. Track.apply_weather() then sets their wetness to the same maxf(Weather.road_wetness(weather), damp) as the road.
3. road.gdshader line 150: inside #if !defined(RT), EMISSION += paint * paint_a * paint_glow * (0.3 + 0.7 * 25.0 / (25.0 + length(VERTEX))). Lines near the car pop like headlight returns and stop glowing out to the horizon.
4. _build_wall_run() "neon" profile: replace the 4-point rectangle with [(o,-0.4),(o,0.94),(o+0.06,1.0),(o+0.12,1.05),(o+0.44,1.05),(o+0.5,1.0),(o+0.5,-0.4)]. No point is in front of x = o, and the collision profile c stays the same. The flat-shaded loft turns each chamfer into a highlight line.
5. track_neon.gdshader: uniform float seam_every = 0.0. When > 0: sq = fract(UV.y/seam_every); e *= mix(0.15, 1.0, smoothstep(0.0, 0.03, sq) * smoothstep(1.0, 0.97, sq)), in both the RT and non-RT branches. Add a new material key "neon_cyan_seam" (seam_every 2.0) and use it only for the barrier strip.
6. build_corner_signs(): xo = (hw + WALL_GAP + 0.25) * outside, so the board sits on the barrier top. Add a 6 cm dark backing box and two posts from 1.05 up to y0 with Acc.box(), committed with material("metal_dark").

**Web:** The same ALU-only shaders run on Compatibility. self_lit 0.35 keeps curbs readable without SSR and with few lights.

**Verify:**

1. tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=arena --quality=2 --views="chase:300;drive:520" --out=$OUT --tag=edge, and --track=downtown --views="drive:180;chase:300". Compare with ar_aces_0/1 and dt2_1/dt2_2:
   - curbs are bright near the camera and dimmer far away, with neon specular and reflections, and darker at the base;
   - lane dashes fade with distance;
   - two thin highlight lines run along the barrier top;
   - the cyan strip shows 2 m LED modules;
   - the chevrons sit on the barrier.
2. --compat --quality=1 with the same views: curbs and hazard stripes still readable.
3. Headless: tools/run_scene.sh res://tests/tracks/test_collision_faces.tscn --headless and res://tests/tracks/test_road_smooth.tscn --headless (collision is unchanged).
4. tools/check_scripts.sh.

**Risks:** Curbs can go too dark on Low, where there are few lights: self_lit may need a quality step. Hazard stripes must stay readable as a jump warning. Loop interiors get the cached curb material too; check a loop view.

### 7. Tunnels: discrete fixtures, ribs and real downlights in a rhythm, no fake sodium emission, fog cleared inside

*impact 3/5 · ~3h · GPU: About 7 small unshadowed spots, 0.05-0.1 ms and only while inside (cluster-local). FogVolumes about 0.05 ms. · from: R1 lighting (proposal 8) + R2 atmosphere (P4, tunnel part) + R3 geometry (proposal 3), merged; tiles, fans and niches deferred*

**Files:** `game/tracks/track_builder.gd`, `game/shaders/road.gdshader`

**Presets:** Real lights and no fakes on Forward+ Medium and up. FogVolume on High and up. Low and the web get a dashed fake light.

**Implementation:**

The only tunnels are HOTEL ORBIT (downtown, 56 m) and SKYLINE (rooftop, 50 m). Today they get one OmniLight, and only at quality 2 or higher. All changes are in _build_tunnel():

1. Fixtures: remove the continuous lights_l/lights_r lofts. Every 4 m on each side, add a housing Acc.box Vector3(0.5, 0.12, 1.3) committed with material("metal_dark"), and a lens box 0.42 x 0.02 x 1.2 just below it with material("neon_white") (cool LED against the orange city; keep neon_sodium for the guardrail style). Use the frame basis so they follow banking.
2. Ribs: for each d in ring_ds(d0 + 3, d1 - 3, 6.0), loft the inner profile over three frames [d-0.25, d, d+0.25], with the middle ring pushed 0.2 m inward along each segment normal. Add them to shell; their two flat-shaded faces catch the light.
3. Forward+ at quality 1 and up: replace the OmniLight with a SpotLight3D every 8 m, alternating sides under the fixtures, aimed down and about 15 degrees inward. About 7 per tunnel.
   - spot_range 10, spot_angle 60, spot_angle_attenuation 1.2, light_energy 3, light_specular 1.0, light_volumetric_fog_energy 0.3
   - distance_fade_begin 80, distance_fade_length 30
4. Remove the fakes on Forward+ at quality 1 and up: material("tunnel") emission_enabled false, and road_material() tunnel_fake 0.
   - Put Settings.quality into both cache keys. They key only on compat today, although these values depend on quality.
5. High and up: one FogVolume per 20 m segment, frame-aligned. shape = RenderingServer.FOG_VOLUME_SHAPE_BOX, size Vector3(2*oh, 9, 20), material = FogMaterial with density -0.004. Negative density subtracts the global volumetric fog, so the lights form pools instead of soup.
6. Low and the web: keep the fake light but dash it. In road.gdshader multiply the tunnel term by 0.4 + 0.6*pow(0.5 + 0.5*cos(6.2832*UV.y/8.0), 4.0).

Leave collision, the portals and track_buildings._through (oh = hw + 2.8) untouched.

**Web:** Fake emission kept, but dashed in road.gdshader. Zero lights on Compatibility.

**Verify:**

1. tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=downtown --quality=2 --views="cp:0" --out=$OUT --tag=tun (cp:0 is inside Hotel Orbit). Compare with dt2_0/new_q2_0:
   - pools every 8 m with darker gaps between them;
   - fixture reflections on the damp road;
   - a visible rib rhythm;
   - no uniform orange.
2. --quality=1 against new_q1_0.
3. --track=rooftop --views="cp:0" (the SKYLINE tunnel, if that is where cp:0 sits).
4. --compat --quality=1: the road shows banded pools.
5. tools/run_scene.sh res://tests/tracks/test_collision_faces.tscn --headless.

**Risks:** Without the fake emission, the walls between pools can go fully black. The ribs and the metal_dark housings need the spots' light_specular. The FogVolume orientation must follow the frames on curved bores.

### 8. Barrier neon strips light the deck: an analytic line light in road.gdshader

*impact 3/5 · ~2.5h · GPU: Under 0.05 ms (about 15 ALU per road pixel). · from: R1 lighting (proposal 3)*

**Files:** `game/tracks/track_builder.gd`, `game/shaders/road.gdshader`

**Presets:** Every preset and both renderers. It is the only edge light the web deck gets.

**Implementation:**

Do this after steps 5-6, and only if the deck next to the barriers still reads black. SSR already gives the specular part on Forward+; this adds the diffuse part.

1. TrackBuilder.Acc:
   - Add var col := PackedColorArray().
   - add() takes an optional colour, default Color(0,0,0,0), so existing callers don't change.
   - commit() writes Mesh.ARRAY_COLOR when col.size() == v.size().
   - loft() gets an optional per-ring cols array, like uv2s.
2. build_road() deck loop (around lines 924-947): per ring Color(wl, wr, 1, 0). wl/wr = 1 when wall_mode_at(data, d) covers that side and d is outside the wall exclusions (gaps, loops ±1 m), the same tests the barrier runs use further down.
3. road.gdshader:
   - New uniforms: strip_color (_neon_color("cyan"), because every track is a platform with neon cyan barriers), strip_energy (1.4 on Forward+, 1.1 on Compatibility), strip_h 0.79, strip_gap 0.13 (= WALL_GAP - 0.02, the strip's x offset in _build_wall_run).
   - In fragment(): sl = x + hw + strip_gap; sr = hw + strip_gap - x.
   - k(s) = strip_h*s / pow(s*s + strip_h*strip_h, 1.5). This models a Lambertian strip facing the road: zero right under it, peak about 0.55 m out.
   - Inside #if !defined(RT): EMISSION += col * strip_color.rgb * strip_energy * (COLOR.r*k(sl) + COLOR.g*k(sr)) * (1.0 - 0.5*wet).
   - The road_lookdev strip has no vertex colours, so COLOR is white there and both sides get spill. That's fine for look-dev.

**Web:** Runs unchanged on Compatibility (ALU only).

**Verify:**

1. tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=downtown --quality=2 --views="drive:180;chase:300" --out=$OUT --tag=spill. Compare with dt2_1/dt2_2: a cyan gradient about 1.5 m wide along both barriers, absent at wall gaps and walls:none segments.
2. --track=arena --views="chase:300" against ar_aces_1.
3. The same views with --compat --quality=1.
4. tools/run_scene.sh res://tests/tracks/test_road_smooth.tscn --headless.

**Risks:** Physically, a 0.14 m strip lights a 0.07-albedo road only faintly, so strip_energy is an art value: keep it subtle or it reads as another glow band. The car does not occlude the spill.

### 9. Sector ReflectionProbes (UPDATE_ONCE) so car paint, glass and the off-screen road reflect neon instead of the black sky

*impact 4/5 · ~5h · GPU: About 0.2-0.4 ms at 1440p at runtime (clustered probe lookups). The one-time capture is 6 faces x N probes at about 1-2 ms each, spread over the countdown. · from: R1 lighting (proposal 6)*

**Files:** `game/tracks/track_probes.gd`, `game/tracks/track.gd`, `game/cars/visual/car_visual.gd`, `game/tests/tracks/track_view.gd`, `docs/ARCHITECTURE.md`

**Presets:** Forward+ Medium (10 probes), High (24), Ultra (40). Off on Low and on the web.

**Implementation:**

1. New game/tracks/track_probes.gd: class_name TrackProbes, static func build(root: Node3D, path: TrackPath, theme: String) -> int.
   - Called at the end of Track.build after the scenery, Forward+ at quality 1 and up only.
   - Run tools/godot_import.sh to register the class.
2. One ReflectionProbe about every 80 m along the path, capped per preset (the atlas reflection_count default is 64). Each probe:
   - position = path.sample_transform(d).origin + up*10, yaw-aligned with the road
   - size: city Vector3(width+50, 40, 90), arena (width+120, 70, 120), coast (width+80, 40, 100)
   - origin_offset Vector3(0, -8, 0), so it captures at car-roof height
   - box_projection true for city, false otherwise
   - blend_distance 10, max_distance 400, enable_shadows false
   - update_mode ReflectionProbe.UPDATE_ONCE, intensity 1.0, mesh_lod_threshold 4.0, ambient_mode ReflectionProbe.AMBIENT_DISABLED
3. Tunnel zones: one probe fitted to the bore with interior = true, ambient_mode AMBIENT_COLOR, ambient_color (0.18,0.14,0.1), ambient_color_energy 0.5. This keeps the city's 1.6 sky ambient out of the tunnel and pairs with step 7.
4. Keep cars out of the captures: probe cull_mask = 1. In car_visual.gd, put Body, Wheels, Calipers, Glow and ContactShadow on VisualInstance3D.layers = 2 (this covers remote cars and ghosts too). No layers are used anywhere today, so the camera's mask already includes layer 2. reflection_mask defaults to all layers, so cars still receive probe light.
5. Capture timing: build the probes during the track build so the 3.5 s countdown hides the capture. First spend 30 minutes checking whether off-screen ONCE probes capture immediately or only when first in view. If only in view, accept a per-sector fade-in, which blend_distance masks.
6. Add --warm=N to track_view.gd (wait N frames before the first view). Log the probe count next to BUILD_MS.
7. Skip Ultra reflection_size 512 for now (it needs a user://engine.cfg override and a restart).

**Web:** Off on Compatibility: probes add per-object work on WebGL2. The web keeps sky-only reflections.

**Verify:**

1. tools/run_scene.sh res://race/race.tscn -- --track=downtown --quality=2 --frames=240 --shot=$OUT/probe_car.png. Compare with base60.png: neon signs and lit windows appear in the side panels and clearcoat.
2. tools/run_scene.sh res://tests/tracks/track_view.tscn -- --track=downtown --quality=2 --warm=240 --views="drive:180;chase:300;cp:0" --out=$OUT --tag=probe. Compare with dt2_*:
   - coloured reflections at the bottom of the frame and past the barriers, where SSR has none;
   - the glass reflects;
   - the tunnel ambient is dark;
   - no start-grid car is baked into the road reflection.
3. --track=arena: the car reflects the floods and stands.
4. On a real GPU, the perf overlay's worst-frame figure shows no mid-race re-capture hitches.

**Risks:** Capture hitches at load. Atlas eviction can re-render probes when you come back to a sector (mid-race stutter); measure the worst frame. Box-projection seams between sectors. Probes don't capture volumetric fog. This is the riskiest step, so it comes last.

## Rejected proposals

- **R2 P8: CompositorEffect motion blur, nitro radial blur, chromatic aberration**: About 11 h, so not one sitting. It shows nothing in the still screenshots the owner judged, and lavapipe compute is too slow to tune it in this container. NFS Most Wanted (2005) was itself known for heavy motion blur, so this doesn't remove a '2005' tell. Revisit once the stills are fixed.
- **R2 P3: per-theme 3D colour-grade LUT (adjustment_color_correction)**: A grade doesn't fix any of the lighting or material tells, and a heavy grade (MW's green and sepia) is itself a mid-2000s NFS signature. adjustment_contrast and adjustment_saturation are already set. Re-evaluate after steps 1-3 if the palette still clashes.
- **R2 P2 sub-item: procedural lens dirt (env.glow_map)**: Taste risk, and an early-2010s trope. It adds haze in exactly the frames steps 1-2 clear up.
- **R2 P6: auto exposure in races, DOF in the garage and lobby**: The only tunnels are 50-56 m on two tracks, about 1.5 s per lap. Auto exposure on night scenes tends to lift blacks, the same objection the owner had to AgX. DOF belongs to the separate 'menus look mobiley' work, not this pass.
- **R2 P7: rain v2 (lit streaks, splashes, ripples, lens water, lit spray)**: 6+ hours spread over 8 files and several systems, too big for one sitting. Rain appears only on the 2 wet city tracks and in weather modes. Split it later and start with lit, speed-stretched streaks.
- **R2 P5: sky light-pollution dome and far skyline impostor ring**: Step 1 (volumetric_fog_sky_affect 1.0 -> 0.1) already uncovers the panorama and the procedural glow band that is there. Judge the sky after step 1 before adding a dome or another ring.
- **R2 P4 sub-item: canyon-mist FogVolume with 3D noise**: It brings back a uniform veil right after step 1 removes one, and the city decks sit 50 m above streets that are not visible yet. Revisit together with street life.
- **R3: rooftop clutter and tower massing (parapets, HVAC, tanks, cranes, chamfered towers)**: About 5 h for the 2 city tracks only. Lower impact per hour than the lighting and material steps. It's the next city item if the silhouettes still read as boxes after step 3.
- **R3: street canyon life (lamp grid, traffic light-streams, canopies)**: About 6 h, and mostly visible only at jumps and deck edges. Deferred.
- **R3: elevated-deck structure and arena infield props (girders, capitals, fences, tyre stacks, camera towers)**: About 6 h. The arena gets real lighting first (steps 1 and 5); structure and clutter come later. The alpha-hash fences also add shimmer risk under TAA/FSR2.
- **R3: road wear (expansion joints, tar snakes, patches, manholes, apex rubber)**: The wet road is already the strongest part of the look. At 3.5 h it has lower impact per hour than steps 1-8. Good follow-up after this plan.
- **R3: skid marks MultiMesh ring buffer**: Not a tell in any screenshot, and it needs a cars-module API addition (contact point and normal getters; get_drift_amount, get_slip_angle, get_wheelspin, get_water_amount and get_wheel_contact already exist). Deferred.
- **R3 road-edge sub-items: 4 m module joints, splice plates, cat-eyes**: Cat-eyes mainly help concrete and guardrail barriers, and no current track uses them: every track is a platform, so every barrier is the neon style. Joints are deferred; step 6 keeps the chamfers and LED seams, which cost nothing.
- **R1 4c: Ultra shadowed headlight with a procedural light_projector**: Its claim that projectors require shadow_enabled is unverified. A car-mounted shadowed spot re-renders every frame for a small payoff. Dropped from step 4.
- **R1 5 / R2 P4: Ultra shadowed flood SpotLights**: A shadowed spot with about 150 m range in a 4096 positional atlas gives blurry shadows, and it re-renders whenever cars move (+1-3 ms). Dropped from step 5; it could be a later Ultra experiment.
- **R2 P1 detail: raise GateLight light_volumetric_fog_energy to 1.5**: Wrong direction. The start gate fills the start frame, and its light in the fog is part of the pink wash in linux_build_arena. Step 1 lowers it to 0.4.
- **R1 7 detail: lower city ambient_light_energy 1.6 -> 1.0 inside the facade step**: A global change that also darkens the road, car and props. Keep it out of the facade step and tune the wall lift instead; revisit ambient on its own.
- **R1 7 / R3 1 detail: concrete PBR texture sampling on facades**: Two texture fetches per facade pixel for little gain at night. Step 3 stays ALU-only, so it also runs on the web.
- **R2 P1 detail: volumetric_fog_length 160 -> 240**: Coarser froxels for no visible gain once the density drops. Dropped.
