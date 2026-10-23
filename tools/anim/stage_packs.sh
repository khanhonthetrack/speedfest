#!/usr/bin/env bash
# Stage the owner's humanoid animation packs and rebuild their manifests.
#
# Three of the four packs may not be redistributed (docs/ANIMATIONS.md, "Licences"), so the repo
# keeps their inventories, not their files. The zips live with the owner; this unpacks them into
# the untracked assets/anim/<pack>/ at the repo root -- the same place the owner's other source
# material sits -- and rebuilds tools/anim/manifests/*.json from what it finds.
#
# usage: tools/anim/stage_packs.sh <dir with the zips>      (or pass the .zip files themselves)
#
# The CC0 pack (Quaternius' Universal Animation Library) does not need staging: it is committed,
# ready to use, at stadium/assets/anim/ual/.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$root/assets/anim"
manifests="$root/tools/anim/manifests"

if [ $# -eq 0 ]; then
    echo "usage: $0 <dir with the pack zips | zip ...>" >&2
    exit 2
fi

zips=()
for arg in "$@"; do
    if [ -d "$arg" ]; then
        while IFS= read -r z; do zips+=("$z"); done \
            < <(find "$arg" -maxdepth 1 -name '*.zip' | sort)
    else
        zips+=("$arg")
    fi
done

pack_id() {  # the pack a zip belongs to, from its name (the uploads carry a random prefix)
    case "$(basename "$1" | tr '[:upper:]' '[:lower:]')" in
        *universal_animation_library*) echo ual_standard ;;
        *human_basic_motions*)         echo human_basic_motions ;;
        *emotes_and_social*)           echo motifect_emotes_social ;;
        *daily_life*)                  echo motifect_daily_life ;;
        *)                             echo "" ;;
    esac
}

for zip in "${zips[@]}"; do
    id="$(pack_id "$zip")"
    if [ -z "$id" ]; then
        echo "skipping $(basename "$zip"): not one of the four packs" >&2
        continue
    fi
    dir="$out/$id"
    echo "== $id <- $(basename "$zip")"
    rm -rf "$dir"
    mkdir -p "$dir"
    python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
        "$zip" "$dir"
    python3 "$root/tools/anim/inspect_packs.py" "$dir" --pack "$id" --quiet \
        --json "$manifests/$id.json"
done

echo
echo "staged under $out (untracked). Clip tables: docs/ANIMATIONS.md"
