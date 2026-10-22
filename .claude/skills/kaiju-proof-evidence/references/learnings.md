# Learnings log (kaiju-proof-evidence)

Only findings that proved effective on Kaiju Incremental: a method that caught or prevented a real
defect, a recurring failure whose fix was verified (test, capture or green CI), or a measured
time saving. Each entry: `## YYYY-MM-DD · topic`, then **Finding**, **Evidence** (PR, commit, run
id, capture), **Lesson**. If a finding contradicts SKILL.md, fix SKILL.md instead of appending;
mark entries "promoted" once moved into it. A lesson that is true for every project goes to the
general skill's log instead (github-hygiene, game-architecture, art-qa-critic, ask-the-director,
ai-game-dev-playbook in ~/.claude/skills).

## 2026-10-23 · Capture scripts must hand their own sim events to the view
**Finding:** a capture script that creates sim events between its own sim steps (a helicopter shot down on cue)
never reaches the view, because the view reads events from the rampage's step, so the burning helicopter was
missing from the stills while the sim counted the kill.
**Evidence:** VFX lead, heli deaths, claude/heli-deaths 9b947478 (stills fixed in the same branch; touched suites
helideaths, tentacles, military and powers green).
**Lesson:** when a capture script injects or forces sim events, pass those events to the view's event handler
itself, and check in the still that the thing the event should show is actually on screen.
