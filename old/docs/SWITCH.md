# Path to Nintendo Switch / Switch 2

The long-term goal is a console release. Notes for whoever picks this up:

## Reality check
- Godot's open-source repo **can't ship console export templates**: the Nintendo SDK is under
  NDA. Console ports go through:
  1. Becoming a registered **Nintendo Developer** (developer.nintendo.com). Apply as a company or
     individual, get approved, then get access to the SDK and devkits.
  2. A Godot **console porting partner**, e.g. **W4 Games** (W4 Consoles, made by Godot's core
     developers), Lone Wolf Technology, Pineapple Works, or RAWRLAB. They provide Switch export
     templates and support for Godot 4.x. You'll still need Nintendo developer approval.
- **Switch 2** is far more capable (custom NVIDIA Ampere-class GPU, DLSS, more RAM). Target Switch 2
  first if possible. A Forward+/Mobile-renderer Godot build is realistic there.
- **Switch 1** (Tegra X1, about 0.4 TFLOPS docked) needs the **Mobile** renderer, or Compatibility,
  with lower settings.

## What we do now so the port is cheap later
- Keep the renderer split clean: `Settings.is_compat()` / `Settings.quality` gate expensive
  features (SSR, SSAO, SSIL, SDFGI, volumetric fog, light counts). A "Switch" quality preset can be added.
- Procedural meshes and materials stay small. Expensive effects are optional.
- Controller-first input. All actions are already mapped to gamepad.
  Joy-Con: use the `JOY_BUTTON_*` abstraction and don't hard-code Xbox labels in the UI (show
  glyphs per controller later).
- 30/60 fps budget thinking: physics at a fixed 60 Hz. Rendering must hold 60 on Switch 2 and 30
  on Switch 1.
- Online: Nintendo requires its own online service (NPLN) for console multiplayer. The Node relay
  server is fine for web/desktop. The console version will need a platform-specific transport.
  Keep `Net` behind its API so the transport can be swapped.
- **Split-screen** local multiplayer is a big win on Switch. The race scene should be able to host
  multiple local cars and cameras (future work: SubViewport per player).
- Avoid web-only APIs in gameplay code (`JavaScriptBridge` is used only in `Settings.resolve_server_url`).

## Art upgrade path
The procedural cars and tracks are a fast starting point. For "beautiful graphics" on console:
- Replace `CarVisual` internals with artist-made glTF models (same API: wheel pivots, part slots
  for hood/kit/spoiler/rims, material slots for paint/carbon/glass/lights).
- Bake lighting (LightmapGI) for static track geometry on Switch 1. Use SDFGI or VoxelGI on Switch 2.
- Use ReflectionProbes per track sector for wet roads (cheap reflections).

## Ray tracing / path tracing
See docs/RENDERING.md. NVIDIA's path tracing fork of Godot is Windows + RTX only and isn't a console
option. On Switch 2, the realistic route is mainline features (reflection probes, baked GI) and,
later, hybrid RT reflections through mainline's RenderingDevice ray-tracing API.

