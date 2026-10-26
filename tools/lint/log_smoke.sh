#!/usr/bin/env bash
# log_smoke.sh: seeded headless runs whose engine logs must be clean (D-295, debt rows 1-2).
#
# Two runs, each on a fixed 60 fps frame clock:
#   1. tools/release/demo_smoke.gd: the title, NEW KAIJU, Kaiju Creation, a rampage, the thanks screen,
#      Endless mode and a relaunch, through the game's own screens;
#   2. tools/lint/log_smoke.gd: every species' autoplayed rampage to a death, everything freed.
# A run fails on ANY engine ERROR / WARNING / SCRIPT ERROR line or leak report in its log (a vector that is
# not finite, a normalise of zero, a resource still alive at exit), or when its own checks fail. The lines
# are never filtered or muted: fix the cause. Exit 0 = both logs clean, 1 = lines found (counted, with the
# first backtrace of each kind) or a run did not finish.
#
#   GODOT=/path/to/godot tools/lint/log_smoke.sh [script args for log_smoke.gd, e.g. --species=insectoid --seconds=20]
#   LOGS=<dir> keeps the raw logs there (default: a temp dir, removed).
#   ONLY=demo|rampage runs just one of the two.
#   BEFORE_ENGINE='<command>' runs before every engine start and must succeed (a shared PC: `bash C:/kt/wait_window.sh`).
#   tools/lint/log_smoke.sh --selftest   plants an error, a warning and leaks, expects each to be caught.
set -u
cd "$(dirname "$0")/../.." || exit 1
GODOT="${GODOT:-godot}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-1200}"

# Every line the engine prints for an error, a warning or a leak at exit (ANSI colour stripped first).
# "ERROR:", "WARNING:", "SCRIPT ERROR:", "USER ERROR:", "USER WARNING:" and "SHADER ERROR:" start a
# line; the leak reports at exit (ObjectDB instances, RID allocations, resources, paged allocators) are
# ERROR / WARNING lines too and are named again so a run that prints them without the prefix still fails.
PATTERN='^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING|SHADER ERROR):|^(Parse|Compile) Error|ObjectDB instances were leaked|RID allocations of type|Leaked instance|still in use at exit|Pages in use'

before_engine() {  # the caller's gate before each engine start (a speed run may own the PC)
	[ -z "${BEFORE_ENGINE:-}" ] || bash -c "$BEFORE_ENGINE" || { echo "log_smoke: the engine start was refused"; exit 1; }
}

native_path() {  # the engine on Windows needs a Windows path in APPDATA
	if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}

# check_log <file>: print the offending lines, grouped; exit status 1 when any.
check_log() {
	local raw="$1" clean n
	clean="$(mktemp)"
	sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r$//' "$raw" > "$clean"
	n=$(grep -cE "$PATTERN" "$clean")
	if [ "$n" = 0 ]; then rm -f "$clean"; return 0; fi
	echo "log_smoke: $n engine ERROR/WARNING/leak lines (cause each; never filter):"
	grep -E "$PATTERN" "$clean" | sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -rn | head -40
	echo "-- first of each kind, with its backtrace:"
	awk -v pat="$PATTERN" '
		$0 ~ pat { key = $0; gsub(/[0-9]+/, "N", key); show = !(key in seen); seen[key] = 1; if (show) print; next }
		show && /^[ \t]+(at:|GDScript backtrace|\[[0-9]+\])/ { print; next }
		{ show = 0 }
	' "$clean" | head -150
	rm -f "$clean"
	return 1
}

if [ "${1:-}" = "--selftest" ]; then
	# The checker must catch an error, a warning and each leak report, and pass a clean log.
	tmp="$(mktemp -d)"
	printf 'Engine v4.7.2\nLOG_SMOKE done\n' > "$tmp/clean.log"
	check_log "$tmp/clean.log" > /dev/null || { echo "FAIL: a clean log was rejected"; exit 1; }
	for bad in 'ERROR: Condition "!v.is_finite()" is true.' 'WARNING: Vector3 cannot be normalized' \
		'WARNING: 3 ObjectDB instances were leaked at exit' 'ERROR: 21 RID allocations of type X were leaked at exit.' \
		'ERROR: 4 resources still in use at exit.' 'SCRIPT ERROR: Parse Error: x' 'Leaked instance dependency: x'; do
		printf 'Engine v4.7.2\n%s\nLOG_SMOKE done\n' "$bad" > "$tmp/bad.log"
		check_log "$tmp/bad.log" > /dev/null && { echo "FAIL: not caught: $bad"; exit 1; }
	done
	rm -rf "$tmp"
	echo "log_smoke selftest: PASS"
	exit 0
fi

run_data="$(mktemp -d)"
trap 'rm -rf "$run_data"' EXIT
logs="${LOGS:-$run_data}"
mkdir -p "$logs"
export XDG_DATA_HOME="$run_data/data" XDG_CONFIG_HOME="$run_data/config" XDG_CACHE_HOME="$run_data/cache"
if [ ! -d .godot/imported ]; then  # a fresh checkout: the class_name cache comes from one import
	before_engine
	APPDATA="$(native_path "$run_data")" timeout "${IMPORT_TIMEOUT:-600}" "$GODOT" --headless --path . --editor --import \
		> "$run_data/import.log" 2>&1 || { echo "log_smoke: FAIL the import failed"; tail -20 "$run_data/import.log"; exit 1; }
fi

failed=0
# run_one <name> <script> [script args]: run it, then read its log.
run_one() {
	local name="$1" script="$2" log code
	shift 2
	log="$logs/$name.log"
	echo "== $name ($script)"
	before_engine
	APPDATA="$(native_path "$run_data")" timeout "$SMOKE_TIMEOUT" "$GODOT" --headless --fixed-fps 60 --path . \
		--script "$script" -- "$@" > "$log" 2>&1
	code=$?
	if [ "$code" = 124 ]; then echo "log_smoke: FAIL $name timed out after ${SMOKE_TIMEOUT}s"; tail -5 "$log"; failed=1; return; fi
	if [ "$code" != 0 ]; then echo "log_smoke: FAIL $name exit $code"; grep -E "^FAIL|^(DEMO_SMOKE)" "$log" | head; failed=1; fi
	sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log" | grep -E "^(log_smoke:|LOG_SMOKE|DEMO_SMOKE)" | head -20
	if [ "$name" = rampage ] && ! grep -q "^LOG_SMOKE done" "$log"; then
		echo "log_smoke: FAIL the rampage run never finished"; tail -20 "$log"; failed=1; return
	fi
	if ! check_log "$log"; then failed=1; fi
}

[ "${ONLY:-}" = rampage ] || run_one demo tools/release/demo_smoke.gd
[ "${ONLY:-}" = demo ] || run_one rampage tools/lint/log_smoke.gd "$@"
if [ "$failed" = 0 ]; then
	echo "log_smoke: PASS (no ERROR, WARNING or leak line in either log)"
	exit 0
fi
echo "log_smoke: FAIL"
exit 1
