<!-- M7-1 research (session 10, 2026-10-15): written by a research agent, then verified claim by
claim by a second agent. Only our own write-up and facts/line references; no fork code is copied.
Section 7 lists what turned out wrong or out of date; the body has the ghost formula corrected. -->

# SpeedFest PC version: implementation guide

How to read the citations: `[Sn]` points to the source list at the end. `fork:path:line` means a local clone of NVIDIA's fork (branch `nvidia-pt-dlss`, tip `135dff3887` "NVIDIA: Pathtracer + DLSS", 2026-07-24; the branch is three NVIDIA commits on upstream master `c3e6b2c` of 2026-06-23, see section 7). `472:file:line` means mainline `4.7.2-stable` files fetched from raw.githubusercontent.com [S5–S18]. Anything marked **(estimate)** is a planning number I did not measure. Measure it in-game (see 1.7).

---

## 0. Decisions in one screen

1. **The real PC game stays on mainline 4.7.2, Forward+, Vulkan on Windows and Linux.** `project.godot` already has no `driver.windows` override, so Windows uses Vulkan [S5 472:ProjectSettings.xml:3344]. Keep it that way: the RTX fork can only path trace on Vulkan (its D3D12 RT functions are stubs, fork:drivers/d3d12/rendering_device_driver_d3d12.cpp:5547-5600), and a Linux CI editor can only bake Vulkan shaders (D3D12 baking needs `D3D12_ENABLED`, i.e. a Windows editor; 472:editor/editor_node.cpp:9500-9519).
2. **The lag fix is mostly physics interpolation plus frame pacing, not graphics.** Physics runs at 60 Hz, and on a 120–240 Hz screen an un-interpolated car judders. The working tree already has an uncommitted start on this (`physics/common/physics_interpolation=true`, `physics_jitter_fix=0.0`, root mode OFF, Car mode ON, `tests/race/test_interpolation`). Section 1.5 lists what is still missing (ghost sub-tick sampling, wheel MultiMesh, the camera).
3. **"Looks like 2005": use what Forward+ already has.** That means AgX tonemapping, real (cheap, unshadowed) lights next to every neon emitter, full-res SSR plus per-sector ReflectionProbes for the wet road, SSAO, SSIL on Ultra, volumetric fog with lamp shafts, PCSS soft shadows, decals, GPU particles, TAA/FSR2 instead of MSAA, and CompositorEffect motion blur. Ship four presets (1.7).
4. **Hardware RT in mainline 4.7 is only a low-level, experimental `RenderingDevice` API.** The renderer uses none of it (section 2).
5. **Optional RTX: one codebase.** At runtime the game detects NVIDIA's fork with `ClassDB.class_has_method(&"Environment", &"set_pathtracing_enabled")`. Only there does Settings show "RTX path tracing", "DLSS", "Frame Generation" and "Reflex". Those options drive `Environment.pathtracing_*`, `Viewport.scaling_3d_mode = 6 (SCALING_3D_MODE_DLSS)`, `Viewport.frame_generation` and the `Streamline` singleton, all through `set()`/`ClassDB` so the scripts still compile on mainline. Shaders get `#if defined(RT)` branches that the fork compiles and mainline ignores (fork:scene/resources/shader.cpp:113-118).
6. **Exports:** Windows and Linux presets (already present, needs small key changes), plus a GitHub Actions workflow that downloads 4.7.2 and its templates, verifies them with `SHA512-SUMS.txt`, imports, exports both, uploads artifacts, and creates a Release on `v*` tags (section 5).

---

## 1. Mainline Godot 4.7 Forward+ for a night/dusk racer

### 1.1 What 4.4 → 4.7 added that matters here

| Version | Feature (exact name) | Source |
|---|---|---|
| 4.4 | **Ubershaders** (specialized pipelines compile in the background while an ubershader draws), **3D physics interpolation** (enable it in project settings), **Jolt Physics** (experimental), **AgX tonemapper** (`Environment.TONE_MAPPER_AGX`), LightmapGI bicubic sampling and shadowmasks, `Light3D.shadow_caster_mask`, rendering-driver fallback (`rendering/rendering_device/fallback_to_*`), Metal/MetalFX | [S1] |
| 4.5 | **Shader baker** (export option `shader_baker/enabled`), stencil buffer, **SMAA 1x** (`Viewport.SCREEN_SPACE_AA_SMAA`=2), specular occlusion (`rendering/reflections/specular_occlusion/enabled`, default true), bent normal maps (`BaseMaterial3D.bent_normal_enabled/texture`), physics interpolation moved to SceneTree (API unchanged) | [S2], [S5] |
| 4.6 | **SSR overhauled** (Hi-Z, full or half res: `rendering/environment/screen_space_reflection/half_size`, default true), **glow blended before tonemapping, with Screen as the default** (`glow_blend_mode` default 1), AgX controls `tonemap_agx_white`/`tonemap_agx_contrast`, octahedral reflection/radiance maps, **new Windows projects default to D3D12**, Jolt default for new projects | [S3], [S6 472:Environment.xml:129,319-325] |
| 4.7 | **AreaLight3D** (rectangular area light, PCSS soft shadows; extra cost on all objects once one is in view), **HDR output** (`display/window/hdr/request_hdr_output`), **Nearest 3D scaling** (`SCALING_3D_MODE_NEAREST`=5), clearcoat energy fixes, per-pass environment UBOs (perf), 3D particle scale/rotation, **experimental RenderingDevice ray tracing API** (section 2) | [S4], [S11 AreaLight3D.xml:6-12], [S7 Viewport.xml:578] |

(For context: 4.7 stable shipped around June 2026 and 4.7.2 around August 2026 [S36, secondary]. 4.8 beta 1 came out 2026-10-15 with contact shadows, multi-bounce AO and animated decals, but no RT [S24].)

### 1.2 Features, exact names, and how SpeedFest should use them

**Lighting for neon at night (the biggest win, and cheap).** Forward+ is clustered, so many *unshadowed* `OmniLight3D`/`SpotLight3D` are affordable (`rendering/limits/cluster_builder/max_clustered_elements` [S5]). Put a real light next to every important emitter (neon sign, boost pad, tunnel strip, floodlight) so the wet road picks up colour. Emission plus glow only *looks* bright and lights nothing. `Light3D.light_size` (omni/spot) and `light_angular_distance` (directional) give PCSS soft shadows: Forward+ supports both, Mobile supports positional only [S11 Light3D.xml:57-60,97-100]. `AreaLight3D` (`area_size`, `area_texture`, `area_range`, `area_attenuation`) fits neon tubes, but add it on Ultra only: "In Forward+, there is an additional GPU cost on all rendered objects as soon as one area light is present in the view frustum" [S11 AreaLight3D.xml:12].

**Tonemap, glow, exposure.** `Environment.tonemap_mode = TONE_MAPPER_AGX` with `tonemap_agx_white` (default 16.29, "at least 6.0" recommended) and `tonemap_agx_contrast` (default 1.25) [S6 472:Environment.xml:319-325]. Since 4.6 glow happens before tonemapping, with `GLOW_BLEND_MODE_SCREEN` as the default [S3]. SpeedFest forces `GLOW_BLEND_MODE_ADDITIVE` (scenery_env.gd `_build`), so re-tune `glow_hdr_threshold`/`glow_intensity` after switching to AgX. Auto exposure for tunnels lives in `CameraAttributesPractical`/`CameraAttributes` (`auto_exposure_enabled`, `auto_exposure_scale`, `auto_exposure_speed`, `auto_exposure_min_sensitivity`, `auto_exposure_max_sensitivity`) [S11 CameraAttributes*.xml]. Assign it to `WorldEnvironment.camera_attributes`.

**Reflections (wet asphalt and puddles).**
- SSR: `ssr_enabled`, `ssr_max_steps` (default 64), `ssr_fade_in`, `ssr_fade_out`, `ssr_depth_tolerance`, plus the global `rendering/environment/screen_space_reflection/half_size` (runtime: `RenderingServer.environment_set_ssr_half_size(bool)`) [S6 472:Environment.xml:302-318], [S5 472:ProjectSettings.xml:2935], [S9].
- `ReflectionProbe` per track sector covers what SSR can't see (off-screen neon): `update_mode` ONCE, `box_projection`, `interior`, `size`, `blend_distance`, `reflection_mask`; atlas size from `rendering/reflections/reflection_atlas/reflection_size` (default 256) and `reflection_count` (default 64) [S11 ReflectionProbe.xml], [S5]. In the GI docs, probes in mode Once are the fastest GI/reflection option, and "Always" is much more expensive [S21].
- `rendering/anti_aliasing/screen_space_roughness_limiter/enabled` reduces specular shimmer on a glossy road [S5].

**AO and indirect light.** `ssao_enabled`, `ssao_intensity/radius/power/detail/horizon/sharpness/light_affect/ao_channel_affect`; quality via `rendering/environment/ssao/quality` (`ENV_SSAO_QUALITY_VERY_LOW`=0…`ULTRA`=4) and `ssao/half_size` (runtime `RenderingServer.environment_set_ssao_quality(quality, half_size, adaptive_target, blur_passes, fadeout_from, fadeout_to)`). SSIL: `ssil_enabled`, `ssil_intensity/radius/sharpness/normal_rejection`, `rendering/environment/ssil/quality` and `half_size` [S6], [S9], [S5]. SSIL gives the "neon spills onto the wall" look cheaply and complements other GI [S21].

**GI choice for procedural, fast-camera tracks.**
- **LightmapGI** is not viable at runtime: "Lightmap baking functionality is only available in the editor" [S11 LightmapGI.xml:8]. SpeedFest builds tracks in code.
- **SDFGI** (`sdfgi_enabled`, `sdfgi_cascades`, `sdfgi_min_cell_size`, `sdfgi_max_distance`, `sdfgi_use_occlusion`, `sdfgi_y_scale`, `sdfgi_bounce_feedback`, project `rendering/global_illumination/sdfgi/probe_ray_count|frames_to_converge|frames_to_update_lights`, `gi/use_half_resolution`) is "one of the most demanding" GI techniques. Its "performance drops when the camera moves too fast" (use ≤4 cascades), and it does not support dynamic emissive surfaces [S21], [S6 472:Environment.xml:217-220]. That is a bad fit at 250 km/h, so offer it only as an Ultra option on open tracks (stadium, coast).
- **VoxelGI** can be baked in exported projects (`VoxelGI.bake()`, "generally takes from 5 to 20 seconds"), and dynamic objects receive and emit GI [S11 VoxelGI.xml:9,24], [S21]. For LIVE rotation, bake per track once (tool script or first load), cache the `VoxelGIData` resource, and load it on later visits. This is the High/Ultra GI.
- Low/Medium: sky ambient plus probes plus real lights (fake GI).

**Fog.** Keep exponential `fog_*` everywhere. Volumetric fog: `volumetric_fog_enabled/density/albedo/emission/anisotropy/length/detail_spread/gi_inject/ambient_inject/sky_affect/temporal_reprojection_enabled/temporal_reprojection_amount` [S6]. Grid size comes from `rendering/environment/volumetric_fog/volume_size` (default 64), `volume_depth` (default 64) and `use_filter` (runtime `environment_set_volumetric_fog_volume_size`, `environment_set_volumetric_fog_filter_active`) [S5], [S9]. For shafts from street lamps use `Light3D.light_volumetric_fog_energy`. Use `FogVolume` for tunnels. Forward+ only [S6 472:Environment.xml:362-364].

