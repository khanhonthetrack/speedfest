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
   - "RTX ready." → turn on **Path tracing (experimental)**, set **Light bounces** to 2 and
     **DLSS** to Quality.
   - "DLSS unavailable…" → the Streamline DLLs aren't next to the exe, or the GPU isn't RTX.
     (The engine's own "Streamline failed to initialize" error only shows once a viewport switches to DLSS.)
   - "This GPU or driver has no Vulkan ray tracing." → update the driver.
   You can also force path tracing from the command line:
   `godot.exe --path C:\dev\speedfest-rtx\game -- --rtx --dlss=Quality`
6. **Test drive:** Neon Downtown in Rain, 250+ km/h, at 1080p with DLSS Quality and Performance.
   Write down fps, ghosting, whether neon lights the road, the puddles, the rain overlay, and the smear
   after a respawn. Send screenshots. This decides whether the RTX mode is worth more work.

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
In the fork editor, add a "Windows RTX" export preset: a copy of "Windows" with
`custom_template/release` set to your `godot.windows.template_release.x86_64.exe`. Export it, then put
the Streamline `bin\x64` DLLs and their `*.license.txt` next to `SpeedFest.exe`, and add NVIDIA DLSS
credits.

**Never commit the NVIDIA DLLs to this repository.** The DLSS runtime is under NVIDIA's RTX SDK
license (redistribution only inside an application, never under an open-source license; notify
NVIDIA before a commercial release: https://developer.nvidia.com/sw-notification). The CI
builds never include the fork or the DLLs.
