# HANDOFF: start here (written 2026-10-15 ~06:35 UTC by orchestrator #2)

The owner is near the account usage limit, so all agents stopped and recorded their state. This page
is the entry point for the next agent. Read it first, then `CLAUDE.md`, `docs/PLAN.md`, the end of
`docs/PROGRESS.md`, `docs/TRANSCRIPT.md` (owner requests, verbatim) and `docs/M1_SPECS.md` (all module
specs, plus the **"M3 rework"** section at the bottom).

## 1. What works right now (playable)

Branch **`ccr-49301774-b5a4ns`** is the integration branch. Every module is merged, and the web
build is committed in `server/public/`.
- Game: menus, garage (tuning + NFSU2 styling), 3 cars, 3 tracks, solo time attack (PB + ghosts +
  splits), online rooms (2–8 players, countdown, live leaderboard, results), HUD, synthesized audio.
- Tests: `tools/integration/check_all.sh` → **CHECK_ALL PASS** (compile, 24 suites, server 12/12,
  AutoDriver finishes all tracks, net smoke, 3-client online round). `game/tests/ui_menus/lobby_smoke.sh`
  PASS. The keyboard-player emulation finishes all 3 tracks with all 3 cars (0 respawns).
- Hosting: `docs/HOSTING.md` (Render.com step by step, `render.yaml` blueprint; or PC + Cloudflare
  tunnel). Deploy from this branch. **Turn off Render Auto-Deploy during game night** (a push
  redeploys and drops players).
- `main` is NOT updated (this session may only push to `ccr-49301774-b5a4ns`). Ask the owner before
  merging into `main`.

## 2. In progress: Trackmania-style track rework (NOT merged yet)

The owner wants **all three tracks Trackmania-style**, with the themes kept as the setting: floating
platform roads with open edges, big gap jumps, loops and wall rides, turbo pads (yellow boost, red
super boost), short 30–45 s tracks. Spec: `docs/DESIGN.md` §4 and `docs/M1_SPECS.md` → "M3 rework".
The current (old-style) tracks on the integration branch are the playable fallback until the new
ones pass.

State per module branch (each one's `docs/modules/<key>.md` has a "Handoff" section at the top with
details; check `git log origin/module/<key>` for the latest commit):

| branch | state at handoff |
|---|---|
| `module/tracks` | **New Pulse Arena** done (start-tower dive, yellow turbo, walled banked turn, red super boost into a loop, 75° wall ride, gap jump, half-pipe 180, final jump through the finish arch, ~1.47 km point-to-point). AutoDriver 31–39 s, 0 respawns, all cars. **Open:** the keyboard emulation falls off at the wall-ride exit for brute/veloce (roll ramp 62 m vs ~245 km/h entry after the super boost). The fix per physics' envelope is a roll ramp ≥ 100 m and entry ≤ ~215 km/h. **Update 06:42: tracks pushed new downtown and coast layouts too ("part 2", de1b225 or later).** Physics measured all 9 car×track runs: the analog AutoDriver finishes with 0 respawns (arena 32–37 s, downtown 25–27 s, coast 31–33 s). The keyboard emulation is clean on 4/9 and needs 1–2 respawns on the rest, mainly the wall-ride geometry (62 m roll ramp with the curve at full curvature from roll 0; exact spots and fixes in docs/modules/physics.md and tracks.md). Matrix script: `game/tests/physics/run_real_tracks.sh`. Downtown at 25–27 s is shorter than the 30–45 s target. New API: `track.kill_y_at(pos)` (race already uses it). Must also set `path.set_meta("ground_y", …)` and mark the "elevated" and "wallride" zones for scenery. |
| `module/physics` | Rework support done (wall rides, super boost capped at ≤ 60 m/s² for ≤ 4 s with a 450 km/h hard cap and no tunnelling, big jumps, AutoDriver full throttle in wallride zones). `game/tests/physics/run_all.sh` → PHYSICS_ALL_OK; new `test_wallride`. |
| `module/scenery` | Elevated-deck support done (props on the ground, nothing inside the deck or pillar volume, downtown towers above and below the deck, coast cliffs and sea under the deck). Needs a screenshot check on the new layouts. |

### How to finish the rework (next agent)
1. Resume the sessions with `send_message` (they keep their context; IDs below) or do it yourself.
   Tracks: fix the arena wall-ride exit, then build the new downtown and coast per DESIGN §4.
2. Integrate on a local scratch branch:
   ```bash
   git fetch origin
   git checkout -B trial ccr-49301774-b5a4ns
   git merge origin/module/physics origin/module/scenery origin/module/tracks
   tools/godot_import.sh && tools/integration/check_all.sh            # must print CHECK_ALL PASS
   for t in arena downtown coast; do for c in kaze brute veloce; do
     tools/run_scene.sh res://tests/physics/test_real_tracks.tscn --headless -- --track=$t --car=$c --keyboard | grep -E "RESULT|TEST_"
   done; done                                                          # 0 respawns everywhere
   tools/run_scene.sh res://tests/integration/perf_probe.tscn --compat -- --track=downtown --autodrive --frames=420 --shot=/abs/dt.png
   ```
   Look at the screenshots on both renderers (drop `--compat` for Forward+). On web, keep about
   ≤ 400 draw calls (perf_probe prints PERF lines).
3. If everything passes: `git checkout ccr-49301774-b5a4ns && git merge --ff-only trial`, then
   `tools/export_web.sh`, commit `server/public`, push. Update PLAN/PROGRESS.

## 3. Other open items
- An adversarial review of race, physics and tracks never ran: the workflow died on the usage limit.
  Two earlier reviews (networking; ui/audio/visuals) found and fixed 9 bugs, all covered by tests
  (`server/test`, `game/tests/integration/test_review_fixes`).
- Web frame rate is unmeasured on a real GPU (the containers have none). Compat render stats: arena
  ~165 draw calls, downtown ~190, coast ~310 at quality 1.
- Nice to have: README screenshots; merge to `main` (owner decision).

## 4. Sessions (all spawned by orchestrator #2; resume with send_message, they keep their context)
| module | session |
|---|---|
| orchestrator #2 | session_01FScTiQ4vwQQ8wktXzQJ6Ey |
| physics | session_01DrvZUyYAM3oczRVDW1o8Nf |
| visuals | session_012FyHiPM6GP1ACSFBLqmWJV |
| tracks | session_01XWgKiHbRtgKdaQBXSuzZm7 |
| scenery | session_019ZpoTQnjd2NsrKfAdGeECh |
| ui_menus | session_018sRqzobba64dP5Ld7SByiE |
| ui_hud | session_015JD5jMrvZQVTcVqfNyySq9 |
| audio | session_018yYJrBdZh6uuXVdUQqViJH |
| race | session_01UXTHDb9Svwh7v9CKVysey7 |

Module sessions push only to `module/<key>`. The orchestrator merges into `ccr-49301774-b5a4ns`.
Environment notes: `downloads.godotengine.org` may be blocked, so use the GitHub release mirror (CLAUDE.md).
Containers have only 4 CPUs (local workflows run 2 agents at a time), which is why modules ran as
separate cloud sessions.