**Anti-aliasing and upscaling (mainline).** `Viewport.scaling_3d_mode` offers `SCALING_3D_MODE_BILINEAR`=0, `FSR`=1 (FSR 1.0, spatial), `FSR2`=2 (FSR 2.2, temporal; at scale 1.0 it is "a TAA solution"), `METALFX_SPATIAL`=3, `METALFX_TEMPORAL`=4 (Apple only), and `NEAREST`=5 (4.7). There is **no DLSS, XeSS or FSR3 in mainline** [S7 472:Viewport.xml:555-582]. Other knobs: `scaling_3d_scale`, `fsr_sharpness`, `use_taa`, `screen_space_aa` (`SCREEN_SPACE_AA_FXAA`=1, `SMAA`=2), `msaa_3d`, `use_debanding`, `texture_mipmap_bias`, `anisotropic_filtering_level` (`ANISOTROPY_16X`=4) [S7]. The project-level equivalents are `rendering/anti_aliasing/quality/{msaa_3d,screen_space_aa,use_taa,use_debanding,smaa_edge_detection_threshold}` and `rendering/scaling_3d/{mode,scale,fsr_sharpness}` [S5]. **Drop MSAA on PC.** Changing MSAA at runtime "will trigger pipeline recompilations" (stutter) [S20], and `Settings.apply()` currently changes `msaa_3d` with every quality switch (settings.gd `apply`). Use TAA, or FSR2 at 1.0, plus optional SMAA, and set `rendering/anti_aliasing/quality/msaa_3d=0` in `project.godot` (it is 1 today) so pipelines get precompiled for the setting actually used.

**Shadows.** `DirectionalLight3D.directional_shadow_mode` (`SHADOW_PARALLEL_4_SPLITS`), `directional_shadow_max_distance`, `directional_shadow_split_1..3`, `directional_shadow_blend_splits`, `directional_shadow_fade_start`, `directional_shadow_pancake_size` [S11]. Atlas: `rendering/lights_and_shadows/directional_shadow/size` (project: 4096) and `positional_shadow/atlas_size`, `atlas_quadrant_N_subdiv`, `atlas_16_bits`. Filter: `directional_shadow/soft_shadow_filter_quality` and `positional_shadow/soft_shadow_filter_quality` (`SHADOW_QUALITY_HARD`=0 … `SOFT_ULTRA`=5; runtime `RenderingServer.directional_soft_shadow_filter_set_quality()` / `positional_soft_shadow_filter_set_quality()`) [S5], [S9]. Soft High and Ultra also multiply the constant blur by 1.5× and 2× [S5 472:ProjectSettings.xml:3152-3155].

**Decals.** `Decal` (`size`, `texture_albedo/normal/orm/emission`, `emission_energy`, `albedo_mix`, `modulate`, `upper_fade`, `lower_fade`, `normal_fade`, `distance_fade_*`, `cull_mask`) for skid marks, puddles and grime; filter via `rendering/textures/decals/filter` [S11 Decal.xml], [S5].

**LOD, culling, CPU.** Tracks are procedural `ArrayMesh`es, so there are no import-time LODs. `ImporterMesh.generate_lods()` works in exported games because meshoptimizer is built into release templates ("Having this on release by default ... procedural stuff", 472:modules/meshoptimizer/config.py) [S37], [S11 ImporterMesh.xml:52-62]. Then `GeometryInstance3D.lod_bias`, `Viewport.mesh_lod_threshold` and `rendering/mesh_lod/lod_change/threshold_pixels` apply. Use `visibility_range_begin/end` for HLOD props. For downtown canyons, `rendering/occlusion_culling/use_occlusion_culling` + `OccluderInstance3D` with `BoxOccluder3D` per building (procedural) [S5], [S11].

**GPU particles.** `GPUParticles3D` (`amount`, `amount_ratio`, `fixed_fps`, `interpolate`, `trail_enabled/trail_lifetime`, `collision_base_size`, `sub_emitter`, `transform_align`) [S11 GPUParticles3D.xml]. Rain splashes via a `GPUParticlesCollisionHeightField3D`. Scale with `amount_ratio` per preset.

**Compositor effects.** `Compositor.compositor_effects` and `CompositorEffect` (`effect_callback_type`: PRE_OPAQUE, POST_OPAQUE, POST_SKY, PRE_TRANSPARENT, POST_TRANSPARENT; `needs_motion_vectors`, `needs_normal_roughness`, `needs_separate_specular`, `access_resolved_color/depth`) [S11 CompositorEffect.xml]. Use them for speed-dependent motion blur (needs motion vectors), radial blur on nitro, lens flares and chromatic aberration. Each one is a RenderingDevice compute shader written in GLSL.

**HDR output.** `display/window/hdr/request_hdr_output` / `Window.hdr_output_requested` [S5 472:ProjectSettings.xml:987-989]. On Windows, 4.7.2's **Vulkan driver reports no HDR output support** (`SUPPORTS_HDR_OUTPUT` returns false under `WINDOWS_ENABLED`, 472:drivers/vulkan/rendering_device_driver_vulkan.cpp:7412-7417), while D3D12 reports it [S13]. HDR on Windows therefore means D3D12. Make it an opt-in "Graphics API: Direct3D 12 (HDR)" option (1.3).

### 1.3 Vulkan vs D3D12 on Windows

- 4.6+: "new Windows projects default to Direct3D 12 for more stable driver support and fewer platform quirks" [S3]. The engine-level default for `rendering/rendering_device/driver.windows` is still `"vulkan"`, and SpeedFest doesn't override it [S5 472:ProjectSettings.xml:3344-3348]. Keep `fallback_to_d3d12=true` (default) and `fallback_to_opengl3=true` (default; falls back to Compatibility, which `Settings.is_compat()` already handles) [S5 472:ProjectSettings.xml:3351].
- **Recommendation: Vulkan default.** It is required for fork path tracing (D3D12 RT stubs in both mainline and fork: 472:rendering_device_driver_d3d12.cpp:5517+, fork:…d3d12.cpp:5547-5600) and for Linux-CI shader baking. Offer D3D12 as a restart option. Persist it with `application/config/project_settings_override="user://engine.cfg"` (a user file that overrides project settings at startup [S5 472:ProjectSettings.xml:352-354]), writing `rendering/rendering_device/driver.windows="d3d12"` there. For testing, use `--rendering-driver d3d12` [S18].

### 1.4 Shader and pipeline stutter

- Ubershaders (4.4) and the pipeline cache (`rendering/rendering_device/pipeline_cache/enable`, default true) plus the shader cache (`rendering/shader_compiler/shader_cache/enabled`, default true) are automatic [S1], [S5].
- Precompilation "relies on the RenderingServer seeing evidence of all shaders, meshes, or rendering features at load-time". Material overrides can't be precompiled, and enabling MSAA or instancing VoxelGI at runtime triggers recompiles [S20]. **SpeedFest creates almost all materials in code**, so: (a) build a warm-up pass into the track loading screen that draws every track/car material once, off-screen, for at least one frame (the docs suggest exactly this [S20]); (b) don't change MSAA at runtime.
- **Shader baker**: export option `shader_baker/enabled` (default false) [S15 472:editor_export_platform_pc.cpp:49-51,70]. Facts from the source:
  1. It only runs when a RenderingDevice renderer is active (`_is_active` requires `RendererSceneRenderRD::get_singleton()`), so a `--headless` export silently skips baking [S14 472:shader_baker_export_plugin.cpp:56-59].
  2. It bakes for the preset's `rendering/rendering_device/driver` [S14 :61-63].
  3. It only customizes `Material` resources that are part of the export, plus engine and embedded shaders [S14 :276-294]. Bare `.gdshader` files that code wraps in `ShaderMaterial.new()` are **not** covered. Commit one `.tres` ShaderMaterial per game shader (e.g. `res://shaders/baked/*.tres`) so the baker sees them.
  4. Linux editors can bake Vulkan, not D3D12 (D3D12 baker platform is behind `#ifdef D3D12_ENABLED`, 472:editor/editor_node.cpp:9509-9513).
  The docs: the baker "will generally not resolve existing stutters" but cuts first-launch load time [S20].
- Monitor `Performance.PIPELINE_COMPILATIONS_CANVAS/MESH/SURFACE/DRAW/SPECIALIZATION`. Non-zero `DRAW` during a race is a bug [S11 Performance.xml], [S20].

### 1.5 3D physics interpolation (the "laggy" fix)

Exact API, 4.7.2:
- Project setting `physics/common/physics_interpolation` (bool, default false, read at startup; runtime toggle `SceneTree.physics_interpolation`). When it is on, `physics/common/physics_jitter_fix` is disabled automatically [S5 472:ProjectSettings.xml:2689-2693], [S10 SceneTree.xml:291].
- Per node: `Node.physics_interpolation_mode` (INHERIT/ON/OFF), `Node.reset_physics_interpolation()` (call it **after** moving the node), `Node3D.get_global_transform_interpolated()` (for `_process` code such as cameras; it creates an "interpolation pump" on first call) [S10 Node.xml:873-879,1061-1065; Node3D.xml:50-56].
- Cameras moved in `_process` should turn automatic interpolation off and follow an interpolated target [S19].
- Sub-tick time: `Engine.get_physics_interpolation_fraction()` [S10 Engine.xml:110-113]. MultiMesh per-instance helpers: `MultiMesh.reset_instance_physics_interpolation`, `set_buffer_interpolated` [S19].

State in SpeedFest (working tree, uncommitted at the time of writing): `project.godot` sets `common/physics_interpolation=true` and `common/physics_jitter_fix=0.0`; `Settings._ready` sets `get_tree().root.physics_interpolation_mode = OFF`; `Car._init` sets ON; `tests/race/test_interpolation.gd` checks camera, RemoteCar and GhostPlayer are OFF. Already correct: `ChaseCamera.update_camera` reads `target.get_global_transform_interpolated()` in `_process` (race/chase_camera.gd:123), and `Car.teleport()` calls `reset_physics_interpolation()` after moving (cars/car.gd:338-339). Still to do:
1. **Ghost.** `race.gd:384` calls `ghost_player.set_time(run_ticks * TICK_MS)` in `_process`, so the ghost only moves on ticks (steppy at 144 Hz). **Corrected (measured, section 7):** the body is drawn at lerp(previous tick, last tick, fraction), i.e. `1 - fraction` ticks *behind* `run_ticks`, so use `(run_ticks - (1 - fraction)) * TICK_MS` = `Car.display_tick_lag()`. Done in 9a47cc8.
2. **Wheels.** `Car` calls `visual.set_wheel_state()` per tick (cars/car.gd:1003), which writes `MultiMesh.set_instance_transform` (car_visual.gd:178,185). The wheel spin and suspension of the interpolated body therefore step at 60 Hz. Either compute them in `_process` from interpolated state, or use `MultiMesh.set_buffer_interpolated`.
3. **Respawns and camera cuts.** After teleporting, call `ChaseCamera.snap()` too (it exists, chase_camera.gd:96), so camera lag doesn't streak.
4. Keep physics at 60 Hz: ghosts, the AutoDriver and the network all use ticks.

### 1.6 Frame pacing

- `display/window/vsync/vsync_mode` (default 1) / `DisplayServer.window_set_vsync_mode()`: `VSYNC_DISABLED`=0, `ENABLED`=1, `ADAPTIVE`=2 (tears below refresh), `MAILBOX`=3 (uncapped, no tearing) [S5 472:ProjectSettings.xml:1107-1113], [S10 DisplayServer.xml:3432-3437]. `settings.gd` only toggles ENABLED/DISABLED today. Expose all four modes.
- `application/run/max_fps` / `Engine.max_fps`: with V-Sync Enabled on a VRR (G-Sync/FreeSync) monitor, cap slightly below refresh with `r - r*r/3600` (144 Hz → 138) [S5 472:ProjectSettings.xml:423-428], [S10 Engine.xml:315-318].
- `rendering/rendering_device/vsync/frame_queue_size` (default 2) and `swapchain_image_count` (default 3; 2 means lower latency but halving to 30 fps on misses) [S5 :3388-3396].
- `WINDOW_MODE_EXCLUSIVE_FULLSCREEN` "has less overhead" (on X11 it bypasses the compositor). Make it the default fullscreen mode on PC; `settings.gd` uses `WINDOW_MODE_FULLSCREEN` today [S10 DisplayServer.xml:3268-3283].
- Fork only: NVIDIA Reflex via `rendering/streamline/reflex_mode` (0 off, 1 on, 2 on+boost) and `reflex_frame_limit_us` (section 3.7).

### 1.7 PC presets (1080p–1440p, GTX 1060 → RTX 4080)

