#!/usr/bin/env bash
# Planted-defect self-test for tools/lint/check_lfs.sh: green on a scratch repo whose LFS files are pointers, red by rule
# name on a raw binary the .gitattributes says is LFS (LFS-RAW) and on a .gitattributes that dropped the LFS rule
# (LFS-MISSING). The raw blob is planted with hash-object so no installed LFS filter can quietly fix it.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
POINTER=$'version https://git-lfs.github.com/spec/v1\noid sha256:0000000000000000000000000000000000000000000000000000000000000000\nsize 5\n'

new_repo() { # new_repo <name> <gitattributes text>
	local r="$tmp/$1"
	mkdir -p "$r/tools/lint" "$r/assets"
	cp "$here/check_lfs.sh" "$r/tools/lint/"
	git -C "$r" init -q
	printf '%s\n' "$2" > "$r/.gitattributes"
	echo "$r"
}
plant() { # plant <repo> <path> <content>: store the content as the blob for path, filters off
	local blob
	blob="$(printf '%s' "$3" | git -C "$1" hash-object -w --no-filters --stdin)"
	git -C "$1" update-index --add --cacheinfo "100644,$blob,$2"
}
expect() { # expect <label> <repo> <green|RULE>
	local out code
	git -C "$2" add .gitattributes tools > /dev/null 2>&1
	out="$(bash "$2/tools/lint/check_lfs.sh" 2>&1)"
	code=$?
	if [ "$3" = green ]; then
		if [ "$code" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1 should pass"; echo "$out"; fail=1; fi
	elif [ "$code" != 0 ] && printf '%s' "$out" | grep -q "$3"; then
		echo "ok: $1 -> $3"
	else
		echo "FAIL: $1 should fail with $3 (exit $code)"; echo "$out"; fail=1
	fi
}

RULES=$'*.kvox filter=lfs diff=lfs merge=lfs -text\n*.vskin filter=lfs diff=lfs merge=lfs -text'

r="$(new_repo clean "$RULES")"
plant "$r" assets/a.kvox "$POINTER"
plant "$r" assets/a.vskin "$POINTER"
plant "$r" assets/plain.txt "not lfs, any bytes"
expect "pointers pass" "$r" green

r="$(new_repo raw "$RULES")"
plant "$r" assets/a.kvox "$POINTER"
plant "$r" assets/big.vskin "RAWBYTES-not-a-pointer"
expect "a raw .vskin" "$r" LFS-RAW

r="$(new_repo dropped "*.vskin filter=lfs diff=lfs merge=lfs -text")"
expect "the .kvox rule removed" "$r" LFS-MISSING

r="$(new_repo binary "*.kvox binary
*.vskin binary")"
plant "$r" assets/a.kvox "RAWBYTES"
expect "the old 'binary' rules" "$r" LFS-MISSING

exit $fail
