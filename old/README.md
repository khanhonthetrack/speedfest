# old/ — the archived first SpeedFest

This is the browser-first SpeedFest as it stood on 2026-10-19, kept for reference only. Nothing here
is built, tested or shipped any more, and no current code depends on it.

| dir | what it was |
|---|---|
| `old/game/` | the Godot 4.7 project: 6 cars, 34 tracks, weather, menus, online play |
| `old/server/` | the node server that served the web build and ran the online rounds |
| `old/tools/` | its import/test/export tooling (`check_all.sh`, the audio and texture generators) |
| `old/docs/` | its plan, architecture, design, specs, hosting, rendering and module docs |

**The browser version is removed.** The committed web export (`server/public`), the web shell, the
web export preset, `tools/export_web.sh` and the browser test harnesses are deleted, not archived.

What lives on in the current game (`game/`): the TMNF physics core, the procedural mesh kit and the
car/environment shader ideas — ported, not referenced.
