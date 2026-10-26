#!/usr/bin/env bash
# merge_on_green.sh: squash-merge a PR only when every check is green at the exact head commit you name.
#
# Usage: tools/gh/merge_on_green.sh <pr-number> <full-head-sha>      (from any folder inside the repo)
#   POLL=160 seconds between looks (default 160), MAX_LOOKS=30 looks before giving up.
# Stops if the PR head moves off <full-head-sha> (a new push makes an earlier green stale). The merge itself passes
# --match-head-commit, so GitHub refuses it if the head moved in the last second.
# Exit: 0 merged, 1 a check is red, 2 head moved, 3 timed out still pending, 64 bad arguments.
# Only the merge role runs this (kaiju-pr: the lead merges; builders never do).
set -u
pr="${1:-}"
sha="${2:-}"
if [ -z "$pr" ] || [ "${#sha}" -ne 40 ]; then
  echo "usage: tools/gh/merge_on_green.sh <pr-number> <full 40-character head sha>" >&2
  exit 64
fi
cd "$(git rev-parse --show-toplevel)" || exit 64
poll="${POLL:-160}"
looks="${MAX_LOOKS:-30}"
s=""
for _ in $(seq 1 "$looks"); do
  head=$(gh pr view "$pr" --json headRefOid --jq .headRefOid)
  [ -z "$head" ] && { sleep 60; continue; }
  [ "$head" != "$sha" ] && { echo "HEAD MOVED $head"; exit 2; }
  s=$(gh pr view "$pr" --json statusCheckRollup --jq '[.statusCheckRollup[]|(if (.status // "COMPLETED") != "COMPLETED" then "PENDING" elif (.conclusion // "") == "" then (.state // "PENDING") else .conclusion end)]|map(ascii_upcase)|group_by(.)|map("\(.[0])=\(length)")|join(" ")')
  if ! echo "$s" | grep -qE 'PENDING|QUEUED|IN_PROGRESS|^$'; then
    if echo "$s" | grep -qE 'FAILURE|CANCELLED|TIMED_OUT|ERROR'; then echo "RED: $s"; exit 1; fi
    if gh pr merge "$pr" --squash --match-head-commit "$sha"; then echo "MERGED $pr ($s)"; exit 0; fi
    echo "merge refused, waiting"
  fi
  sleep "$poll"
done
echo "TIMEOUT: $s"
exit 3
