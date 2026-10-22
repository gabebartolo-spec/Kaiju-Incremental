# Kaiju Incremental: working rules for every Claude Code session

Godot 4.7.2, GDScript (static typing on). Read this file, then your handoff (`agent-handoffs/<role>.md`), then the core
docs this file imports ("Always loaded" below; they load in full automatically). The general
rules every project shares live in `~/.claude/CLAUDE.md` and the skills it names
(`ask-the-director`, `ai-game-dev-playbook`, `github-hygiene`, `game-architecture`,
`art-qa-critic`); this file holds only what is true for Kaiju Incremental.

## Always loaded

Claude Code imports these core documents in full at every session start (the `@` lines below),
so they are part of this file: read them as rules, never skim or skip them.

@docs/VISION.md
@docs/ROADMAP.md
@docs/STATUS.md

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

- Isolate every Godot run (`tools/run_tests.sh` does; a direct run sets
  `APPDATA=<your scratch dir>`).
- The art role owns GPU jobs (renders, generation, local models).
- Worktrees: `git worktree add -b claude/<topic> ../Kaiju-Incremental-wt/<topic> origin/main`. Remove
  the worktree when the PR merges. More than four live worktrees is a violation.
- Only the merge role edits `docs/STATUS.md` and `docs/DECISIONS.md`, in a docs-only board PR
  after each merge; every other PR states its board and log changes in its body.
- Revert `.import` churn before committing.

## Sessions and context

Handoffs live in `agent-handoffs/<role>.md`.

## Skills

Project skills live in `.claude/skills/kaiju-*` and extend the general ones; each keeps a
`references/learnings.md`.
