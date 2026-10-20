#!/usr/bin/env bash
# Main skips its re-test when the tree it just got is the tree a green PR run already
# tested (director 2026-10-19, github-hygiene §4). Run by the tests.yml plan job on a push
# to main, with GH_TOKEN, GITHUB_REPOSITORY and the checkout at the pushed commit
# (fetch-depth 0). Prints "reuse <pr number>" when ALL of these hold, else prints nothing
# and the caller runs the tests:
#   - the commit came from a pull request, whose merge ref (refs/pull/N/merge) is still
#     fetchable;
#   - the merge ref has the same tree as the pushed commit, and its first parent is the
#     commit main was at before this push (so the PR was tested on today's base);
#   - the PR's last tests.yml run on its head commit succeeded with every shard green
#     (not skipped), and started after that base commit existed.
# Any doubt (no PR, missing ref, API error) prints nothing: a re-test is the safe answer.
set -u
sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"
repo="${GITHUB_REPOSITORY:?}"
pr=$(gh api "repos/$repo/commits/$sha/pulls" --jq '.[0].number // empty' 2> /dev/null) || exit 0
[ -n "$pr" ] || exit 0
git fetch -q origin "refs/pull/$pr/merge" 2> /dev/null || exit 0
merge=$(git rev-parse FETCH_HEAD)
[ "$(git rev-parse "$merge^{tree}")" = "$(git rev-parse "$sha^{tree}")" ] || exit 0
[ "$(git rev-parse "$merge^1")" = "$(git rev-parse "$sha^1")" ] || exit 0
head=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha 2> /dev/null) || exit 0
run=$(gh api "repos/$repo/actions/workflows/tests.yml/runs?head_sha=$head&event=pull_request&per_page=5" \
	--jq '[.workflow_runs[] | select(.status == "completed")] | sort_by(.created_at) | last | [.id, .conclusion, .created_at] | @tsv' 2> /dev/null) || exit 0
read -r run_id conclusion created <<< "$run"
[ "${conclusion:-}" = success ] || exit 0
shards=$(gh api "repos/$repo/actions/runs/$run_id/jobs?per_page=50" \
	--jq '[.jobs[] | select(.name | startswith("shard"))] | if length > 0 and all(.conclusion == "success") then "ok" else "no" end' 2> /dev/null) || exit 0
[ "$shards" = ok ] || exit 0
base_time=$(git log -1 --format=%cI "$sha^1")
[ "$(date -d "$created" +%s)" -gt "$(date -d "$base_time" +%s)" ] || exit 0
echo "reuse $pr"
