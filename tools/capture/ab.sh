#!/usr/bin/env bash
# ab.sh: the same seeded shot on a base ref and on this checkout, as one labelled before/after sheet
# (rule 7's evidence for a visual PR). Both sides run tools/capture/shot.gd with identical flags.
#
#   bash tools/capture/ab.sh --out=C:/kt/ab/water -- --still-at=8,12 --time=night
#   bash tools/capture/ab.sh --base=origin/main --out=DIR -- <shot.gd flags>
#
# The base side is a detached worktree at ../Kaiju-Incremental-wt/_ab-base (made once, moved to the
# base ref on each run, prepared by tools/wt_setup.sh). This checkout's shot.gd and wt_setup.sh are
# copied into it untracked, so a base older than these tools still works. Runs go through gpu_slot
# one after the other, never at once. Output: DIR/before_*.png, DIR/after_*.png, DIR/ab_sheet.png
# (before row over after row), DIR/{before,after}.log.
# Env: GODOT, GPU_SLOT (as wt_setup.sh), PY (default C:/Python314/python.exe),
#      SHEET (default ~/.claude/tools/look_sheet.py), RES (default 1920x1080).
set -u
cd "$(dirname "$0")/../.." || exit 1
HERE="$PWD"
BASE=origin/main
OUT=""
while [ $# -gt 0 ]; do
	case "$1" in
	--base=*) BASE="${1#--base=}" ;;
	--out=*) OUT="${1#--out=}" ;;
	--) shift; break ;;
	*) echo "ab.sh: unknown option $1 (shot.gd flags go after --)"; exit 2 ;;
	esac
	shift
done
[ -n "$OUT" ] || { echo "ab.sh: --out=DIR is required"; exit 2; }
GODOT="${GODOT:-$(command -v godot || echo C:/kt/godotbin/godot)}"
GPU_SLOT="${GPU_SLOT:-C:/kt/gpu_slot.sh}"
PY="${PY:-C:/Python314/python.exe}"
SHEET="${SHEET:-$HOME/.claude/tools/look_sheet.py}"
RES="${RES:-1920x1080}"
WT="$(dirname "$HERE")/_ab-base"
mkdir -p "$OUT"

git fetch -q origin 2> /dev/null
if [ ! -d "$WT" ]; then
	git worktree add -q --detach "$WT" "$BASE" || exit 1
else
	git -C "$WT" checkout -q --detach "$BASE" || exit 1
fi
cp tools/capture/shot.gd "$WT/tools/capture/shot.gd"
cp tools/wt_setup.sh "$WT/tools/wt_setup.sh"
(cd "$WT" && bash tools/wt_setup.sh > /dev/null) || { (cd "$WT" && bash tools/wt_setup.sh --check); exit 1; }
bash tools/wt_setup.sh > /dev/null || { bash tools/wt_setup.sh --check; exit 1; }

args=("$@")
rm -f "$OUT"/before_*.png "$OUT"/after_*.png
shoot() { # dir, tag
	local appdata
	appdata="$(cygpath -w "$OUT" 2> /dev/null || echo "$OUT")\\appdata_$2"
	(cd "$1" && APPDATA="$appdata" GPU_SLOT_OWNER="ab-$2" timeout 600 bash "$GPU_SLOT" "$GODOT" --path . \
		--resolution "$RES" --windowed --fixed-fps 60 --script tools/capture/shot.gd -- \
		"${args[@]}" --out="$OUT" --tag="$2" > "$OUT/$2.log" 2>&1)
}
fail=0
shoot "$WT" before || { echo "before run failed: $OUT/before.log"; fail=1; }
shoot "$HERE" after || { echo "after run failed: $OUT/after.log"; fail=1; }
grep -h "^shot: saved" "$OUT/before.log" "$OUT/after.log" 2> /dev/null
[ "$fail" = 0 ] || exit 1

before=("$OUT"/before_*.png)
after=("$OUT"/after_*.png)
[ "${#before[@]}" = "${#after[@]}" ] || { echo "ab.sh: ${#before[@]} before stills, ${#after[@]} after"; exit 1; }
"$PY" "$SHEET" --out "$OUT/ab_sheet.png" --cols "${#before[@]}" \
	--title "before $(git -C "$WT" rev-parse --short HEAD) (top) / after $(git rev-parse --short HEAD) + working tree (bottom)" \
	"${before[@]}" "${after[@]}"