Measure everything with an in-game GPU timer: `RenderingServer.viewport_set_measure_render_time(vp_rid, true)` + `viewport_get_measured_render_time_gpu()` / `_cpu()` [S9 472:RenderingServer.xml:4105-4111], `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS`. On first launch, auto-pick a preset: `RenderingServer.get_video_adapter_type()` (integrated means Low), then a 3-second GPU-time benchmark on a demo flythrough.

| | **Low** | **Medium** | **High** | **Ultra** |
|---|---|---|---|---|
| Target (estimate) | GTX 1060 / RX 580, 1080p60 | GTX 1660S–RTX 2060, 1080p60–90 | RTX 3060 Ti–3070, 1440p60–100 / 1080p120 | RTX 4070 Ti–4080, 1440p120+ |
| `scaling_3d_mode` / scale | FSR (1.0) 0.77 | FSR2 1.0 at 1080p (=TAA), 0.77 at 1440p | FSR2 1.0, or 0.77 at 1440p high fps | FSR2 1.0 (native TAA) |
| `screen_space_aa` / `msaa_3d` | FXAA / off | none / off | none / off | SMAA optional / off |
| `anisotropic_filtering_level` | 4× (2) | 8× (3) | 16× (4) | 16× (4) |
| Sun/moon shadow | 2 splits, 80 m, atlas 2048, SOFT_VERY_LOW | 4 splits, 150 m, 2048, SOFT_LOW | 4 splits, 250 m, 4096, SOFT_MEDIUM, blend_splits | 4 splits, 350 m, 4096, SOFT_HIGH, `light_angular_distance` ≈0.5 (PCSS) |
| Positional shadows | none | 2 nearest lamps, atlas 2048 | 6 lamps, 4096, SOFT_LOW | 12 lamps, 4096 16-bit, SOFT_MEDIUM, `light_size` 0.1–0.3 m |
| Dynamic lights (`light_budget()`) | 16 | 48 | 96 | 160 |
| SSAO | off | LOW, half_size | MEDIUM | HIGH |
| SSIL | off | off | off | MEDIUM, half_size |
| SSR | off (probes only) | half_size, 48–64 steps | full res, 128 steps | full res, 256 steps |
| ReflectionProbes (ONCE, box) | 128 px | 256 | 256 | 512 (`reflection_size`) |
| Volumetric fog | off | off | on, 64×64, filter on | on, 128×128 |
| GI | none (sky ambient) | none | VoxelGI if cached data exists | VoxelGI; SDFGI option on open tracks (≤4 cascades, `gi/use_half_resolution`) |
| Glow / tonemap | on / AgX | on / AgX | on / AgX | on / AgX (+ HDR when D3D12) |
| Auto exposure | off | off | on | on |
| Particles (`amount_ratio`) | 0.3 (CPU) | 0.5 | 1.0 + collision | 1.0 + trails |
| Decals / motion blur | off / off | skids / off | on / low | on / on |
| `mesh_lod_threshold` / sky `radiance_size` | 2.0 / 128 | 1.0 / 256 | 1.0 / 256 | 0.75 / 512 |

Expected per-feature GPU cost, **(estimate)**, RTX 3070-class at 1440p. Multiply by roughly 2–2.5 for a GTX 1060 at 1080p. These follow the docs' relative ordering [S21]; the docs give no ms figures, so measure. SDFGI was developed on a GTX 1060 at a stable 60 fps in its demo scene [S34].

| Feature | Cost (estimate) |
|---|---|
| Sun PSSM 4 splits, 4096 | 1–2.5 ms (geometry-bound) |
| Each shadowed omni lamp (when updated) | 0.3–1 ms |
| SSAO medium / half | 0.5–1 / ~0.3 ms |
| SSIL medium half / full | 0.8–1.5 / 1.5–3 ms |
| SSR half 64 / full 256 | 0.4–0.8 / 1.5–3 ms |
| Volumetric fog 64² / 128² | 0.5–1 / 1.5–3 ms |
| SDFGI 4 cascades half-res | 2–4 ms + spikes at high camera speed [S21] |
| VoxelGI half-res | 1–2 ms |
| TAA / FSR2 native / SMAA / FXAA | 0.2–0.4 / 0.6–1.2 / 0.3–0.6 / ~0.1 ms |
| Glow | 0.3–0.7 ms |
| CompositorEffect motion blur | 0.3–0.8 ms |

Budgets: 16.7 ms at 60 fps, 8.3 ms at 120 fps. Keep about 25% headroom for rain particles and transparents.

---

## 2. Hardware ray tracing in mainline 4.7: exact status

- **Available:** an *experimental* low-level ray tracing API on `RenderingDevice`. It covers `blas_create`/`blas_build`, `tlas_create`/`tlas_build`, `raytracing_pipeline_create`, `raytracing_list_begin`/`bind_raytracing_pipeline`/`bind_uniform_set`/`set_push_constant`/`trace_rays`/`end`, hit SBT functions, shader stages `SHADER_STAGE_RAYGEN`/`ANY_HIT`/`CLOSEST_HIT`/`MISS`/`INTERSECTION`, and feature flags `SUPPORTS_RAYTRACING_PIPELINE`=12 and `SUPPORTS_RAY_QUERY`=11, both "currently only supported when using Vulkan" [S8 472:RenderingDevice.xml:25-37,811-931,2762-2774,2837-2846]. It came from GH-99119 (4.7 dev 1, "initial Vulkan ray-tracing work ... groundwork") [S25].
- **Not available:** the built-in renderer uses none of it. `Environment` and `ProjectSettings` have no RT reflections, GI or shadows (no `raytrac*`/`pathtrac*` members in 4.7.2 docs).
- **In 4.7.2 ray query never activates.** Vulkan requests `VK_KHR_acceleration_structure`, `deferred_host_operations` and `ray_tracing_pipeline`, but not `VK_KHR_ray_query` (472:rendering_device_driver_vulkan.cpp:584-587), so `SUPPORTS_RAY_QUERY` is effectively false. `master` (4.8 beta) now requests it (master …vulkan.cpp:599), but 4.8 beta 1 adds no RT render features [S24].
- **D3D12:** every RT entry point errors with "Ray tracing is not currently supported by the D3D12 driver" [S13].
- **What it allows for SpeedFest:** a custom `CompositorEffect` that builds its own BLAS/TLAS from the procedural track meshes and traces puddle/road reflections with a raygen shader (see the GDScript demo linked in [S25]). It has no access to the renderer's materials, lights or scene acceleration structure. That is a research project, not M7.

---

## 3. NVIDIA RTX fork (`NVIDIA-RTX/godot`, branch `nvidia-pt-dlss`)

### 3.1 What it is and its base
- One squashed commit, `135dff3887` (2026-07-24, NVIDIA author). `version.py` says **4.8.0 "dev"**. The README is stock Godot, with no NVIDIA docs; the documentation lives in the class reference XMLs. Branch `nvidia-pt-dlss-dev` is also 4.8-dev; `backport/nvidia-pt-dlss-4.6.3` and `worktree-dlss-fg-reflex` are 4.6.3-stable. All four expose the same `pathtracing_*`, `SCALING_3D_MODE_DLSS`=6, `frame_generation`, `rendering/pathtracing/*` and `rendering/streamline/*` names (checked via raw files).
- A third-party mirror reports the base as upstream master of 2026-06-23 [S32]. It includes 4.7 features (e.g. AreaLight3D debug draws in fork:scene/main/viewport.cpp:5392).
- **Path tracing is a variant of Forward+, not a new renderer name.** For `rendering_method == "forward_plus"` the compositor instantiates `RenderForwardClusteredPT` (fork:servers/rendering/renderer_rd/renderer_compositor_rd.cpp:385-391). Each frame it path traces only when the view's `Environment` has `pathtracing_enabled` and the device supports RT pipelines. Otherwise it calls the normal Forward+ path (fork:render_forward_clustered_pt.cpp:53-67, 497-501). It never path traces reflection-probe renders (`!is_reflection_probe`, :53-55).

### 3.2 How a project turns it on (exact names)
| Where | Name | Notes |
|---|---|---|
| `Environment` | `pathtracing_enabled` (bool, default false) | fork:doc/classes/Environment.xml:211-214 |
| | `pathtracing_samples_per_pixel` (int, default 1; 1–2 is enough with RR) | :219-222 |
| | `pathtracing_max_bounces` (int, default 3; **setter clamps to 1..8**, despite the doc mentioning 0) | :215-218, fork:scene/resources/environment.cpp:635-637 |
| | `pathtracing_denoiser` (`RenderingServer.PT_DENOISER_NONE`=0, `PT_DENOISER_DLSS_RAY_RECONSTRUCTION`=1, default 1) | :207-210, RenderingServer.xml:5998-6002 |
| | `pathtracing_debug_mode` (`Environment.RT_DEBUG_DISABLED`=0 … `RT_DEBUG_EMISSIVE`=21, `RT_DEBUG_BRDF_REJECTION`=22) | :203-206, 483-549 |
| `RenderingServer` | `environment_set_pathtracing(env, enable, debug_mode, samples_per_pixel, max_bounces, denoiser)`, `viewport_set_frame_generation(viewport, bool)` | RenderingServer.xml:1402-1411; rendering_server.cpp:2871 |
| `Viewport` | `scaling_3d_mode = SCALING_3D_MODE_DLSS` (**6**), `scaling_3d_scale` 0.5 Performance / 0.58 Balanced / 0.66 Quality / 1.0 DLAA | Viewport.xml:585-586 |
| | `frame_generation` (bool) | Viewport.xml:347-349; viewport.cpp:5406 |
| | `fsr_sharpness`: under DLSS it becomes the **NIS** sharpening amount (`/2`, NIS runs when > 0; default 0.2 means NIS at 0.1) | render_forward_clustered.cpp:1860; effects/dlss.cpp:533 |
| | debug draws `DEBUG_DRAW_DLSS_RR_DIFFUSE_ALBEDO`(29)…`_SPECULAR_HIT_DIST`(32), reconstructed depth | Viewport.xml:791-804 |
| Project settings | `rendering/scaling_3d/mode` gains `"NVIDIA DLSS:6"` | rendering_server.cpp:3782 |
| | `rendering/pathtracing/async_shader_compilation` (true), `use_shader_execution_reordering` (true, Ada+), `use_simple_shadows` (false; ray-query shadows, cheaper), `deformed_mesh_cache_ttl_frames` (60), `multimesh_blas_cache_ttl_frames` (3600), `multimesh_cache_cpu_transforms` (false), `multimesh_merged_blas_max_triangles` (65536) | ProjectSettings.xml:3258-3284; rendering_server.cpp:3829-3834; environment.cpp:1502 |
| | `rendering/streamline/dlss_preset` ("?", F…O), `dlss_ray_reconstruction_preset` ("?", D…O), `reflex_mode` (0/1/2), `reflex_frame_limit_us`, `streamline_log`, `streamline_imgui` | drivers/streamline/streamline.cpp:63-68 |
| Singleton `Streamline` | `get_capability(STREAMLINE_CAPABILITY_DLSS=0, _DLSS_G=1, _DLSS_RR=2, _REFLEX=3, _PCL=4, _NIS=5)`, `set_parameter(STREAMLINE_PARAM_REFLEX_MODE=0, _REFLEX_FRAME_LIMIT_US=1, _DLSS_PRESET=2, _DLSS_RR_PRESET=3, value)` | streamline.cpp:41-55; doc/classes/Streamline.xml |
| Node | `RTProceduralInstance3D` (AABB procedural geometry for PT) | doc/classes/RTProceduralInstance3D.xml |
| Command line | none to enable PT; debug only: `--raytracing-validation`, `--gpu-markers` | main/main.cpp:662,667 |

**The denoiser only runs inside the DLSS scaling pass.** RR guide buffers are passed only in the `SCALE_3D_DLSS` branch of `_render_3d_upscaling` (fork:render_forward_clustered.cpp:1843-1885), and the PT path calls it only when upscaling or TAA is active (render_forward_clustered_pt.cpp:474-485). So **path tracing without `scaling_3d_mode = 6` is undenoised 1-spp noise**. The third-party mirror reaches the same conclusion [S32].

