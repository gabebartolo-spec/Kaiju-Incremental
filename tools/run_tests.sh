#!/usr/bin/env bash
# Runs every Godot check CI runs (.github/workflows/tests.yml), locally or in Actions:
#   1. import the project (a script that fails to compile during import fails the run);
#   2. every test suite in tests/, each with a time limit so a hang fails fast instead of
#      eating the runner; a suite whose log shows a script error fails even if every
#      check it reached passed;
#   3. the harness self-test (tools/test_run_tests.sh), when no suites are named.
#
# A green suite must mean every check ran:
#   - suites run on a fixed frame clock (--fixed-fps), so a busy machine cannot change
#     what happens between two checks;
#   - every suite has a floor in tests/expected_checks.txt; a suite that reports fewer
#     checks fails ("checks went missing"), a suite with no floor fails until one is
#     added, and floors only go up (game-architecture §6);
#   - a check a suite skips on purpose prints one "SKIP: <reason>" line; skipped checks
#     count towards the floor and the summary says how many were skipped.
#
# Every run gets its own user data, settings and editor caches: APPDATA (Windows) and
# the XDG dirs (Linux) point at a temp dir for the whole run, so two agents' runs never
# share a save, a setting or an editor cache (CLAUDE.md "Machine rules").
#
#   GODOT=/path/to/godot tools/run_tests.sh          # everything
#   SUITE_TIMEOUT=300 tools/run_tests.sh data smoke   # just some suites
#
# Exits nonzero if anything failed.
set -u
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-godot}"
SUITE_TIMEOUT="${SUITE_TIMEOUT:-900}"
IMPORT_TIMEOUT="${IMPORT_TIMEOUT:-600}"
# The check floors (tools/test_run_tests.sh points this at its own file).
EXPECTED_CHECKS="${EXPECTED_CHECKS:-tests/expected_checks.txt}"
# SUITES_ONLY=1 skips the harness self-test after the suites.
# EXTRAS_ONLY=1 runs only the self-test, no suites.
# CI splits the work this way: shards run SUITES_ONLY, one job runs EXTRAS_ONLY.
SUITES_ONLY="${SUITES_ONLY:-0}"
ALL_SUITES=(smoke sim powers city flow)
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

echo "== Godot: $("$GODOT" --headless --version 2> /dev/null | tail -1)"
echo "== Importing the project"
timeout "$IMPORT_TIMEOUT" "$GODOT" --headless --path . --editor --import > "$LOG_DIR/import.log" 2>&1
import_code=$?
if [ "$import_code" != 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$LOG_DIR/import.log"; then
	grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error" "$LOG_DIR/import.log" || tail -20 "$LOG_DIR/import.log"
	note_error "the project failed to import (exit $import_code)"
	echo "Logs: $LOG_DIR"
	exit 1
fi
summary+=("| import | pass | |")

for suite in ${SUITES[@]+"${SUITES[@]}"}; do
	runner="tests/run_${suite}_tests.gd"
	log="$LOG_DIR/$suite.log"
	start=$(date +%s)
	timeout "$SUITE_TIMEOUT" "$GODOT" --headless --fixed-fps 60 --path . --script "$runner" > "$log" 2>&1
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
	# Every check must have run: compare with the suite's floor.
	ran=$(echo "$result" | grep -oE "[0-9]+ checks" | head -1 | grep -oE "[0-9]+")
	floor=$(grep -E "^$suite[[:space:]]" "$EXPECTED_CHECKS" 2> /dev/null | awk '{print $2}')
	skipped=$(grep -c "^SKIP:" "$log")
	if [ "$status" = pass ] && [ -z "$floor" ]; then
		status="FAIL"
		detail="$result, but $EXPECTED_CHECKS has no floor for '$suite'"
	elif [ "$status" = pass ] && [ -n "$ran" ] && [ $((ran + skipped)) -lt "$floor" ]; then
		status="FAIL"
		detail="$result, but only $ran of at least $floor checks ran: checks went missing"
	fi
	if [ "$skipped" -gt 0 ]; then
		detail="$detail ($skipped skipped on purpose)"
	fi
	printf '%-5s %-11s %4ss  %s\n' "$status" "$suite" "$secs" "$detail"
	if [ "$status" = FAIL ]; then
		failed=1
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
	summary+=("| $suite | $status | $detail (${secs}s) |")
done

# The harness checks itself: a short or unfloored suite must fail, and an untyped
# declaration must not compile.
if [ "$SUITES_ONLY" != 1 ] && [ "$#" -eq 0 ]; then
	echo "== Harness self-test"
	if GODOT="$GODOT" tools/test_run_tests.sh > "$LOG_DIR/harness_selftest.log" 2>&1; then
		summary+=("| harness_selftest | pass | |")
	else
		selftest_log="$LOG_DIR/harness_selftest.log"
		tail -15 "$selftest_log"
		# Name what failed. The self-test prints one "FAIL: <what>" line per broken
		# expectation; when its first step ("the real floor should pass") failed, the
		# smoke suite itself is red and the harness is not at fault, so say so and quote
		# the suite's own failure line.
		what=$(grep -E "^FAIL:" "$selftest_log" | head -1 | sed 's/^FAIL: //')
		suite_line=$(grep -oE "suite '[^']+' failed: [^(]*" "$selftest_log" | head -1)
		if [ -z "$what" ]; then
			detail="no FAIL line in the self-test log, see $selftest_log"
		elif [ "$what" = "the real floor should pass" ] && [ -n "$suite_line" ]; then
			detail="the smoke suite is red, not the harness: $suite_line"
		else
			detail="$what${suite_line:+ ($suite_line)}"
		fi
		note_error "harness self-test (tools/test_run_tests.sh): $detail"
		failed=1
		summary+=("| harness_selftest | FAIL | $detail |")
	fi
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### Test results"
		echo "| Check | Result | Detail |"
		echo "|---|---|---|"
		printf '%s\n' "${summary[@]}"
	} >> "$GITHUB_STEP_SUMMARY"
fi
echo "Logs: $LOG_DIR"
[ "$failed" = 0 ] && echo "All checks passed." || echo "Some checks FAILED."
exit "$failed"
