#!/usr/bin/env bash
# push_gate.sh: the seconds-long CI checks every push passes first (director 2026-10-30: "sessions keep failing
# CI in predictable ways"). Run by the PreToolUse hook in .claude/settings.json on any `git push`; a fail blocks
# the push and the session reads why. Covers what went red most: doc line caps and gdformat/gdlint (lint.yml),
# the repo checks and the Python lints prepush step 2 runs. No Godot here: the touched suites are tools/run_touched.py (D-403).
# The selftests run only when tools/lint/ changed (they take minutes on Windows).
#   bash tools/lint/push_gate.sh          # changed files against origin/main
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
BASE="${BASE:-origin/main}"
failed=()
run() { # run <label> <command...>
	local label="$1"
	shift
	if ! out=$("$@" 2>&1); then
		printf '== %s\n%s\n' "$label" "$out" | tail -n 30
		failed+=("$label")
	fi
}

# Line caps: the same loop as lint.yml doc-caps.
caps() {
	local f cap n bad=0
	for f in docs/*.md; do
		cap=$(head -n 6 "$f" | sed -n 's/^Cap: \([0-9][0-9]*\) lines.*/\1/p' | head -n 1)
		[ -n "$cap" ] || continue
		n=$(wc -l < "$f")
		if [ "$n" -gt "$cap" ]; then echo "$f: $n lines, cap is $cap (DECISIONS.md: python tools/roll_decisions.py)"; bad=1; fi
	done
	n=$(wc -l < CLAUDE.md)
	if [ "$n" -gt 120 ]; then echo "CLAUDE.md: $n lines, cap is 120"; bad=1; fi
	return $bad
}
run "doc line caps" caps

changed=$(git diff --name-only --diff-filter=ACMR "$BASE"...HEAD)
gd=$(printf '%s\n' "$changed" | grep -E '\.gd$' | grep -vE '^(\.godot|\.claude|tests/fixtures/lint)/' || true)
if [ -n "$gd" ]; then
	snake() { printf '%s\n' "$gd" | grep -vE '(^|/)[a-z0-9]+(_[a-z0-9]+)*\.gd$' && return 1 || return 0; }
	run "snake_case file names" snake
	# shellcheck disable=SC2086 # one path per word, no spaces in .gd paths (snake_case)
	run "gdlint" python -m gdtoolkit.linter $gd
	# shellcheck disable=SC2086
	run "gdformat --check (fix: python -m gdtoolkit.formatter <file>)" python -m gdtoolkit.formatter --check $gd
fi

run "workflow timeouts" python tools/lint/workflow_timeouts.py
run "tuning keys" python tools/lint/tuning_keys.py
run "licence register" python tools/lint/licence_register.py
run "complexity ratchet" python tools/lint/complexity_ratchet.py
run "data schemas" python tools/lint/data_schemas.py
run tools/lint/check_thread_resources.sh bash tools/lint/check_thread_resources.sh
# The slow repo checks run only when the push touches what they read (check_uids 60 s, check_lfs 20 s on Windows).
if printf '%s\n' "$changed" | grep -qE '\.(gd|gdshader|gdshaderinc|uid)$'; then run tools/lint/check_uids.sh bash tools/lint/check_uids.sh; fi
if printf '%s\n' "$changed" | grep -qvE '\.(md|gd|uid|py|sh|json|yml|cfg|txt|tscn|tres|gdshader|gdshaderinc)$'; then
	run tools/lint/check_lfs.sh bash tools/lint/check_lfs.sh
fi
# check_i18n reads the Chinese font, which stays an LFS pointer unless pulled (CI pulls it).
run tools/lint/check_i18n.sh bash tools/lint/check_i18n.sh
if printf '%s\n' "$changed" | grep -q '^tools/lint/'; then run "tools/lint/run_all.sh (tools/lint changed)" bash tools/lint/run_all.sh; fi

if [ "${#failed[@]}" -gt 0 ]; then
	echo "push_gate: FAIL ${failed[*]}"
	exit 1
fi
echo "push_gate: ok"
