# SpeedFest RTX (optional path tracing + DLSS)

The normal PC build (Windows/Linux zips from GitHub Actions, "Desktop builds") runs on stock Godot
4.7.2 with Forward+ and needs no RTX card. **RTX path tracing, DLSS, Frame Generation and Reflex only
exist in NVIDIA's fork of Godot** (`github.com/NVIDIA-RTX/godot`, branch `nvidia-pt-dlss`, Godot
4.8-dev). SpeedFest supports both from one codebase: at runtime `Settings.is_rtx_fork()` checks for
`Environment.set_pathtracing_enabled`, and an **NVIDIA RTX** block appears in Settings → Graphics
only on a fork build. On stock Godot all of it stays switched off.

Background, sources and limits: `docs/research/m7_pc_rtx.md` (sections 3, 4 and 7).

## What you need
- Windows 10 20H1 (19041) or newer, or Windows 11, with a current NVIDIA Game Ready driver (≥ 512.15).
- An RTX 20-series or newer GPU. RTX 30/40 recommended; Frame Generation needs RTX 40+.
- Path tracing needs **Vulkan**. That's SpeedFest's default; don't start it with `--rendering-driver d3d12`.
- The Streamline SDK v2.10.0 DLLs (DLSS, Ray Reconstruction, Reflex):
  https://github.com/NVIDIA-RTX/Streamline/releases/download/v2.10.0/streamline-sdk-v2.10.0.zip
  Use the files in `bin\x64` (**not** `bin\x64\development`).

Path tracing has no denoiser except DLSS Ray Reconstruction. Without DLSS it is unusable 1-sample
noise, so SpeedFest only lets you turn path tracing on when Ray Reconstruction is available.

## Step by step (owner test)
1. **Get an RTX editor.** NVIDIA ships no binaries; build it (below), or use a community build such
   as the "Godot RTX" Windows zip on itch.io (third party, not NVIDIA; pick a build of `nvidia-pt-dlss`).
2. Copy `streamline-sdk-v2.10.0\bin\x64\*.dll` and the `*.license.txt` files **next to the editor
   exe**, unless they are already there.
3. Clone SpeedFest into a **separate folder** that you never commit or push from, because the fork
   upgrades the project to 4.8:
   `git clone https://github.com/khanhonthetrack/speedfest C:\dev\speedfest-rtx`
4. Start the RTX editor → Import → `C:\dev\speedfest-rtx\game\project.godot`. Accept "This project
   was last edited in Godot 4.7 … change it to Godot 4.8". Wait for the import to finish. In Project
   Settings, check that the renderer is Forward+ and `rendering_device/driver.windows` is `vulkan`.
