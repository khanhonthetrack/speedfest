# SpeedFest Stadium on RTX cards

## Stock Godot 4.7.2 (every build): Options → Graphics
- **Low**: no ambient occlusion or glow, shadows to 300 m in 2 splits (slow GPUs).
- **High** (default): SSAO, glow, shadows to 700 m.
- **Ultra** (RTX-class GPUs): real-time global illumination (SDFGI, 6 cascades), screen-space
  reflections (water, glossy surfaces) and indirect light (SSIL), light volumetric haze lit by the
  sun, shadows to 900 m in 4 splits. `--set_quality=2` forces it for a run. With SDFGI the fabric
  roofs' undersides would only get light bounced off the grass, so Ultra adds the sunlight that
  shows through the membrane (`TmRtx.MEMBRANE`, `TmMaterials.TRANSLUCENT`).

## NVIDIA's RTX fork of Godot (branch `nvidia-pt-dlss`)
The same code detects the fork at runtime (`env/tm_rtx.gd`, from SpeedFest's `m7-rtx` work, see
`docs/RTX.md` on that branch) and then shows, under Options:
- **DLSS** Off / DLAA / Quality / Balanced / Performance. On RTX 20/30 cards it uses the CNN model
  (preset F), measured 2-3x cheaper there than the transformer models (RTX 2060, `docs/RTX.md`).
- **Path tracing (experimental)** with DLSS Ray Reconstruction as the denoiser. On an RTX 2060 it
  runs but slowly (a photo mode there; RTX 40/50 for play). Under path tracing the game uses its
  standard materials: the fork drew our procedural shaders wrongly (the car vanished).
- A status line saying what this PC can do.

Run it (tested on this PC, RTX 2060, driver 616.56, fork built in `C:\dev\godot-rtx` with the
Streamline 2.10 DLLs next to the exe):
1. Copy `stadium/` to a folder you never commit from (the 4.8 fork upgrades the project), e.g.
   `C:\dev\stadium-rtx`, without `.godot/` and `server/node_modules/`.
2. `godot-rtx.exe --path C:\dev\stadium-rtx --import` (once), then run it, or straight into a
   race: `godot-rtx.exe --path C:\dev\stadium-rtx res://race/race.tscn -- --track=A01 --set_dlss=2 --set_path_tracing=1`.

Our shaders compile as the fork's ray-tracing hit shaders too: `env/rt.gdshaderinc` replaces the
screen-space derivatives they don't have, and the car's clearcoat is left out there.

Known: the fork logs "slSetConstants ... eErrorDuplicatedConstants" every frame with DLSS on; the
image is right (checked in screenshots); not investigated further.
