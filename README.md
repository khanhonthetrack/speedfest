# SpeedFest web build (static)

Built from `main@eac62e7` with Godot 4.7.2.stable.official.ed1daf0bf, export preset "Web" (single-threaded:
`variant/thread_support=false`). Serve this folder with any static file server, also from a
sub-path (e.g. `/speedfest/`); no COOP/COEP headers needed. Example:
`python3 -m http.server 8000` then open http://localhost:8000/.

Online rooms need the game server (`server/` on `main`); a static host runs solo mode.
Rebuild: `tools/publish_web_build.sh --push` on `main` (docs/HOSTING.md "Static web build").
