#!/usr/bin/env bash
# The harness must not report green when it should not. Through tools/run_tests.sh:
#   1. the quick smoke suite                                 -> must pass
#   2. a fixture with a _check_ function nobody calls         -> must fail ("functions short")
#   3. a fixture with a _check_ function that makes no check  -> must fail, by name
# (the fixtures are tests/fixtures/run_<name>_tests.gd), and, with Godot directly, that the
# project's typing rules hold:
#   4. tests/fixtures/compile/untyped_var.gd must fail to parse ("has no static type")
#   5. tests/fixtures/compile/typed_ok.gd must parse
# and that LANES=2 (two suites at once) passes two good suites and reports both bad fixtures.
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
