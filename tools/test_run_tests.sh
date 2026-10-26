#!/usr/bin/env bash
# The harness must not report green when it should not. Through tools/run_tests.sh:
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
