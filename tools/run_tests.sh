#!/usr/bin/env bash
# Runs every Godot check CI runs (.github/workflows/tests.yml), locally or in Actions:
#   1. import the project (a script that fails to compile during import fails the run);
#   2. every test suite in tests/, each with a time limit so a hang fails fast instead of
#      eating the runner; a suite whose log shows a script error fails even if every
#      check it reached passed;
#   3. the harness self-test (tools/test_run_tests.sh), when no suites are named.
#
# A green suite must mean every test ran:
#   - suites run on a fixed frame clock (--fixed-fps), so a busy machine cannot change
#     what happens between two checks;
#   - every suite calls its test functions through tests/lib/functions_ran.gd and ends with
#     "<Suite> tests: K of M functions, N checks, F failures"; a `_check_*` function that
#     never ran or made no check is a failure by name, and a line short of functions
#     ("functions short") or with no function count fails here. Nothing is kept by hand:
#     no floors, and suites are found by filename (tests/run_<suite>_tests.gd), so a new
#     suite or test counts itself and two PRs never conflict over a registry
#     (director 2026-10-19, github-hygiene §4);
#   - a check a suite skips on purpose prints one "SKIP: <reason>" line, and the summary
#     says how many were skipped.
#   - a suite's "NOTICE: <text>" line (a number a passing check reports, such as the counts
#     suite's FxPool peaks) becomes a notice annotation in Actions, readable without the logs.
#
# Every run gets its own user data, settings and editor caches: APPDATA (Windows) and
# the XDG dirs (Linux) point at a temp dir for the whole run, so two agents' runs never
# share a save, a setting or an editor cache (CLAUDE.md "Machine rules").
#
# While a speed run holds the PC (D-299) it starts no Godot: it waits on the gate (tools/speed_gate.sh,
# C:/kt/wait_window.sh) before the import and before each suite, and until 6144 MB of RAM is free (D-317, MIN_FREE_MB,
# polled every RAM_POLL_SECS = 5 s); the waits are totalled on the last line. No gate file, no effect.
#
#   GODOT=/path/to/godot tools/run_tests.sh          # everything
#   SUITE_TIMEOUT=300 tools/run_tests.sh data smoke   # just some suites
#   tools/run_tests.sh --quick data                   # the local loop: no re-import (QUICK=1 too)
#   tools/run_tests.sh --verbose                      # every suite's line (VERBOSE=1 too)
#   TIMINGS_FILE=tools/ci_timings.txt tools/run_tests.sh   # re-measure the CI shard plan
#   LANES=2 tools/run_tests.sh sim city               # two suites at once (CI shards; each has its own user data)
#   tools/run_tests.sh flow@1/2 flow@2/2              # one suite as two parts (a "split" line of tools/ci_timings.txt):
#                                                     # each part runs half of its calls, together exactly the suite
#
# Exits nonzero if anything failed.
set -u
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
SUITE_TIMEOUT="${SUITE_TIMEOUT:-900}"
IMPORT_TIMEOUT="${IMPORT_TIMEOUT:-600}"
# Where the runners live (tools/test_run_tests.sh points this at its fixtures).
RUNNER_DIR="${RUNNER_DIR:-tests}"
# QUICK=1 skips the project import: the local loop after one full run, when only scripts
# changed. CI and any asset change run the import.
QUICK="${QUICK:-0}"
# Quiet by default (director 2026-10-19): only failures and a one-line summary, so a run
# costs an agent a few lines of context. VERBOSE=1 or --verbose prints every suite's line,
# the import and the log dir. --quick is the same as QUICK=1: the local one-suite loop.
VERBOSE="${VERBOSE:-0}"
while [ "${1:-}" = "--quick" ] || [ "${1:-}" = "--verbose" ]; do
	[ "$1" = "--quick" ] && QUICK=1
	[ "$1" = "--verbose" ] && VERBOSE=1
	shift
done
say() {  # a line printed only with VERBOSE=1
	if [ "$VERBOSE" = 1 ]; then echo "$@"; fi
}
# SUITES_ONLY=1 skips the harness self-test after the suites.
# EXTRAS_ONLY=1 runs only the self-test, no suites.
# CI splits the work this way: shards run SUITES_ONLY, one job runs EXTRAS_ONLY.
SUITES_ONLY="${SUITES_ONLY:-0}"
ALL_SUITES=()
for runner_file in tests/run_*_tests.gd; do
	[ -e "$runner_file" ] || continue
	name="${runner_file#tests/run_}"
	ALL_SUITES+=("${name%_tests.gd}")
