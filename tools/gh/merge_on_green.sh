#!/usr/bin/env bash
# merge_on_green.sh: squash-merge a PR only when every check is green at the exact head commit you name, and the head
# merged with current main still passes the cheap gates.
#
# Usage: tools/gh/merge_on_green.sh <pr-number> <full-head-sha>      (from any folder inside the repo)
#        tools/gh/merge_on_green.sh --check <pr-number> <full-head-sha>   (only the fresh-merge check, then exit)
#   POLL=160 seconds between looks (default 160), MAX_LOOKS=30 looks before giving up.
#   BASE=origin/main the branch the fresh-merge check merges into (set it to an old sha to replay a past merge).
# Stops if the PR head moves off <full-head-sha> (a new push makes an earlier green stale). The merge itself passes
# --match-head-commit, so GitHub refuses it if the head moved in the last second.
# Fresh-merge check: CI tests a PR's merge with main as main was when the run started. A PR whose run predates a new
# check on main merges green and turns main red (night 2026-10-27: #240 hit UID-MISSING, #257 broke data schemas).
# So right before merging, the head is merged into current main in a scratch worktree and the cheap gates CI runs on
# that merge (tools/lint/run_all.sh, data schemas, licence register; no Godot) run there; any red stops the merge.
# Exit: 0 merged (or --check passed), 1 a check is red, 2 head moved, 3 timed out still pending, 4 the merge with
# current main fails a cheap gate, 5 the head does not merge cleanly into main, 64 bad arguments.
# Only the merge role runs this (kaiju-pr: the lead merges; builders never do).
set -u
check_only=0
if [ "${1:-}" = "--check" ]; then
  check_only=1
  shift
fi
pr="${1:-}"
sha="${2:-}"
if [ -z "$pr" ] || [ "${#sha}" -ne 40 ]; then
  echo "usage: tools/gh/merge_on_green.sh [--check] <pr-number> <full 40-character head sha>" >&2
  exit 64
fi
cd "$(git rev-parse --show-toplevel)" || exit 64
poll="${POLL:-160}"
looks="${MAX_LOOKS:-30}"
base="${BASE:-origin/main}"
py="${PYTHON:-python}"

fresh_merge_check() { # merges $sha into current $base in a scratch worktree and runs the cheap gates there
  local tmp out rc=0
  git fetch -q origin main "pull/$pr/head" || return 5
  tmp="$(mktemp -d)/fresh"
  GIT_LFS_SKIP_SMUDGE=1 git worktree add -q --detach "$tmp" "$base" || return 5
  if ! git -C "$tmp" -c user.name=merge-check -c user.email=merge-check@localhost \
    merge -q --no-ff --no-edit "$sha" > /dev/null 2>&1; then
    echo "CONFLICT: $sha does not merge cleanly into $base"
    rc=5
  elif ! out="$(cd "$tmp" && bash tools/lint/run_all.sh 2>&1 && "$py" tools/lint/data_schemas.py 2>&1 \
    && "$py" tools/lint/licence_register.py 2>&1)"; then
    echo "STALE GREEN: #$pr merged with $base fails a cheap gate (merge origin/main into the PR and fix it there):"
    printf '%s\n' "$out" | grep -E 'FAIL|ERROR|error|problems|MISSING' | head -12
    rc=4
  else
    echo "fresh merge with $base: cheap gates ok"
  fi
  git worktree remove --force "$tmp" > /dev/null 2>&1
  return $rc
}

if [ "$check_only" = 1 ]; then
  fresh_merge_check
  exit $?
fi

s=""
for _ in $(seq 1 "$looks"); do
  head=$(gh pr view "$pr" --json headRefOid --jq .headRefOid)
  [ -z "$head" ] && { sleep 60; continue; }
  [ "$head" != "$sha" ] && { echo "HEAD MOVED $head"; exit 2; }
  s=$(gh pr view "$pr" --json statusCheckRollup --jq '[.statusCheckRollup[]|(if (.status // "COMPLETED") != "COMPLETED" then "PENDING" elif (.conclusion // "") == "" then (.state // "PENDING") else .conclusion end)]|map(ascii_upcase)|group_by(.)|map("\(.[0])=\(length)")|join(" ")')
  if ! echo "$s" | grep -qE 'PENDING|QUEUED|IN_PROGRESS|^$'; then
    if echo "$s" | grep -qE 'FAILURE|CANCELLED|TIMED_OUT|ERROR'; then echo "RED: $s"; exit 1; fi
    fresh_merge_check || exit $?
    if gh pr merge "$pr" --squash --match-head-commit "$sha"; then echo "MERGED $pr ($s)"; exit 0; fi
    echo "merge refused, waiting"
  fi
  sleep "$poll"
done
echo "TIMEOUT: $s"
exit 3
