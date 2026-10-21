#!/usr/bin/env bash
# check_scripts.sh: parse and compile every GDScript file with Godot's own parser (R 5.6).
#
# Catches Godot 3 names agents write in a Godot 4 project (`yield`, `onready`/`export`
# without @, `instance()`, `Spatial`, `KinematicBody`, `rand_range`, `deg2rad`,
# `PoolStringArray`, three-argument `connect()`, `empty()`) and any other parse or compile
# error, in a script nothing loads yet as much as in one the game uses. The project import
# alone does not: it compiles none of these (checked 2026-10-21 with 13 planted scripts).
# No regex list is needed: the typing warnings are errors in project.godot, so a Godot 3 call
# on an untyped value fails to compile too.
#
# Files are found by tools/check_scripts.gd walking res:// (folders with a .gdignore are
# skipped). Needs an imported project (the class_name cache); CI runs it after the import.
#
#   GODOT=/path/to/godot tools/check_scripts.sh
#
# Exits nonzero if any script fails; prints the engine's error lines and the bad paths.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
CHECK_TIMEOUT="${CHECK_TIMEOUT:-300}"

run_data="$(mktemp -d)"
trap 'rm -rf "$run_data"' EXIT
native_path() { # Godot on Windows needs a Windows path in APPDATA
	if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}
log="$run_data/check_scripts.log"
code=0
APPDATA="$(native_path "$run_data")" XDG_DATA_HOME="$run_data/data" \
	XDG_CONFIG_HOME="$run_data/config" XDG_CACHE_HOME="$run_data/cache" \
	timeout "$CHECK_TIMEOUT" "$GODOT" --headless --path . --script res://tools/check_scripts.gd \
	> "$log" 2>&1 || code=$?

summary="$(grep -E '^check_scripts: ' "$log" | tail -n 1)"
if [ "$code" != 0 ] || [ -z "$summary" ] || grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$log"; then
	grep -E "SCRIPT ERROR|Parse Error|Compile Error|^ERROR: Failed to load script" "$log" | sort -u | head -60
	grep -E '^BAD ' "$log" | sed 's/^BAD /::error::does not compile: /'
	echo "${summary:-check_scripts: no summary line (exit $code)}"
	tail -n 3 "$log"
	echo "FAIL: a script does not parse or compile (exit $code)"
	exit 1
fi
echo "ok: $summary"