done
[ "$#" -gt 0 ] && SUITES=("$@") || SUITES=("${ALL_SUITES[@]}")
# Read once and clear it: the harness self-test runs this script again, and a child
# that inherited EXTRAS_ONLY would run no suites and pass a short one.
extras_only="${EXTRAS_ONLY:-0}"
unset EXTRAS_ONLY
[ "$extras_only" = 1 ] && SUITES=()

LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"
RUN_DATA="$(mktemp -d)"
trap 'rm -rf "$RUN_DATA"' EXIT
native_path() {  # Godot on Windows needs a Windows path in APPDATA
	if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}
APPDATA="$(native_path "$RUN_DATA")"
export APPDATA
export XDG_DATA_HOME="$RUN_DATA/data" XDG_CONFIG_HOME="$RUN_DATA/config" XDG_CACHE_HOME="$RUN_DATA/cache"

failed=0
summary=()
in_ci=0
[ -n "${GITHUB_ACTIONS:-}" ] && in_ci=1

note_error() {  # message
	if [ "$in_ci" = 1 ]; then echo "::error::$1"; else echo "ERROR: $1"; fi
}

# D-299 (director 2026-10-27, "PC to itself"): a speed run needs zero Godot on the PC, so wait for
# the gate before EVERY Godot launch below (version query, import, each suite), not only at the start:
# a run of 7-20 suites would otherwise hold a speed run off for 20-40 minutes. tools/speed_gate.sh
# has the details; where the gate file is absent (CI, Linux) it does nothing.
. tools/speed_gate.sh
wait_speed_gate
say "== Godot: $("$GODOT" --headless --version 2> /dev/null | tail -1)"
if [ "$QUICK" = 1 ]; then
	say "== Quick: skipping the import (run once without QUICK=1 after asset changes)"
