#!/usr/bin/env bash
# The CI shard plan (tools/plan_ci_shards.sh) must run every suite exactly once, and every part of a
# split suite exactly once: a suite dropped from the matrix, or run twice, is the one way a faster CI
# could quietly test less (debt row 4, D-295). Checked here:
#   1. the real plan (tools/ci_timings.txt): the suites in the matrix are exactly every tests/run_*_tests.gd
#      (a "split <suite> <n>" suite as its n parts <suite>@1/n .. <suite>@n/n) except the "pr_skip" ones, which
#      the slow job runs on main, and no entry is there twice;
#   2. a split planted on a real suite: its parts are all in the plan and the whole suite is not;
#   3. a split of a suite that does not exist, and a split into fewer than two parts, are refused.
# No Godot needed; tools/test_run_tests.sh runs it, and so does the harness job in CI.
set -u
cd "$(dirname "$0")/.." || exit 1
PLAN=tools/plan_ci_shards.sh
REAL=tools/ci_timings.txt
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bad=0

suites() {  # every suite runner in tests/, by name
	local f s
	for f in tests/run_*_tests.gd; do
		s="${f#tests/run_}"
		echo "${s%_tests.gd}"
	done
}

planned() {  # timings file -> every entry of the matrix, one per line, sorted
	CI_TIMINGS="$1" bash "$PLAN" --matrix | grep -oE '"suites":"[^"]*"' | sed 's/"suites":"//; s/"$//' | tr ' ' '\n' | grep -v '^$' | sort
}

wanted() {  # timings file -> what the matrix must hold, one per line, sorted
	local timings="$1" slow s n k
	slow=" $(CI_TIMINGS="$timings" bash "$PLAN" --slow) "
	for s in $(suites); do
		case "$slow" in *" $s "*) continue ;; esac
		n=$(awk -v s="$s" '$1 == "split" && $2 == s {print $3}' "$timings" | head -1)
		if [ -n "$n" ]; then
			for ((k = 1; k <= n; k++)); do echo "$s@$k/$n"; done
		else
			echo "$s"
		fi
	done | sort
}

# 1. the real plan
planned "$REAL" > "$tmp/got.txt"
wanted "$REAL" > "$tmp/want.txt"
if [ ! -s "$tmp/got.txt" ]; then
	echo "FAIL: the shard plan is empty"
	bad=1
elif [ "$(sort "$tmp/got.txt" | uniq -d | wc -l)" != 0 ]; then
	echo "FAIL: the shard plan runs these twice: $(sort "$tmp/got.txt" | uniq -d | tr '\n' ' ')"
	bad=1
elif ! diff "$tmp/want.txt" "$tmp/got.txt" > "$tmp/diff.txt"; then
	echo "FAIL: the shard plan and the suites in tests/ differ (< should run, > does):"
	cat "$tmp/diff.txt"
	bad=1
else
	echo "ok: the shard plan runs all $(wc -l < "$tmp/got.txt" | tr -d ' ') entries (every suite, every part) exactly once"
fi

# 2. a split planted on a real suite
{ cat "$REAL"; echo "split carving 3"; } > "$tmp/planted.txt"
planned "$tmp/planted.txt" > "$tmp/got.txt"
if [ "$(grep -c '^carving@[123]/3$' "$tmp/got.txt")" = 3 ] && ! grep -qx carving "$tmp/got.txt" \
	&& [ "$(sort "$tmp/got.txt" | uniq -d | wc -l)" = 0 ] \
	&& diff <(wanted "$tmp/planted.txt") "$tmp/got.txt" > /dev/null; then
	echo "ok: a planted split puts all three parts in the plan and not the whole suite"
else
	echo "FAIL: a planted 'split carving 3' should plan carving@1/3, carving@2/3 and carving@3/3 only"
	grep carving "$tmp/got.txt"
	bad=1
fi

# 3. refused splits
for line in "split nosuchsuite 2" "split carving 1" "split carving x"; do
	{ cat "$REAL"; echo "$line"; } > "$tmp/refused.txt"
	if CI_TIMINGS="$tmp/refused.txt" bash "$PLAN" --matrix > /dev/null 2> "$tmp/err.txt"; then
		echo "FAIL: '$line' should be refused"
		bad=1
	elif grep -q '^ERROR: split' "$tmp/err.txt"; then
		echo "ok: '$line' is refused"
	else
		echo "FAIL: '$line' failed without saying why"
		cat "$tmp/err.txt"
		bad=1
	fi
done
exit "$bad"
