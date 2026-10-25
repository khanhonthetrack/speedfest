#!/usr/bin/env bash
# A video clip of a scene, for the owner (owner, 25 Oct: "Next time, i want to see clips, not just
# stills"): Godot's Movie Maker writes every frame at a fixed frame rate (however slowly it renders),
# with the game's sound, then ffmpeg makes an H.264 MP4 a browser plays.
#   stadium/tools/clip.sh <out.mp4> <res://scene.tscn> [--fps 30] [--size 1280x720] [--seconds S]
#                         [--skip S] [--crf 21] [--timeout 7000] -- [the scene's own args]
# --skip drops the first S seconds (a cutscene held on its first frame while its light settles:
# story_lab's --hold=<S * fps>); --seconds counts them.
# A cutscene: res://story/story_lab.tscn [--seconds 17] -- --scene=c01_close --play [--t=23] (from
# --t, it quits at the scene's end or after --seconds); the cast: res://story/cast_lab.tscn --seconds 4 -- --who=kit,dee --clip=Stand_Talk --play
set -uo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"; SCENE="$2"; shift 2
FPS=30; SIZE=1280x720; SECONDS_=0; SKIP=0; CRF=21; TIMEOUT=7000
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fps) FPS="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --seconds) SECONDS_="$2"; shift 2 ;;
    --skip) SKIP="$2"; shift 2 ;;
    --crf) CRF="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
TMP="$(mktemp -d)"
QUIT=""; [[ "$SECONDS_" != "0" ]] && QUIT="--quit-after $(( SECONDS_ * FPS ))"
CMD=("$GODOT" --path "$ROOT" --rendering-method forward_plus --resolution "$SIZE" --write-movie "$TMP/clip.avi"
     --fixed-fps "$FPS" $QUIT "$SCENE" -- "$@")
if command -v xvfb-run >/dev/null; then
  timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 ${SIZE}x24" "${CMD[@]}" > "$TMP/godot.log" 2>&1
else
  timeout "$TIMEOUT" "${CMD[@]}" > "$TMP/godot.log" 2>&1
fi
grep -E "ERROR|SCRIPT ERROR" "$TMP/godot.log" | head -5
[[ -s "$TMP/clip.avi" ]] || { echo "CLIP_FAIL no movie (log: $TMP/godot.log)"; exit 1; }
ffmpeg -loglevel error -y -ss "$SKIP" -i "$TMP/clip.avi" -c:v libx264 -preset slow -crf "$CRF" -pix_fmt yuv420p \
  -movflags +faststart -c:a aac -b:a 160k "$OUT" || { echo "CLIP_FAIL ffmpeg"; exit 1; }
rm -rf "$TMP"
echo "CLIP_OK $OUT $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT") s, $(( $(stat -c %s "$OUT") / 1024 )) KB"
