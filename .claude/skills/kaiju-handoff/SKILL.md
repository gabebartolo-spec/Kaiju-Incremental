---
name: kaiju-handoff
description: Writing and starting from a Kaiju Incremental agent handoff - the file ~/.claude/handoffs/kaiju/ROLE.md outside git that lets a fresh session continue without the old transcript, its 120-line cap, edited not appended, and when to hand off. Use it when a task is done or you switch to unrelated work, when a session's context nears its 260k auto-compact, before the director restarts or clears a session, and at the start of any new session.
---

# Handoffs

Fresh session at every task boundary for a lead; every session auto-compacts at 260k and keeps its handoff and commits current at each milestone (rulebook "Context and handoff").
Write the handoff first, then start the new session from it.
A helper (builder, subagent) never stops or hands off for context size: it auto-compacts and keeps its
handoff and commits current at each milestone. The lead respawns one with the same name from its handoff only if
it cannot compact or drifts after compacting (director 2026-10-21). A top-level session
starts its own successor only when safe (nothing of its own running, no half-done push or merge,
no unanswered director question), gives it the same title, and archives itself. The user-level Stop hook blocks a turn
that changed the project without a fresh handoff; write it, never ask the director to remind you.

## Where

`~/.claude/handoffs/kaiju/<role>.md`: ONE copy per role, outside git, shared by both Claude accounts, so it is
never on a branch and never stale on main (director 2026-10-25, after a regen lead could not find its handoff).
Cap 120 lines, **edited when state changes, never appended as a log and not rewritten from scratch every turn**.
Write it with Write/Edit; never commit it. Finished or stale roles move to `archive/` in that folder. The
SessionStart hook lists the live ones, and from any folder (even a "No folder" session) it names the lead's file.
The skeleton is `references/handoff-skeleton.md` beside this file; no handoff or brief lives in the repo.

## What it says

State, Task (the STATUS.md item and one sentence), Branch and commit (branch, sha, worktree, PR
or "no PR yet"), Unfinished changes (what is half-done and what done looks like), Evidence so
far, Attempts (the fix-loop record: what was tried for each open bug and why it failed), Open
decisions (question ids, waiting on whom), Running jobs (PIDs, run ids), Findings for the lead (the lead curates them into
~/.claude/memory-shared/co-lead-playbook.md before any refresh), Rules learnt the hard
way (under 10 lines). A decision that exists only in a chat does not exist: once the director
answers, it goes in full under "Board and log" in the PR that acts on it.

## Starting a session from one

Read, in order: the handoff; `CLAUDE.md`; only the roadmap section you were assigned;
`docs/STATUS.md` "Assigned items" and your own row. Then check every PR the handoff names
against GitHub (`gh pr view <n>`) and that the branch tip is the sha written there. Carry on from
"Unfinished changes". With nothing assigned, say "available" and wait.

## Learnings

Proven findings for this project live in `references/learnings.md`.
