#!/usr/bin/env bash
# prepush.sh: the local gate every branch passes before it is pushed for merge (director 2026-10-26:
# "add the pre-push check and require it before any merge is armed").
#
# Runs what CI's first gates run, so a push never goes red on something a minute of local work
# catches, then the suites the change touches:
#   1. branch is not behind origin/main (a stale branch merges main first);
#   2. tuning keys + complexity ratchet (tests.yml preflight);
#   3. snake_case names, gdlint and gdformat --check on the changed .gd files (lint.yml);
#   4. headless import + every script parsed and compiled (tests.yml preflight), then the repo lints
#      (tools/lint/run_all.sh, also lint.yml: every script has its committed .uid, ...);
#   4c. the local native DLL's md5 against main's CI build (tools/native_dll.sh): a stale or
#      missing DLL silently runs the slow GDScript mesher in every bench and capture (a mismatch
#      fails; a branch that changes native/ is not compared, its DLL is its own build);
#   5. the touched suites: tools/lint/prepush_picks.py picks every suite whose runner, or code its
#      runner or tests/lib helpers reference (a changed sim/ or scenes/ script by class_name or
#      res:// path, a changed data/tuning.json section), changed; plus SUITES. No cap on how many.
#      PREPUSH_DRY=1 prints the picked suites with reasons and exits (RANGE="a...b" picks for
#      another diff, e.g. RANGE=origin/main...origin/claude/some-pr).
# The last line is "prepush: PASS <sha>" or "prepush: FAIL <step>"; paste it in your report.
# The lead arms a merge only for a head that printed PASS.
#
#   GODOT=/path/to/godot_console.exe SUITES="sim city" tools/prepush.sh
set -u
cd "$(dirname "$0")/.." || exit 1
# The Python user site, resolved before anything (a caller's APPDATA override hides it, and with
# it gdtoolkit): put it on PYTHONPATH for every python call below.
user_site="$(python -c 'import site;print(site.getusersitepackages())' 2> /dev/null || true)"
if [ -n "$user_site" ]; then
	if command -v cygpath > /dev/null 2>&1; then user_site="$(cygpath -u "$user_site")"; fi
	export PYTHONPATH="$user_site${PYTHONPATH:+:$PYTHONPATH}"
fi
GODOT="${GODOT:-godot}"
SUITES="${SUITES:-}"
BASE="${BASE:-origin/main}"

# picks: print "suite<TAB>reason" lines for a diff range, then the expected time
picks() { printf '%s
' "$1" | python tools/lint/prepush_picks.py --timings tools/ci_timings.txt; }

fail() { echo "prepush: FAIL $1"; exit 1; }
step() { echo "== $1"; }

if [ "${PREPUSH_DRY:-0}" = 1 ]; then
	range="${RANGE:-$BASE...HEAD}"
	BASE_REF="${RANGE:-}"; BASE_REF="${BASE_REF%%...*}"
	[ -n "${RANGE:-}" ] || BASE_REF="$BASE"
	NEW_REF="${RANGE:-}"; NEW_REF="${NEW_REF##*...}"
	[ -n "${RANGE:-}" ] || NEW_REF=""
	export BASE_REF NEW_REF
	dry=$(git diff --name-only --diff-filter=ACMR "$range")
	[ -n "$dry" ] || { echo "no changed files in $range: no suites"; exit 0; }
	picks "$dry"
	exit 0
fi

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

step "4b repo lints (tools/lint/run_all.sh: .uid files, ...)"
bash tools/lint/run_all.sh || fail "repo lints"

step "4c native DLL against main's CI build"
REF="$BASE" bash tools/native_dll.sh check || fail "native DLL (bash tools/native_dll.sh fetch)"

step "5 touched suites"
BASE_REF="$BASE" picks "$changed" | tee "$run_data/picks.txt" | sed 's/^/  /'
auto=$(grep -v '^#' "$run_data/picks.txt" | cut -f1)
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
