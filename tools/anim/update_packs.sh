#!/usr/bin/env bash
# Rebuild the animation packs' manifests, and replace a pack from a newer zip.
#
# The four packs live in the repo at stadium/assets/anim/<pack>/ exactly as they shipped
# (stadium/assets/anim/CREDITS.md: sources and licences; docs/ANIMATIONS.md: the study). This
# keeps tools/anim/manifests/*.json in step with them.
#
# usage: tools/anim/update_packs.sh                        # rebuild every manifest
#        tools/anim/update_packs.sh <dir with zips>        # replace those packs, then rebuild
#        tools/anim/update_packs.sh <pack.zip> ...         # the same, named one by one
#
# After replacing a pack, run `godot --headless --path stadium --import` so Godot picks the new
# files up, and commit the .import files it writes beside them.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
packs="$root/stadium/assets/anim"
manifests="$root/tools/anim/manifests"

pack_id() {  # the pack a zip belongs to, from its name (an upload carries a random prefix)
    case "$(basename "$1" | tr '[:upper:]' '[:lower:]')" in
        *universal_animation_library*) echo ual_standard ;;
        *human_basic_motions*)         echo human_basic_motions ;;
        *emotes_and_social*)           echo motifect_emotes_social ;;
        *daily_life*)                  echo motifect_daily_life ;;
        *)                             echo "" ;;
    esac
}

zips=()
for arg in "$@"; do
    if [ -d "$arg" ]; then
        while IFS= read -r z; do zips+=("$z"); done \
            < <(find "$arg" -maxdepth 1 -name '*.zip' | sort)
    else
        zips+=("$arg")
    fi
done

for zip in ${zips+"${zips[@]}"}; do
    id="$(pack_id "$zip")"
    if [ -z "$id" ]; then
        echo "skipping $(basename "$zip"): not one of the four packs" >&2
        continue
    fi
    echo "== $id <- $(basename "$zip")"
    rm -rf "$packs/$id"
    mkdir -p "$packs/$id"
    python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
        "$zip" "$packs/$id"
    # Quaternius' zip wraps everything in one folder; the other three unpack flat. Strip it, so
    # every pack sits at stadium/assets/anim/<pack>/ the same way.
    inner="$(find "$packs/$id" -mindepth 1 -maxdepth 1)"
    if [ "$(printf '%s\n' "$inner" | wc -l)" -eq 1 ] && [ -d "$inner" ]; then
        mv "$inner"/* "$packs/$id/" && rmdir "$inner"
    fi
done

for dir in "$packs"/*/; do
    id="$(basename "$dir")"
    python3 "$root/tools/anim/inspect_packs.py" "$dir" --pack "$id" --quiet \
        --json "$manifests/$id.json"
done
