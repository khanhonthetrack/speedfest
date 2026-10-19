#!/usr/bin/env bash
# Parse-check every GDScript in the project (fast; catches syntax/type errors).
# Prints SCRIPT_ERROR lines and exits 1 if any script fails to load.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$ROOT/game/.godot/imported" ]]; then "$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true; fi
OUT=$(timeout 300 godot --headless --path "$ROOT/game" --audio-driver Dummy res://tests/check_scripts.tscn 2>&1)
echo "$OUT" | grep -E "SCRIPT_ERROR|SCRIPT_OK_COUNT|ERROR|error" | head -60
echo "$OUT" | grep -q "SCRIPT_ERRORS=0" && exit 0 || exit 1