### 3.3 Requirements
- **API: Vulkan only for path tracing.** It needs `VK_KHR_acceleration_structure` + `VK_KHR_ray_tracing_pipeline`, and optionally `VK_KHR_ray_query` and `VK_EXT_ray_tracing_invocation_reorder` (fork:drivers/vulkan/rendering_device_driver_vulkan.cpp:590-594,7650-7653). D3D12 has no RT (above). Streamline initializes for both Vulkan and D3D12 (fork:main/main.cpp:2703-2708), so DLSS SR could run on D3D12 but PT cannot.
- **GPU:** any GPU exposing RT pipelines can path trace, but **the only denoiser is DLSS RR, which needs an NVIDIA RTX GPU** (Environment.xml:208, RenderingServer.xml:6001-6002). itch: "An NVIDIA GPU is not required to run the path tracer ... Ray Reconstruction is currently required for denoising", and DLSS/DLAA/RR need RTX 20-series or newer [S27]. Frame Generation needs RTX 40+ [S33], [S32]. In practice this is **RTX 20+, with RTX 30/40 recommended**.
- **OS and driver:** Streamline is Windows-only: `use_streamline` defaults to on but is forced off on non-Windows platforms (fork:SConstruct:202,608-612). A Linux build of the fork can path trace with no denoiser, which is unusable. Streamline needs Win10 20H1 (19041)+ and, on NVIDIA, driver **512.15 or newer** [S30 README]. Use the current Game Ready driver.
- **DLLs:** `sl.interposer.dll` is loaded with `LoadLibraryA` from the exe directory (fork:drivers/streamline/streamline_context.cpp:74; drivers/vulkan/rendering_context_driver_vulkan.cpp:922-927). Without it you get "DLSS is not available because Streamline failed to initialize (sl.interposer.dll not found…)" (fork:servers/rendering/renderer_viewport.cpp:1061). The vendored headers are Streamline **2.10.0** (fork:thirdparty/streamline/include/sl_version.h). Use the v2.10.0 release zip [S30], whose `bin/x64` contains `sl.interposer.dll`, `sl.common.dll`, `sl.dlss.dll`, `nvngx_dlss.dll`, `sl.dlss_d.dll`, `nvngx_dlssd.dll`, `sl.dlss_g.dll`, `nvngx_dlssg.dll`, `sl.reflex.dll`, `sl.pcl.dll`, `sl.nis.dll`, `NvLowLatencyVk.dll` and the `*.license.txt` files.
- **Editor vs game:** FG, Reflex and PCL load only when not in the editor or project manager (`STREAMLINE_GAME_ONLY`, streamline_context.cpp:171-228, 328-350). Test FG in the running game, not the editor viewport.

### 3.4 Does a 4.7 project open in it?
Yes. The project manager warns "This project was last edited in Godot 4.7. Opening will change it to Godot 4.8" (fork:editor/project_manager/project_manager.cpp:689) and rewrites `config/features`. **Use a separate clone, never committed**, because the game repo must stay 4.7.2. Path tracing doesn't need a project setting to be present; SpeedFest builds its `Environment` in code.

### 3.5 What path tracing does not support (from the code)
- **Compatibility and Mobile renderers** (PT lives in `RenderForwardClusteredPT` only). The web build is unaffected.
- **Bypassed:** SDFGI, SSR, SSAO, SSIL and shadow maps (Environment.xml:213). The PT path frees the SSIL/SSAO/SSR buffers (render_forward_clustered_pt.cpp:120-122) and forces `voxel_gi_count = 0` (:83), so VoxelGI is off too.
- **Volumetric fog / FogVolume:** the PT path has no volumetric pass. Only the regular exponential/depth `fog_*` is applied per ray segment (fork:shaders/raytracing/raytracing_closest_hit_common_inc.glsl:239-259,455-456). Third-party coverage also lists volumetrics and decals as future work [S28].
- **GPUParticles3D:** never enters the TLAS, because only `INSTANCE_MESH`/`INSTANCE_MULTIMESH` are collected (fork:servers/rendering/renderer_scene_cull.cpp:3330-3334). The opaque raster list isn't built under PT; only the alpha list is (pt.cpp:150-152). **Alpha or additive particles still draw as a raster overlay. Opaque GPU particles vanish.** `CPUParticles3D` (MultiMesh-based) is path traced.
- **Transparent / alpha-blend / additive materials** are rasterized *on top* of the PT image with ordinary clustered lighting (pt.cpp:113-119, 234-249). They are not reflected and do not refract. There is no glass.
- **Decals:** no decal code in the RT shaders (grep), so they don't show on path-traced surfaces.
- **Lights:** only Omni, Spot and Directional (fork:render_raytracing.h:119-123). **AreaLight3D is ignored.** At most **64 lights per frame** (48 in-frustum + 16 indirect budget, render_raytracing.h:145-147), ranked by `energy × luminance × range² / dist²` with a penalty behind the camera (render_raytracing.cpp:2815-2848,2895-2900). The light struct has no shadow flags (render_raytracing.h:125-141), so `shadow_enabled` and projectors are ignored and every PT light casts traced shadows. Soft shadows come from `light_size` (omni/spot) and the directional size (render_raytracing.cpp:2871,2919).
- **Material model:** albedo, normal map, ORM, metallic, roughness, specular, emission and uv1 scale/offset (fork:shaders/raytracing/raytracing_data_inc.glsl:85-105). Custom `ShaderMaterial`s run their `vertex()` + `fragment()` in RT hit groups, but only `ALBEDO`, `ALPHA`, `METALLIC`, `ROUGHNESS`, `SPECULAR`, `EMISSION`, `NORMAL`/`NORMAL_MAP` reach the BRDF (scene_raytracing_raygen.glsl:363-391). `CLEARCOAT`, `ANISOTROPY`, `RIM`, `BACKLIGHT` and SSS are declared but not consumed (raytracing_custom_fragment_inc.glsl:70-91). Custom `light()` is only wired for procedural instances (scene_shader_raytracing.cpp:573-576). **`render_mode unshaded` sets `MODE_UNSHADED` (scene_shader_raytracing.cpp:1642), but no RT shader reads it.** An unshaded neon shader that writes `ALBEDO` therefore becomes lit "paint" under PT. Inference: `vertex()` runs at hit time to compute varyings, so `VERTEX` displacement wouldn't move the traced triangles. SpeedFest's shaders don't displace vertices.
- **DLSS history is never reset.** `params.reset_accumulation = false; // FIXME` (render_forward_clustered.cpp:1874). Respawns and camera cuts will smear for a few frames.
- Pre-opaque compositor effects can't access resolved colour or depth under PT (pt.cpp:303-306). PT hit shaders compile asynchronously with a fallback material, so the first frames can show artifacts (`rendering/pathtracing/async_shader_compilation`).
- Maturity: "in development" [S27]; reports say frame rates "aren't great" [S28].

### 3.6 Materials, lights and sky for good PT results
- **Emissive surfaces only add light when a path hits them.** They get no direct light sampling: NEE samples the light list (closest_hit_common_inc.glsl:458-459; raytracing_lights_inc.glsl:253-301). Small bright emitters create noise that RR has to clean up. For neon that should light the road, keep the emissive mesh *and* add an `OmniLight3D`/`SpotLight3D` with `light_size` 0.1–0.5 m.
- **Light units carry over.** Energy uses rasterizer conventions: ×π in non-physical units, or lumens ×1/(4π) for omni and ×1/π for spot with `use_physical_light_units`, times exposure normalization (render_raytracing.cpp:2783-2799). Emission is scaled by `emissive_exposure_normalization` (raygen.glsl:382). Existing `light_energy` and `EMISSION` values stay meaningful.
- **Sky:** there is no raster sky draw in the PT path. Primary misses return the sky's **radiance map sampled at LOD 0** (scene_raytracing_raygen.glsl:181-247). The visible sky resolution is therefore `Sky.radiance_size`; SpeedFest uses 256 on Forward+ (scenery_env.gd `_build`). Under PT, raise it to `Sky.RADIANCE_SIZE_1024`/`2048`. This is cheap because `env_sky.gdshader` is static (no TIME); `PROCESS_MODE_REALTIME` would cap it at 256 [S11 Sky.xml:57-59].
- Wet road: low `ROUGHNESS` gives real reflections. **Disable the fake reflections** (puddle `sheen`, road `tunnel_fake`, car-paint `night_rim`). Set `pathtracing_max_bounces` to 2 (3 on RTX 4080), with spp 1.
- Fog: exponential fog works. Turn volumetric fog off under PT.

### 3.7 DLSS / RR / FG / Reflex options
- **DLSS SR / DLAA** in raster mode (the fork without PT): `scaling_3d_mode=6` with `scaling_3d_scale` <1 for SR and 1.0 for DLAA. The fork picks the closest of DLAA, MaxQuality, Balanced, MaxPerformance and UltraPerformance (effects/dlss.cpp:63-141).
- **Ray Reconstruction** is used automatically when PT plus `PT_DENOISER_DLSS_RAY_RECONSTRUCTION` is active and the capability is present (dlss.cpp:512-528). Preset via `rendering/streamline/dlss_ray_reconstruction_preset`.
- **Frame Generation (DLSS-G):** `Viewport.frame_generation = true`. Only active in-game, when `STREAMLINE_CAPABILITY_DLSS_G` is true, and inside the DLSS pass (render_forward_clustered.cpp:1867; dlss.cpp:478-509). RTX 40+.
- **Reflex:** `rendering/streamline/reflex_mode` 0/1/2 or `Streamline.set_parameter(STREAMLINE_PARAM_REFLEX_MODE, v)`; `reflex_frame_limit_us` gives a low-latency fps cap (streamline.cpp:85-88,186-208).
- **NIS sharpening:** `Viewport.fsr_sharpness` (0 = off) under DLSS.

