#!/usr/bin/env bash
# A video clip of a scene, for the owner (owner, 25 Oct: "Next time, i want to see clips, not just
# stills"): Godot's Movie Maker writes every frame at a fixed frame rate (however slowly it renders),
# with the game's sound, then ffmpeg makes an H.264 MP4 a browser plays.
#   stadium/tools/clip.sh <out.mp4> <res://scene.tscn> [--fps 30] [--size 1280x720] [--seconds S]
#                         [--skip S] [--crf 21] [--timeout 7000] -- [the scene's own args]
# --skip drops the first S seconds (a cutscene held on its first frame while its light settles:
# story_lab's --hold=<S * fps>); --seconds counts them (both may be fractions). --size is the size
# rendered (the cost); the movie comes out at the project's 1600x900 all the same. --timeout (s, default
# 7000) bounds the render: a run it cuts ends CLIP_SHORT, exit 2, the movie kept as far as it got (a
# frame with the rear-view mirror at Ultra takes 8-15 s on 4 cores: give long mirror clips more).
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
QUIT=""; [[ "$SECONDS_" != "0" ]] && QUIT="--quit-after $(awk "BEGIN { printf \"%d\", $SECONDS_ * $FPS + 0.5 }")"
CMD=("$GODOT" --path "$ROOT" --rendering-method forward_plus --resolution "$SIZE" --write-movie "$TMP/clip.avi"
     --fixed-fps "$FPS" $QUIT "$SCENE" -- "$@")
if command -v xvfb-run >/dev/null; then
  timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 ${SIZE}x24" "${CMD[@]}" > "$TMP/godot.log" 2>&1
else
  timeout "$TIMEOUT" "${CMD[@]}" > "$TMP/godot.log" 2>&1
fi
STATUS=$?                                 # 124: the --timeout ran out (the movie is short)
grep -E "ERROR|SCRIPT ERROR" "$TMP/godot.log" | head -5
[[ -s "$TMP/clip.avi" ]] || { echo "CLIP_FAIL no movie (log: $TMP/godot.log)"; exit 1; }
ffmpeg -loglevel error -y -ss "$SKIP" -i "$TMP/clip.avi" -c:v libx264 -preset slow -crf "$CRF" -pix_fmt yuv420p \
  -movflags +faststart -c:a aac -b:a 160k "$OUT" || { echo "CLIP_FAIL ffmpeg"; exit 1; }
rm -rf "$TMP"
LEN="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")"
if [[ $STATUS -eq 124 ]]; then
  echo "CLIP_SHORT $OUT: the --timeout of $TIMEOUT s ran out at $LEN s (raise --timeout; the movie is kept as far as it got)"
  exit 2
fi
echo "CLIP_OK $OUT $LEN s, $(( $(stat -c %s "$OUT") / 1024 )) KB"
