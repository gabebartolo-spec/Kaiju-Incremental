#!/usr/bin/env bash
# The harness must not report green when it should not. Using the quick smoke suite
# through tools/run_tests.sh:
#   1. with its real floor           -> must pass
#   2. with an impossibly high floor -> must fail ("checks went missing")
#   3. with no floor at all          -> must fail ("has no floor")
# and, with Godot directly, that the project's typing rules hold:
#   4. tests/fixtures/compile/untyped_var.gd must fail to parse ("has no static type")
#   5. tests/fixtures/compile/typed_ok.gd must parse
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
SUITE=smoke
real=$(grep -E "^$SUITE[[:space:]]" tests/expected_checks.txt | awk '{print $2}')
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bad=0

printf '%s %s\n' "$SUITE" "$real" > "$tmp/ok.txt"
printf '%s %s\n' "$SUITE" 100000 > "$tmp/high.txt"
printf 'nothing 1\n' > "$tmp/none.txt"

run() {  # floor file
	EXPECTED_CHECKS="$1" SUITES_ONLY=1 tools/run_tests.sh "$SUITE" > "$tmp/out.txt" 2>&1
}

if run "$tmp/ok.txt"; then echo "ok: the real floor passes"; else
	echo "FAIL: the real floor should pass"
	cat "$tmp/out.txt"
	bad=1
fi
if run "$tmp/high.txt"; then
	echo "FAIL: a suite short of its floor passed"
	bad=1
elif grep -q "checks went missing" "$tmp/out.txt"; then echo "ok: missing checks fail the run"; else
	echo "FAIL: a short suite failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi
if run "$tmp/none.txt"; then
	echo "FAIL: a suite with no floor passed"
	bad=1
elif grep -q "has no floor" "$tmp/out.txt"; then echo "ok: a suite with no floor fails"; else
	echo "FAIL: an unfloored suite failed without saying why"
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