### 3.8 Licensing and redistribution
- Fork engine code: MIT (the Godot license header on the NVIDIA files, e.g. fork:drivers/streamline/streamline.cpp:1-29; [S28]).
- Streamline `sl.*.dll` and headers: MIT (license.txt), except the NSight Perf parts (`sl_nvperf.*`) [S30].
- **DLSS runtime (`nvngx_dlss*.dll`) is under the NVIDIA RTX SDKs license** [S31]:
  - You may distribute it "as incorporated in object code format into a software application"; the application must have "material additional functionality"; no stand-alone distribution.
  - You may not make it "subject to an open source software license".
  - **Notify NVIDIA before a commercial release** (https://developer.nvidia.com/sw-notification).
  - For DLSS apps, attribute and "include the NVIDIA Marks on splash screens, in the about box ..., and in credits".
  - Applications must be interoperable with NVIDIA GPUs.
- **Practical rule for this public MIT repo: never commit the DLLs.** Download Streamline v2.10.0 when packaging, and ship the DLLs next to the exe with the `*.license.txt` files from `bin/x64`. Add "NVIDIA DLSS" credits to the RTX build. The Streamline guide also says to ship only the signed production DLLs from `bin/x64` and never the `development` ones [S30 README:35; ProgrammingGuide:98-107,1434-1450]. The fork enables OTA updates (`eAllowOTA | eLoadDownloadedPlugins`, streamline_context.cpp:364).

### 3.9 Prebuilt binaries
- **NVIDIA ships none.** "No compiled binaries are provided, so users must build from source" [S28].
- **itch "Godot RTX" (johnlogostini.itch.io/godot-rtx):** pay what you want. Windows 64-bit zip (121 MB), Linux 64-bit (77 MB), source; "in development"; built from `nvidia-pt-dlss-dev`. The page says nothing about export templates or bundled Streamline DLLs [S27]. The uploader also posted an "Attic" demo ported to 4.7 [S29].
- **bailaiOWO/rtx-godot** (third party, "not affiliated with NVIDIA"): ships a Windows editor zip with the Streamline DLLs and `D3D12Core.dll`. No export templates [S32].
- **Nobody ships export templates.** Build them (3.10).

### 3.10 Building the fork for Windows
Requirements (Godot docs): VS 2022 recommended (2019+), Python 3.9+, SCons 4.4+. D3D12, AccessKit and ANGLE deps come from `misc/scripts/install_*.py`, or are skipped with `d3d12=no`, `accesskit=no`, `angle=no` [S22]. In the fork, Windows defaults to `d3d12=True` (fork:platform/windows/detect.py:297) and auto-disables AccessKit if its SDK is missing (detect.py:476-504).
```bat
:: "x64 Native Tools Command Prompt for VS 2022"
pip install scons
git clone --depth 1 --branch nvidia-pt-dlss https://github.com/NVIDIA-RTX/godot C:\dev\godot-rtx
cd C:\dev\godot-rtx
:: optional: python misc\scripts\install_accesskit.py
scons platform=windows target=editor           arch=x86_64 d3d12=no use_streamline=yes
scons platform=windows target=template_release arch=x86_64 d3d12=no use_streamline=yes production=yes
scons platform=windows target=template_debug   arch=x86_64 d3d12=no use_streamline=yes
:: outputs: bin\godot.windows.editor.x86_64.exe, bin\godot.windows.template_release.x86_64.exe, bin\godot.windows.template_debug.x86_64.exe (+ *.console.exe)
:: then copy streamline-sdk-v2.10.0\bin\x64\*.dll (+ *.license.txt) next to EACH exe
```
`d3d12=no` is safe because PT is Vulkan-only and SpeedFest uses Vulkan. Optional: `use_aftermath=yes` (downloads the Nsight Aftermath SDK, Windows only; SConstruct:203,614-640).

---

## 4. SpeedFest integration design

### 4.1 Runtime detection (compiles unchanged on mainline 4.7.2)
Every API below exists in 4.7.2: `ClassDB.class_has_method/class_has_integer_constant/class_get_integer_constant`, `Engine.has_singleton/get_singleton`, `RenderingServer.get_current_rendering_driver_name/get_rendering_device`, `RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE` [S11 ClassDB.xml:59,167,175], [S9:1635-1663]. Fork identifiers are only touched through strings.
```gdscript
# autoload/settings.gd (sketch)
var rtx_path_tracing := false   # [video] rtx_pt
var rtx_bounces := 2            # [video] rtx_bounces
var upscaler := 0               # 0 TAA/native, 1 FSR2, 2 DLSS (fork only)
var dlss_scale := 0.67          # 1.0 DLAA, 0.67 Q, 0.58 B, 0.5 P
var dlss_frame_gen := false
var reflex_mode := 1

func is_rtx_fork() -> bool:
	return ClassDB.class_has_method(&"Environment", &"set_pathtracing_enabled")

func _sl() -> Object:
	return Engine.get_singleton(&"Streamline") if Engine.has_singleton(&"Streamline") else null

func _sl_const(n: StringName) -> int:
	return ClassDB.class_get_integer_constant(&"Streamline", n) if ClassDB.class_has_integer_constant(&"Streamline", n) else -1

func _sl_cap(n: StringName) -> bool:
	var sl := _sl()
	var c := _sl_const(n)
	return sl != null and c >= 0 and bool(sl.call(&"get_capability", c))

func dlss_available() -> bool:   # false on mainline, Linux fork builds, missing DLLs, non-RTX
	return is_rtx_fork() and not is_compat() and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS")

func can_path_trace() -> bool:
	if not is_rtx_fork() or is_compat():
		return false
	if RenderingServer.get_current_rendering_driver_name() != "vulkan":
		return false   # fork D3D12 driver has no RT
	var rd := RenderingServer.get_rendering_device()
	return rd != null and rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE) \
		and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS_RR")   # the only denoiser today
```
Note: `Engine.has_singleton("Streamline")` alone is only a fork marker. It is registered unconditionally (fork:main/main.cpp:1091-1093), and `get_capability` returns false when Streamline wasn't compiled in or didn't load (streamline.cpp:262-288).

### 4.2 Applying it
```gdscript
func _apply_viewport_upscaler(vp: Viewport) -> void:
	var pt := rtx_path_tracing and can_path_trace()
	if (pt or upscaler == 2) and dlss_available():
		var dlss := ClassDB.class_get_integer_constant(&"Viewport", &"SCALING_3D_MODE_DLSS")   # 6
		vp.scaling_3d_mode = dlss as Viewport.Scaling3DMode
		vp.scaling_3d_scale = dlss_scale
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = false
		vp.fsr_sharpness = 0.0                     # NIS off unless the player wants it
		vp.set(&"frame_generation", dlss_frame_gen and _sl_cap(&"STREAMLINE_CAPABILITY_DLSS_G"))
		if _sl_cap(&"STREAMLINE_CAPABILITY_REFLEX"):
			_sl().call(&"set_parameter", _sl_const(&"STREAMLINE_PARAM_REFLEX_MODE"), reflex_mode)
	# else: the mainline preset path (FSR2/TAA/SMAA)

## call at the END of tune_environment()
func _apply_path_tracing(env: Environment) -> void:
	if not is_rtx_fork():
		return
	var pt := rtx_path_tracing and can_path_trace() and dlss_available()
	env.set(&"pathtracing_enabled", pt)
	if not pt:
		return
	env.set(&"pathtracing_samples_per_pixel", 1)
	env.set(&"pathtracing_max_bounces", rtx_bounces)
	env.set(&"pathtracing_denoiser", 1)   # RenderingServer.PT_DENOISER_DLSS_RAY_RECONSTRUCTION
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
```
UI (`ui/settings_menu.gd`, PC only, an extra "RTX" block shown only when `can_path_trace()` / `dlss_available()`): "RTX path tracing (experimental)" on/off; "Bounces" 1/2/3; "DLSS" DLAA/Quality/Balanced/Performance; "Frame Generation" (only if `DLSS_G`); "Reflex" Off/On/Boost (only if `REFLEX`). Persist under `[video]` in `user://settings.cfg`. Add a `TestHooks` arg `--rtx` so scenes can force it on the fork.

### 4.3 Scene changes when PT is on (file by file)
- `tracks/scenery/scenery_env.gd`: in `retune()`, after `Settings.tune_environment(env)`, set `env.sky.radiance_size = Sky.RADIANCE_SIZE_1024` (2048 on 4080-class) under PT, and 256 otherwise. Skip `_quality_extras()`' SSR step tuning under PT. In `_sun_extras()`, give the moon/sun a small `light_angular_distance` (≈0.5–1°) for soft traced shadows.
- Lights (`city_kit.gd:627` spot lamps, `arena_kit.gd:431` floods, `track_builder.gd:1227`, `track.gd:229`, `car_visual.gd` headlights/underglow): set `light_size` 0.1–0.3 under PT. Remember the 64-light cap ranked by energy/range/distance. Shadow flags don't matter under PT. Lights that only exist to fake bounce can be dropped.
- Particles: rain (`scenery_rain.gd`, alpha `StandardMaterial3D`) and nitro/sparks stay as raster overlays, which is fine. Never use *opaque* `GPUParticles3D` under PT, or switch them to `CPUParticles3D`.
- Respawn and camera cycle: run a 0.1–0.2 s fade (or the existing flash) to hide DLSS history smear (no reset API, 3.5).
- Decals: under PT they won't show on opaque surfaces. Puddles are already geometry (`track_puddle.gdshader`).
- Glow, tonemap, exposure and exponential fog keep working (post-process is shared: pt.cpp:487-491).

### 4.4 Shader `#if defined(RT)` patches
The fork preprocesses every shader twice, the second time with `RT` defined (fork:scene/resources/shader.cpp:113-118). Mainline never defines `RT`.
```glsl
// env_neon.gdshader (same idea: track_neon, track_stripes, track_chevron, env_screen)
void fragment() {
#if defined(RT)
	ALBEDO = vec3(0.0);                 // `unshaded` is ignored by the path tracer
	EMISSION = COLOR.rgb * energy * k;  // real emitter (pair it with a light for road spill)
#else
	ALBEDO = COLOR.rgb * energy * k;
#endif
}
```
- `road.gdshader:146` (tunnel fake bounce): wrap in `#if !defined(RT)`.
- `track_puddle.gdshader:76-82`: under RT drop `refl * fres * sheen` and keep only the rim glow. The real reflection comes from `ROUGHNESS` 0.015.
- `car_paint.gdshader:338-343` (`night_rim` fake sheen): `#if !defined(RT)`. Clearcoat isn't path traced, so fold coat gloss into `ROUGHNESS` under RT.
- Additive shaders (`car_flame`, `car_glow`, `env_glow`, `track_boost`) need no change: they go to the raster overlay.

### 4.5 Owner step-by-step (Windows PC with an RTX card)
1. Update to the latest NVIDIA Game Ready driver (Streamline needs at least 512.15 [S30]). Windows 10 20H1+ or 11.
2. Get an RTX editor: either the itch "Godot RTX" Windows zip [S27], or build it (3.10).
3. Download https://github.com/NVIDIA-RTX/Streamline/releases/download/v2.10.0/streamline-sdk-v2.10.0.zip and copy `bin\x64\*.dll` (not `development\`) next to the editor exe, unless they are already there.
4. `git clone https://github.com/khanhonthetrack/speedfest C:\dev\speedfest-rtx`. This is a separate folder: never commit or push from it.
5. Start the RTX editor → Import → `C:\dev\speedfest-rtx\game\project.godot` → accept "last edited in Godot 4.7 … change it to 4.8". Wait for the import. Check Project Settings: Renderer = Forward+, `rendering_device/driver.windows` = vulkan.
6. Check the Output panel for the error "DLSS is not available because Streamline failed to initialize…". If it appears, the DLLs aren't next to the exe.
7. Play (F5). Settings → Graphics → RTX → enable path tracing and pick DLSS Quality. Until 4.2 is merged, run the editor exe with `--path C:\dev\speedfest-rtx\game -- --rtx` instead.
8. Test Neon Downtown in rain at 250+ km/h at 1080p with DLSS Quality and Performance. Write down fps, ghosting, neon spill, puddles, rain overlay, and respawn smear. Send screenshots. This is the go/no-go for the RTX mode.
9. To give the RTX build to friends: build templates (3.10). In the fork editor, add a "Windows RTX" preset (a copy of Windows with `custom_template/release` set to `godot.windows.template_release.x86_64.exe`). Export, copy the Streamline DLLs and `*.license.txt` next to `SpeedFest.exe`, add NVIDIA DLSS credits, and zip it.

---

## 5. Desktop export

### 5.1 `game/export_presets.cfg` (4.7.2 keys)
Preset-level keys the 4.7.2 exporter writes: `name, platform, dedicated_server, custom_features, export_filter, include_filter, exclude_filter, export_path, patches, patch_delta_*, encryption_include_filters, encryption_exclude_filters, seed, encrypt_pck, encrypt_directory, script_export_mode`. `runnable` is only read as a legacy key (472:editor/export/editor_export.cpp:60-104,333-338). PC options come from 472:editor_export_platform_pc.cpp:58-71: `custom_template/debug|release`, `debug/export_console_wrapper` (No/Debug Only/Debug and Release), `binary_format/embed_pck`, `texture_format/s3tc_bptc`, `texture_format/etc2_astc`, `shader_baker/enabled`, plus `binary_format/architecture`. Windows-only options (472:platform/windows/export/export_plugin.cpp:474-487) are `codesign/*`, `application/modify_resources`, `application/icon` (empty means `application/config/icon` is used, converted to .ico: :515-539), `console_wrapper_icon`, `icon_interpolation`, `file_version`/`product_version` (must be 4 integers `a.b.c.d`, no `-`: :392-408), `company_name`, `product_name`, `file_description`, `copyright`, `trademarks`, `export_angle` (Auto/Yes/No), `export_d3d12` (Auto/Yes/No), and `d3d12_agility_sdk_multiarch`.
```ini
[preset.1]
name="Linux"
platform="Linux"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, web/*"
export_path="../build/linux/speedfest.x86_64"
script_export_mode=2

[preset.1.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
shader_baker/enabled=true
binary_format/architecture="x86_64"

[preset.2]
name="Windows"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, web/*"
export_path="../build/windows/SpeedFest.exe"
script_export_mode=2

[preset.2.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
shader_baker/enabled=true
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=true
application/icon=""                      ; falls back to res://icon.svg; better: a 256 px PNG/ICO
application/icon_interpolation=4
application/file_version="0.7.0.0"
application/product_version="0.7.0.0"
application/company_name="SpeedFest"
application/product_name="SpeedFest"
application/file_description="SpeedFest - arcade stunt time-attack racer"
application/copyright=""
application/trademarks=""
application/export_angle=0
application/export_d3d12=0
application/d3d12_agility_sdk_multiarch=true
```
- There is **no per-preset renderer or driver key**. The driver comes from project settings with feature overrides (`rendering/rendering_device/driver.windows`). Leave it at Vulkan.
- S3TC/BPTC also needs `rendering/textures/vram_compression/import_s3tc_bptc=true`, which `project.godot` already has.
- `shader_baker/enabled=true` is harmless in headless CI (it silently skips) and bakes under Xvfb (5.2).
- The official templates ship no `D3D12Core*.dll` or ANGLE DLLs (tpz listing [S23]), so `export_d3d12`/`export_angle` copy nothing and D3D12 uses the system runtime.
- Windows icon and version resources are patched natively by `TemplateModifier` (export_plugin.cpp:539), which also works on Linux CI. Leave codesigning off.

### 5.2 GitHub Actions: `.github/workflows/desktop.yml`
Release asset names were verified from `SHA512-SUMS.txt` [S23]: `Godot_v4.7.2-stable_linux.x86_64.zip`, `Godot_v4.7.2-stable_export_templates.tpz` (1,281,349,702 bytes). The tpz contains `templates/linux_{debug,release}.x86_64`, `templates/windows_{debug,release}_x86_64.exe`, `templates/windows_{debug,release}_x86_64_console.exe`, `templates/icudt_godot.dat` and `templates/version.txt`. The CLI `<path>` "should be absolute or relative to the project directory", and "The target directory must exist" (472:main/main.cpp:701-703).
```yaml
name: Desktop builds
on:
  push:
    branches: [main]
    tags: ["v*"]
  workflow_dispatch:
    inputs:
      bake_shaders:
        description: "Bake Vulkan shaders (editor under Xvfb + lavapipe)"
        type: boolean
        default: false
permissions:
  contents: write            # create/upload the Release on tags
concurrency:
  group: desktop-${{ github.ref }}
  cancel-in-progress: true
env:
  GODOT_VERSION: "4.7.2"
  GODOT_STATUS: "stable"
jobs:
  export:
    runs-on: ubuntu-24.04
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4

      - name: Cache Godot + templates
        id: godot-cache
        uses: actions/cache@v4
        with:
          path: |
            ~/godot-bin
            ~/.local/share/godot/export_templates/4.7.2.stable
          key: godot-4.7.2-stable-linux64-templates-v1

      - name: Download Godot 4.7.2 + export templates (verified)
        if: steps.godot-cache.outputs.cache-hit != 'true'
        run: |
          set -euo pipefail
          TAG="${GODOT_VERSION}-${GODOT_STATUS}"
          BASE="https://github.com/godotengine/godot/releases/download/${TAG}"
          EDITOR="Godot_v${TAG}_linux.x86_64"
          TPZ="Godot_v${TAG}_export_templates.tpz"
          mkdir -p ~/godot-dl ~/godot-bin && cd ~/godot-dl
          curl -fsSL --retry 5 -O "$BASE/SHA512-SUMS.txt"
          curl -fsSL --retry 5 -O "$BASE/${EDITOR}.zip"
          curl -fsSL --retry 5 -C - -O "$BASE/${TPZ}"
          grep -E "  (${EDITOR}\.zip|${TPZ})$" SHA512-SUMS.txt | sha512sum -c -
          unzip -o "${EDITOR}.zip" -d ~/godot-bin && chmod +x ~/godot-bin/${EDITOR}
          TPL=~/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_STATUS}
          mkdir -p "$TPL"
          unzip -j -o "${TPZ}" 'templates/version.txt' 'templates/icudt_godot.dat' \
            'templates/linux_*.x86_64' 'templates/windows_*_x86_64*.exe' -d "$TPL"
          ls -la "$TPL"; rm -rf ~/godot-dl

      - name: Godot on PATH
        run: echo "GODOT=$HOME/godot-bin/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64" >> "$GITHUB_ENV"

      - name: Import
        run: '"$GODOT" --headless --path game --import'

      - name: Vulkan (lavapipe) + Xvfb for shader baking
        if: inputs.bake_shaders || startsWith(github.ref, 'refs/tags/v')
        run: sudo apt-get update && sudo apt-get install -y mesa-vulkan-drivers xvfb

      - name: Export Windows + Linux
        run: |
          set -euo pipefail
          mkdir -p build/windows build/linux
          if [[ "${{ inputs.bake_shaders }}" == "true" || "$GITHUB_REF" == refs/tags/v* ]]; then
            RUN=(xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver vulkan)   # baker needs an RD renderer
          else
            RUN=("$GODOT" --headless)                                                       # baker silently skipped
          fi
          "${RUN[@]}" --path game --export-release "Windows" ../build/windows/SpeedFest.exe
          "${RUN[@]}" --path game --export-release "Linux"   ../build/linux/speedfest.x86_64
          test -s build/windows/SpeedFest.exe && test -s build/linux/speedfest.x86_64

      - name: Package
        run: |
          set -euo pipefail
          VER="${GITHUB_REF_NAME//\//-}"
          mkdir -p dist
          (cd build/windows && zip -9 -r "../../dist/SpeedFest-${VER}-windows-x86_64.zip" .)
          tar -C build/linux -czf "dist/SpeedFest-${VER}-linux-x86_64.tar.gz" .   # keeps the +x bit

      - uses: actions/upload-artifact@v4
        with:
          name: speedfest-desktop-${{ github.ref_name }}
          path: dist/*

      - name: GitHub Release (tags only)
        if: startsWith(github.ref, 'refs/tags/v')
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release view "$GITHUB_REF_NAME" >/dev/null 2>&1 \
            && gh release upload "$GITHUB_REF_NAME" dist/* --clobber \
            || gh release create "$GITHUB_REF_NAME" dist/* --title "SpeedFest $GITHUB_REF_NAME" --generate-notes
```
Notes: Linux is packaged as a tar.gz so the executable bit survives (artifact zips drop file modes). The Xvfb plus `mesa-vulkan-drivers` path is the same software-Vulkan setup CLAUDE.md already uses for screenshots. The RTX build is **not** built in CI: it needs MSVC, a fork build and NVIDIA DLLs that can't go into the public repo. Build it locally (3.10, 4.5 step 9).

---

## 6. Implementation order (sequential, push after each step)
1. Finish physics interpolation (1.5 items 1–3), then make `test_interpolation` and the visual smoothness checks pass. Frame pacing options: V-Sync 4 modes, FPS cap with VRR formula, exclusive fullscreen.
2. Kill stutter: `msaa_3d=0` in project.godot, no runtime MSAA, a material warm-up at track load, `.tres` wrappers for the baker, and a HUD for `PIPELINE_COMPILATIONS_DRAW`.
3. PC presets (1.7) in `Settings.tune_environment`/`apply` (global RS knobs: SSR half size, SSAO/SSIL quality, fog volume size, shadow filter), AgX re-grade per theme, lights next to neon, probes per sector. Screenshots on each preset.
4. Desktop presets and CI (5.1, 5.2), then tag `v0.7.0` and smoke-test the Windows zip on the owner's PC.
5. RTX: detection plus options (4.1–4.2), `#if defined(RT)` shader branches (4.4), scene changes (4.3). Owner test on the fork (4.5). Decide from footage.
6. Later: VoxelGI per-track cache, CompositorEffect motion blur, AreaLight3D neon on Ultra, D3D12 + HDR option.

---

## Sources
- [S1] https://godotengine.org/releases/4.4/  [S2] https://godotengine.org/releases/4.5/  [S3] https://godotengine.org/releases/4.6/  [S4] https://godotengine.org/releases/4.7/
- [S5] https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml
- [S6] …/4.7.2-stable/doc/classes/Environment.xml  [S7] …/Viewport.xml  [S8] …/RenderingDevice.xml  [S9] …/RenderingServer.xml
- [S10] …/Node.xml, Node3D.xml, Engine.xml, SceneTree.xml, DisplayServer.xml
- [S11] …/Light3D.xml, AreaLight3D.xml, VoxelGI.xml, LightmapGI.xml, Sky.xml, ReflectionProbe.xml, Decal.xml, GeometryInstance3D.xml, ImporterMesh.xml, GPUParticles3D.xml, Compositor(Effect).xml, CameraAttributes*.xml, Performance.xml, ClassDB.xml
- [S12] https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/drivers/vulkan/rendering_device_driver_vulkan.cpp
- [S13] …/4.7.2-stable/drivers/d3d12/rendering_device_driver_d3d12.cpp
- [S14] …/4.7.2-stable/editor/export/shader_baker_export_plugin.cpp (+ editor/editor_node.cpp:9500-9519)
- [S15] …/4.7.2-stable/editor/export/editor_export_platform_pc.cpp  [S16] …/platform/windows/export/export_plugin.cpp, template_modifier.cpp  [S17] …/editor/export/editor_export.cpp  [S18] …/main/main.cpp
- [S19] https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html , …/advanced_physics_interpolation.html
- [S20] https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html
- [S21] https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html , …/using_sdfgi.html
- [S22] https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_windows.html
- [S23] https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt (and a zip central-directory listing of the .tpz)
- [S24] https://raw.githubusercontent.com/godotengine/godot/master/drivers/vulkan/rendering_device_driver_vulkan.cpp (line 599); https://godotengine.org/article/dev-snapshot-godot-4-8-beta-1/
- [S25] https://www.phoronix.com/news/Godot-4.7-Dev-1-Vulkan-RT (GH-99119); demo https://github.com/Fahien/godot-raytracing-gdscript-demo (via https://ziva.sh/blogs/godot-ray-tracing)
- [S26] NVIDIA fork clone (local, not committed) @135dff3887; other branches via https://raw.githubusercontent.com/NVIDIA-RTX/godot/<branch>/...
- [S27] https://johnlogostini.itch.io/godot-rtx  [S28] https://www.cgchannel.com/2026/03/get-nvidias-new-path-tracing-fork-of-the-godot-game-engine/  [S29] https://forum.godotengine.org/t/godot-rtx-nvidia-fork-path-tracing/135657
- [S30] https://raw.githubusercontent.com/NVIDIA-RTX/Streamline/main/README.md , …/docs/ProgrammingGuide.md , …/license.txt ; https://github.com/NVIDIA-RTX/Streamline/releases/download/v2.10.0/streamline-sdk-v2.10.0.zip
- [S31] https://raw.githubusercontent.com/NVIDIA/DLSS/main/LICENSE.txt (identical text ships as bin/x64/nvngx_dlss.license.txt)
- [S32] https://raw.githubusercontent.com/bailaiOWO/rtx-godot/main/README.md (third party, not NVIDIA)
- [S33] https://www.techradar.com/gaming/nvidias-ai-takes-gaming-to-new-heights-with-dlss-35-and-ray-reconstruction ; https://www.igorslab.de/en/nvidia-optimizes-dlss-frame-generation-for-rtx-40-gpus-less-vram-consumption-and-higher-performance/
- [S34] https://godotengine.org/article/godot-40-gets-sdf-based-real-time-global-illumination/
- [S36] https://gamedev.net/news/5172-godot-engine-472-stable-released/ (secondary, dates only)
- [S37] https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/meshoptimizer/config.py
- SpeedFest files read: game/project.godot, game/autoload/settings.gd, game/tracks/scenery/scenery_env.gd, game/export_presets.cfg, game/race/chase_camera.gd, game/cars/car.gd, game/race/race.gd, game/race/ghost_player.gd, game/race/remote_car.gd, game/cars/visual/car_visual.gd, game/shaders/*.gdshader, docs/RENDERING.md, docs/HANDOFF.md

---

## 7. Verification (a second agent re-checked every claim against the fork source, 4.7.2 sources and the repo)

**Result:** 3 claims are wrong (#1, #34, #35). 4 claims are out of date because the repo moved on after the report was written (#117, #118, #121, #123). 2 claims are right but cite the wrong lines or file (#33, #115). The other 120 are verified.

**How I checked**
- Fork claims: grepped the fork clone at the local fork clone (shown as `F:`).
- Fork history: the local clone has only one commit, so I made a metadata-only clone (`--filter=blob:none`).
- Other fork branches: raw files from raw.githubusercontent.com/NVIDIA-RTX/godot/<branch>/.
- Mainline claims: files from `https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/...` (shown as `M:`).
- Archives: zip directories of the 4.7.2 templates `.tpz` and the Streamline v2.10.0 zip, read with HTTP range requests.
- Web pages: WebFetch.
- SpeedFest: read against HEAD `9a47cc8` and the working tree.
- Nothing was modified in either repo, and Godot was not run.

Shorthand used below:
- PT = `servers/rendering/renderer_rd/forward_clustered/render_forward_clustered_pt.cpp`
- RFC = `.../forward_clustered/render_forward_clustered.cpp`
- RRc / RRh = `.../forward_clustered/render_raytracing.cpp` / `.h`
- RTS = `servers/rendering/renderer_rd/shaders/raytracing/`

### Verification table (claim numbers refer to the research agent's claim list)

| # | Verdict | Evidence / correction |
|---|---|---|
| 1 | **WRONG** | The local clone is shallow (depth 1), which is why it shows one commit. The branch actually has **three** NVIDIA commits, all by L Sikkes on 2026-07-24, on top of upstream master `c3e6b2c` (2026-06-23): `6d10056` "NVIDIA: Miscellaneous" (CI/.github, 107 files), `5e232ff` "NVIDIA: Dependencies" (thirdparty/streamline etc., 29 files), and `135dff3` "NVIDIA: Pathtracer + DLSS" (191 files). The tip's hash, author and date are correct. |
| 2 | Verified | Fetched `version.py` on all four branches: pt-dlss and -dev are 4.8.0 dev; backport/…-4.6.3 and worktree-dlss-fg-reflex are 4.6.3 stable. |
| 3 | Verified | `grep NVIDIA\|RTX\|Streamline F:README.md` finds nothing. |
| 4 | Verified | F:doc/classes/Environment.xml:203-222 (names, types, defaults and enums match). |
| 5 | Verified | F:scene/resources/environment.cpp:636 `CLAMP(p_bounces, 1, 8)`. The editor hint is also 1..8 (:1509). The doc says 0 means direct-only (Environment.xml:216), but the setter clamps it to 1. |
| 6 | Verified | F:servers/rendering/rendering_server_enums.h:760-762; RenderingServer.xml:5998-6002. |
| 7 | Verified | F:servers/rendering/rendering_server.cpp:3100; RenderingServer.xml:1402-1411. |
| 8 | Verified | DLSS=6 on all four branches (Viewport.xml:585 / 583 / 584). The 4.6.3 backport also adds NEAREST=5, so MAX=7. The scale list text is at F:Viewport.xml:586. |
| 9 | Verified | F:Viewport.xml:347; scene/main/viewport.cpp:5073-5084,5406; rendering_server.cpp:2871. |
| 10 | Verified | Six settings: F:rendering_server.cpp:3829-3834. `use_simple_shadows` is defined in F:environment.cpp:1502. Docs: ProjectSettings.xml:3258-3284. |
| 11 | Verified | F:drivers/streamline/streamline.cpp:63-68 (hints `?,F..O` and `?,D..O`, reflex range 0-2). |
| 12 | Verified | F:rendering_server.cpp:3782. |
| 13 | Verified | F:streamline.cpp:42-55; doc/classes/Streamline.xml:29-58 (NIS=5, REFLEX=3, PCL=4). |
| 14 | Verified | F:main/main.cpp:1091-1093. `get_capability` is guarded by `#ifdef STREAMLINE_ENABLED` and returns false otherwise. The report's 4.1 cites streamline.cpp:262-288; the function is actually at **247-260**. |
| 15 | Verified | F:servers/rendering/renderer_rd/renderer_compositor_rd.cpp:385-391. If a device has fewer than 48 textures per stage it falls back to Mobile (:380-384). |
| 16 | Verified | PT:53-67 (`!is_reflection_probe && pathtracing_enabled && _setup_rt()`); PT:498-501 checks `SUPPORTS_RAYTRACING_PIPELINE`. |
| 17 | Verified | `grep pathtrac F:main/main.cpp` finds nothing. Flags at :662,667. |
| 18 | Verified | RFC:1843-1890 (RR guide buffers only in the `SCALE_3D_DLSS` branch); PT:475-484. `_resolve_scale_3d_mode` (RFC:1772-1787) never forces DLSS. |
| 19 | Verified | RFC:1860 `sharpness = fsr_sharpness/2`; effects/dlss.cpp:533 (`> 0` and `nis_available`). The `fsr_sharpness` default is 0.2 (Viewport.xml:350). |
| 20 | Verified | effects/dlss.cpp:63-141. If no mode fits the requested size it errors "Couldn't find an appropriate DLSS mode". |
| 21 | Verified | RFC:1874. Mainline FSR2 has the same FIXME (M:render_forward_clustered.cpp:2493). |
| 22 | Verified | F:drivers/d3d12/rendering_device_driver_d3d12.cpp:5548-5604 plus :4224 (15 occurrences). The dev branch also has 15. |
| 23 | Verified | F:drivers/vulkan/rendering_device_driver_vulkan.cpp:590-594 (all registered as optional, `false`). |
| 24 | Verified | F:SConstruct:202,608-612. |
| 25 | Verified | F:drivers/streamline/streamline_context.cpp:74; F:servers/rendering/renderer_viewport.cpp:1061. Vulkan also loads the interposer as its loader (rendering_context_driver_vulkan.cpp:922-933). The error is only printed when a viewport is switched to DLSS mode (renderer_viewport.cpp:1056-1063). |
| 26 | Verified | F:thirdparty/streamline/include/sl_version.h:24-26 (2.10.0). |
| 27 | Verified | F:main.cpp:2703-2708 → streamline.cpp:96-98 `sl_context.initialize(d3d12)`. |
| 28 | Verified | streamline_context.cpp:171-228,328-350. DLSS, DLSS_RR and NIS load in the editor too; PCL, Reflex and DLSS-G load only in the game. |
| 29 | Verified | streamline_context.cpp:363-364. |
| 30 | Verified | PT:120-122 and :83; Environment.xml:213 (the doc names SDFGI, SSR and shadow maps only). |
| 31 | Verified | RTS/raytracing_closest_hit_common_inc.glsl:239-259,455-456. `grep volumetric` over the RT shaders and PT finds nothing. |
| 32 | Verified | F:servers/rendering/renderer_scene_cull.cpp:3329-3334. Shadow-only casters are also excluded (:3331-3332). |
| 33 | Verified, but citation partly wrong | The content is right: PT:150-152 fills the list with `p_alpha_only=true`, PT:312-314 has the comment "transparents are still rasterized on top", and the transparent pass is PT:432-454. The cited lines are wrong: PT:113-119 is the motion-vector flags and PT:234-249 is the background-mode switch. |
| 34 | **WRONG (second half)** | Only OMNI=0, DIRECTIONAL=1 and SPOT=3 exist (RRh:119-123), so that part is right. But area lights are **not** dropped. Every `INSTANCE_LIGHT` goes into `rt_light_instances` (scene_cull.cpp:3329-3330). `gather_lights` scores all of them and maps any non-spot light to `RT_LIGHT_TYPE_OMNI` (RRc:2886-2912), using `area_range` (PARAM_RANGE, light_3d.cpp:764) and `light_size` as the radius (AreaLight3D default 0.5). So from the code, an AreaLight3D is traced as a spherical omni light, not ignored. Not tested at runtime. |
| 35 | **WRONG (budget part)** | The 64 cap is right: `RT_LIGHTS_MAX=64` (RRh:145), used at RRc:3092-3094. `RT_LIGHTS_FRUSTUM_BUDGET=48` and `_INDIRECT_BUDGET` are defined (RRh:146-147) but never used anywhere. The real rule: directional lights first, then the top-scored positional lights until 64 (RRc:2851-2925). |
| 36 | Verified | RRc:2817-2848. The score uses the raw `light_energy` parameter. Range 0 counts as 1e12. Lights behind the camera get a ×0.05 penalty, ramped in over 20 m. |
| 37 | Verified | RRh:125-141 has no shadow field; NEE always traces a shadow ray (RTS/raytracing_lights_inc.glsl:191-247). |
| 38 | Verified | RRc:2783-2799. |
| 39 | Verified | RTS/raytracing_data_inc.glsl:85-105. |
| 40 | Verified | RTS/scene_raytracing_raygen.glsl:372-388. `vertex()` runs at hit time (raytracing_custom_fragment_inc.glsl:56). |
| 41 | Verified | scene_shader_raytracing.cpp:1642; `grep MODE_UNSHADED RTS` finds nothing. |
| 42 | Verified | scene_shader_raytracing.cpp:570-576. |
| 43 | Verified | F:scene/resources/shader.cpp:113-118. |
| 44 | Verified | closest_hit_common_inc.glsl:458-459; raytracing_lights_inc.glsl:253-301. |
| 45 | Verified | raygen.glsl:181-247 (`radiance_octmap_sample(sky_uv, 0.0)`); PT has no sky draw call. |
| 46 | Verified, with a nuance | PT:291-306. The warning only fires when **MSAA is on** (`ce_pre_opaque_wants_resolved` requires `use_msaa`). |
| 47 | Verified | F:doc/classes/RTProceduralInstance3D.xml (inherits GeometryInstance3D). |
| 48 | Verified | F:editor/project_manager/project_manager.cpp:689. |
| 49 | Verified | F:platform/windows/detect.py:297; AccessKit handling at :476-504. |
| 50 | Verified | F:SConstruct:203,614-640. |
| 51 | Verified | M:doc/classes/RenderingDevice.xml:25-37,811-931,1291-1310 (all marked `experimental`), plus `hit_sbt_*` at :720-770. |
| 52 | Verified | M:RenderingDevice.xml:2837-2846 ("only supported when using Vulkan", and not on macOS/iOS). |
| 53 | Verified | M:drivers/vulkan/rendering_device_driver_vulkan.cpp:584-587. `ray_query_support` is declared `false` in the .h:166 and never assigned, so `SUPPORTS_RAY_QUERY` (:7408-7409) is always false. |
| 54 | Verified | master …vulkan.cpp:599 and :1124-1125; master version.py is 4.8 beta. |
| 55 | Verified | `grep -ci "pathtrac\|raytrac"` on M:Environment.xml and ProjectSettings.xml gives 0. |
| 56 | Verified | M:drivers/d3d12/rendering_device_driver_d3d12.cpp:4208, 5517+ (14 occurrences). |
| 57 | Verified | Phoronix, 2026-02-13: "Godot 4.7 Dev 1 … initial plumbing for ray-tracing … (GH-99119)". |
| 58 | Verified | godotengine.org/article/dev-snapshot-godot-4-8-beta-1 (2026-10-15): no ray tracing or path tracing terms. |
| 59 | Verified | M:Viewport.xml:555-582. |
| 60 | Verified | M:Viewport.xml:618-627. |
| 61 | Verified | M:Viewport.xml:561-562. |
| 62 | Verified | M:ProjectSettings.xml:2689-2693. |
| 63 | Verified | M:SceneTree.xml:291. |
| 64 | Verified | M:Node3D.xml:50-56. |
| 65 | Verified | M:Node.xml:873-879. |
| 66 | Verified | M:Engine.xml:110-113. |
| 67 | Verified | M:DisplayServer.xml:3426-3437. |
| 68 | Verified | M:ProjectSettings.xml:426. |
| 69 | Verified | M:ProjectSettings.xml:3388,3393. |
| 70 | Verified | M:ProjectSettings.xml:3344,3351,3355,3359. |
| 71 | Verified | godotengine.org/releases/4.6: "new Windows projects default to Direct3D 12…". Also stated at M:ProjectSettings.xml:3349. |
| 72 | Verified | M:vulkan.cpp:7412-7417. D3D12 returns true (M:d3d12.cpp:5893-5894). |
| 73 | Verified | M:ProjectSettings.xml:987. |
| 74 | Verified | M:ProjectSettings.xml:352-354. |
| 75 | Verified | M:ProjectSettings.xml:2935. |
| 76 | Verified | M:Environment.xml:319,322. |
| 77 | Verified | M:Environment.xml:129,450. |
| 78 | Verified | M:ProjectSettings.xml:2989,2992. |
| 79 | Verified | M:ProjectSettings.xml:3248,3251. |
| 80 | Verified | M:LightmapGI.xml:8. |
| 81 | Verified | M:VoxelGI.xml:24. |
| 82 | Verified | docs.godotengine.org/en/stable/…/using_sdfgi.html (4.7 docs): "performance will suffer if the camera moves too fast", "decreasing this to 4 or lower". |
| 83 | Verified | M:Environment.xml:218 and the SDFGI docs page. |
| 84 | Verified | M:AreaLight3D.xml:12,18-33. |
| 85 | Verified | M:Light3D.xml:57-60,97-100. |
| 86 | Verified | M:RenderingServer.xml:5139-5155. |
| 87 | Verified | M:RenderingServer.xml:5780-5807. |
| 88 | Verified | All 8 methods are in M:RenderingServer.xml (SSAO quality signature at :1482-1487). |
| 89 | Verified | M:Sky.xml:39-42,57-59. |
| 90 | Verified | M:CompositorEffect.xml:23-89. |
| 91 | Verified | M:Performance.xml:235-247 (values 34-38). |
| 92 | Verified | docs …/pipeline_compilations.html (4.7 docs), quoted exactly. |
| 93 | Verified | M:editor/export/shader_baker_export_plugin.cpp:56-59 (also needs the `shader_baker` feature). |
| 94 | Verified | :61-63. |
| 95 | Verified | :277-296. It also handles Label3D/Sprite3D (:298-360) and the embedded engine/material shaders (:144-166). |
| 96 | Verified | M:editor/editor_node.cpp:9509-9513. |
| 97 | Verified | M:editor/export/editor_export_platform_pc.cpp:70. |
| 98 | Verified | pc.cpp:58-71. `binary_format/architecture` comes from the platform plugin (windows export_plugin.cpp:462). |
| 99 | Verified | M:platform/windows/export/export_plugin.cpp:462-487. |
| 100 | Verified | export_plugin.cpp:392-410. |
| 101 | Verified, with a nuance | export_plugin.cpp:512-539. An empty icon falls back first to `application/config/windows_native_icon`, then to `config/icon`, then goes through `_process_icon` → .ico. |
| 102 | Verified | M:editor/export/editor_export.cpp:333-338 (under `#ifndef DISABLE_DEPRECATED`). |
| 103 | Verified | M:main/main.cpp:701-703. |
| 104 | Verified | SHA512-SUMS.txt lists both files; HTTP Content-Length is 1,281,349,702. |
| 105 | Verified | Read the .tpz zip directory: those files are present; there are no D3D12Core or libEGL DLLs. |
| 106 | Verified | M:modules/meshoptimizer/config.py:2. |
| 107 | Verified | M:ImporterMesh.xml:52-60 (`normal_split_angle` is noted as unused). |
| 108 | Verified | The zip's `bin/x64` has all of those, plus `sl.deepdvc/directsr/nvperf.dll` and `nvngx_deepdvc.dll`. The license files are `nis`, `nvngx_dlss` and `reflex` `.license.txt`. `sl.imgui.dll` is only in `bin/x64/development/`. |
| 109 | Verified | Streamline README.md:23-24. |
| 110 | Verified | Streamline license.txt: MIT text, with an NSight Perf exception (sl_nvperf.h…). |
| 111 | Verified | README.md:35 (production, NVIDIA-signed builds only); ProgrammingGuide.md:98-107,1438-1446. |
| 112 | Verified | NVIDIA/DLSS LICENSE.txt:12,15,24,27,71,77,89. It is identical (ignoring CRLF line endings) to the zip's `bin/x64/nvngx_dlss.license.txt`. |
| 113 | Verified | itch page: Windows 121 MB, Linux 77 MB, Source 72 MB, "Name your own price", links tree/nvidia-pt-dlss-dev, quotes match. |
| 114 | Verified | CG Channel, 2026-03-13: Vulkan, MIT, "no compiled binaries". |
| 115 | Verified, but wrong file cited | `main/README.md` is a one-line stub. The cited content is in **`master/README.md`** (lines 12, 21, 36-44, 150, 164). It now says the upstream base is 4.8-dev5 (2026-09-10). |
| 116 | Verified | docs …/compiling_for_windows.html (4.7 docs). |
| 117 | **OUT OF DATE** | True at HEAD (`msaa_3d=1`, no `driver.windows`). The working tree now has `msaa_3d=0` (uncommitted). There is still no driver override. |
| 118 | **OUT OF DATE** | True at HEAD settings.gd:144-147. The working tree's `apply_viewport()` now forces `MSAA_DISABLED` on Forward+. |
| 119 | Verified | race/chase_camera.gd:123. |
| 120 | Verified | Now at cars/car.gd:349 (move) and :356 (reset), at HEAD. |
| 121 | **OUT OF DATE** | True at 1f4fbcb race.gd:384. Fixed in commit 9a47cc8: `set_time((run_ticks - car.display_tick_lag()) * TICK_MS)` (race.gd:384-385). |
| 122 | Verified | car_visual.gd:178,185. The call is now car.gd:1030 and poses the wheels between ticks (9a47cc8). |
| 123 | **OUT OF DATE** | The contents are correct (project.godot, settings.gd:32, car.gd:169-172, the test file), but they are **committed** in f7350d4 (2026-10-15 23:18), not uncommitted. |
| 124 | Verified | shaders/env_neon.gdshader:2,30. |
| 125 | Verified | road.gdshader:146; track_puddle.gdshader:76-82; car_paint.gdshader:338-343. |
| 126 | Verified | env_sky.gdshader has TIME only in a comment; scenery_env.gd:65. It also forces `PROCESS_MODE_QUALITY` (:66). |
| 127 | Verified | No `VERTEX =` and no screen, depth or normal texture hints in any .gdshader. |
| 128 | Verified | tracks/scenery/scenery_rain.gd:35-36 (ALPHA + **ADD** blend), :70. |
| 129 | Verified | race/chase_camera.gd:57. |

### Corrections to the report body (outside the numbered claims)
1. **The ghost formula in 1.5 item 1 is off by one tick.** Physics interpolation draws `lerp(previous tick, last tick, fraction)` (M:ProjectSettings.xml:2690, "between the last two transforms"). So the drawn car is `1 - fraction` ticks *behind* `run_ticks`. The report's `(run_ticks + fraction)` would put the ghost about one tick ahead of the car. HEAD already uses the correct `run_ticks - (1 - fraction)` (car.gd:334-338, race.gd:385; commit 9a47cc8 says the old sampling was 0.3 m+ off).
2. **1.5 items 1-3 are already done.** Ghost and wheels are handled in 9a47cc8. `camera.snap()` is already called after teleports (race.gd:288, 508). `snap()` is at chase_camera.gd:67, not :96.
3. **Several to-do items are already in progress.** `tools/export_desktop.sh` already exists (88c7360), so the CI in 5.2 should call it rather than duplicate it. Uncommitted work in settings.gd (+101 lines) and settings_menu.gd already adds the 4 V-Sync modes, the VRR FPS cap formula, exclusive fullscreen and TAA/FSR2/SMAA modes.
4. **3.5 "Bypassed: SDFGI, SSR, SSAO, SSIL, shadow maps (Environment.xml:213)".** The doc lists only SDFGI, SSR and shadow maps. SSAO and SSIL being freed comes from the code (PT:120-122).
5. **Owner step 6 in 4.5 will not show the error at startup.** The "Streamline failed to initialize" message only appears once a viewport switches to DLSS mode (renderer_viewport.cpp:1056-1063).
6. **Respawn and camera-cut smear is not DLSS-only.** Mainline FSR2 never resets its history either (M:render_forward_clustered.cpp:2493), so the High and Ultra mainline presets (FSR2 native) will smear on cuts too.
7. **The fork's Windows build commands in 3.10 are missing a flag.** `winrt` defaults on and needs Windows SDK ≥ 10.0.22621, or SCons exits; with VS2019 it must be exactly 10.0.22621 (F:platform/windows/detect.py:154-169). Add `winrt=no` or install that SDK. ANGLE turns itself off with a message if missing (detect.py:539-561).

### Important things the report missed (path tracing on SpeedFest content)
- **UV2 is replaced by UV under path tracing.** RTS/raytracing_custom_fragment_inc.glsl:48 sets `uv2_interp = rt_uv`, and UV2 is renamed to that (scene_shader_raytracing.cpp:1490). SpeedFest stores data in UV2 in env_neon (animation mode and phase), road (tunnels marked by `UV2.y >= 2`), track_puddle, track_ground, env_terrain and env_screen. Under PT these will read UV1 and behave wrongly. The `#if defined(RT)` patches need to handle this.
- **MultiMesh instance colour and INSTANCE_CUSTOM look unsupported in RT.** There is no instance colour in the RT GLSL. `INSTANCE_CUSTOM` is renamed to `instance_custom` (scene_shader_raytracing.cpp:1538), which no RT shader declares. SpeedFest uses `set_instance_color` (scenery_instances.gd:54-55, arena_kit.gd:246-251) and INSTANCE_CUSTOM (env_building.gdshader:27). Expect wrong colours or a fallback material. Inferred from the code, not tested.
- **VIEW and NORMAL are in different spaces in RT hit shaders.** `VIEW = -gl_WorldRayDirectionEXT` is world space (custom_fragment_inc.glsl:50), but NORMAL is transformed to view space (:61). Fresnel terms like `dot(NORMAL, VIEW)` in car_paint and track_puddle would be wrong under PT. Inferred from the code.
- **The TLAS covers a ±z_far cube around the camera** (renderer_scene_cull.cpp:3445). With `far = 4000` m, every instance and light within 4 km goes into the TLAS and light scoring. Lower `far` or use visibility ranges under PT.
- **Diffuse bounces are capped at 2** (`MAX_DIFFUSE_BOUNCES 2u`, raytracing_inc.glsl:134), whatever `pathtracing_max_bounces` is set to.
- **Next-event estimation picks one light uniformly** from a small reservoir sample (raytracing_lights_inc.glsl:268-301), not by importance. Many neon lights means more noise for Ray Reconstruction to clean up.
- **The DLSS preset can't be set per viewport.** It is hard-coded to `'?'` (RFC:1868), so only the `rendering/streamline/dlss*_preset` project settings apply (dlss.cpp:357-359,391-393).
- **TAA is redundant with a temporal upscaler.** The engine turns TAA off internally when FSR2 or DLSS is active (renderer_viewport.cpp:225-229), and falls back to bilinear when the scale is above 1.0 (:209-214).
- **The sky uses `PROCESS_MODE_QUALITY`** (scenery_env.gd:66). Raising `radiance_size` to 1024 or 2048 under PT makes every `retune()` an expensive importance-sampled rebake that may hitch.
- **SpeedFest currently uses the ACES tonemapper** (scenery_env.gd:71), not AgX, so the AgX re-grade is new work.
- **Streamline OTA downloads:** with `eAllowOTA | eLoadDownloadedPlugins` set (streamline_context.cpp:364), a shipped build may download newer NVIDIA plugins.
- **The `streamline_imgui` setting won't work with the shipped DLLs**, because `sl.imgui.dll` is only in the `development/` folder.
- **Light ranking uses raw energy.** Because the score uses `light_energy` and treats range 0 as infinite (RRc:2826-2840), a few large-range floodlights can push all the neon lights out of the 64 slots.
