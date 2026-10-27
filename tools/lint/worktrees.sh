#!/usr/bin/env bash
# worktrees.sh: guardrail C1, one live worktree per live session (D-053): flags worktrees nobody is using.
#
# D-053's ruling is "one live worktree per live session", and D-296 removed the builder count, so there is no fixed
# total to exceed any more (it was MAX_WORKTREES=12). What this finds is the dead ones, so the lead can prune them.
#
# Reads `git worktree list --porcelain`, or the file named by $WORKTREE_LIST (the self-test feeds it captured
# listings). The first entry is the main worktree. Entries inside <parent directory of main>/Kaiju-Incremental-wt/
# and inside the desktop app's session folder <main>/.claude/worktrees/ are checked. Any other linked worktree is
# listed as a warning but not checked. A prunable entry is a stale registration rather than a live worktree.
#
#   WT-STALE-MERGED  the branch's work is already on origin/main: its upstream is gone (GitHub deletes a merged PR's
#                    branch), or it has commits and the files they changed are identical on origin/main   (error, exit 1)
#   WT-STALE-IDLE    no commit and no staging-area change in the last STALE_HOURS (default 24)             (error, exit 1)
#   WT-UNCOUNTED     a linked worktree anywhere else                                                     (warning)
#   WT-PRUNABLE      a stale registration: run `git worktree prune`                                      (warning)
# A stale worktree with uncommitted changes says "dirty": look at `git status` there before removing it.
# Fix: `git worktree remove <path>` (and `git branch -D <branch>` once it is merged).
#
# Output follows the other lints: <source>:0: [warning ]RULE message, then `ok: ...`.
# Windows paths (C:/...) and POSIX paths both work; Windows paths compare case-blind.
# Test hooks: WORKTREE_LIST (a listing), WORKTREE_FACTS (lines `path|tip epoch|index epoch|merged 0/1|gone 0/1|dirty 0/1`
# instead of asking git), WT_NOW (epoch seconds), BASE_REF (default origin/main), STALE_HOURS.
#
# Usage: bash tools/lint/worktrees.sh

export GIT_OPTIONAL_LOCKS=0 # git status here must not rewrite the index: its age is one of the things measured
STALE_HOURS="${STALE_HOURS:-24}" # a worktree with no commit and no index change for this long is idle
BASE_REF="${BASE_REF:-origin/main}"
WT_DIR_NAME="Kaiju-Incremental-wt"
SESSION_DIR_NAME=".claude/worktrees"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_name="git-worktree-list"
if [ -n "${WORKTREE_LIST:-}" ]; then
  source_name="$(basename -- "$WORKTREE_LIST")"
fi
now="${WT_NOW:-$(date +%s)}"

read_list() {
  if [ -n "${WORKTREE_LIST:-}" ]; then
    cat -- "$WORKTREE_LIST"
  else
    git -C "$repo_root" worktree list --porcelain 2>/dev/null
  fi
}

emit() { # emit <error|warning> <RULE> <message>
  local kind="$1" rule="$2" message="$3" tag=""
  if [ "$kind" = "warning" ]; then
    tag="warning "
  fi
  printf '%s:0: %s%s %s\n' "$source_name" "$tag" "$rule" "$message"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::%s file=%s,line=0::%s %s\n' "$kind" "$source_name" "$rule" "${message//%/%25}"
  fi
}

lower_if_windows() { # Windows paths are case-insensitive, POSIX paths are not
  if [[ "$1" =~ ^[A-Za-z]:/ ]]; then
    printf '%s' "${1,,}"
  else
    printf '%s' "$1"
  fi
}

# facts <path>: prints "tip index merged gone dirty" (epochs, then 0/1 flags) for one worktree.
facts() {
  local path="$1" line tip idx merged=0 gone=0 dirty=0 branch base files gitdir
  if [ -n "${WORKTREE_FACTS:-}" ]; then
    line="$(grep -F -- "$path|" "$WORKTREE_FACTS" | head -n 1)"
    if [ -n "$line" ]; then
      IFS='|' read -r _ tip idx merged gone dirty <<< "$line"
      echo "$tip $idx $merged $gone $dirty"
    else
      echo "$now $now 0 0 0"
    fi
    return
  fi
  tip="$(git -C "$path" log -1 --format=%ct HEAD 2>/dev/null || echo "$now")"
  gitdir="$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null)"
  idx="$(stat -c %Y "$gitdir/index" 2>/dev/null || echo "$tip")"
  if [ -n "$(git -C "$path" status --porcelain --untracked-files=no 2>/dev/null | head -n 1)" ]; then dirty=1; fi
  branch="$(git -C "$path" symbolic-ref --short -q HEAD 2>/dev/null)"
  if [ -n "$branch" ] && [ "$(git -C "$path" for-each-ref --format='%(upstream:track)' "refs/heads/$branch")" = "[gone]" ]; then
    gone=1
  fi
  if git -C "$path" rev-parse -q --verify "$BASE_REF" > /dev/null 2>&1; then
    base="$(git -C "$path" merge-base "$BASE_REF" HEAD 2>/dev/null)"
    if [ -n "$base" ] && [ "$(git -C "$path" rev-list --count "$BASE_REF..HEAD")" -gt 0 ]; then
      files="$(git -C "$path" diff --name-only "$base" HEAD)"
      # the files this branch changed are the same on the base ref: squash-merged (or merged some other way)
      if [ -n "$files" ] && (cd "$path" && printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 git diff --quiet "$BASE_REF" HEAD --); then
        merged=1
      fi
    fi
  fi
  echo "$tip $idx $merged $gone $dirty"
}

