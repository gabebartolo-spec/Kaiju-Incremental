#!/usr/bin/env bash
# Renders a tools/capture script on GitHub Actions (xvfb + Mesa software rendering) and
# downloads the PNG/MP4 results, so no windowed Godot runs on the director's PC.
#
#   tools/capture/ci_capture.sh capture_rig.gd -- --species=reptilian --stage=adult --out=dir
#   tools/capture/ci_capture.sh capture_looks.gd -- --out=dir
#
# Options before the script name: --movie (record a clip), --renderer=auto|forward_plus|
# mobile|gl_compatibility, --fps=N, --resolution=WxH, --ref=<branch> (default: current
# branch; it must be pushed). `--out=<dir>` among the script args is the LOCAL download
# directory (default: ./ci-capture-out); it is not forwarded to the script.
set -euo pipefail

movie=false renderer=auto fps=30 res=1280x720 ref="" script=""
while [ $# -gt 0 ]; do
  case "$1" in
    --movie) movie=true;;
    --renderer=*) renderer="${1#*=}";;
    --fps=*) fps="${1#*=}";;
    --resolution=*) res="${1#*=}";;
    --ref=*) ref="${1#*=}";;
    --) shift; break;;
    -*) echo "unknown option $1" >&2; exit 2;;
    *) script="$1";;
  esac
  shift
done
[ -n "$script" ] || { echo "usage: $0 [--movie] [--renderer=..] <script.gd> [-- script args, --out=<dir>]" >&2; exit 2; }

dest="./ci-capture-out"
args=()
for a in "$@"; do
  case "$a" in --out=*) dest="${a#*=}";; *) args+=("$a");; esac
done
case "$script" in
  capture_rig.gd|capture_cues.gd|capture_powers.gd)
    [ "$movie" = true ] || echo "note: $script is a clip script; add --movie to record it" >&2;;
esac

[ -n "$ref" ] || ref="$(git rev-parse --abbrev-ref HEAD)"
git ls-remote --exit-code --heads origin "$ref" >/dev/null || { echo "branch $ref is not pushed to origin" >&2; exit 1; }

before="$(gh run list --workflow=capture.yml --limit 1 --json databaseId --jq '.[0].databaseId // 0')"
# gh prints the new run's URL: take its id from there, so a run another session dispatched at the
# same moment is never mistaken for this one. Older gh prints nothing: then the first newer run.
said="$(gh workflow run capture.yml --ref "$ref" -f script="$script" -f args="${args[*]:-}" \
  -f renderer="$renderer" -f movie="$movie" -f fps="$fps" -f resolution="$res" 2>&1)"
echo "$said"
run="$(printf '%s\n' "$said" | grep -oE 'actions/runs/[0-9]+' | head -1 | cut -d/ -f3 || true)"

if [ -z "$run" ]; then
  echo "dispatched; waiting for the run to appear..."
  for _ in $(seq 1 30); do
    sleep 4
    run="$(gh run list --workflow=capture.yml --limit 5 --json databaseId,event \
      --jq "[.[] | select(.event==\"workflow_dispatch\" and .databaseId > $before)][-1].databaseId // empty")"
    [ -n "$run" ] && break
  done
fi
[ -n "$run" ] || { echo "run did not appear" >&2; exit 1; }
echo "run $run: $(gh run view "$run" --json url --jq .url)"

status=0
gh run watch "$run" --exit-status --interval 15 >/dev/null || status=$?
mkdir -p "$dest"
gh run download "$run" --dir "$dest" || { echo "no artifact downloaded" >&2; exit 1; }
echo "downloaded to $dest (run status: $status)"
exit "$status"
