#!/usr/bin/env bash
# native_dll.sh: this checkout's native DLL against main's CI build (tech debt row 14, D-295).
#
# A missing or stale native/bin DLL does not fail the game: it quietly runs the slow GDScript
# mesher and flood, so a bench times the wrong thing. The DLL is not in git (native/bin/ is
# ignored); main's CI builds it (build.yml, Windows release) and uploads the small artifact
# "native-windows" (the DLL and native.txt, the git tree id of native/ it was built from).
#
#   tools/native_dll.sh check   print the local md5s and main's CI build md5; exit 1 on a mismatch
#   tools/native_dll.sh fetch   copy main's CI DLL into native/bin under both names
#   tools/native_dll.sh md5     print the local md5s only
#
# check: a branch whose native/ differs from origin/main's is not comparable (its DLL is its own
# build; tests.yml and build.yml build it in the PR): it prints the md5s and passes. Where main's
# build cannot be found (no gh, offline, no build of this native/ yet, artifact expired) it says
# NOT CHECKED and passes; only a real mismatch fails (exit 1).
# Env: REF=origin/main (the branch to compare with), KAIJU_NATIVE_CACHE=~/.cache/kaiju-native,
# RUNS=12 (how many recent successful builds to look through).
set -u
cd "$(dirname "$0")/.." || exit 1
REF="${REF:-origin/main}"
BRANCH="${REF#origin/}"
CACHE="${KAIJU_NATIVE_CACHE:-$HOME/.cache/kaiju-native}"
RUNS="${RUNS:-12}"
BIN=native/bin
REL=libkaiju_carve.windows.template_release.x86_64.dll
DBG=libkaiju_carve.windows.template_debug.x86_64.dll

md5_of() { if [ -f "$1" ]; then md5sum "$1" | cut -d' ' -f1; else echo "missing"; fi; }

local_md5s() {
	echo "local $BIN/$DBG  md5 $(md5_of "$BIN/$DBG")"
	echo "local $BIN/$REL  md5 $(md5_of "$BIN/$REL")"
}

# find_build: put main's CI DLL for the tree of native/ at $REF into $CACHE/<tree>/ and print the
# tree; prints nothing (and a reason on stderr) when there is none.
find_build() {
	local tree dir run
	tree="$(git rev-parse "$REF:native" 2> /dev/null)" || { echo "no $REF:native (git fetch?)" >&2; return 1; }
	dir="$CACHE/$tree"
	if [ -f "$dir/$REL" ]; then echo "$tree"; return 0; fi
	command -v gh > /dev/null 2>&1 || { echo "gh is not installed" >&2; return 1; }
	local runs
	runs="$(gh run list --workflow build.yml --branch "$BRANCH" --status success --limit "$RUNS" \
		--json databaseId --jq '.[].databaseId' 2> /dev/null)" || { echo "gh run list failed (offline?)" >&2; return 1; }
	for run in $runs; do
		local tmp
		tmp="$(mktemp -d)"
		if gh run download "$run" -n native-windows -D "$tmp" > /dev/null 2>&1 \
			&& [ -f "$tmp/native.txt" ] && [ -f "$tmp/$REL" ] && grep -qx "tree=$tree" "$tmp/native.txt"; then
			mkdir -p "$dir" && cp "$tmp/$REL" "$dir/$REL" && echo "run=$run" > "$dir/run.txt"
			rm -rf "$tmp"
			echo "$tree"
			return 0
		fi
		rm -rf "$tmp"
	done
	echo "no successful $BRANCH build.yml run among the last $RUNS holds native/ $tree" >&2
	return 1
}

cmd="${1:-check}"
case "$cmd" in
md5) local_md5s ;;
fetch)
	tree="$(find_build)" || { echo "native_dll: FAIL no CI build to fetch"; exit 1; }
	mkdir -p "$BIN"
	cp "$CACHE/$tree/$REL" "$BIN/$REL"
	cp "$CACHE/$tree/$REL" "$BIN/$DBG"
	echo "native_dll: fetched $REF's CI build ($(cat "$CACHE/$tree/run.txt")), md5 $(md5_of "$BIN/$REL"), under both names"
	echo "native_dll: restart any running Godot; a loaded DLL is locked on Windows"
	;;
check)
	local_md5s
	if [ "$(git rev-parse HEAD:native 2> /dev/null)" != "$(git rev-parse "$REF:native" 2> /dev/null)" ]; then
		echo "native_dll: native/ differs from $REF on this branch: its DLL is its own build, not compared with main's"
		exit 0
	fi
	tree="$(find_build 2> "${TMPDIR:-/tmp}/native_dll_why.$$")" || {
		echo "native_dll: NOT CHECKED ($(cat "${TMPDIR:-/tmp}/native_dll_why.$$")); local md5s above"
		rm -f "${TMPDIR:-/tmp}/native_dll_why.$$"
		exit 0
	}
	rm -f "${TMPDIR:-/tmp}/native_dll_why.$$"
	want="$(md5_of "$CACHE/$tree/$REL")"
	echo "main's CI build ($(cat "$CACHE/$tree/run.txt"), native/ $tree)  md5 $want"
	bad=0
	for f in "$DBG" "$REL"; do
		if [ "$(md5_of "$BIN/$f")" != "$want" ]; then bad=1; fi
	done
	if [ "$bad" = 1 ]; then
		echo "native_dll: FAIL the local DLL is not main's CI build: run  bash tools/native_dll.sh fetch"
		exit 1
	fi
	echo "native_dll: ok, both local DLLs are main's CI build"
	;;
*)
	echo "usage: $0 check|fetch|md5" >&2
	exit 2
	;;
esac
