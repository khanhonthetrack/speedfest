#!/usr/bin/env bash
# Import all assets of game/ (creates game/.godot cache). Run once per checkout, whenever you add
# assets (fonts, audio, textures, shaders) and after adding a script with a new class_name.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
timeout 600 godot --headless --path "$ROOT/game" --import 2>&1 | grep -vE "^\s*$" | tail -20
exit 0
