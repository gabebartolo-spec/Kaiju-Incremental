#!/usr/bin/env bash
# drive_timing.sh: guarded bench driver. Replays a recorded route on the stage-3 city and writes per-frame timings
# (tools/capture/bench_frames.gd, render plan Phase 0). Waits for the PC, runs ONE windowed Godot, and kills only its own.
#
# Usage: ROUTE=<route.json> tools/bench/drive_timing.sh <worktree> <outdir> <label> <graphics> [time=night] [weather=clear]
#   ROUTE        the recorded route (required; record one with `tools/capture/capture_one_look.gd --route=record`)
#   GODOT        the Godot console exe (default: the desktop 4.7.2 console build)
#   MODE         timing = no other Godot at all and no League of Legends (p95 benches); guard (default) = no bench_/ablate
#                Godot and more than 6 GB free RAM
#   BENCH_ROLE   your role name, for your bench-window file (default: drive)
#   KT_DIR       the folder holding the window files (default: C:/kt)
#   DRY_RUN=1    do the waiting and the window protocol, print what would launch, launch nothing
# Window protocol (machine rules D-292, D-299): a windowed launch waits while any $KT_DIR/BENCH_WINDOW* that is not yours
# was touched in the last 20 min (older flags are stale), and while the director's ~/.claude/focus-pause exists.
# MODE=timing takes $KT_DIR/BENCH_WINDOW_<role> itself, only when none is live, for this ONE run (it keeps touching it),
# and removes it on exit, also on a signal.
# Headless Godot runs may go beside a bench (D-292). Needs the bench scripts of PR #259 (tools/capture/bench_frames.gd).
# Kills the run (its own process tree only) if the log passes 5 MB (FLOOD) or 25 min pass (TIMEOUT).
set -u
if [ "$#" -lt 4 ]; then
  sed -n '2,/^set -u/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
  exit 64
fi
W="$1"; OUT="$2"; LABEL="$3"; GFX="$4"; TOD="${5:-night}"; WX="${6:-clear}"
ROUTE="${ROUTE:?set ROUTE=<route.json> (record one with tools/capture/capture_one_look.gd --route=record)}"
G="${GODOT:-C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
ROLE="${BENCH_ROLE:-drive}"
KT="${KT_DIR:-C:/kt}"
MY_WINDOW="$KT/BENCH_WINDOW_$ROLE"
[ -f "$W/tools/capture/bench_frames.gd" ] || { echo "no $W/tools/capture/bench_frames.gd (needs PR #259)"; exit 4; }
mkdir -p "$OUT"
took_window=0
release_window() { [ "$took_window" = 1 ] && rm -f "$MY_WINDOW"; took_window=0; }
nap() { sleep "$1" & wait $!; }  # a signal interrupts `wait`, a plain sleep would hold the trap for its whole length
trap release_window EXIT
trap 'release_window; exit 143' TERM
trap 'release_window; exit 130' INT HUP

others() { powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'godot%' and not Name like '%console%'\" | ForEach-Object { \$_.CommandLine }" | tr -d '\r' | grep -v -- '--headless'; }  # D-292: headless runs may go beside
free_gb() { powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB)" | tr -d '\r\n'; }
league() {  # the director's game: timing beside it is worthless (2026-10-16 rule)
  tasklist //FI "IMAGENAME eq League of Legends.exe" 2>/dev/null | grep -qi "League of Legends" && return 0
  nvidia-smi --query-compute-apps=process_name --format=csv,noheader 2>/dev/null | grep -qi "league" && return 0
  return 1
}
other_window() {  # another role's bench window (or the old unsuffixed BENCH_WINDOW) is live: touched within 20 min (D-299)
  [ -d "$KT" ] || return 1
  local f
  while IFS= read -r f; do
    [ "$f" = "$MY_WINDOW" ] && continue
    return 0
  done < <(find "$KT" -maxdepth 1 -name 'BENCH_WINDOW*' -mmin -20 2> /dev/null)
  return 1
}
busy() {
  [ -e "$HOME/.claude/focus-pause" ] && return 0  # the director's pause (D-299): wait it out, like wait_window.sh
  other_window && return 0
  if [ "${MODE:-guard}" = timing ]; then league && return 0; [ -n "$(others)" ]; return; fi
  others | grep -E "bench_|ablate" > /dev/null && return 0
  [ "$(free_gb)" -le 6 ]
}
while true; do
  if [ "${MODE:-guard}" = timing ] && [ "$took_window" = 0 ] && [ -d "$KT" ] && ! other_window; then
    touch "$MY_WINDOW" && took_window=1  # none is live: take mine, keep others from launching
  fi
  [ "$took_window" = 1 ] && touch "$MY_WINDOW"  # a flag older than 20 min counts as stale
  if ! busy; then nap 20; if ! busy; then break; fi; fi
  nap 30
done
if [ "${DRY_RUN:-0}" = 1 ]; then echo "$LABEL: would launch (window taken: $took_window)"; exit 0; fi
LOG="$OUT/$LABEL.log"
cd "$W" || exit 4
APPDATA="$OUT/appdata_$LABEL" "$G" --path . --resolution 3840x2160 --windowed --fixed-fps 60 --disable-vsync \
  --script tools/capture/bench_frames.gd -- --route-file="$ROUTE" --time="$TOD" --weather="$WX" \
  --graphics="$GFX" --out="$OUT" --label="$LABEL" > "$LOG" 2>&1 &
PID=$!
WPID=$(cat /proc/$PID/winpid 2>/dev/null)
start=$(date +%s); verdict=ok
while kill -0 $PID 2>/dev/null; do
  sz=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
  league && touch "$OUT/$LABEL.VOID_LEAGUE"
  if [ "$sz" -gt 5000000 ]; then verdict=FLOOD; fi
  if [ $(( $(date +%s) - start )) -gt 1500 ]; then verdict=TIMEOUT; fi
  if [ "$verdict" != ok ]; then
    taskkill //T //F //PID "$WPID" > /dev/null 2>&1; kill $PID 2>/dev/null; break
  fi
  [ "$took_window" = 1 ] && touch "$MY_WINDOW"
  nap 5
done
wait $PID 2>/dev/null; code=$?
sl=$(grep -c "self_list" "$LOG"); tc=$(grep -c "ThreadCheck:" "$LOG")
if [ "$verdict" = FLOOD ]; then head -c 200000 "$LOG" > "$LOG.head"; rm -f "$LOG"; fi
echo "$LABEL verdict=$verdict exit=$code self_list=$sl threadcheck_first=$tc"
