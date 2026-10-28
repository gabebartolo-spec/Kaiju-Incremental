#!/usr/bin/env bash
# Speed-run driver: interleaved rounds of capture_one_look --frames, read as GPU ms (D-299, D-313).
#
# Wall frame time is CPU-bound at 4K (about 30 ms against 21 ms of GPU) and swings +-2 ms between
# identical configs, so it cannot judge a bar of 0.05 ms. capture_one_look prints both lines:
#   ONEL frame ms mean .. median .. p95 .. max ..   (wall, noisy)
#   ONEL gpu ms mean .. median .. p95 .. max ..     (RenderingServer measured render time of the viewport)
# Judge a speed bar on the GPU line; the wall line is context.
#
# The driver holds C:/kt/BENCH_WINDOW_<OWNER> from the first run to the last (touched every 4 s), and before
# EVERY run waits until no other Godot (headless included) and no League of Legends is running, at two checks
# 20 s apart. While a run is going it samples the other-Godot count every 4 s: a run whose count was above 0
# (or that saw League, or printed no GPU line) is VOID and is run again (up to 4 tries). It touches
# C:/kt/SPEED_LAST_END only at the very end.
#
#   GODOT=<console exe> OUT=<dir> [ROUNDS=3] [OWNER=perf-p1c] [CONFIGS=...] [COMMON=...] \
#     bash C:/kt/wait_window.sh && bash tools/capture/bench_driver.sh        (cwd = the worktree)
#
#   CONFIGS: one config per line, "name|extra capture_one_look args" (default: the P1c four,
#            off/both for item 3 and cur/new for item 4). A round runs every config once, in order.
#   COMMON:  args every config shares (default: stage 3, Medium, night, calm, replayed route, 600 frames).
#   ROUTE:   the replay route file (default the baseline's route.json).
# Output: <OUT>/COST.txt (every run, its others count, VALID or VOID, and a final SUMMARY of the VALID runs
# per config: mean of the GPU mean and median, and of the wall mean), <OUT>/run_<name>.log (the raw run).
# The DLL path and date are logged first: a bench on the wrong native library measures the script fallback.
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT to the console exe}" "${OUT:?set OUT to a scratch folder}"
ROUNDS="${ROUNDS:-3}"
OWNER="${OWNER:-perf-p1c}"
ROUTE="${ROUTE:-C:/Users/DANTE/AppData/Local/Temp/claude/pb/route.json}"
TAG="bench_driver_$OWNER"
WINDOW="C:/kt/BENCH_WINDOW_$OWNER"
COMMON="${COMMON:---stage=3 --graphics=medium --time=night --calm --route=replay --route-file=$ROUTE --frames=600}"
CONFIGS="${CONFIGS:-off|--set=deband=false --tune=display.graphics.medium.fsr_sharpness=0.2
both|
cur|--set=agx_contrast=1.25,post_contrast=1.3
new|}"
mkdir -p "$OUT"
LOG="$OUT/COST.txt"
VALID="$OUT/valid.tsv"

others_count() {  # Godot processes that are not this driver's runs (headless ones count)
	powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -notmatch '$TAG' }).Count" | tr -d '\r\n '
}
league() {
	tasklist 2> /dev/null | grep -qi "League of Legends" && return 0
	nvidia-smi --query-compute-apps=name --format=csv,noheader 2> /dev/null | grep -qi league && return 0
	return 1
}
finish() {
	[ -n "${HELD:-}" ] || return 0
	rm -f "$WINDOW"
	[ -n "${MADE_CFG:-}" ] && rm -f override.cfg
	touch C:/kt/SPEED_LAST_END
}
trap finish EXIT

# take the window: nobody else may hold one (the Godot queue's own BENCH_WINDOW_gq is held for this very job)
if ls C:/kt/BENCH_WINDOW* 2> /dev/null | grep -v -e "BENCH_WINDOW_$OWNER" -e "BENCH_WINDOW_gq" | grep -q .; then
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
	echo "== bench_driver $(date '+%F %H:%M:%S') sha $(git rev-parse --short HEAD) owner $OWNER rounds $ROUNDS"
	for dll in native/bin/*.dll; do [ -e "$dll" ] && echo "   DLL $(pwd)/$dll $(date -r "$dll" '+%F %H:%M')"; done
	echo "   common: $COMMON"
} | tee -a "$LOG"

run_one() { # $1 = config name, $2 = its extra args, $3 = run id; 0 = VALID, 1 = VOID
	local cfg="$1" extra="$2" run="$3" rl="$OUT/run_$3.log" maxo=0 o
	while true; do # wait for silence, twice 20 s apart
		touch "$WINDOW"
		if [ "$(others_count)" = 0 ] && ! league; then
			sleep 20
			touch "$WINDOW"
			if [ "$(others_count)" = 0 ] && ! league; then break; fi
		fi
		sleep 15
	done
	echo "== $run $(date +%H:%M:%S) $extra" | tee -a "$LOG"
	# shellcheck disable=SC2086  # COMMON and extra are word-split on purpose
	APPDATA="$OUT/appdata_$run" timeout 900 "$GODOT" --path . --resolution 3840x2160 --windowed \
		--fixed-fps 60 --disable-vsync --script tools/capture/capture_one_look.gd -- $COMMON \
		--out="$OUT" --label="$run" --tag="$TAG" $extra > "$rl" 2>&1 &
	local pid=$!
	while kill -0 "$pid" 2> /dev/null; do
		touch "$WINDOW"
		o=$(others_count)
		o=${o:-0}
		[ "$o" -gt "$maxo" ] 2> /dev/null && maxo=$o
		sleep 4
	done
	wait "$pid"
	grep -E "ONEL frame|ONEL gpu|SCRIPT ERROR" "$rl" | tee -a "$LOG"
	local lg=""
	league && lg="+League"
	if [ "$maxo" = 0 ] && [ -z "$lg" ] && grep -q "ONEL gpu" "$rl"; then
		echo "   others=0 VALID" | tee -a "$LOG"
		# cfg, GPU mean, GPU median, wall mean (ONEL lines: field 5 = mean, 7 = median)
		printf '%s\t%s\t%s\t%s\n' "$cfg" \
			"$(grep 'ONEL gpu' "$rl" | awk '{print $5}')" "$(grep 'ONEL gpu' "$rl" | awk '{print $7}')" \
			"$(grep 'ONEL frame' "$rl" | awk '{print $5}')" >> "$VALID"
		return 0
	fi
	echo "   others=$maxo$lg VOID" | tee -a "$LOG"
	return 1
}

: > "$VALID"
mapfile -t CFG_LINES <<< "$CONFIGS" # an array, so no run can swallow the config list from stdin
for round in $(seq 1 "$ROUNDS"); do
	for line in "${CFG_LINES[@]}"; do
		name="${line%%|*}"
		extra="${line#*|}"
		[ -n "$name" ] || continue
		for try in 1 2 3 4; do
			run_one "$name" "$extra" "${name}_r${round}t${try}" && break
		done
	done
done
{
	echo "SUMMARY (VALID runs only; GPU ms is the judge, wall ms is context)"
	awk -F'\t' '{n[$1]++; g[$1]+=$2; m[$1]+=$3; w[$1]+=$4; if(!($1 in o)){o[$1]=++k; nm[k]=$1}}
		END{for(i=1;i<=k;i++){c=nm[i]; printf "SUMMARY %-8s n=%d gpu_mean %.3f gpu_median %.3f wall_mean %.2f\n", c, n[c], g[c]/n[c], m[c]/n[c], w[c]/n[c]}}' "$VALID"
	echo ALLDONE
} | tee -a "$LOG"
