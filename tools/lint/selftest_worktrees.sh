#!/usr/bin/env bash
# Planted-defect self-test for tools/lint/worktrees.sh (stale worktrees, no fixed total).
#   A. captured listings + planted facts: fresh worktrees pass, however many; a merged / upstream-gone / idle one is red by rule
#      name; an idle one with a recent staging-area change passes; prunable and out-of-place entries are warnings only.
#   B. a real scratch repo: a fresh branch passes; a branch whose upstream was deleted after its merge, and a squash-merged
#      branch, are red WT-STALE-MERGED; a worktree whose last commit is old is red WT-STALE-IDLE.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
NOW=1800000000
H=3600

expect() { # expect <label> <exit 0|1> <rule-or-empty> <env assignments...> -- (runs worktrees.sh with them)
  local label="$1" want="$2" rule="$3" out code
  shift 3
  out="$(env "$@" bash "$here/worktrees.sh" 2>&1)"
  code=$?
  if [ "$code" = "$want" ] && { [ -z "$rule" ] || printf '%s' "$out" | grep -q "$rule"; }; then
    echo "ok: $label${rule:+ -> $rule}"
  else
    echo "FAIL: $label (exit $code, want $want${rule:+ with $rule})"
    echo "$out" | head -8
    fail=1
  fi
}

listing() { # listing <file> <worktree names...>: main + one block per name under Kaiju-Incremental-wt
  local f="$1" n
  shift
  printf 'worktree C:/Users/X/Kaiju Incremental\nHEAD aaa\nbranch refs/heads/main\n\n' > "$f"
  for n in "$@"; do
    printf 'worktree C:/Users/X/Kaiju-Incremental-wt/%s\nHEAD bbb\nbranch refs/heads/claude/%s\n\n' "$n" "$n" >> "$f"
  done
}
fact() { # fact <file> <name> <tip age h> <index age h> <merged> <gone> <dirty>
  printf 'C:/Users/X/Kaiju-Incremental-wt/%s|%s|%s|%s|%s|%s\n' "$2" "$((NOW - $3 * H))" "$((NOW - $4 * H))" "$5" "$6" "$7" >> "$1"
}

# ---- A. planted facts
listing "$tmp/fresh.txt" a b c
: > "$tmp/fresh_facts.txt"
for n in a b c; do fact "$tmp/fresh_facts.txt" $n 2 1 0 0 0; done
expect "fresh worktrees pass" 0 "" WORKTREE_LIST="$tmp/fresh.txt" WORKTREE_FACTS="$tmp/fresh_facts.txt" WT_NOW=$NOW

many=(); for i in $(seq 1 20); do many+=("w$i"); done
listing "$tmp/many.txt" "${many[@]}"
: > "$tmp/many_facts.txt"
for n in "${many[@]}"; do fact "$tmp/many_facts.txt" "$n" 1 1 0 0 0; done
expect "20 fresh worktrees pass (no fixed total)" 0 "" WORKTREE_LIST="$tmp/many.txt" WORKTREE_FACTS="$tmp/many_facts.txt" WT_NOW=$NOW

listing "$tmp/l.txt" a b
: > "$tmp/f.txt"; fact "$tmp/f.txt" a 2 1 1 0 0; fact "$tmp/f.txt" b 2 1 0 0 0
expect "a merged branch" 1 WT-STALE-MERGED WORKTREE_LIST="$tmp/l.txt" WORKTREE_FACTS="$tmp/f.txt" WT_NOW=$NOW

: > "$tmp/f.txt"; fact "$tmp/f.txt" a 2 1 0 1 0; fact "$tmp/f.txt" b 2 1 0 0 0
expect "an upstream-gone branch" 1 WT-STALE-MERGED WORKTREE_LIST="$tmp/l.txt" WORKTREE_FACTS="$tmp/f.txt" WT_NOW=$NOW

: > "$tmp/f.txt"; fact "$tmp/f.txt" a 30 30 0 0 0; fact "$tmp/f.txt" b 2 1 0 0 0
expect "no commit or index change in 30 h" 1 WT-STALE-IDLE WORKTREE_LIST="$tmp/l.txt" WORKTREE_FACTS="$tmp/f.txt" WT_NOW=$NOW

: > "$tmp/f.txt"; fact "$tmp/f.txt" a 30 3 0 0 1; fact "$tmp/f.txt" b 2 1 0 0 0
expect "old commit but staged work an hour ago passes" 0 "" WORKTREE_LIST="$tmp/l.txt" WORKTREE_FACTS="$tmp/f.txt" WT_NOW=$NOW

