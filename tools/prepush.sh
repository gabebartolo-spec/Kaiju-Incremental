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
#      res:// path, a changed data/tuning.json section), changed, and 'native' for any new or changed
#      tools/capture or tools/bench .gd (no runner loads those; the suite scans the folder); plus SUITES.
#      No cap on how many.
#      PREPUSH_DRY=1 prints the picked suites with reasons and exits (RANGE="a...b" picks for
#      another diff, e.g. RANGE=origin/main...origin/claude/some-pr).
# The last line is "prepush: PASS <sha>" or "prepush: FAIL <step>"; paste it in your report.
# The lead arms a merge only for a head that printed PASS. On Windows a step stopped from outside
# (taskkill /F) reads as exit 0 to this bash, so exit 0 proves nothing: every Godot step passes only on
# exit 0 AND its own success line. Step 4 import: the engine's "[ DONE ] loading_editor_layout" line
# (printed when the editor has loaded, the last thing --import waits for); check_scripts.sh: "ok:
# check_scripts: <n> scripts, 0 failed"; step 4b run_all.sh: "lint: ok"; step 5 run_tests.sh: "All
# checks passed (<n> suites)." for the n suites asked for. These three tools print their line last. A killed,
# silent or cut-short step prints "prepush: FAIL <step>". tools/lint/tests/test_prepush_guard.py covers
# every step.
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
# run_step <label> <log> <success-line regex> <command...>: runs the command (its output shows live and is kept
# in <log>) and succeeds only when it exits 0 AND the last non-blank line of its output matches the regex. A step
# killed from outside reads as exit 0 here (MSYS), and a killed step never printed its success line. tee keeps the
# output live; the exit code is the first pipe stage's.
run_step() {
	local label="$1" log="$2" regex="$3" code got
	shift 3
	"$@" 2>&1 | tee "$log"
	code=${PIPESTATUS[0]}
	[ "$code" = 0 ] || return 1
	got=$(tr -d '\r' < "$log" | grep -v '^[[:space:]]*$' | tail -n 1)
	if printf '%s\n' "$got" | grep -qE "$regex"; then return 0; fi
	echo "$label exited 0 but its last line is not its success line (killed or cut short?): ${got:-<no output>}"
	return 1
}

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
# every workflow job names a timeout-minutes (lint.yml runs it too)
python tools/lint/workflow_timeouts.py || fail "a workflow job has no timeout-minutes"
python tools/lint/tuning_keys.py || fail "tuning keys"
python tools/lint/licence_register.py || fail "licence register (docs/LICENSING_REGISTER.md covers every assets/ file)"
python tools/lint/complexity_ratchet.py || fail "complexity ratchet"
# every data/*.json against its schema in data/schemas (the tests.yml preflight runs it too)
python tools/lint/data_schemas.py || fail "data schemas (data/schemas/README.md)"

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
. tools/speed_gate.sh  # D-299: no Godot while a speed run holds the PC; also gated in check_scripts.sh and run_tests.sh
wait_speed_gate
APPDATA="$(native_path "$run_data")" XDG_DATA_HOME="$run_data/data" XDG_CONFIG_HOME="$run_data/config" \
	timeout 600 "$GODOT" --headless --path . --editor --import > "$run_data/import.log" 2>&1 || code=$?
if [ "$code" != 0 ] || grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$run_data/import.log"; then
	grep -E -A3 "SCRIPT ERROR|Parse Error|Compile Error" "$run_data/import.log" | head -40
	fail "import (exit $code)"
fi
# --import prints nothing on success but the editor's start-up progress, whose last line is "[ DONE ]
# loading_editor_layout" (Godot 4.7.2, checked in 21 saved import logs); a killed import never gets there.
if ! grep -qE '\[ DONE \].*loading_editor_layout' "$run_data/import.log"; then
	echo "godot exited $code but its import log has no \"[ DONE ] loading_editor_layout\" line (killed or cut short?); last lines:"
	tail -n 5 "$run_data/import.log"
	fail "import (exit $code, never finished)"
fi
run_step "check_scripts.sh" "$run_data/check_scripts.log" '^ok: check_scripts: [0-9]+ scripts, 0 failed$' \
	env GODOT="$GODOT" tools/check_scripts.sh || fail "script compile"

step "4b repo lints (tools/lint/run_all.sh: .uid files, ...)"
run_step "run_all.sh" "$run_data/lints.log" '^lint: ok$' bash tools/lint/run_all.sh || fail "repo lints"

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
# PASS needs run_tests' own success line as its LAST line, with the number of suites asked for, as well
# as exit 0 (run_step above): on Windows a run stopped with `taskkill /F` reports exit 0 to the bash
# waiting for it, and once printed a false "prepush: PASS" (debt-ci-data, 2026-10-27 06:09).
n_suites=$(echo "$suites" | wc -w | tr -d ' ')
# shellcheck disable=SC2086
run_step "run_tests.sh" "$run_data/suites.log" "^All checks passed \\($n_suites suites\\)\\.\$" \
	env GODOT="$GODOT" tools/run_tests.sh --quick $suites || fail "suites ($suites)"

echo "prepush: PASS $(git rev-parse HEAD)"