# Parse the porcelain listing: one block per worktree, blocks separated by a blank line.
paths=()
prunable=()
branches=()
current=""
current_prune=""
current_branch=""

flush_entry() {
  if [ -n "$current" ]; then
    paths+=("$current")
    prunable+=("$current_prune")
    branches+=("$current_branch")
  fi
  current=""
  current_prune=""
  current_branch=""
}

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in
    "worktree "*)
      flush_entry
      current="${line#worktree }"
      current="${current//\\//}"
      current="${current%/}"
      ;;
    "branch "*)
      current_branch="${line#branch refs/heads/}"
      ;;
    detached)
      current_branch="(detached)"
      ;;
    prunable*)
      current_prune="${line#prunable}"
      current_prune="${current_prune# }"
      current_prune="${current_prune:-stale entry}"
      ;;
    "") flush_entry ;;
  esac
done < <(read_list)
flush_entry

if [ "${#paths[@]}" -eq 0 ]; then
  echo "ok: no worktree list available (not a git checkout?), nothing to check"
  exit 0
fi

main_path="${paths[0]}"
wt_dir="${main_path%/*}/$WT_DIR_NAME"
prefix="$(lower_if_windows "$wt_dir/")"

session_dir="$main_path/$SESSION_DIR_NAME"
session_prefix="$(lower_if_windows "$session_dir/")"

limit=$((STALE_HOURS * 3600))
checked=0
stale=0
for ((i = 1; i < ${#paths[@]}; i++)); do
  path="${paths[i]}"
  key="$(lower_if_windows "$path")"
  if [ -n "${prunable[i]}" ]; then
    emit warning WT-PRUNABLE "$path is stale (${prunable[i]}); run: git worktree prune"
    continue
  fi
  if [[ "$key" == "$prefix"* ]]; then
    name="$WT_DIR_NAME/${path:${#prefix}}"
  elif [[ "$key" == "$session_prefix"* ]]; then
    name="$SESSION_DIR_NAME/${path:${#session_prefix}}"
  else
    emit warning WT-UNCOUNTED "$path is a linked worktree outside $wt_dir and $session_dir (not checked)"
    continue
  fi
  checked=$((checked + 1))
  read -r tip idx merged gone dirty <<< "$(facts "$path")"
  note="${branches[i]:+ (branch ${branches[i]})}"
  [ "$dirty" = 1 ] && note="$note, dirty: has uncommitted changes, check git status first"
  newest=$tip
  [ "$idx" -gt "$newest" ] && newest=$idx
  idle_hours=$(((now - newest) / 3600))
  if [ "$gone" = 1 ]; then
    emit error WT-STALE-MERGED "$name$note: its upstream branch is gone (merged and deleted on GitHub). Remove it: git worktree remove $path"
    stale=$((stale + 1))
  elif [ "$merged" = 1 ]; then
    emit error WT-STALE-MERGED "$name$note: its changes are already on $BASE_REF. Remove it: git worktree remove $path"
    stale=$((stale + 1))
  elif [ $((now - newest)) -gt "$limit" ]; then
    emit error WT-STALE-IDLE "$name$note: no commit or staging-area change for ${idle_hours} h (limit $STALE_HOURS h). Remove it, or commit and say who is using it: git worktree remove $path"
    stale=$((stale + 1))
  fi
done

if [ "$stale" -gt 0 ]; then
  echo "$stale of $checked worktrees are stale (D-053: one live worktree per live session). Tell the merge role to prune them."
  exit 1
fi
echo "ok: $checked live worktrees ($WT_DIR_NAME and $SESSION_DIR_NAME), none merged or idle over $STALE_HOURS h"
