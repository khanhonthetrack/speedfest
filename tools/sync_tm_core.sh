#!/usr/bin/env bash
# The TMNF car model lives in stadium/core (the Stadium remake) and is copied, unchanged, into
# game/cars/tm for SpeedFest. usage: tools/sync_tm_core.sh          copy stadium -> game
#                                     tools/sync_tm_core.sh --check  fail if the copies differ
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILES=(tm_tuning.gd tm_car_model.gd tm_body.gd)
if [[ "${1:-}" == "--check" ]]; then
  for f in "${FILES[@]}"; do
    if ! cmp -s "$ROOT/stadium/core/$f" "$ROOT/game/cars/tm/$f"; then
      echo "TM_CORE_OUT_OF_SYNC $f (run tools/sync_tm_core.sh)"; exit 1
    fi
  done
  echo "TM_CORE_IN_SYNC"; exit 0
fi
mkdir -p "$ROOT/game/cars/tm"
for f in "${FILES[@]}"; do cp "$ROOT/stadium/core/$f" "$ROOT/game/cars/tm/$f"; done
echo "copied ${FILES[*]} to game/cars/tm"
