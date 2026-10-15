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

## 2026-10-14 ~23:10 — M1 launched (orchestrator)

- Started 8 module agents in parallel. Each builds in its own git worktree and pushes to
  `module/<key>`. An independent reviewer then audits and fixes the work on the same branch:
  `networking`, `audio`, `physics`, `race`, `visuals`, `scenery`, `tracks`, `ui`.
- The full per-module specs given to the agents are in the workflow script. The essentials are in
  docs/ARCHITECTURE.md and docs/PLAN.md. Each module documents itself in `docs/modules/<key>.md`.
- Next: merge all `module/*` branches into `main` (M2 integration).

## 2026-10-15 ~00:05 UTC — Takeover (orchestrator #2, session_01FScTiQ4vwQQ8wktXzQJ6Ey)

- The first orchestrator (session_01CMDh9pTv1h5xawNJJ9eFH2) stopped after pushing only
  `module/networking` (last push 23:25). The owner said it got stuck and asked this session to continue.
- Merged `module/networking`: Node server (rooms, round flow, static + gzip/br), real WebSocket
  `Net` client. Verified: `npm test` 10/10, `tools/net_smoke_test.sh` PASS (3 headless clients, 81 checks).
  Net also adds `player_checkpoint`, `finish_result` signals, `server_now_ms()`, `round_time_left_ms()`.
- Environment note: `downloads.godotengine.org` is blocked here; Godot + templates come from the
  GitHub release mirror (CLAUDE.md updated).
- Added core `game/ui/ui_theme.gd` (`UITheme`: palette, fonts, shared Theme, time formatting) so
  the UI work can be split into `ui_menus` and `ui_hud` without both touching a theme.
- Relaunched the remaining M1 modules as parallel cloud sessions (this container has 4 CPUs):
  physics, visuals, tracks, scenery, ui_menus, ui_hud, audio, race. Each starts from branch
  `ccr-49301774-b5a4ns`, works only in its owned files, documents itself in `docs/modules/<key>.md`
  and pushes to its own session branch. The orchestrator merges them into `ccr-49301774-b5a4ns`.
- Module sessions (spawned 00:11 UTC, each pushes to its own `ccr-*` branch; specs in `docs/M1_SPECS.md`):
  physics `session_01DrvZUyYAM3oczRVDW1o8Nf`, visuals `session_012FyHiPM6GP1ACSFBLqmWJV`,
  tracks `session_01XWgKiHbRtgKdaQBXSuzZm7`, scenery `session_019ZpoTQnjd2NsrKfAdGeECh`,
  ui_menus `session_018sRqzobba64dP5Ld7SByiE`, ui_hud `session_015JD5jMrvZQVTcVqfNyySq9`,
  audio `session_018yYJrBdZh6uuXVdUQqViJH`, race `session_01UXTHDb9Svwh7v9CKVysey7`.
- Next (orchestrator): web export pipeline check with stubs, HOSTING.md, ARCHITECTURE.md Net
  additions; then merge module branches as they land (M2).

## 2026-10-15 ~00:50 UTC — Networking review (orchestrator)

- Adversarial review workflow on the merged networking module (3 finders, verifier per finding):
  7 findings verified, 4 confirmed (2 were the same bug), 3 refuted. Fixed:
  - **Hidden web tab drops reliable messages**: Godot's web loop stops on a hidden tab while the
    browser keeps queueing frames; relayed 20 Hz state filled the 4096-packet queue after ~50 s
    (5 players), and then room/round_end/round_start were silently dropped. The server now
    skips lossy state relays to clients silent for > 5 s (`STALE_RX_MS`), and Net raises its
    inbound limits as a backstop.
  - Reloading the page mid-round (same name, old socket not yet reaped) split a player's times;
    the server now folds the old socket's times into the live player.
  - Static cache keyed by `realpath`, so case variants on Windows/macOS hosts share one copy of the wasm.
  - Server tests 12/12 (2 new regression tests fail without the fix), net smoke test PASS.
- Trial merge of all 7 pushed module branches (local only): 1 compile error (race's test track
  vs the real Track; sent to the race agent). The race scene runs with the real car/track/HUD,
  but the AutoDriver can't finish the real tracks yet. Results sent to the physics and tracks agents.

## 2026-10-15 ~01:10 UTC — M2 integration (orchestrator)

- Merged physics, tracks, scenery and race (first complete versions) on top of networking, visuals,
  audio, ui_hud and ui_menus. 103 scripts compile; every module test suite passes (physics
  run_all, tracks 70, race 41+10+4, scenery 24, audio 64, hud 34, garage 17, lobby 19, visuals 29,
  core 8).
- The real race scene with `--autodrive` finishes every track: arena 39.6 s, downtown 60.3 s,
  coast 54.0 s (PB saved, splits vs PB on the next run, auto-restart).
- Online, headless: `game/tests/race/online_round_test.sh 3 75 --autodrive --track=arena` PASS
  (3 clients finish 38.6/39.5/39.6 s, results, back to lobby).
- Online, real web build in headless Chromium (`tools/integration/online_browser_test.js`, 2
  clients): PASS for the flow (connect, join, round start, race scene with remote car, round end,
  lobby). SwiftShader is far too slow to drive, so web frame rate can't be judged here.
- New `res://tests/integration/perf_probe.tscn` (race scene + render stats). Compat, quality 1:
  arena ~140 draw calls / 95k tris, downtown ~200 / 134k, coast ~380 / 290k (coast is near the
  budget). Web builds default to quality 1.
- Visual note: a near-black car (brute's default paint) is hard to see at night on compat.

## 2026-10-15 ~01:40 UTC — Review of merged UI/audio/visuals (orchestrator)

- Adversarial review (3 finders + verifiers) of ui_menus, ui_hud, audio, visuals: 5 confirmed,
  all fixed by the integrator (owning sessions had finished), with `tests/integration/test_review_fixes`
  (fails 4/7 without the fixes):
  - Hovering a button while typing in chat stole focus, so Space/Enter could press START/LEAVE.
    `MenuKit.hover_focus` now skips while a text field is being edited; Esc in a room must be
    pressed twice (first arms Leave).
  - Garage/name changes made while connected but outside a room never reached the server.
    `Game.leave_garage` now sends when online, and `Net.create_room/join_room` send the profile first.
  - A hidden (stale) remote car kept droning at its last rpm: remote EngineAudio mutes while hidden.
  - `CarVisual.build()` twice lost the wheels/calipers (PB ghost after a new PB): stale refs reset.
  - A round started while returning from the results screen (hidden tab) is now joined automatically
    on lobby entry (`Game.last_round_id`); a deliberately quit round stays manual.
- New `tools/integration/check_all.sh` gate: CHECK_ALL PASS (24 suites + server + autodrive on 3
  tracks + online rounds). `lobby_smoke.sh` (real lobby UI, 3 clients, real server) PASS.
