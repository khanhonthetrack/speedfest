# SpeedFest on PC (Windows / Linux)

The PC build is the full game on Godot 4.7.2's Forward+ renderer (Vulkan). It looks better than the
web build: reflections, AO, volumetric fog, soft shadows, real lights at the neon. It is also
smoother: the car is drawn between physics ticks, so it doesn't judder at 120-240 Hz.

## Getting it
GitHub Actions builds both platforms on every push to `main` (workflow **Desktop builds**):
1. Open the repository on GitHub → **Actions** → **Desktop builds** → the latest green run.
2. Under **Artifacts**, download **SpeedFest-windows** (or **SpeedFest-linux**). You must be signed in.
3. Unzip it. The artifact contains `SpeedFest-windows.zip`; unzip that too, then run `SpeedFest.exe`
   (Linux: `speedfest.x86_64`).
A pushed tag `v*` (for example `v0.7.0`) also attaches both zips to a GitHub Release.

To build locally: `tools/export_desktop.sh [windows|linux|all] [--debug]` writes to `build/`
(needs the Godot 4.7.2 editor and export templates, see CLAUDE.md).

## Requirements
- A GPU with Vulkan support (roughly GTX 900 / RX 400 / Intel UHD 600 or newer). Without Vulkan, Godot falls back
  to Direct3D 12, then to the Compatibility renderer (the web look).
- Windows 10/11 64-bit or a 64-bit Linux desktop.
- The first launch compiles shaders and can take a while, and the first laps can hitch. Later
  launches use the shader cache.

## Settings that matter (Settings → Graphics / Display)
| Setting | Recommendation |
|---|---|
| Graphics quality | Low: integrated GPUs, GTX 1060. Medium: GTX 1660 / RTX 2060. High: RTX 3060 Ti+ at 1440p. Ultra: RTX 4070 Ti+ |
| Anti-aliasing | Auto picks FXAA (Low), TAA (Medium) or FSR 2 at native resolution (High/Ultra). SMAA is sharp and has no ghosting |
| Render scale | Below 100 % upscales with FSR (or FSR 2 if selected). 77 % is a good 1440p trade-off |
| Mode (F11) | Fullscreen (exclusive) has the least lag. Borderless suits multi-monitor setups |
| V-Sync | On (no tearing). Mailbox: no tearing and low lag where supported. Off: lowest lag |
| FPS limit | With G-Sync/FreeSync use V-Sync On + **VRR** (caps a little under the refresh rate) |
| Show FPS counter | Shows FPS, frame time, the worst frame, GPU/CPU ms and pipelines compiled mid-race (should stay 0) |

## Optional NVIDIA RTX
Path tracing, DLSS, Frame Generation and Reflex need NVIDIA's fork of Godot. See `docs/RTX.md`. On
the normal build the NVIDIA RTX settings block doesn't appear.

## Reporting problems
Turn on **Show FPS counter** and note the numbers, the track, the quality preset and the GPU. If it
crashes, run `SpeedFest.console.exe` from a debug build (`tools/export_desktop.sh windows --debug`)
to see the log.
