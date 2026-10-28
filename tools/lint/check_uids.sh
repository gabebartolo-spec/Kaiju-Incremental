#!/usr/bin/env bash
# check_uids.sh: every Godot script and shader in git has its .uid file in git too (debt row 7, D-295).
# Godot 4.4+ writes <file>.uid next to each .gd / .gdshader / .gdshaderinc on import; without the committed
# copy every PC makes its own id, and a scene that points at a script by uid then resolves differently per PC
# (and a stray untracked .uid blocks a later merge). Reads the git index, so it needs no Godot and runs in CI.
#
#   UID-MISSING    a tracked script or shader with no tracked <file>.uid                       (error)
#   UID-ORPHAN     a tracked .uid whose script or shader is not tracked                         (error)
#   UID-DUPLICATE  one uid:// value in two .uid files                                           (error)
#
# Folders holding a .gdignore are skipped (Godot never imports them), as are .godot/ and .claude/.
# Usage: bash tools/lint/check_uids.sh   (runs in the repo the script sits in; the self-test copies it into a
# scratch repo to plant defects).
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

files="$(git ls-files)"

ignored_dirs="$(printf '%s\n' "$files" | sed -n 's#/\.gdignore$#/#p; s#^\.gdignore$#./#p')"

emit() { # emit <RULE> <path> <message>
	printf '%s:0: %s %s\n' "$2" "$1" "$3"
	if [ -n "${GITHUB_ACTIONS:-}" ]; then printf '::error file=%s,line=0::%s %s\n' "$2" "$1" "$3"; fi
}

in_ignored_dir() { # in_ignored_dir <path>
	local d
	[ -z "$ignored_dirs" ] && return 1
	while IFS= read -r d; do
		[ "$d" = "./" ] && return 0
		case "$1" in "$d"*) return 0 ;; esac
	done <<< "$ignored_dirs"
	return 1
}

# The file list is fed through process substitution, never a here-string: on Git Bash a here-string over
# 64 KiB (the list passed that at ~2060 tracked files) blocks forever and every local lint run hung.
declare -A have
while IFS= read -r f; do have["$f"]=1; done < <(printf '%s\n' "$files")

bad=0
checked=0
while IFS= read -r f; do
	case "$f" in
		.godot/* | .claude/*) continue ;;
		*.gd | *.gdshader | *.gdshaderinc)
			in_ignored_dir "$f" && continue
			checked=$((checked + 1))
			if [ -z "${have["$f.uid"]:-}" ]; then
				emit UID-MISSING "$f" "has no tracked $f.uid: run a headless import (godot --headless --import) and commit the new .uid"
				bad=1
			fi
			;;
		*.uid)
			src="${f%.uid}"
			case "$src" in *.gd | *.gdshader | *.gdshaderinc | *.gdextension) ;; *) continue ;; esac
			if [ -z "${have["$src"]:-}" ]; then
				emit UID-ORPHAN "$f" "its file $src is not tracked: delete the .uid"
				bad=1
			fi
			;;
	esac
done < <(printf '%s\n' "$files")

# One uid value, one file. (Reads the working tree copy of each tracked .uid.)
dups="$(printf '%s\n' "$files" | grep -E '\.uid$' | while IFS= read -r u; do
	[ -f "$u" ] && printf '%s %s\n' "$(tr -d '\r\n ' < "$u")" "$u"
done | sort | awk '{ if ($1 == prev) { print prev " " pfile " " $2 } prev = $1; pfile = $2 }')"
if [ -n "$dups" ]; then
	while read -r id a b; do emit UID-DUPLICATE "$b" "shares $id with $a: delete one .uid and re-import"; done <<< "$dups"
	bad=1
fi

if [ "$bad" = 0 ]; then echo "ok: $checked scripts and shaders, each with a tracked .uid"; fi
exit "$bad"
