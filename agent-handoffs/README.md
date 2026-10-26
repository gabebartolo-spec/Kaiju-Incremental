# Agent handoffs (moved)

Handoffs no longer live in this repo (director 2026-10-25: a regen lead could not find its handoff among stale copies
on main and a dozen branches). One copy per role, outside git, shared by both Claude accounts:
`C:/Users/DANTE/.claude/handoffs/kaiju/<role>.md` (finished or stale roles: `archive/` there). Cap 120 lines, edited
not appended, written with Write/Edit, never committed. The SessionStart hook lists them in every session (from any
folder it names the lead's file); the Stop hook blocks a turn that changed the project without updating yours. The
`kaiju-handoff` skill says what goes in it. Skeleton:

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
