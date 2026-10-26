#!/usr/bin/env bash
# Planted-defect self-test for tools/lint/check_uids.sh: the check is green on a clean scratch repo and red,
# by rule name, on each defect it exists to catch (a script with no .uid, a .uid with no script, one uid in
# two files), and ignores folders holding a .gdignore.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

new_repo() { # new_repo <name>: a scratch repo holding the check and one good script
	local r="$tmp/$1"
	mkdir -p "$r/tools/lint" "$r/scenes"
	cp "$here/check_uids.sh" "$r/tools/lint/"
	git -C "$r" init -q
	printf 'extends Node\n' > "$r/scenes/good.gd"
	printf 'uid://aaaaaaaaaaaaa\n' > "$r/scenes/good.gd.uid"
	echo "$r"
}
expect() { # expect <label> <repo> <green|RULE>
	local out code
	git -C "$2" add -A > /dev/null 2>&1
	out="$(bash "$2/tools/lint/check_uids.sh" 2>&1)"
	code=$?
	if [ "$3" = green ]; then
		if [ "$code" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1 should pass"; echo "$out"; fail=1; fi
	elif [ "$code" != 0 ] && printf '%s' "$out" | grep -q "$3"; then
		echo "ok: $1 -> $3"
	else
		echo "FAIL: $1 should fail with $3 (exit $code)"; echo "$out"; fail=1
	fi
}

r="$(new_repo clean)"
expect "a clean repo passes" "$r" green

r="$(new_repo missing)"
printf 'extends Node\n' > "$r/scenes/bad.gd"
expect "a script with no .uid" "$r" UID-MISSING

r="$(new_repo shader)"
printf 'shader_type spatial;\n' > "$r/scenes/bad.gdshader"
expect "a shader with no .uid" "$r" UID-MISSING

r="$(new_repo orphan)"
printf 'uid://bbbbbbbbbbbbb\n' > "$r/scenes/gone.gd.uid"
expect "a .uid whose script is gone" "$r" UID-ORPHAN

r="$(new_repo dup)"
printf 'extends Node\n' > "$r/scenes/other.gd"
printf 'uid://aaaaaaaaaaaaa\n' > "$r/scenes/other.gd.uid"
expect "one uid in two files" "$r" UID-DUPLICATE

r="$(new_repo ignored)"
mkdir -p "$r/tests/fixtures/compile"
: > "$r/tests/fixtures/compile/.gdignore"
printf 'extends Node\n' > "$r/tests/fixtures/compile/not_imported.gd"
expect "a .gdignore folder is skipped" "$r" green

exit $fail
