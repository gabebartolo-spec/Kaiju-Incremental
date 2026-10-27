#!/usr/bin/env bash
# A pull request or a push to main skips its re-test when a green workflow_dispatch run already tested the exact same
# tree (D-319: a builder's finished change runs the full check on GitHub first, through C:/kt/gh_check.sh, before its
# PR is marked ready; without this the PR and then main would run the same suites twice more).
# Usage (tests.yml plan job, GH_TOKEN and GITHUB_REPOSITORY set, fetch-depth 0):
#   tools/ci_reuse_dispatch_run.sh <commit under test> <PR head sha>
# Prints "reuse <run id>" when ALL of these hold, else prints nothing and the caller runs the tests:
#   - the commit under test has the same tree as the PR head (the head already holds current main, so merging it
#     changes nothing);
#   - a tests.yml workflow_dispatch run on that head finished green with every shard green (not skipped).
# Same tree means the same files, workflows included, so the dispatch run tested exactly what this run would.
# Any doubt (missing commit, API error) prints nothing: a re-test is the safe answer.
set -u
tested="${1:-}"
head="${2:-}"
repo="${GITHUB_REPOSITORY:?}"
[ -n "$tested" ] && [ -n "$head" ] || exit 0
t1=$(git rev-parse -q --verify "$tested^{tree}" 2> /dev/null) || exit 0
# the head's tree from the API: after a merge GitHub deletes the branch, so the head may not be in the checkout
t2=$(gh api "repos/$repo/commits/$head" --jq '.commit.tree.sha' 2> /dev/null) || exit 0
[ "$t1" = "$t2" ] || exit 0
run=$(gh api "repos/$repo/actions/workflows/tests.yml/runs?head_sha=$head&event=workflow_dispatch&per_page=10" \
	--jq '[.workflow_runs[] | select(.status == "completed" and .conclusion == "success")] | sort_by(.created_at) | last | .id // empty' 2> /dev/null) || exit 0
[ -n "$run" ] || exit 0
shards=$(gh api "repos/$repo/actions/runs/$run/jobs?per_page=50" \
	--jq '[.jobs[] | select(.name | startswith("shard"))] | if length > 0 and all(.conclusion == "success") then "ok" else "no" end' 2> /dev/null) || exit 0
[ "$shards" = ok ] || exit 0
echo "reuse $run"
