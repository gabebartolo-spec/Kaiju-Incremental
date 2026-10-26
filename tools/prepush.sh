#!/usr/bin/env bash
# prepush.sh: the local gate every branch passes before it is pushed for merge (director 2026-10-26:
# "add the pre-push check and require it before any merge is armed").
#
# Runs what CI's first gates run, so a push never goes red on something a minute of local work
# catches, then the suites the change touches:
#   1. branch is not behind origin/main (a stale branch merges main first);
#   2. tuning keys + complexity ratchet (tests.yml preflight);
#   3. snake_case names, gdlint and gdformat --check on the changed .gd files (lint.yml);
#   4. headless import + every script parsed and compiled (tests.yml preflight);
#   5. the touched suites: every suite whose runner or tests/lib helper changed, plus SUITES.
# The last line is "prepush: PASS <sha>" or "prepush: FAIL <step>"; paste it in your report.
# The lead arms a merge only for a head that printed PASS.
#
#   GODOT=/path/to/godot_console.exe SUITES="sim city" tools/prepush.sh
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
SUITES="${SUITES:-}"
BASE="${BASE:-origin/main}"

fail() { echo "prepush: FAIL $1"; exit 1; }
step() { echo "== $1"; }

step "1 up to date with $BASE"
git fetch -q origin || fail "git fetch"
behind=$(git rev-list --count "HEAD..$BASE")
[ "$behind" = 0 ] || fail "branch is $behind commits behind $BASE: git merge $BASE first"

changed=$(git diff --name-only --diff-filter=ACMR "$BASE...HEAD")
gd=$(echo "$changed" | grep -E '\.gd$' | grep -v -E '^(\.godot|\.claude|tests/fixtures/lint)/' || true)

step "2 tuning keys and complexity"
python tools/lint/tuning_keys.py || fail "tuning keys"
python tools/lint/complexity_ratchet.py || fail "complexity ratchet"

step "3 lint on $(echo "$gd" | grep -c . ) changed .gd files"
if [ -n "$gd" ]; then
	bad=$(echo "$gd" | grep -v -E '(^|/)[a-z0-9]+(_[a-z0-9]+)*\.gd$' || true)
	[ -z "$bad" ] || fail "not snake_case: $bad"
	echo "$gd" | xargs python -m gdtoolkit.linter || fail "gdlint"
	echo "$gd" | xargs python -m gdtoolkit.formatter --check || fail "gdformat (run python -m gdtoolkit.formatter on the files)"
fi

step "4 import and compile"
run_data="$(mktemp -d)"
trap 'rm -rf "$run_data"' EXIT
native_path() { if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
code=0
APPDATA="$(native_path "$run_data")" XDG_DATA_HOME="$run_data/data" XDG_CONFIG_HOME="$run_data/config" \
	timeout 600 "$GODOT" --headless --path . --editor --import > "$run_data/import.log" 2>&1 || code=$?
if [ "$code" != 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$run_data/import.log"; then
	grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error" "$run_data/import.log" | head -40
	fail "import (exit $code)"
fi
GODOT="$GODOT" tools/check_scripts.sh || fail "script compile"

step "5 touched suites"
auto=$(echo "$changed" | sed -n -E 's#^tests/run_([a-z0-9_]+)_tests\.gd$#\1#p')
for lib in $(echo "$changed" | grep -E '^tests/lib/.*\.gd$' || true); do
	for runner in $(grep -l -F "$lib" tests/run_*_tests.gd 2> /dev/null || true); do
		auto="$auto $(basename "$runner" | sed -E 's/^run_(.*)_tests\.gd$/\1/')"
	done
done
suites=$(echo "$SUITES $auto" | tr ' ' '\n' | grep . | sort -u | tr '\n' ' ')
if [ -z "$suites" ]; then
	echo "no suite named or touched; name the suites you iterated on in SUITES"
	fail "no suites"
fi
for s in $suites; do
	[ -f "tests/run_${s}_tests.gd" ] || fail "no suite '$s' (tests/run_${s}_tests.gd)"
done
echo "suites: $suites"
# shellcheck disable=SC2086
GODOT="$GODOT" tools/run_tests.sh --quick $suites || fail "suites ($suites)"

echo "prepush: PASS $(git rev-parse HEAD)"
