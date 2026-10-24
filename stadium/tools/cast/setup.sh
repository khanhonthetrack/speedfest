#!/usr/bin/env bash
# The cast's tools (PLAN M20-9): Blender 4.5.15 LTS, the MPFB 2.0.18 add-on, the MakeHuman asset
# packs and the stylised cast's Quaternius packs in packs.lock.json, each checked by sha256, into a
# cache outside the repo (about 3 GB):
#   CAST_CACHE=<dir> stadium/tools/cast/setup.sh      (default ~/.cache/speedfest-cast)
# then `source $CAST_CACHE/env.sh` gives BLENDER and BLENDER_USER_RESOURCES for build.sh.
# Downloads resume (curl -C -) and are skipped when the file in the cache already matches.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="${CAST_CACHE:-$HOME/.cache/speedfest-cast}"
LOCK="$HERE/packs.lock.json"
mkdir -p "$CACHE/zips"
field() { python3 -I -c "import json,sys; d=json.load(open('$LOCK')); print(eval(sys.argv[1]))" "$1"; }

fetch() {   # url sha256 path
  local url="$1" sum="$2" out="$3"
  if [[ -f "$out" ]] && echo "$sum  $out" | sha256sum -c --status; then return 0; fi
  for i in 1 2 3 4; do
    curl -sSL -C - --retry 3 -o "$out" "$url" && break || sleep $((2 ** i))
  done
  if ! echo "$sum  $out" | sha256sum -c --status; then
    echo "SETUP_FAIL sha256 mismatch: $out" >&2; rm -f "$out"; exit 1
  fi
}

# Blender 4.5.15 LTS (the build the cast was made with: outputs depend on the version)
BVER=$(field 'd["blender"]["version"]'); BDIR="$CACHE/$(field 'd["blender"]["dir"]')"
if [[ ! -x "$BDIR/blender" ]]; then
  if command -v blender >/dev/null && blender --version 2>/dev/null | head -1 | grep -q "Blender $BVER"; then
    BDIR="$(dirname "$(readlink -f "$(command -v blender)")")"
  else
    fetch "$(field 'd["blender"]["url"]')" "$(field 'd["blender"]["sha256"]')" "$CACHE/blender.tar.xz"
    tar -xJf "$CACHE/blender.tar.xz" -C "$CACHE" && rm -f "$CACHE/blender.tar.xz"
  fi
fi
BLENDER="$BDIR/blender"

# MPFB 2.0.18 into its own Blender user folder (the add-on, GPL, never ships: only what it builds)
export BLENDER_USER_RESOURCES="$CACHE/bl_user"
MPFB_ZIP="$CACHE/zips/$(field 'd["mpfb"]["file"]')"
fetch "$(field 'd["mpfb"]["url"]')" "$(field 'd["mpfb"]["sha256"]')" "$MPFB_ZIP"
DATA="$BLENDER_USER_RESOURCES/extensions/.user/user_default/mpfb/data"
if [[ ! -d "$DATA" ]]; then
  "$BLENDER" -b --offline-mode --command extension install-file -r user_default -e "$MPFB_ZIP" >/dev/null
fi

# the packs: unzipped into MPFB's data folder (its own "load pack" button only extracts the zip there)
python3 -I -c "import json; [print(p['file'], p['sha256'], p['url']) for p in json.load(open('$LOCK'))['packs']]" |
while read -r file sum url; do
  fetch "$url" "$sum" "$CACHE/zips/$file"
  mark="$DATA/.unpacked_${file%.zip}"
  if [[ ! -f "$mark" ]]; then
    python3 -I -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$CACHE/zips/$file" "$DATA"
    touch "$mark"
  fi
done

# the stylised cast's sources (Quaternius' modular packs, CC0) into $CACHE/stylised/<pack>/
python3 -I -c "import json; [print(f['pack'], f['file'].replace(' ', '%20'), f['sha256'], f['url']) for f in json.load(open('$LOCK'))['stylised']['files']]" |
while read -r pack file sum url; do
  mkdir -p "$CACHE/stylised/$pack"
  fetch "$url" "$sum" "$CACHE/stylised/$pack/${file//%20/ }"
done

cat > "$CACHE/env.sh" <<EOF
export BLENDER="$BLENDER"
export BLENDER_USER_RESOURCES="$BLENDER_USER_RESOURCES"
export CAST_CACHE="$CACHE"
EOF
echo "SETUP_OK $CACHE ($("$BLENDER" --version 2>/dev/null | head -1))"
