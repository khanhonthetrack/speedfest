# Rendering beyond the web build: path tracing (Godot RTX / NVIDIA fork) investigation

Owner request (2026-10-15): *"Maybe for beyond web version - this graphics sorry, is kinda trivial
and menu looks very mobiley ans boring. Maybe lets investigate using Godot RTX engine, for example
https://johnlogostini.itch.io/godot-rtx or NVIDIA fork of godot? Ray path tracing looks good for
puddles etc."*

## 1. What these are (researched 2026-10-15)

**They are the same thing.** "Godot RTX" on itch.io is a packaged download of **NVIDIA's path
tracing fork of Godot**: branch `nvidia-pt-dlss` of `github.com/NVIDIA-RTX/godot`. It was
presented at GDC 2026 and released mid-March 2026.

| | |
|---|---|
| What it does | Replaces rasterized lighting with **real-time path tracing** (direct and indirect light, reflections, shadows), toggled per `Environment` (`pathtracing_enabled`). DLSS Super Resolution, DLAA and **DLSS Ray Reconstruction** (the denoiser). Frame Generation on RTX 40+ |
| Base engine | Godot `master` from about June 2026 (4.7-dev era). Close to our 4.7.2. A third-party mirror tracks 4.8-dev |
| License | Engine changes are MIT. DLSS, Ray Reconstruction and Streamline are closed-source NVIDIA binaries |
| Platforms | Windows x64 (Vulkan and D3D12). Streamline/DLSS are Windows-only. itch also lists a Linux build, but without the NVIDIA denoiser |
| GPU | Path tracing needs a ray-tracing GPU. **The only denoiser today is DLSS Ray Reconstruction (NVIDIA RTX 20+)**, so in practice it's RTX-only. NVIDIA says a vendor-neutral denoiser (NRD) is coming |
| Export | No export templates are shipped. You build them yourself (`scons ... use_streamline=yes target=template_release`) and ship the Streamline DLLs next to the game |
| Maturity | "In development". Reported issues: noise and temporal flicker, artifacts, **no volumetric fog**, some broken lighting cases, and path tracing disables SDFGI/SSR. NVIDIA's plans: radiance cache, D3D12, eventually an add-on or upstreaming (not committed) |

