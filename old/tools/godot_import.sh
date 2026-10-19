#!/usr/bin/env bash
# Import all assets of the Godot project (creates game/.godot cache). Run once per checkout
# and whenever you add new assets (fonts, audio, textures, shaders).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
godot --headless --path "$ROOT/game" --import 2>&1 | grep -vE "^\s*$" | tail -20
