#!/usr/bin/env bash
# The harness must not report green when it should not. Through tools/run_tests.sh:
#   0. (a fake Godot) the speed-run gate (D-299): asked before every launch, waited on; no gate file, no change
#   1. the quick smoke suite                                 -> must pass
#   2. a fixture with a _check_ function nobody calls         -> must fail ("functions short")
#   3. a fixture with a _check_ function that makes no check  -> must fail, by name
# (the fixtures are tests/fixtures/run_<name>_tests.gd), and, with Godot directly, that the
# project's typing rules hold:
#   4. tests/fixtures/compile/untyped_var.gd must fail to parse ("has no static type")
#   5. tests/fixtures/compile/typed_ok.gd must parse
# and that LANES=2 (two suites at once) passes two good suites and reports both bad fixtures, that a suite run as
# parts (suite@1/2, suite@2/2) makes exactly the checks the whole suite makes, and that the CI shard plan
# (tools/test_plan_ci_shards.sh) runs every suite, and every part of a split suite, exactly once.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bad=0
. tools/speed_gate.sh

# D-299 (director 2026-10-27, "PC to itself"): the runner asks the speed-run gate before EVERY Godot
# launch (the version query, the import, each suite), so a run of 7-20 suites stops between suites
# while a speed run holds the PC. No real Godot: a fake one logs each launch next to the gate's calls.
# `tools/test_run_tests.sh speed-gate` runs only this case.
check_speed_gate() {
	local log="$tmp/gate.log" runs="$tmp/gate_runs"
	cat > "$tmp/fake_godot.sh" << 'EOF'
#!/usr/bin/env bash
echo "godot $*" >> "$GATE_LOG"
case "$*" in
*--version*) echo "4.7.2.fake" ;;
*--script*) echo "Fake tests: 1 of 1 functions, 1 checks, 0 failures" ;;
esac
EOF
	cat > "$tmp/gate.sh" << 'EOF'
#!/usr/bin/env bash
n=$(cat "$GATE_COUNT" 2> /dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$GATE_COUNT"
if [ "$n" -le 2 ]; then echo "gate wait $n" >> "$GATE_LOG"; exit 1; fi
echo "gate ok $n" >> "$GATE_LOG"
EOF
	chmod +x "$tmp/fake_godot.sh" "$tmp/gate.sh"
	# 1. a gate that fails twice, then passes: the runner waits, and asks again before every launch
	rm -f "$log" "$runs"
	GATE_LOG="$log" GATE_COUNT="$runs" SPEED_GATE="$tmp/gate.sh" GODOT="$tmp/fake_godot.sh" \
		SUITES_ONLY=1 tools/run_tests.sh alpha beta > "$tmp/gate_out.txt" 2>&1
	local code=$?
	local before launches unguarded
	before=$(awk '/^godot/ {exit} /^gate/ {n++} END {print n + 0}' "$log" 2> /dev/null)
	launches=$(grep -c '^godot' "$log" 2> /dev/null)
	unguarded=$(awk '/^godot/ && prev !~ /^gate ok/ {n++} {prev = $0} END {print n + 0}' "$log" 2> /dev/null)
	if [ "$code" = 0 ] && [ "${before:-0}" -ge 3 ] && [ "$launches" = 4 ] && [ "$unguarded" = 0 ]; then
		echo "ok: the runner waits for the speed-run gate before every Godot launch ($before gate calls before the first)"
	else
		echo "FAIL: the runner must wait for SPEED_GATE before every Godot launch (exit $code, $before gate calls" \
			"before the first launch, want 3 or more; $launches launches, want 4; $unguarded not right after a pass)"
		cat "$log" "$tmp/gate_out.txt" 2> /dev/null
		bad=1
	fi
	# 2. no gate file (CI, Linux): nothing changes - same result, same launches, no wait
	rm -f "$log" "$runs"
	GATE_LOG="$log" GATE_COUNT="$runs" SPEED_GATE="$tmp/no_such_gate.sh" GODOT="$tmp/fake_godot.sh" \
		SUITES_ONLY=1 tools/run_tests.sh alpha beta > "$tmp/gate_out_none.txt" 2>&1
	code=$?
	launches=$(grep -c '^godot' "$log" 2> /dev/null)
	if [ "$code" = 0 ] && [ "$launches" = 4 ] && ! grep -q '^gate' "$log" && cmp -s "$tmp/gate_out.txt" "$tmp/gate_out_none.txt"; then
		echo "ok: a missing SPEED_GATE file changes nothing"
	else
		echo "FAIL: a missing SPEED_GATE file must change nothing (exit $code, $launches launches, want 4)"
		cat "$log" "$tmp/gate_out_none.txt" 2> /dev/null
		bad=1
	fi
}
check_speed_gate
if [ "${1:-}" = speed-gate ]; then exit "$bad"; fi

if SUITES_ONLY=1 tools/run_tests.sh smoke > "$tmp/out.txt" 2>&1; then echo "ok: the smoke suite passes"; else
	echo "FAIL: the smoke suite should pass"
	cat "$tmp/out.txt"
	bad=1
