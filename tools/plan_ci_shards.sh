#!/usr/bin/env bash
# Splits the Godot suites across CI shards from measured times, so no list of suites or
# shards is kept by hand (director 2026-10-19, github-hygiene §4). Suites are found by
# filename (tests/run_<suite>_tests.gd). tools/ci_timings.txt holds "<suite> <seconds>"
# lines from real CI runs, one "shards <n>" line and one "lanes <n>" line (suites a shard runs
# at once), and "split <suite> <n>" lines for a suite too long for one lane, which then runs as n
# parts "<suite>@1/n" ... "<suite>@n/n" with their own timings (tools/run_tests.sh, tests/lib/functions_ran.gd);
# a suite with no timing yet counts as DEFAULT_SECS. Longest suite first, each into the
# lightest bin. Aim for a PR run of about 10-12 minutes: raise "shards" when the heaviest shard
# passes about 8 minutes.
#
#   tools/plan_ci_shards.sh            # print the plan
#   tools/plan_ci_shards.sh --matrix   # the GitHub matrix as JSON (tests.yml plan job)
#   tools/plan_ci_shards.sh --slow     # the "pr_skip" suites (a split one as its parts): pushes to main only
#
# Re-measure at least weekly and after adding a slow suite, from the shard logs of real CI runs:
#   python tools/ci_retime.py
set -u
mode="${1:-}"
cd "$(dirname "$0")/.." || exit 1
TIMINGS="${CI_TIMINGS:-tools/ci_timings.txt}"
DEFAULT_SECS="${DEFAULT_SECS:-60}"

skip=" $(awk '$1 == "pr_skip" {for (i = 2; i <= NF; i++) printf "%s ", $i}' "$TIMINGS" 2> /dev/null)"
if [ "$mode" = "--slow" ]; then
	# A split suite goes to the slow job as its parts too: whole, it would pass run_tests.sh's SUITE_TIMEOUT.
	slow=""
	for s in $skip; do
		parts=$(awk -v s="$s" '$1 == "split" && $2 == s {print $3}' "$TIMINGS" 2> /dev/null | head -1)
		if [ -n "$parts" ] && [ "$parts" -ge 2 ] 2> /dev/null; then
			k=1
			while [ "$k" -le "$parts" ]; do slow+="$s@$k/$parts "; k=$((k + 1)); done
		else
			slow+="$s "
		fi
	done
	echo "$slow" | xargs
	exit 0
fi
rows=""
for runner_file in tests/run_*_tests.gd; do
	[ -e "$runner_file" ] || continue
	suite="${runner_file#tests/run_}"
	suite="${suite%_tests.gd}"
	case "$skip" in *" $suite "*) continue ;; esac
	secs=$(awk -v s="$suite" '$1 == s {print $2}' "$TIMINGS" 2> /dev/null | head -1)
	parts=$(awk -v s="$suite" '$1 == "split" && $2 == s {print $3}' "$TIMINGS" 2> /dev/null | head -1)
	if [ -n "$parts" ]; then
		# "split <suite> <n>": the suite runs as n parts, <suite>@1/n ... <suite>@n/n (tests/lib/functions_ran.gd
		# part()), each its own entry below; a part with no timing yet counts as an even share of the whole.
		case "$parts" in '' | *[!0-9]*) echo "ERROR: split $suite $parts: the part count must be a whole number" >&2; exit 1 ;; esac
		if [ "$parts" -lt 2 ]; then echo "ERROR: split $suite $parts: need at least 2 parts" >&2; exit 1; fi
		k=1
		while [ "$k" -le "$parts" ]; do
			part_secs=$(awk -v s="$suite@$k/$parts" '$1 == s {print $2}' "$TIMINGS" 2> /dev/null | head -1)
			rows+="$suite@$k/$parts ${part_secs:-$(((${secs:-$DEFAULT_SECS} + parts - 1) / parts))}"$'\n'
			k=$((k + 1))
		done
	else
		rows+="$suite ${secs:-$DEFAULT_SECS}"$'\n'
	fi
done
# A split line for a suite that has no runner would drop nothing and say nothing: fail it.
for named in $(awk '$1 == "split" {print $2}' "$TIMINGS" 2> /dev/null); do
	if [ ! -e "tests/run_${named}_tests.gd" ]; then echo "ERROR: split $named: no tests/run_${named}_tests.gd" >&2; exit 1; fi
done
if [ -z "$rows" ]; then
	echo "ERROR: no tests/run_*_tests.gd suites" >&2
	exit 1
fi
shards=$(awk '$1 == "shards" {print $2}' "$TIMINGS" 2> /dev/null | head -1)
lanes=$(awk '$1 == "lanes" {print $2}' "$TIMINGS" 2> /dev/null | head -1)

# Each shard runs `lanes` suites at once (tools/run_tests.sh LANES), so the suites are packed into
# shards x lanes bins, longest first into the lightest bin; bin k belongs to shard ((k-1) mod shards)+1,
# which puts the longest suites in different shards, and a shard's pool starts its longest suite first,
# so no shard waits on a long suite started last.
printf '%s' "$rows" | sort -k2,2nr -k1,1 | awk -v n="${shards:-1}" -v lanes="${lanes:-1}" -v mode="$mode" '
	{ name[NR] = $1; secs[NR] = $2 }
	END {
		if (n < 1) n = 1
		if (lanes < 1) lanes = 1
		if (n > NR) n = NR
		bins = n * lanes
		for (i = 1; i <= NR; i++) {
			best = 1
			for (j = 2; j <= bins; j++) if (load[j] < load[best]) best = j
			load[best] += secs[i]
			sh = (best - 1) % n + 1
			list[sh] = list[sh] (list[sh] == "" ? "" : " ") name[i]
		}
		for (j = 1; j <= bins; j++) {
			sh = (j - 1) % n + 1
			if (load[j] > longest[sh]) longest[sh] = load[j]
		}
		if (mode == "--matrix") {
			out = "{\"include\":["
			for (j = 1; j <= n; j++) out = out (j > 1 ? "," : "") "{\"shard\":\"" j "\",\"lanes\":\"" lanes "\",\"suites\":\"" list[j] "\"}"
			print out "]}"
		} else {
			for (j = 1; j <= n; j++) printf "shard %d (~%ds%s): %s\n", j, longest[j], (lanes > 1 ? sprintf(", %d lanes", lanes) : ""), list[j]
		}
	}'
