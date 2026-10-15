#!/usr/bin/env bash
# Static web build -> orphan branch `web-build` (files at the branch root, index.html at the root).
# Single-threaded Godot web export (preset "Web", variant/thread_support=false): no
# SharedArrayBuffer, so it needs NO COOP/COEP headers and runs from any plain static file server,
# also from a sub-path (all URLs in index.html are relative). Online play needs the Node server
# (server/); on a static host the game runs solo (menus, garage, all tracks, ghosts).
#
# usage: tools/publish_web_build.sh [--push]     (optional env WEB_BUILD_TRAILER: extra commit
#        message paragraph, e.g. Co-Authored-By lines)
# needs: Godot 4.7.2 + export templates (CLAUDE.md), git.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUSH=0; [[ "${1:-}" == "--push" ]] && PUSH=1
SRC="$(git -C "$ROOT" rev-parse --short HEAD)"
TMP="$(mktemp -d)"
trap 'git -C "$ROOT" worktree remove --force "$TMP/wt" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT
"$ROOT/tools/export_web.sh" "$TMP/out" >/dev/null
test -f "$TMP/out/index.html" -a -f "$TMP/out/index.pck" -a -f "$TMP/out/index.wasm"
cd "$ROOT"
if git ls-remote --exit-code --heads origin web-build >/dev/null 2>&1; then
  git fetch -q origin web-build
  git worktree add -q -B web-build "$TMP/wt" origin/web-build
else
  git worktree add -q --detach "$TMP/wt"
  (cd "$TMP/wt" && git checkout -q --orphan web-build && git rm -rq --cached . && git clean -fdxq)
fi
cd "$TMP/wt"
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$TMP/out/." .
touch .nojekyll
GV="$(godot --version | head -1)"
cat > README.md <<MD
# SpeedFest web build (static)

Built from \`main@${SRC}\` with Godot ${GV}, export preset "Web" (single-threaded:
\`variant/thread_support=false\`). Serve this folder with any static file server, also from a
sub-path (e.g. \`/speedfest/\`); no COOP/COEP headers needed. Example:
\`python3 -m http.server 8000\` then open http://localhost:8000/.

Online rooms need the game server (\`server/\` on \`main\`); a static host runs solo mode.
Rebuild: \`tools/publish_web_build.sh --push\` on \`main\` (docs/HOSTING.md "Static web build").
MD
git add -A
git -c user.name="$(git -C "$ROOT" config user.name || echo speedfest)" -c user.email="$(git -C "$ROOT" config user.email || echo speedfest@localhost)" \
  commit -qm "web: static build of main@${SRC} (Godot ${GV}, single-threaded, no COOP/COEP)" \
  ${WEB_BUILD_TRAILER:+-m "$WEB_BUILD_TRAILER"} || echo "no changes"
git log --oneline -1
if [[ $PUSH -eq 1 ]]; then
  for i in 1 2 3 4; do git push -q -u origin web-build && break; sleep $((2 ** i)); done
fi