5. Press Play (F5) and open **Settings**. The **NVIDIA RTX** block has a status line:
   - "RTX ready." → set **DLSS** to Quality (or Performance at 1440p+) with **DLSS model** Auto.
     On RTX 40/50, also try **Path tracing (experimental)** with **Light bounces** 2 (on an RTX
     2060 it runs at 8-25 fps, see "Measured on an RTX 2060").
   - "DLSS unavailable…" → the Streamline DLLs aren't next to the exe, or the GPU isn't RTX.
     (The engine's own "Streamline failed to initialize" error only shows once a viewport switches to DLSS.)
   - "This GPU or driver has no Vulkan ray tracing." → update the driver.
   You can also force path tracing from the command line:
   `godot.exe --path C:\dev\speedfest-rtx\game -- --rtx --dlss=Quality`
6. **Test drive:** Neon Downtown in Rain, 250+ km/h, at 1080p with DLSS Quality and Performance.
   Write down fps, ghosting, whether neon lights the road, the puddles, the rain overlay, and the smear
   after a respawn. Send screenshots. This decides whether the RTX mode is worth more work.

## Measured on an RTX 2060 (session 11, owner's PC)
RTX 2060 6 GB, driver 616.56, Ryzen 5 2600X, Windows 11, 2560x1440. Fork `nvidia-pt-dlss` @ 135dff3
built with VS Build Tools 2026, Streamline 2.10.0. Neon Downtown in rain, High preset, exclusive
fullscreen, `tests/integration/gpu_bench` (AutoDriver, V-Sync off, 20 s from 3 s after GO).
Runner: `tools/rtx_bench.ps1 -Set baseline|dlss|pt` (results and screenshots in `C:\dev\bench`).

| 1440p, High | internal | fps | GPU ms |
|---|---|---|---|
| 4.7.2, FSR 2 native (today's default) | 2560x1440 | 64 | 15.0 |
| 4.7.2, FSR 2 at 67 % | 1715x965 | 105 | 8.8 |
| fork, DLSS Quality, model Fast (preset F) | 1715x965 | **111** | 8.0 |
| fork, DLSS Quality, model Sharp (K, driver default) | 1715x965 | 83 | 11.0 |
| fork, DLSS Quality, model Sharpest (M) | 1715x965 | 50 | 18.8 |
| fork, DLSS Performance, Fast (F) | 1280x720 | **148** | 5.8 |
| fork, DLSS Performance, Sharp (K) | 1280x720 | 103 | 8.7 |
| fork, DLSS Performance, Sharpest (M, driver default) | 1280x720 | 75 | 12.2 |
| fork, DLAA (driver default) | 2560x1440 | 55 | 17.4 |
| fork, path tracing + DLSS Quality | 1715x965 | 8 | 120 |
| fork, path tracing + DLSS Performance | 1280x720 | 14 | 69 |
| fork, path tracing, 1080p, DLSS Performance | 960x540 | 25 | 39 |

- **On RTX 20/30 cards use DLSS with the Fast model.** The driver's defaults are the transformer
  models, which Turing's tensor cores run slowly (that's why Performance was slower than Balanced).
  `Settings.dlss_model` Auto picks Fast (preset F) on RTX 20/30 and the driver's choice on newer
  cards; Sharp (K) still runs DLSS Quality at 83 fps. The image difference is small in stills
  (F slightly softer, a little more smear on rain spray); judge it in motion.
- **Path tracing is not playable on an RTX 2060** (8-25 fps). It works and looks right (city, neon,
  soft wet reflections), so it is a photo-mode option there; RTX 40/50 is where it could be a mode.
- With path tracing off, the fork renders and runs like 4.7.2 (720p High: 4.55 vs 4.49 ms GPU).

### Shader limits found on real hardware (fixed)
The fork compiles every material a second time as ray-tracing hit shaders (`RT` defined). A material
whose RT variant doesn't compile falls back to a default one, which is why the city first vanished:
- `fwidth()` doesn't exist there (no pixel derivatives): `shaders/rt.gdshaderinc` maps it to a
  small constant under RT (DLSS Ray Reconstruction resolves the edges). 9 shaders include it.
- `INSTANCE_CUSTOM` is undeclared (env_building), and small MultiMeshes are merged into one BLAS, so
  there's no per-instance data: all buildings get one style under path tracing.
- `instance uniform`s and `discard` don't exist (track_puddle): seed from the position under RT.
- The fork doesn't print why an RT shader failed (only "Dumped failed shader to ..."). For a local
  debug build, add `ERR_PRINT("RT hit shader compile failed: " + error);` after each
  `_dump_failed_shader(...)` call in `servers/rendering/renderer_rd/forward_clustered/scene_shader_raytracing.cpp`.

### Known issues (open)
- **Puddles are hidden under path tracing.** Once the puddle's RT hit shader is in use, the fork
  stops drawing every other custom material (buildings, neon, road, curbs), even with a trivial RT
  puddle shader; the pipeline build reports no error. Grip in puddles is unchanged. Likely a fork bug.
- **The road loses its markings under path tracing:** `road.gdshader` reads half width, curb amount
  and the tunnel flag from UV2, which the fork replaces with UV1. Fix: pass them in vertex COLOR
  (the RT shaders do read it: RGBA8) from `TrackBuilder.Acc.commit()`, read COLOR under RT.
- Wet-road fakes (`car_paint` night_rim, `road` tunnel_fake, puddle sheen) still add light under RT.

### Windows build notes
- VS Build Tools 2026 (MSVC 14.51) works; run the SCons line from `vcvars64.bat`.
- With 16 GB RAM, `-j10` runs out of compiler heap (C1060) on `editor/translations/doc_translations.gen.cpp`
  (91 MB of source). Build that object alone first (`... -j1 bin\obj\editor\translations\doc_translations.gen.windows.editor.x86_64.obj`),
  then the rest with `-j8`. The editor took ~35 min on a Ryzen 5 2600X and ~16 GB of disk.
- Import the project once **with a window** (`godot.windows.editor.x86_64.console.exe --path ... --import`, no
  `--headless`): headless import on the fork skips the BPTC (desktop HD) textures.

## What has been verified without an RTX card (session 10)
A Linux build of the fork (`nvidia-pt-dlss` @ 135dff388, 4.8-dev, built in the cloud container) ran
SpeedFest on Mesa's software Vulkan (lavapipe), which exposes `VK_KHR_ray_tracing_pipeline`:
- the project imports and all 142 scripts compile on 4.8-dev; test_interpolation 15/15,
  test_race_logic 41/41 and the TM lab pass; tracks render exactly like on 4.7.2 with path tracing off;
- `tests/core/test_settings` 14/14 on the fork: the fork is detected, `can_path_trace()` is true,
  the status line says DLSS is unavailable (no Streamline on Linux), path tracing stays off without
  the Ray Reconstruction denoiser, and `--rtx` turns it on (SSR/SSAO/SSIL/fog off, bounces set);
- with `--rtx` the fork's path tracer runs and compiles SpeedFest's materials into RT hit shaders,
  including the `#if defined(RT)` branches (e.g. track_stripes' emission).
Not verifiable there: actual path-traced frames. lavapipe can't build the fork's RT pipelines
("OpTypeForwardPointer is not supported yet": the fork's RT shaders use forward-declared buffer
references, which Mesa's SPIR-V front end doesn't translate). A default-material cube fails the same
way, so it's the driver, not SpeedFest. Frames, DLSS, Ray Reconstruction, Frame Generation and Reflex
need the owner's NVIDIA GPU (steps above).

## Known limits of the fork's path tracer (from its source; details in the research doc)
- Transparent and additive materials (rain, nitro flames, glows, ghosts) are drawn on top as raster
  and don't appear in reflections. Opaque GPU particles disappear. Decals don't show.
- Only omni, spot and directional lights, at most 64 per frame, ranked by energy, range and distance.
  Emissive surfaces light things only when a path happens to hit them, so neon that should light the
  road needs a real light next to it.
- Materials: albedo, normal, roughness, metallic, specular and emission. Clearcoat, rim and
  "unshaded" are ignored (an unshaded neon shader becomes lit paint unless it has an `RT` branch).
  UV2 reads as UV1 and MultiMesh instance colours aren't available, so a few SpeedFest shaders need
  `#if defined(RT)` branches (work in progress).
- DLSS history isn't reset on a cut, so respawns and camera changes smear for a few frames.
  Mainline FSR 2 has the same issue.
- Volumetric fog isn't traced; SSR, SSAO, SSIL, SDFGI, VoxelGI and shadow maps are replaced by tracing.

## Building the fork yourself (Windows)
"x64 Native Tools Command Prompt for VS 2022", Python 3.9+:
```bat
pip install scons
git clone --depth 1 --branch nvidia-pt-dlss https://github.com/NVIDIA-RTX/godot C:\dev\godot-rtx
cd C:\dev\godot-rtx
scons platform=windows target=editor           arch=x86_64 d3d12=no winrt=no use_streamline=yes
scons platform=windows target=template_release arch=x86_64 d3d12=no winrt=no use_streamline=yes production=yes
scons platform=windows target=template_debug   arch=x86_64 d3d12=no winrt=no use_streamline=yes
```
Outputs are in `bin\` (editor, templates and `*.console.exe`). Copy the Streamline `bin\x64` DLLs
next to each exe. `winrt=no` avoids needing Windows SDK 10.0.22621. `d3d12=no` is safe because
path tracing is Vulkan-only.

## Giving an RTX build to friends
**Automated (GitHub Actions "RTX build (Windows)", `.github/workflows/rtx.yml`, branch `rtx-build`):**
builds the fork's release template with MSVC (pinned to the commit tested on the RTX 2060, cached),
exports SpeedFest into it with stock 4.7.2 (`tools/export_rtx.sh`; the fork reads 4.7 packs: same
PCK v4 and GDScript tokenizer 101, and it avoids the fork's headless BPTC import bug), then
smoke-tests the exe on Windows (4.8 runtime, headless boot, AutoDriver finishes Skyline).
Download the run's artifact **SpeedFest-windows-rtx** (GitHub login needed), unzip, run
**`add_nvidia_dlss.bat`** in the folder (copies the runtime from `C:\dev\streamline-2.10.0` if it's
there, otherwise downloads NVIDIA's official SDK zip and extracts only `bin\x64` DLLs + licences),
zip the folder again and send it. Friends can also run the .bat themselves. `README-RTX.txt` in the
zip explains requirements, settings and credits.

**By hand:** in the fork editor, add a "Windows RTX" export preset: a copy of "Windows" with
`custom_template/release` set to your `godot.windows.template_release.x86_64.exe`. Export it, then put
the Streamline `bin\x64` DLLs and their `*.license.txt` next to `SpeedFest.exe`, and add NVIDIA DLSS
credits.

**Never commit the NVIDIA DLLs to this repository.** The DLSS runtime is under NVIDIA's RTX SDK
license (redistribution only inside an application, never under an open-source license; notify
NVIDIA before a commercial release: https://developer.nvidia.com/sw-notification). The CI
builds never include the fork or the DLLs.
