# Kaiju Incremental: working rules for every Claude Code session

Godot 4.7.2, GDScript (static typing on). Read this file, then your handoff (`agent-handoffs/<role>.md`), then only the
roadmap section you were assigned (`docs/ROADMAP.md`, by section, never whole). The general
rules every project shares live in `~/.claude/CLAUDE.md` and the skills it names
(`ask-the-director`, `ai-game-dev-playbook`, `github-hygiene`, `game-architecture`,
`art-qa-critic`); this file holds only what is true for Kaiju Incremental.

## Philosophy (permanent)

**Designed by a person, developed with AI, never designed by AI.** The director supplies vision,
taste and final judgement. Agents supply execution, evidence and honest pushback.

- **You are the disaster: every rampage must feel bigger than the last.** Every system is judged by whether it serves that. A system that does not change
  what the player sees, decides or remembers is cut, not polished.
- **A roadmap item is context, not authorisation.** Start only what `docs/STATUS.md` lists as
  assigned. When an assigned task is done: stop, report with evidence, recommend the next step, wait.
- **Simplest viable option first.** Fewer systems, fewer numbers, fewer files. Challenge
  over-ambitious items and say what the simpler alternative is.
- **Challenge the director** when a request conflicts with these rules or `docs/VISION.md`. One
  paragraph, a better option, then do what the director decides.
- **Ask, don't ponder.** A judgement call that is the director's is asked at once, the
  `ask-the-director` way. Never park a question in a wall of text; never guess at a visual.

## Hard rules

1. **No runtime AI.** No LLM, diffusion or network model in the shipped game. AI is a
   development tool only.
2. **Determinism.** Every simulation path is seeded and replayable. A test that uses the clock is
   a bug; a flaky test is a seed to pin, not a rerun.
3. **Sim is the authority.** `sim/` has no Node, Scene or UI dependency and runs headless.
   Presentation reads sim events; it never decides outcomes.
4. **Data, not code, holds content and balance** (`data/`, schema-validated). Magic numbers in
   code are rejected in review.
5. **Licensing.** Nothing enters `assets/` or `tools/` unless `docs/LICENSING_REGISTER.md` lists
   it as CLEARED. Free and commercially usable only.
6. **No spend** without the director's written yes in `docs/DECISIONS.md`.
7. **Proof before "done".** A change is done when its evidence is in the PR body. "It works" is
   not evidence; what the game did is.
8. **Change method after two failed fixes.** Gather different evidence and rethink.

## Machine rules (shared PC, one GPU)

- One Godot process per agent; isolate every run (`tools/run_tests.sh` does; a direct run sets
  `APPDATA=<your scratch dir>`). Never kill Godot by image name; kill by the PID you recorded.
- GPU jobs (renders, generation, local models) one at a time; the art role owns them.
- Worktrees: `git worktree add -b claude/<topic> ../Kaiju-Incremental-wt/<topic> origin/main`. Remove
  the worktree when the PR merges. More than four live worktrees is a violation.
- Only the merge role edits `docs/STATUS.md` and `docs/DECISIONS.md`, in a docs-only board PR
  after each merge; every other PR states its board and log changes in its body.
- Stage files by name, never `git add -A`; never `git stash`; revert `.import` churn.
- Windowed Godot or Blender runs never steal the director's focus (no_focus override.cfg,
  `blender -b`, captures on CI).

## Sessions and context

- Fresh session at every task boundary; write `agent-handoffs/<role>.md` first (120-line cap,
  rewrite not append). Routine work at 50-100k tokens; past 150k, hand off.
- End every turn with your state: working, running a check, awaiting director, blocked, available.

## Skills

Project skills live in `.claude/skills/kaiju-*` and extend the general ones; each has a
`references/learnings.md` with the evidence bar from `~/.claude/CLAUDE.md`. General lessons go
to the general skill's log so every project benefits.
