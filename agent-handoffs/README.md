# Agent handoffs

One file per task (sessions and subagents alike: `lead.md`, `rubble-break.md`, ...), cap 120 lines, rewritten not
appended, on the task's branch so it travels with the PR. It is the task's ONLY state file (director 2026-10-21):
lead.md, STATUS.md and notes folders point to it, never copy it. When the task ends or goes stale (no update for 2 days
and no live branch), the lead moves it to `archive/`. The `kaiju-handoff` skill says what goes
in it. The user-level Stop hook blocks a turn that changed the project without a fresh handoff.

```
# <Role> handoff, <date> <time>
## State: working | running a check | awaiting director | blocked | available
## Task
## Branch and commit
## Unfinished changes
## Evidence so far
## Attempts (fix-loop record)
## Open decisions
## Running jobs
## Findings for the lead
(what helped or caught a defect this task, with evidence, or "none"; the lead records the worthwhile
ones in ~/.claude/memory-shared/co-lead-playbook.md. Leads write "playbook: updated" or "nothing new")
## Rules learnt the hard way (under 10 lines)
```
