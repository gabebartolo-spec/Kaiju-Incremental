# Learnings log (kaiju-godot-tests)

Only findings that proved effective on Kaiju Incremental: a method that caught or prevented a real
defect, a recurring failure whose fix was verified (test, capture or green CI), or a measured
time saving. Each entry: `## YYYY-MM-DD · topic`, then **Finding**, **Evidence** (PR, commit, run
id, capture), **Lesson**. If a finding contradicts SKILL.md, fix SKILL.md instead of appending;
mark entries "promoted" once moved into it. A lesson that is true for every project goes to the
general skill's log instead (github-hygiene, game-architecture, art-qa-critic, ask-the-director,
ai-game-dev-playbook in ~/.claude/skills).

## 2026-10-23 · pkill in Git Bash can't stop Windows Godot runs
**Finding:** a builder ran `pkill -f probe_mil8` to stop its own probes. Git Bash's pkill can't see native Windows
processes, so two runs sat hung for 30 minutes at 0 CPU until the lead stopped them by PID (wrappers and children).
**Evidence:** lead stall watcher 2026-10-23 07:35 (PIDs 19068/34260 and 31776/29388).
**Lesson:** record the PID your own run starts (wrapper and child), stop it with
`powershell Stop-Process -Id <pid>`, and check it's gone. Never kill by name or pattern, which the rulebook bans
anyway.

## 2026-10-23 · A wait loop must match the suite's summary line, not "passed|FAILED"
**Finding:** a VFX builder waited on a helideaths run with `until grep -qE "passed|FAILED|Some checks" <log>`. The
run ended with "1 failures" (lower case, no "FAILED"), so the loop never ended and sat 90 minutes until the lead's
stall watcher flagged it as a stale loop.
**Evidence:** lead stall watcher 2026-10-23 14:55 (staleloop PIDs 6516/27388); helideaths run 13:27.
**Lesson:** wait on the runner's own summary line (`grep -qE "tests: [0-9]+ checks, [0-9]+ failures"`) or on the
process exiting (its PID), never on words that only one outcome prints; and give every wait loop a time limit.
