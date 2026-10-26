#!/usr/bin/env bash
# check_lfs.sh: files that .gitattributes sends to Git LFS are LFS pointers in git, not raw binaries (debt row 8, D-295).
# A PC without git-lfs installed commits the raw bytes of a .kvox or .vskin (1-11 MB each) straight into the history, and
# nothing noticed. Reads the git index and blobs (no git-lfs binary, no Godot), so it runs in CI.
#
#   LFS-RAW        a tracked file whose filter is lfs is stored as raw bytes, not a pointer      (error)
#   LFS-MISSING    .gitattributes no longer sends *.kvox or *.vskin to LFS                        (error)
#
# Fix for LFS-RAW: `git lfs install` once on the PC, then `git add --renormalize <file>` and commit.
# Usage: bash tools/lint/check_lfs.sh   (runs in the repo the script sits in)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

emit() { # emit <RULE> <path> <message>
	printf '%s:0: %s %s\n' "$2" "$1" "$3"
	if [ -n "${GITHUB_ACTIONS:-}" ]; then printf '::error file=%s,line=0::%s %s\n' "$2" "$1" "$3"; fi
}

bad=0
for ext in kvox vskin; do
	# a made-up path with the extension, so the pattern is judged whatever files exist today
	if [ "$(git check-attr filter -- "check_lfs_probe.$ext" | sed 's/.*: //')" != "lfs" ]; then
		emit LFS-MISSING .gitattributes "*.$ext is not sent to LFS: add '*.$ext filter=lfs diff=lfs merge=lfs -text'"
		bad=1
	fi
done

checked=0
# one git process for the whole tree: check-attr prints path, attribute, value, each NUL-terminated
while IFS= read -r -d '' path && IFS= read -r -d '' _attr && IFS= read -r -d '' filter; do
	[ "$filter" = "lfs" ] || continue
	checked=$((checked + 1))
	head="$(git cat-file blob ":$path" | head -c 40)"
	case "$head" in
		"version https://git-lfs.github.com/spec/"*) ;;
		*)
			emit LFS-RAW "$path" "is stored as raw bytes but .gitattributes says LFS: run 'git lfs install', then 'git add --renormalize $path'"
			bad=1
			;;
	esac
done < <(git ls-files -z | git check-attr -z --stdin filter)

if [ "$bad" = 0 ]; then echo "ok: $checked LFS files, all stored as pointers"; fi
exit "$bad"