fi
# The fixtures reuse the import the first run made.
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh uncalled > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a suite with an uncalled test function passed"
	bad=1
elif grep -q "functions short" "$tmp/out.txt" && grep -q "_check_x is never called" "$tmp/out.txt"; then
	echo "ok: an uncalled test function fails the run, by name"
else
	echo "FAIL: the uncalled fixture failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh nocheck > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a test function with no check passed"
	bad=1
elif grep -q "_check_empty made no checks" "$tmp/out.txt"; then
	echo "ok: a test function with no check fails the run, by name"
else
	echo "FAIL: the no-check fixture failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi
# A suite that passes every check but leaks at the exit fails (debt row 2), naming the engine's own line.
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh leak > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a suite whose exit leaked passed"
	bad=1
elif grep -q "the exit leaked: .*ObjectDB instances" "$tmp/out.txt"; then
	echo "ok: a suite that leaks at the exit fails the run, with the engine's line"
else
	echo "FAIL: the leak fixture failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi
# Two suites at once (LANES=2, what CI shards use) report exactly what one at a time reports.
if QUICK=1 LANES=2 SUITES_ONLY=1 tools/run_tests.sh carving structures > "$tmp/out.txt" 2>&1 	&& grep -q "All checks passed (2 suites)" "$tmp/out.txt"; then
	echo "ok: two suites in two lanes both run and pass"
else
	echo "FAIL: LANES=2 should run two real suites and pass"
	cat "$tmp/out.txt"
	bad=1
fi
if QUICK=1 LANES=2 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh uncalled nocheck > "$tmp/out.txt" 2>&1; then
	echo "FAIL: two bad suites in two lanes passed"
	bad=1
elif grep -q "_check_x is never called" "$tmp/out.txt" && grep -q "_check_empty made no checks" "$tmp/out.txt"; then
	echo "ok: both failures are reported when two suites run in two lanes"
else
	echo "FAIL: LANES=2 lost a failure"
	cat "$tmp/out.txt"
	bad=1
fi

# A suite run as parts ("parts@1/2", "parts@2/2"): the parts make exactly the functions and checks the whole
# suite makes, nothing twice and nothing dropped (tests/lib/functions_ran.gd part()).
sums() {  # run_tests.sh output -> "functions checks" added up over its suite lines
	grep -oE "[0-9]+ of [0-9]+ functions, [0-9]+ checks" "$1" | tr -dc '0-9 \n' | awk '{ k += $1; m += $2; c += $3 } END { print k, m, c }'
}
QUICK=1 VERBOSE=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh parts > "$tmp/whole.txt" 2>&1
QUICK=1 VERBOSE=1 LANES=2 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh parts@1/2 parts@2/2 > "$tmp/parts.txt" 2>&1
if [ "$(sums "$tmp/whole.txt")" = "3 3 8" ] && [ "$(sums "$tmp/parts.txt")" = "3 3 8" ] \
	&& grep -q "All checks passed (2 suites)" "$tmp/parts.txt"; then
	echo "ok: two parts of a suite make exactly the 3 functions and 8 checks the whole suite makes"
else
	echo "FAIL: parts@1/2 and parts@2/2 should add up to the whole suite (3 functions, 8 checks)"
	echo "whole: $(sums "$tmp/whole.txt"); parts: $(sums "$tmp/parts.txt")"
	cat "$tmp/whole.txt" "$tmp/parts.txt"
	bad=1
fi
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh stray > "$tmp/out.txt" 2>&1 \
	&& ! QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh stray@1/2 > "$tmp/out.txt" 2>&1 \
	&& grep -q "outside _t and _h" "$tmp/out.txt"; then
	echo "ok: a check made outside _t and _h fails a suite run in parts, not the whole suite"
else
	echo "FAIL: a stray check should pass whole and fail as a part"
	cat "$tmp/out.txt"
	bad=1
fi
if bash tools/test_plan_ci_shards.sh > "$tmp/plan.txt" 2>&1; then
	cat "$tmp/plan.txt"
else
	echo "FAIL: the shard plan"
	cat "$tmp/plan.txt"
	bad=1
fi

native_path() {  # Godot on Windows needs a Windows path in APPDATA
	if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}
check_parse() {  # script, expect (fail|pass); isolated like every run
	wait_speed_gate  # D-299: this is a Godot launch too
	APPDATA="$(native_path "$tmp")" XDG_DATA_HOME="$tmp/data" XDG_CONFIG_HOME="$tmp/config" \
		"$GODOT" --headless --path . --check-only --script "$1" > "$tmp/parse.txt" 2>&1
	local code=$?
	if [ "$2" = fail ] && [ "$code" != 0 ] && grep -q "has no static type" "$tmp/parse.txt"; then
		echo "ok: $1 is rejected (untyped declaration)"
	elif [ "$2" = pass ] && [ "$code" = 0 ]; then
		echo "ok: $1 parses"
	else
		echo "FAIL: $1 should $2 to parse (exit $code)"
		cat "$tmp/parse.txt"
		bad=1
	fi
}
check_parse tests/fixtures/compile/untyped_var.gd fail
check_parse tests/fixtures/compile/typed_ok.gd pass
exit "$bad"