**Mainline Godot**: 4.7 added low-level hardware ray-tracing plumbing to `RenderingDevice`
(acceleration structures, RT pipelines; PR #99119), but **the built-in renderer doesn't use it**.
4.7.2 also doesn't request `VK_KHR_ray_query` (fixes in PR #122051, aimed at 4.8). The Godot
rendering lead: "we're a ways away" from hardware RT in the renderer.

## 2. Fit for SpeedFest

**What it would make gorgeous**, our exact showcase: neon signs and emissive edge strips that
actually *light* the wet road, true reflections in puddles and on car paint, soft shadows,
and light bouncing in the downtown canyons.

**Why it can't be our foundation:**
1. **Platform conflict.** It's Windows plus an NVIDIA RTX GPU in practice. It can't run on the web
   build (WebGL2) or on **Nintendo Switch / Switch 2**: console Godot ports (W4 Consoles, Switch 2
   in beta since Oct 2025) come from mainline Godot, and DLSS Ray Reconstruction via Streamline
   isn't available there. The owner's end goal is Switch 2.
2. **Racing is the worst case for real-time path tracing.** A fast camera and fast-moving cars
   cause ghosting and smearing in temporal denoisers. Needs testing on real hardware at
   250+ km/h. The 60 fps target leaves 1–2 samples per pixel.
3. **Experimental fork risk.** It tracks a June 2026 master, we'd have to build our own export
   templates, the future is unconfirmed, and features we use are missing (volumetric fog; rain
   particles and alpha-blended FX need checking).
4. **Honest root cause of "trivial" graphics: content, not lighting tech.** Our buildings are
   procedural boxes, the cars are generated lofts, there are no textures, and the materials are
   simple. Path tracing only makes simple geometry look *correctly lit*; it stays simple
   geometry. The biggest visual win for the beyond-web version is **real art**, plus the mainline
   features we don't use yet.

## 3. Recommendation

**Stay on mainline Godot for the real game. Run the NVIDIA fork as an optional desktop "RTX mode"
experiment from the same codebase.**

1. **Desktop graphics track (mainline, also feeds Switch 2):**
   - Real assets: Blender-modeled cars (same `CarVisual` API: part slots, wheel pivots), a modular
     city and stadium kit, PBR textures (wet asphalt with puddle masks, concrete, carbon, metal
     flake). These are what make NFSU2-style shots.
   - Use what Forward+ already has: per-sector `ReflectionProbe`s (cheap wet reflections, works
     on Switch), the 4.6-overhauled SSR, `Decal`s for puddles and road grime, volumetric fog with
     light shafts from street lamps, SDFGI or `LightmapGI` for baked city GI, and lens flares,
     motion blur and heat haze as `CompositorEffect`s.
   - A desktop-default "Ultra" preset. Keep the Compatibility path only for the web.
2. **Make the project fork-ready (small, no fork dependency):** detect at runtime whether
   `Environment` has `pathtracing_enabled`. If it does, offer *Settings → Graphics → "Path tracing
   (experimental, RTX)"*: enable it on the track environment and switch `scaling_3d_mode` to DLSS.
   Stock Godot ignores the option. One codebase, no fork lock-in.
3. **Prototype on the owner's PC** (Windows plus an NVIDIA RTX card; RTX 3070 or better
   recommended). Run the itch "Godot RTX" editor, open `game/project.godot`, and drive Neon
   Downtown in the rain. Record fps at 1080p with DLSS Quality and Performance, and check fast-motion
   ghosting, rain particles, neon light, puddles and car paint. Decide from real footage.
4. **Watch mainline RT:** once `RenderingDevice` ray queries work (4.8), **hybrid RT reflections for
   wet roads and puddles only** (a `CompositorEffect`) is vendor-neutral and could someday map to
   Switch 2's RT cores. That's the realistic "ray-traced puddles on console" path.

## 4. Menus ("mobiley and boring")

The current menus are flat 2D panels with stacked chips and buttons. For the desktop/console version,
move to an **NFSU2-style 3D front end**:
- The **garage is the menu**: one lit 3D scene (car on a lift, paint booth, dyno, neon signage).
  The camera dollies between stations instead of switching screens.
- Diegetic UI: menu items as neon signs and wall screens, big skewed type, and few boxes.
- Cinematic transitions (camera cuts, light flicker, engine rev), music-synced pulses, and the
  car always center-stage (rim light, reflections).
- Controller-first focus and layout for Switch. The web build can keep the light 2D menus.

## Sources
- Godot RTX on itch.io: https://johnlogostini.itch.io/godot-rtx
- NVIDIA fork, branch `nvidia-pt-dlss`: https://github.com/NVIDIA-RTX/godot/tree/nvidia-pt-dlss
- Third-party mirror with build and setup notes (not NVIDIA): https://github.com/bailaiOWO/rtx-godot
- Coverage: https://gamefromscratch.com/nvidia-release-rtx-powered-godot-fork/ ,
  https://www.cgchannel.com/2026/03/get-nvidias-new-path-tracing-fork-of-the-godot-game-engine/ ,
  https://ziva.sh/blogs/godot-ray-tracing , https://forum.godotengine.org/t/path-tracing-forks-future/135423
- Mainline RT plumbing: https://github.com/godotengine/godot/pull/99119 , https://github.com/godotengine/godot/pull/122051 ,
  https://www.phoronix.com/news/Godot-4.7-Dev-1-Vulkan-RT
- W4 Consoles Switch 2 beta: https://www.w4games.com/blog/w4-games-news-1/w4-consoles-beta-support-for-the-nintendo-switch-2-87
