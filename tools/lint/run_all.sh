#!/usr/bin/env bash
# run_all.sh: the project's repo-hygiene lints, run by lint.yml (project-lints) and tools/prepush.sh.
# Nothing is registered here: drop a file in tools/lint/ and it runs.
#   check_*.sh        a lint over the repo as it is; exit non-zero = red
#   selftest_*.sh     plants a defect in a scratch repo and proves the matching check goes red on it
#   tests/test_*.py   unittest smoke tests for the Python tools CI and prepush run
# Needs bash, git and python; no Godot (those gates live in tests.yml preflight). Runs every file, prints
# which failed, exits 1 if any did.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
failed=()
run() { # run <label> <command...>
	local label="$1"
	shift
	echo "== $label"
	if "$@"; then :; else failed+=("$label"); fi
}
for f in tools/lint/check_*.sh tools/lint/selftest_*.sh; do
	[ -f "$f" ] || continue
	run "$f" bash "$f"
done
if ls tools/lint/tests/test_*.py > /dev/null 2>&1; then
	run "python smoke tests" python -m unittest discover -s tools/lint/tests -p 'test_*.py'
fi
if [ "${#failed[@]}" -gt 0 ]; then
	echo "lint: FAIL ${failed[*]}"
	exit 1
fi
echo "lint: ok"
