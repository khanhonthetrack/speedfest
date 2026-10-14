#!/usr/bin/env bash
# Export the web build. Default output: server/public (committed, served by server/).
# usage: tools/export_web.sh [outdir] [--debug]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/server/public}"
MODE="--export-release"
[[ "${2:-}" == "--debug" ]] && MODE="--export-debug"
mkdir -p "$OUT"
"$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true
godot --headless --path "$ROOT/game" $MODE "Web" "$OUT/index.html" 2>&1 | grep -vE "^\s*$" | tail -20
ls -la "$OUT"