: > "$tmp/f.txt"; fact "$tmp/f.txt" a 30 30 0 0 1; fact "$tmp/f.txt" b 2 1 0 0 0
expect "an idle dirty worktree says dirty" 1 "dirty" WORKTREE_LIST="$tmp/l.txt" WORKTREE_FACTS="$tmp/f.txt" WT_NOW=$NOW

: > "$tmp/f.txt"; fact "$tmp/f.txt" a 30 30 0 0 0; fact "$tmp/f.txt" b 2 1 0 0 0
expect "STALE_HOURS=48 lets a 30 h one pass" 0 "" WORKTREE_LIST="$tmp/l.txt" WORKTREE_FACTS="$tmp/f.txt" WT_NOW=$NOW STALE_HOURS=48

{
  printf 'worktree C:/Users/X/Kaiju Incremental\nHEAD aaa\nbranch refs/heads/main\n\n'
  printf 'worktree C:/Users/X/Kaiju-Incremental-wt/gone\nHEAD bbb\nprunable gitdir file points to non-existent location\n\n'
  printf 'worktree C:/Elsewhere/odd\nHEAD ccc\nbranch refs/heads/odd\n\n'
} > "$tmp/odd.txt"
expect "prunable and out-of-place entries only warn" 0 "WT-PRUNABLE" WORKTREE_LIST="$tmp/odd.txt" WORKTREE_FACTS=/dev/null WT_NOW=$NOW

# ---- B. a real repo: origin, main clone, worktrees under Kaiju-Incremental-wt
g() { git -c user.name=t -c user.email=t@example.com "$@"; }
origin="$tmp/origin.git"
g init -q --bare -b main "$origin"
mkdir -p "$tmp/real"
main="$tmp/real/Kaiju Incremental"
g clone -q "$origin" "$main" 2> /dev/null
mkdir -p "$main/tools/lint"
cp "$here/worktrees.sh" "$main/tools/lint/"
printf 'one\n' > "$main/a.txt"; printf 'x\n' > "$main/b.txt"
g -C "$main" add -A; g -C "$main" commit -q -m base; g -C "$main" branch -M main; g -C "$main" push -q -u origin main
wtd="$tmp/real/Kaiju-Incremental-wt"; mkdir -p "$wtd"

g -C "$main" worktree add -q -b claude/fresh "$wtd/fresh" origin/main
real() { # real <label> <exit> <rule>
  local out code
  out="$(cd "$main" && bash tools/lint/worktrees.sh 2>&1)"; code=$?
  if [ "$code" = "$2" ] && { [ -z "$3" ] || printf '%s' "$out" | grep -q "$3"; }; then echo "ok: real repo, $1${3:+ -> $3}"; else echo "FAIL: real repo, $1 (exit $code, want $2 $3)"; echo "$out" | head -6; fail=1; fi
}
real "fresh branch from main" 0 ""

# upstream gone: push a branch, delete it on the remote, prune
g -C "$main" worktree add -q -b claude/pushed "$wtd/pushed" origin/main
printf 'two\n' > "$wtd/pushed/a.txt"; g -C "$wtd/pushed" commit -q -am work; g -C "$wtd/pushed" push -q -u origin claude/pushed 2> /dev/null
real "pushed branch, upstream still there" 0 ""
g -C "$main" push -q origin --delete claude/pushed 2> /dev/null; g -C "$main" fetch -q --prune
real "upstream deleted after the merge" 1 WT-STALE-MERGED
g -C "$main" worktree remove --force "$wtd/pushed"; g -C "$main" branch -q -D claude/pushed

# squash-merged: the branch's change lands on main as a different commit
g -C "$main" worktree add -q -b claude/squashed "$wtd/squashed" origin/main
printf 'three\n' > "$wtd/squashed/b.txt"; g -C "$wtd/squashed" commit -q -am squashme
printf 'three\n' > "$main/b.txt"; g -C "$main" commit -q -am "squash of squashme"; g -C "$main" push -q origin main
real "squash-merged branch" 1 WT-STALE-MERGED
g -C "$main" worktree remove --force "$wtd/squashed"; g -C "$main" branch -q -D claude/squashed

# idle: the last commit is old, nothing touched since
g -C "$main" worktree add -q -b claude/old "$wtd/old" origin/main
printf 'four\n' > "$wtd/old/a.txt"
GIT_COMMITTER_DATE="2020-01-01T00:00:00" GIT_AUTHOR_DATE="2020-01-01T00:00:00" g -C "$wtd/old" commit -q -am ancient
touch -d "2020-01-02" "$(git -C "$wtd/old" rev-parse --absolute-git-dir)/index"
real "old commit, index untouched" 1 WT-STALE-IDLE

exit $fail
