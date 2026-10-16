#!/usr/bin/env bash
# Export the optional RTX build for Windows (docs/RTX.md "Giving an RTX build to friends").
# SpeedFest is exported with stock Godot 4.7.2 into a release template built from NVIDIA's fork
# (nvidia-pt-dlss, 4.8-dev). The fork reads 4.7 packs: same PCK format (v4) and GDScript tokenizer
# (101). Exporting with 4.7.2 also avoids the fork's headless import, which skips BPTC textures.
#   build/SpeedFest-RTX/SpeedFest.exe (+ SpeedFest.console.exe, README-RTX.txt, add_nvidia_dlss.bat/.ps1)
#   build/SpeedFest-windows-rtx.zip
# The NVIDIA DLLs (DLSS / Streamline runtime) aren't included: add_nvidia_dlss.bat in the folder fetches
# them on the player's PC. They're only added here when STREAMLINE_DIR points at an
# extracted streamline-sdk-v2.10.0: its bin/x64 DLLs (not bin/x64/development) and license files.
# Never commit them or upload them from CI (NVIDIA RTX SDK license, docs/RTX.md).
#
# usage: [STREAMLINE_DIR=/path/streamline-sdk-v2.10.0] tools/export_rtx.sh <godot.windows.template_release.x86_64.exe>
#        (the fork's console wrapper, <same name>.console.exe, must sit next to the template)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# -ge 1 ]] || { echo "usage: tools/export_rtx.sh <fork template_release .exe>" >&2; exit 2; }
TPL="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
test -s "$TPL" || { echo "template not found: $TPL" >&2; exit 1; }
[[ -s "${TPL%.exe}.console.exe" || -s "${TPL%.exe}_console.exe" ]] || echo "warning: no console wrapper next to the template" >&2
OUT="$ROOT/build/SpeedFest-RTX"
ZIP="$ROOT/build/SpeedFest-windows-rtx.zip"

# A temporary "Windows RTX" preset: a copy of "Windows" with the fork template, the console wrapper
# in release builds too (friends can see errors), and no shader baking (4.7.2's baked shaders
# don't match the fork). export_presets.cfg is restored afterwards.
PRESETS="$ROOT/game/export_presets.cfg"
cp "$PRESETS" "$PRESETS.rtx-bak"
trap 'mv -f "$PRESETS.rtx-bak" "$PRESETS"' EXIT
python3 - "$PRESETS" "$TPL" <<'EOF'
import re, sys
path, tpl = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
parts = re.split(r"(?m)^(?=\[preset\.\d+(?:\.options)?\]\s*$)", text)
blocks = {}
for p in parts:
    m = re.match(r"\[preset\.(\d+)(\.options)?\]", p)
    if m:
        blocks[(int(m.group(1)), bool(m.group(2)))] = p
win = next(i for (i, opt), b in blocks.items() if not opt and re.search(r'(?m)^name="Windows"$', b))
new = max(i for i, _ in blocks) + 1
def setv(block, key, value):
    pat = re.compile(r"(?m)^%s=.*$" % re.escape(key))
    line = "%s=%s" % (key, value)
    return pat.sub(line.replace("\\", "\\\\"), block) if pat.search(block) else block.rstrip("\n") + "\n" + line + "\n"
head = blocks[(win, False)].replace("[preset.%d]" % win, "[preset.%d]" % new, 1)
head = setv(head, "name", '"Windows RTX"')
head = setv(head, "export_path", '"../build/SpeedFest-RTX/SpeedFest.exe"')
opts = blocks[(win, True)].replace("[preset.%d.options]" % win, "[preset.%d.options]" % new, 1)
opts = setv(opts, "custom_template/release", '"%s"' % tpl)
opts = setv(opts, "debug/export_console_wrapper", "2")
opts = setv(opts, "shader_baker/enabled", "false")
opts = setv(opts, "application/file_description", '"SpeedFest RTX - arcade stunt time-attack racer (NVIDIA DLSS / path tracing build)"')
open(path, "w", encoding="utf-8").write(text.rstrip("\n") + "\n\n" + head.rstrip("\n") + "\n\n" + opts.rstrip("\n") + "\n")
EOF

"$ROOT/tools/godot_import.sh" >/dev/null 2>&1 || true
rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT"
godot --headless --path "$ROOT/game" --export-release "Windows RTX" "$OUT/SpeedFest.exe" 2>&1 | grep -vE "^\s*$" | tail -8
test -s "$OUT/SpeedFest.exe"
for f in README-RTX.txt add_nvidia_dlss.bat add_nvidia_dlss.ps1; do   # CRLF for Notepad/cmd
  sed 's/\r*$/\r/' "$ROOT/tools/rtx/$f" > "$OUT/$f"
done
if [[ -n "${STREAMLINE_DIR:-}" ]]; then
  cp "$STREAMLINE_DIR"/bin/x64/*.dll "$OUT/"
  find "$STREAMLINE_DIR" -maxdepth 3 -iname "*license*" -type f ! -path "*/development/*" -exec cp {} "$OUT/" \;
  echo "added the NVIDIA Streamline/DLSS runtime from $STREAMLINE_DIR (do not commit the result)"
fi
(cd "$ROOT/build" && python3 -c "import shutil,sys; shutil.make_archive(sys.argv[1], 'zip', '.', 'SpeedFest-RTX')" "${ZIP%.zip}")
ls -la "$OUT" "$ZIP"
