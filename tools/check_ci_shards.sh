#!/usr/bin/env bash
# Checks that tools/ci_shards.txt runs every suite in tools/run_tests.sh exactly
# once, and no suite that does not exist. CI runs it first (the "plan" job).
#
#   tools/check_ci_shards.sh            # check, print what is wrong, exit 1 if so
#   tools/check_ci_shards.sh --matrix   # check, then print the GitHub matrix as JSON
set -u
mode="${1:-}"   # the loop below reuses the positional parameters
cd "$(dirname "$0")/.." || exit 1

SHARDS="${SHARDS_FILE:-tools/ci_shards.txt}"
RUNNER="${RUNNER_FILE:-tools/run_tests.sh}"

all=$(sed -n 's/^ALL_SUITES=(\(.*\))[[:space:]]*$/\1/p' "$RUNNER")
if [ -z "$all" ]; then
	echo "ERROR: no ALL_SUITES list found in $RUNNER" >&2
	exit 1
fi

bad=0
declare -A seen=()
shard_ids=()
suites_of=()
while IFS= read -r line; do
	case "$line" in ''|'#'*) continue ;; esac
	id="${line%%:*}"
	list="${line#*:}"
	if ! [[ "$id" =~ ^[0-9]+$ ]] || [ "$id" = "$line" ]; then
		echo "ERROR: $SHARDS: not 'N: suite suite ...': $line" >&2
		bad=1
		continue
	fi
	# shellcheck disable=SC2086
	set -- $list
	if [ "$#" -eq 0 ]; then
		echo "ERROR: $SHARDS: shard $id has no suites" >&2
		bad=1
		continue
	fi
	for s in "$@"; do
		if ! [[ " $all " == *" $s "* ]]; then
			echo "ERROR: $SHARDS: shard $id runs '$s', which is not in ALL_SUITES of $RUNNER" >&2
			bad=1
		elif [ -n "${seen[$s]:-}" ]; then
			echo "ERROR: $SHARDS: '$s' is in shard ${seen[$s]} and shard $id" >&2
			bad=1
		else
			seen[$s]="$id"
		fi
	done
	shard_ids+=("$id")
	suites_of+=("$list")
done < "$SHARDS"

for s in $all; do
	if [ -z "${seen[$s]:-}" ]; then
		echo "ERROR: suite '$s' is in ALL_SUITES but in no CI shard: add it to $SHARDS" >&2
		bad=1
	fi
done
[ "${#shard_ids[@]}" -gt 0 ] || { echo "ERROR: $SHARDS has no shards" >&2; bad=1; }
[ "$bad" = 0 ] || exit 1

if [ "$mode" = "--matrix" ]; then
	out='{"include":['
	for i in "${!shard_ids[@]}"; do
		suites=$(echo "${suites_of[$i]}" | xargs)
		[ "$i" -gt 0 ] && out+=','
		out+="{\"shard\":\"${shard_ids[$i]}\",\"suites\":\"$suites\"}"
	done
	echo "$out]}"
else
	echo "ok: ${#seen[@]} suites in ${#shard_ids[@]} shards, each exactly once"
fi
