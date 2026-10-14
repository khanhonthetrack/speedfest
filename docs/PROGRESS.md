# Progress log

Chronological, newest at the bottom. Every agent appends an entry after meaningful work:
date, who (module/agent), what changed, what's next or blocked.

---

## 2026-10-14 — Session 1 (orchestrator)

- **M0 bootstrap done.**
  - Installed Godot 4.7.2 + templates. Verified headless screenshots under Xvfb on both renderers
    (llvmpipe/lavapipe).
  - Owner answered the design questions: Time Attack only, one track per theme (city / stunt arena /
    coast), JDM coupe + muscle + supercar, browser + keyboard.
  - Wrote DESIGN, ARCHITECTURE (interface contracts), PLAN (module ownership), SWITCH, and CLAUDE.md.
  - Godot skeleton: Settings (quality tiers, env tuning, input map, audio buses), Profile (garage,
    PBs, ghosts), Game (scene flow), TestHooks (CLI test/screenshot hooks), CarDefs (3 cars,
    shared geometry, style schema, sanitizer), TrackDefs, TrackPath (road frames with working loops
    and banking, tested), and stubs for Net/Audio/Car/CarVisual/Tuning/Track/Race/main menu.
  - Tools: `tools/godot_import.sh`, `check_scripts.sh`, `run_scene.sh`, `export_web.sh`.
- **Next:** M1, 8 module agents in parallel (networking, car physics, car visuals, track builder,
  scenery, UI, audio, race), each on its own branch, then integration.
