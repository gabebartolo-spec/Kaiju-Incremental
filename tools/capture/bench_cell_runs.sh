#!/usr/bin/env bash
# Speed-run driver for bench_cell_mesh.gd: interleaved low/high rounds of the remesh bench (render plan item 9;
# D-299, D-313: a timing run holds the PC, so this takes C:/kt/BENCH_WINDOW_<OWNER> like bench_driver.sh does).
#
# Each round runs the bench once per queue (low = main's behaviour, high = render_opt.remesh_high_priority), in
# that order, for headless (dummy renderer: finish_us understates, nothing is uploaded) and for MODES=windowed
# (a real renderer on the local GPU, a small no_focus window: finish_us then includes the mesh upload).
# Before EVERY run it waits for no other Godot (headless included), no League of Legends and >= 6 GB free RAM, at two
# checks 20 s apart; a run that saw another Godot while it ran is VOID and is run again (up to 4 tries).
#
#   GODOT=<console exe> OUT=<dir> [ROUNDS=3] [OWNER=perf-p3b] [MODES="windowed headless"] [CARVES=60] \
#     bash C:/kt/wait_window.sh && bash tools/capture/bench_cell_runs.sh        (cwd = the worktree)
#
# Output: <OUT>/COST.txt (DLL path and date, every run's lines, VALID or VOID), <OUT>/run_<mode>_<queue>_r<n>.log.
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT to the console exe}" "${OUT:?set OUT to a scratch folder}"
ROUNDS="${ROUNDS:-3}"
OWNER="${OWNER:-perf-p3b}"
MODES="${MODES:-windowed headless}"
CARVES="${CARVES:-60}"
TAG="bench_cell_$OWNER"
WINDOW="C:/kt/BENCH_WINDOW_$OWNER"
NEED_KB=6291456
mkdir -p "$OUT"
LOG="$OUT/COST.txt"

others_count() {
	powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -notmatch '$TAG' }).Count" | tr -d '\r\n '
}
league() {
	tasklist 2> /dev/null | grep -qi "League of Legends" && return 0
	nvidia-smi --query-compute-apps=name --format=csv,noheader 2> /dev/null | grep -qi league && return 0
	return 1
}
free_kb() { awk '/MemFree/ {print $2}' /proc/meminfo; }
quiet() { [ "$(others_count)" = 0 ] && ! league && [ "$(free_kb)" -ge "$NEED_KB" ]; }
finish() {
	[ -n "${HELD:-}" ] || return 0
	rm -f "$WINDOW"
	[ -n "${MADE_CFG:-}" ] && rm -f override.cfg
	touch C:/kt/SPEED_LAST_END
}
trap finish EXIT

if ls C:/kt/BENCH_WINDOW* 2> /dev/null | grep -v "BENCH_WINDOW_$OWNER" | grep -q .; then
	echo "another bench window is held; not starting (rerun behind wait_window.sh)" | tee -a "$LOG"
	exit 3
fi
touch "$WINDOW"
HELD=1
if [ ! -e override.cfg ]; then # the windowed run must never take focus
	printf '[display]\n\nwindow/size/mode=0\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\n' > override.cfg
	MADE_CFG=1
fi
{
	echo "== bench_cell_runs $(date '+%F %H:%M:%S') sha $(git rev-parse --short HEAD) owner $OWNER rounds $ROUNDS modes $MODES carves $CARVES"
	for dll in native/bin/*.dll; do [ -e "$dll" ] && echo "   DLL $(pwd)/$dll $(date -r "$dll" '+%F %H:%M')"; done
} | tee -a "$LOG"

run_one() { # $1 = mode, $2 = queue (low|high), $3 = run id; 0 = VALID, 1 = VOID
	local mode="$1" queue="$2" run="$3" rl="$OUT/run_$3.log" maxo=0 o flags
	while true; do # wait for silence, twice 20 s apart
		touch "$WINDOW"
		if quiet; then
			sleep 20
			touch "$WINDOW"
			if quiet; then break; fi
		fi
		sleep 15
	done
	if [ "$mode" = windowed ]; then flags="--windowed --resolution 1280x720"; else flags="--headless"; fi
	echo "== $run $(date +%H:%M:%S) mode $mode queue $queue" | tee -a "$LOG"
	# shellcheck disable=SC2086  # flags are word-split on purpose
	APPDATA="$OUT/appdata_$run" timeout 900 "$GODOT" --path . $flags --script tools/capture/bench_cell_mesh.gd -- \
		--carves="$CARVES" --priority="$queue" --tag="$TAG" > "$rl" 2>&1 &
	local pid=$!
	while kill -0 "$pid" 2> /dev/null; do
		touch "$WINDOW"
		o=$(others_count)
		o=${o:-0}
		[ "$o" -gt "$maxo" ] 2> /dev/null && maxo=$o
		sleep 4
	done
	wait "$pid"
	grep -E "native mesher loaded|finish_us|SCRIPT ERROR" "$rl" | tee -a "$LOG"
	local lg=""
	league && lg="+League"
	if [ "$maxo" = 0 ] && [ -z "$lg" ] && grep -q "finish_us" "$rl"; then
		echo "   others=0 VALID" | tee -a "$LOG"
		return 0
	fi
	echo "   others=$maxo$lg VOID" | tee -a "$LOG"
	return 1
}

for round in $(seq 1 "$ROUNDS"); do
	for mode in $MODES; do
		for queue in low high; do
			for try in 1 2 3 4; do
				run_one "$mode" "$queue" "${mode}_${queue}_r${round}t${try}" && break
			done
		done
	done
done
echo ALLDONE | tee -a "$LOG"
