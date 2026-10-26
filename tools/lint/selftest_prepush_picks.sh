#!/usr/bin/env bash
# Self-test (run by tools/lint/run_all.sh) for tools/lint/prepush_picks.py + prepush.sh PREPUSH_DRY: a docs-only change picks no
# suite; a change to a script a runner loads picks that suite; a tuning section picks its readers.
set -u
cd "$(dirname "$0")/../.." || exit 1
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok: $1"; else echo "FAIL: $1 (got '$2', want '$3')"; fail=1; fi; }
names() { cut -f1 | grep -v '^#' | tr '\n' ' '; }
check "docs only picks none" "$(printf 'docs/DESIGN.md\nREADME.md\n' | python tools/lint/prepush_picks.py | names)" ""
check "a runner picks itself" "$(printf 'tests/run_gait_tests.gd\n' | python tools/lint/prepush_picks.py | names)" "gait "
got="$(printf 'scenes/city_decor.gd\n' | python tools/lint/prepush_picks.py | names)"
case "$got" in *empty_space*) echo "ok: scene script picks the suite that loads it" ;; *) echo "FAIL: city_decor picks '$got'"; fail=1 ;; esac
check "a uid file follows its script" "$(printf 'tests/run_gait_tests.gd.uid\n' | python tools/lint/prepush_picks.py | names)" "gait "
exit $fail
