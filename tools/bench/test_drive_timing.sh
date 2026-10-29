#!/usr/bin/env bash
# Manual stand-in test of drive_timing.sh MODE=timing (D-299). Windows only (powershell, PING.EXE), about 5 minutes, no Godot,
# not part of CI. "Godot" processes are copies of PING.EXE named kgfake*.exe (GODOT_PROC_LIKE='kgfake%'); the "Godot" the
# script launches is a bash wrapper that starts one as its child. Cases:
#   A  any other Godot running (a stand-in, as a headless run would be): the run waits for it to end
#   B  a speed run ended 10 s ago (SPEED_LAST_END): the run waits out the 60 s turn gap
#   C  a full run with a foreign stand-in starting in the middle: verdict others=1 (the wrapper's own child is not
#      counted), SPEED_LAST_END touched, the run's window removed
#   D  a full run with nothing else: others=0
# Usage: bash tools/bench/test_drive_timing.sh [path to the drive_timing.sh to test]   (ONLY_CD=1 skips A and B)
DT="${1:-$(dirname "$0")/drive_timing.sh}"
W="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"; mkdir -p "$T/kt" "$T/out"
cp /c/Windows/System32/PING.EXE "$T/kgfake_a.exe"; cp /c/Windows/System32/PING.EXE "$T/kgfake_b.exe"
echo '{}' > "$T/route.json"
cat > "$T/fake_godot.sh" << EOF
#!/usr/bin/env bash
echo "\$(date +%s)" > "$T/launched_at"
"$T/kgfake_a.exe" -n 22 127.0.0.1 > /dev/null
EOF
chmod +x "$T/fake_godot.sh"
export GODOT_PROC_LIKE='kgfake%' KT_DIR="$T/kt" ROUTE="$T/route.json" BENCH_ROLE=x MODE=timing
bad=0
ok() { echo "ok: $1"; }
no() { echo "FAIL: $1"; bad=1; }

[ -z "${ONLY_CD:-}" ] && {
echo "== A: a stand-in Godot (any, headless or not) is running: the run waits for it"
"$T/kgfake_b.exe" -n 30 127.0.0.1 > /dev/null & BP=$!
s=$(date +%s)
DRY_RUN=1 bash "$DT" "$W" "$T/out" a high > "$T/a.out" 2>&1
e=$(( $(date +%s) - s )); kill -0 $BP 2>/dev/null && alive=1 || alive=0
cat "$T/a.out"
[ "$e" -ge 28 ] && [ "$alive" = 0 ] && ok "A waited ${e}s for the stand-in (30 s run) to end" || no "A took ${e}s, stand-in alive=$alive"
wait $BP 2>/dev/null

echo "== B: a speed run ended 10 s ago (SPEED_LAST_END): wait out the 60 s turn gap"
touch -d '10 seconds ago' "$T/kt/SPEED_LAST_END"
s=$(date +%s)
DRY_RUN=1 bash "$DT" "$W" "$T/out" b high > "$T/b.out" 2>&1
e=$(( $(date +%s) - s )); cat "$T/b.out"
[ "$e" -ge 68 ] && ok "B waited ${e}s (gap left 50 s + the 20 s recheck)" || no "B took only ${e}s"
rm -f "$T/kt/SPEED_LAST_END"
}

echo "== C: a full run; a foreign stand-in starts 8 s in; the wrapper's own child is not counted"
rm -f "$T/launched_at"
( while [ ! -e "$T/launched_at" ]; do sleep 1; done; sleep 8; "$T/kgfake_b.exe" -n 8 127.0.0.1 > /dev/null ) & CP=$!
GODOT="$T/fake_godot.sh" bash "$DT" "$W" "$T/out" c high > "$T/c.out" 2>&1
cat "$T/c.out"
grep -q "others=1$" "$T/c.out" && ok "C counted exactly the one foreign stand-in (others=1)" || no "C verdict: $(tail -1 "$T/c.out")"
ls "$T/out"; cat "$T/out/c.others" 2>/dev/null | cut -c1-80
age=$(( $(date +%s) - $(stat -c %Y "$T/kt/SPEED_LAST_END" 2>/dev/null || echo 0) ))
[ "$age" -lt 40 ] && ok "C touched SPEED_LAST_END (${age}s ago)" || no "C did not touch SPEED_LAST_END (age ${age}s)"
[ ! -e "$T/kt/BENCH_WINDOW_x" ] && ok "C removed its window" || no "C left its window"
wait $CP 2>/dev/null

echo "== D: a run with nothing else running: others=0"
rm -f "$T/kt/SPEED_LAST_END"
GODOT="$T/fake_godot.sh" bash "$DT" "$W" "$T/out" d high > "$T/d.out" 2>&1
tail -1 "$T/d.out"
grep -q "others=0$" "$T/d.out" && ok "D others=0" || no "D verdict: $(tail -1 "$T/d.out")"
[ "$bad" = 0 ] && echo "ALL OK" || echo "SOME FAILED"
rm -rf "$T"
exit $bad
