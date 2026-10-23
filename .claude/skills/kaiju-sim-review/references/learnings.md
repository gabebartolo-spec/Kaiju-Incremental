# Learnings log (kaiju-sim-review)

Only findings that proved effective on Kaiju Incremental: a method that caught or prevented a real
defect, a recurring failure whose fix was verified (test, capture or green CI), or a measured
time saving. Each entry: `## YYYY-MM-DD · topic`, then **Finding**, **Evidence** (PR, commit, run
id, capture), **Lesson**. If a finding contradicts SKILL.md, fix SKILL.md instead of appending;
mark entries "promoted" once moved into it. A lesson that is true for every project goes to the
general skill's log instead (github-hygiene, game-architecture, art-qa-critic, ask-the-director,
ai-game-dev-playbook in ~/.claude/skills).

## 2026-10-23 · Two open PRs claimed the same save version
**Finding:** PR #164 (three growth steps, evolve3 refund) and PR #165 (demo end, new demo keys) were briefed in
parallel and both bumped SaveFile.VERSION from 2 to 3. Both went DIRTY in save_file.gd once the base moved, and
whichever merged second would have skipped the other's migration for saves already at v3.
**Evidence:** GitHub helper report after #161 merged (c19c7f4c); the lead assigned v3 to #164 and v4 to #165.
**Lesson:** the lead reserves the next save version number per PR in the brief. Each migration is its own
`if version < N` step with its own old-save fixture, and the PR that merges second rechecks the whole chain.
