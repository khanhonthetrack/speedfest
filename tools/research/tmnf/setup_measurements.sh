#!/usr/bin/env bash
# Recreates, from public sources only, the local TMNF data the Stadium remake's block work uses
# (measurements for new block families, the fidelity test, the official campaign for map/race
# tests). Everything lands in WORK, outside the repo. NEVER commit anything this produces: it is
# Nadeo's data (the repo keeps only our own generators and numbers).
#
#   WORK/tmnf/app/            the TMNF install (TmForever.exe, Packs/, GameData/Tracks/Campaigns)
#   WORK/classmap.json        class ids (from TmForever.exe + its .map + ModTMNF's class hierarchy)
#   WORK/pak_Stadium.txt      the Stadium pack's listing (names from GBX.NET's FileHashes.txt)
#   WORK/blocks/raw/          decrypted block infos, mobils, materials, solids
#   WORK/blocks/blockinfos.json, material_surfaces.json, campaign_blocks.json
#   WORK/blocks/meas/*.json   collision meshes in block space (what the fidelity test reads)
#
# usage: tools/research/tmnf/setup_measurements.sh WORK [--quick]
#   --quick: only a few solids (checks the pipeline in a minute); the full run decrypts every
#   Stadium solid and takes much longer (run it in the background).
# needs: curl, 7z (p7zip-full), innoextract, git, python3 (apt-get install p7zip-full innoextract)
# then:  TMNF_DIR=WORK/tmnf/app stadium/tools/test_all.sh
#        stadium/tools/run.sh res://tests/test_block_fidelity.tscn --headless -- --meas=WORK/blocks/meas
set -euo pipefail
T="$(cd "$(dirname "$0")" && pwd)"
[[ $# -ge 1 ]] || { sed -n 2,22p "$0"; exit 2; }
W="$(realpath -m "$1")"
QUICK=0; [[ "${2:-}" == "--quick" ]] && QUICK=1
SETUP_URL=https://nadeo-download.cdn.ubi.com/trackmaniaforever/tmnationsforever_setup.exe
SETUP_SHA=2f659138ed4409da404970841e18f03d29921beaf6a424824c8312ddb20f6355
mkdir -p "$W"
cd "$W"

step() { echo "== $*"; }

if [[ ! -f tmnf/app/TmForever.exe ]]; then
  step "TMNF installer (official, freeware)"
  [[ -f tmnationsforever_setup.exe ]] || curl -sS -C - --retry 5 -o tmnationsforever_setup.exe "$SETUP_URL"
  echo "$SETUP_SHA  tmnationsforever_setup.exe" | sha256sum -c -
  mkdir -p tmnf
  # a 7-Zip SFX around an Inno Setup installer
  (cd tmnf && 7z x -y ../tmnationsforever_setup.exe >/dev/null && innoextract -s -q TmNationsForever_Setup_Tmp.exe)
fi

step "reference data (public repos)"
[[ -d modtmnf ]] || git clone -q --depth 1 https://github.com/pixeltris/modtmnf modtmnf
[[ -d gbx-net ]] || git clone -q --depth 1 https://github.com/BigBang1112/gbx-net gbx-net
[[ -f modtmnf_gen/Generated/ClassHierarchy.txt ]] || python3 -I -c \
  "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
  modtmnf/ModTMNF/Analysis/Docs/Generated.zip modtmnf_gen

step "class ids and the pack listing"
[[ -f seeds.tsv ]] || python3 -I "$T/map2seeds.py" tmnf/app/TmForever.map seeds.tsv
[[ -f classmap.json ]] || python3 -I "$T/classmap.py" tmnf/app/TmForever.exe seeds.tsv \
  modtmnf_gen/Generated/ClassHierarchy.txt classmap.json
[[ -s pak_Stadium.txt ]] || python3 -I "$T/nadeopak.py" list tmnf/app/Packs Stadium \
  gbx-net/Resources/FileHashes.txt > pak_Stadium.txt

mkdir -p blocks
cd blocks
step "decrypting block infos, mobils and materials"
python3 -I "$T/decrypt_all.py" "$W" 'ConstructionBlockInfo'
python3 -I "$T/decrypt_all.py" "$W" '\.Mobil\.Gbx$'
python3 -I "$T/decrypt_all.py" "$W" '\.Material\.Gbx$'
step "decrypting solids$([[ $QUICK -eq 1 ]] && echo ' (quick: Road/Main straights and checkpoints only)')"
if [[ $QUICK -eq 1 ]]; then
  python3 -I "$T/decrypt_all.py" "$W" 'Road\\Main\\(Straight|Checkpoint)\\'
else
  python3 -I "$T/decrypt_all.py" "$W" '\.Solid\.Gbx$'
fi
step "block infos, materials, campaign usage, collision meshes"
python3 -I "$T/blockinfo_dump.py" raw blockinfos.json
python3 -I "$T/material_surfaces.py" raw material_surfaces.json
python3 -I "$T/campaign_blocks.py" "$W/tmnf/app/GameData/Tracks/Campaigns/Nations" campaign_blocks.json
python3 -I "$T/extract_surf.py"
echo "MEASUREMENTS READY: $(ls meas | wc -l) meshes in $W/blocks/meas; TMNF install: $W/tmnf/app"