else
say "== Importing the project"
wait_speed_gate
timeout "$IMPORT_TIMEOUT" "$GODOT" --headless --path . --editor --import > "$LOG_DIR/import.log" 2>&1
import_code=$?
if [ "$import_code" != 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$LOG_DIR/import.log"; then
	grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error" "$LOG_DIR/import.log" || tail -20 "$LOG_DIR/import.log"
	note_error "the project failed to import (exit $import_code)"
	echo "Logs: $LOG_DIR"
	exit 1
fi
summary+=("| import | pass | |")
fi
timings=()

# A suite's name as a file name: "flow@1/2" (part 1 of 2) is "flow_p1of2".
skey() {  # suite
	local key="${1//@/_p}"
	echo "${key//\//of}"
}

# One suite, start to finish. It writes everything the run reports to files in $LOG_DIR, so
# several suites can run side by side (LANES) and the report stays in order:
#   <suite>.log     the suite's own output          <suite>.status  pass | FAIL
#   <suite>.report  the lines the run prints        <suite>.row     the step-summary table row
#   <suite>.secs    its run time                    <suite>.done    written last
# Every suite gets its own user data and settings dirs (APPDATA on Windows, XDG on Linux), so two
# suites running at once never share a save or a cache.
run_suite() {  # suite, or suite@K/N for part K of a suite that CI runs in N parts
	local suite="$1"
	local key base part_args=()
	key=$(skey "$suite")
	base="${suite%%@*}"
	[ "$base" != "$suite" ] && part_args=(-- "--part=${suite#*@}")
	local runner="$RUNNER_DIR/run_${base}_tests.gd"
	local log="$LOG_DIR/$key.log"
	local sdata="$RUN_DATA/suite_$key"
	mkdir -p "$sdata"
	local start code secs result status detail ran ran_k ran_m skipped short
	wait_speed_gate  # before the clock starts: a wait is not the suite's time (TIMINGS_FILE)
	start=$(date +%s)
	APPDATA="$(native_path "$sdata")" XDG_DATA_HOME="$sdata/data" XDG_CONFIG_HOME="$sdata/config" \
		XDG_CACHE_HOME="$sdata/cache" \
		timeout "$SUITE_TIMEOUT" "$GODOT" --headless --fixed-fps 60 --path . --script "$runner" \
		${part_args[@]+"${part_args[@]}"} > "$log" 2>&1
	code=$?
	secs=$(($(date +%s) - start))
	result=$(grep -E "[0-9]+ checks, [0-9]+ failures" "$log" | tail -1)
	if [ "$code" = 124 ]; then
		status="FAIL"
		detail="timed out after ${SUITE_TIMEOUT}s"
	elif [ "$code" != 0 ] || [ -z "$result" ]; then
		status="FAIL"
		detail="${result:-no result (exit $code)}"
	elif grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$log"; then
		# A runtime error aborts the function it hit, so the checks after it never
		# run and the suite can still report 0 failures.
		status="FAIL"
		detail="$result, but a script error stopped part of the suite"
	else
		status="pass"
		detail="$result"
	fi
	# Every test function must have run: "K of M functions" with K = M.
	ran=$(echo "$result" | grep -oE "[0-9]+ of [0-9]+ functions" | head -1)
	ran_k=$(echo "$ran" | awk '{print $1}')
	ran_m=$(echo "$ran" | awk '{print $3}')
	skipped=$(grep -c "^SKIP:" "$log")
	short=""
	if [ -n "$result" ] && [ -z "$ran" ]; then
		short="the line has no function count (call tests through _t, tests/lib/functions_ran.gd)"
	elif [ -n "$ran" ] && [ "$ran_k" -lt "$ran_m" ]; then
		short="functions short: $((ran_m - ran_k)) never ran (named in the log)"
	elif [ -n "$ran" ] && [ "$ran_m" -eq 0 ] && [ "$base" = "$suite" ]; then
		# (a part may count none: it counts a function in the part that ran its first call)
		short="the suite has no _check_ functions"
	fi
	if [ -n "$short" ] && [ "$code" != 124 ]; then
		status="FAIL"
		detail="$detail; $short"
	fi
	if [ "$skipped" -gt 0 ]; then
		detail="$detail ($skipped skipped on purpose)"
	fi
	{
		if [ "$VERBOSE" = 1 ] || [ "$status" = FAIL ]; then
			printf '%-5s %-11s %4ss  %s\n' "$status" "$suite" "$secs" "$detail"
		fi
		if [ "$status" = FAIL ]; then
			note_error "suite '$suite' failed: $detail"
			[ "$in_ci" = 1 ] && echo "::group::$suite log (failures and errors)"
			grep -E -A4 "^FAIL:|SCRIPT ERROR|^ERROR" "$log" | head -60
			[ "$in_ci" = 1 ] && echo "::endgroup::"
			# Failed checks and parse errors become job annotations, so a red run can be
			# read without downloading the logs.
			if [ "$in_ci" = 1 ]; then
				grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$log" | head -20 | while IFS= read -r l; do
					printf '::error::%s-log::%s\n' "$suite" "$l"
				done
				grep -E "^FAIL:" "$log" | head -30 | while IFS= read -r l; do
					printf '::error::%s-check::%s\n' "$suite" "${l#FAIL: }"
				done
			fi
		fi
		if [ "$in_ci" = 1 ]; then
			grep -E "^NOTICE: " "$log" | head -10 | while IFS= read -r l; do
				printf '::notice::%s::%s\n' "$suite" "${l#NOTICE: }"
			done
		fi
	} > "$LOG_DIR/$key.report"
	echo "| $suite | $status | $detail (${secs}s) |" > "$LOG_DIR/$key.row"
	echo "$secs" > "$LOG_DIR/$key.secs"
	echo "$status" > "$LOG_DIR/$key.status"
	: > "$LOG_DIR/$key.done"
}

# Prints the report of every suite that has finished and has not been printed yet.
flush_reports() {
	local suite key
	for suite in ${SUITES[@]+"${SUITES[@]}"}; do
		key=$(skey "$suite")
		if [ -e "$LOG_DIR/$key.done" ] && [ ! -e "$LOG_DIR/$key.printed" ]; then
			cat "$LOG_DIR/$key.report"
			: > "$LOG_DIR/$key.printed"
		fi
	done
}

# LANES=N runs up to N suites at once (CI shards use it on 4-core runners). Each suite is
# deterministic on its own fixed frame clock, so the result is the same as one at a time.
LANES="${LANES:-1}"
case "$LANES" in '' | *[!0-9]*) LANES=1 ;; esac
[ "$LANES" -ge 1 ] || LANES=1
for suite in ${SUITES[@]+"${SUITES[@]}"}; do
	rm -f "$LOG_DIR/$(skey "$suite").done" "$LOG_DIR/$(skey "$suite").printed"
	if [ "$LANES" = 1 ]; then
		run_suite "$suite"
		flush_reports
	else
		while [ "$(jobs -rp | wc -l)" -ge "$LANES" ]; do
			wait -n || true
			flush_reports
		done
		run_suite "$suite" &
	fi
done
wait
flush_reports
for suite in ${SUITES[@]+"${SUITES[@]}"}; do
	key=$(skey "$suite")
	if [ "$(cat "$LOG_DIR/$key.status" 2> /dev/null)" != pass ]; then failed=1; fi
	summary+=("$(cat "$LOG_DIR/$key.row" 2> /dev/null || echo "| $suite | FAIL | no result |")")
	timings+=("$suite $(cat "$LOG_DIR/$key.secs" 2> /dev/null || echo 0)")
done

# The harness checks itself: a test function that never ran or made no check must fail,
# and an untyped declaration must not compile.
if [ "$SUITES_ONLY" != 1 ] && [ "$#" -eq 0 ]; then
	say "== Harness self-test"
	if GODOT="$GODOT" tools/test_run_tests.sh > "$LOG_DIR/harness_selftest.log" 2>&1; then
		summary+=("| harness_selftest | pass | |")
	else
		selftest_log="$LOG_DIR/harness_selftest.log"
		tail -15 "$selftest_log"
		# Name what failed. The self-test prints one "FAIL: <what>" line per broken
		# expectation; when its first step ("the smoke suite should pass") failed, the
		# smoke suite itself is red and the harness is not at fault, so say so and quote
		# the suite's own failure line.
		what=$(grep -E "^FAIL:" "$selftest_log" | head -1 | sed 's/^FAIL: //')
		suite_line=$(grep -oE "suite '[^']+' failed: [^(]*" "$selftest_log" | head -1)
		if [ -z "$what" ]; then
			detail="no FAIL line in the self-test log, see $selftest_log"
		elif [ "$what" = "the smoke suite should pass" ] && [ -n "$suite_line" ]; then
			detail="the smoke suite is red, not the harness: $suite_line"
		else
			detail="$what${suite_line:+ ($suite_line)}"
		fi
		note_error "harness self-test (tools/test_run_tests.sh): $detail"
		failed=1
		summary+=("| harness_selftest | FAIL | $detail |")
	fi
fi

# TIMINGS_FILE: write each suite's seconds for tools/plan_ci_shards.sh, keeping its
# "shards <n>" line. Re-measure at least weekly and after adding a slow suite.
if [ -n "${TIMINGS_FILE:-}" ] && [ "${#timings[@]}" -gt 0 ]; then
	# the plan's own lines (shards, lanes, split, pr_skip) stay; a suite line is a measurement
	plan_lines=$(grep -E "^(shards|lanes|split|pr_skip)[[:space:]]" "$TIMINGS_FILE" 2> /dev/null || echo "shards 1")
	{
		echo "# Seconds per suite from tools/run_tests.sh (TIMINGS_FILE=...), $(date +%F)."
		echo "# tools/plan_ci_shards.sh splits the suites across shards from these."
		echo "$plan_lines"
		printf '%s
' "${timings[@]}"
	} > "$TIMINGS_FILE"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### Test results"
		echo "| Check | Result | Detail |"
		echo "|---|---|---|"
		printf '%s\n' "${summary[@]}"
	} >> "$GITHUB_STEP_SUMMARY"
fi
n_suites=${#timings[@]}
if [ "$failed" = 0 ]; then
	say "Logs: $LOG_DIR"
	echo "All checks passed ($n_suites suites)."
else
	echo "Some checks FAILED ($n_suites suites run). Logs: $LOG_DIR"
fi
# Time spent waiting on the speed-run gate and the memory floor (tools/speed_gate.sh): in no suite's time above.
if [ "${SPEED_GATE_WAITED:-0}" -gt 0 ]; then echo "Waited ${SPEED_GATE_WAITED}s for the speed-run gate and the memory floor."; fi
exit "$failed"
