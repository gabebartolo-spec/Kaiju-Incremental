# Kaiju Incremental: working rules for every Claude Code session

Godot 4.7.2, GDScript (static typing on). Read this file, your handoff (`~/.claude/handoffs/kaiju/<role>.md`, outside git), the
`docs/DESIGN.md` sections your task changes or relies on, the `docs/ROADMAP.md` index and only the rows your task names;
grep the rest. No read-receipt message.
Shared rules: `~/.claude/CLAUDE.md`; this file holds only what is true for Kaiju Incremental.

## Philosophy
- **Designed by a person, developed with AI, never designed by AI.** **You are the disaster: every rampage must feel
  bigger than the last**; a system that does not change what the player sees, decides or remembers is cut.
- A roadmap item is context, not authorisation: start only what the director assigns (no roles since 2026-10-29); when done,
  stop, report with evidence, recommend the next step.
- Simplest viable option first (fewer systems, numbers, files). Challenge the director when a request conflicts with
  these rules or DESIGN.md: one paragraph, a better option, then do what he decides. Ask his judgement calls at once,
  the `ask-the-director` way; never guess at a visual.

## Hard rules
1. **No runtime AI:** no LLM, diffusion or network model in the shipped game.
2. **Determinism:** every sim path seeded and replayable; a clock in a test is a bug; a flaky test is a seed to pin.
3. **Sim is the authority:** `sim/` has no Node, Scene or UI dependency and runs headless; presentation reads sim
   events and never decides outcomes.
4. **Data holds content and balance** (`data/`, schema-validated); magic numbers in code are rejected.
5. **Licensing:** nothing enters `assets/` or `tools/` unless `docs/LICENSING_REGISTER.md` lists it CLEARED.
6. **No spend** without the director's written yes in `docs/DECISIONS.md`.
7. **Proof before "done":** the evidence (what the game did) is in the PR body; a new system or rule adds a player-effect
   fixture (on vs off), a bug fix or tuning change the test that shows it fixed.
8. **Change method after two failed fixes.**

## Machine and repo
- Windowed Godot runs go through `bash C:/kt/gpu_slot.sh <command>` (D-376); speed runs only at night (D-331) and
  alone on the PC (D-299). The focus and tool-gate hooks enforce these and their refusal says what to do.
- Resolution (D-339, Kaiju only): 1080p is the baseline. Text, look and the 60 fps Medium bar are judged at 1080p;
  stills and clips for him are 1080p; 4K is checked at each playtest build. Replaces the rulebook's 4K-first check.
- Tests (D-403, relaxes D-383): before a push, run the suites nearest the change: `python tools/run_touched.py`
  (`--list` to see them). A PR runs lints + sim suites; engine suites (`engine` in tools/ci_timings.txt) run on main.
  `tools/run_tests.sh` isolates APPDATA; a direct run sets `APPDATA=<your scratch dir>`.
- Worktrees: `git worktree add -b claude/<topic> ../Kaiju-Incremental-wt/<topic> origin/main`; remove
  when the PR merges; `tools/lint/worktrees.sh` flags merged and idle ones (D-053). Revert `.import` churn.
- A decision goes into `docs/DECISIONS.md` in the PR that acts on it, when the director has ruled (any PR may carry it);
  the same PR edits `docs/DESIGN.md` if the ruling changes what the game is. `docs/STATUS.md` is generated
  (`python tools/status.py`, never by hand) after merges. Main requires checks, so no direct push and no separate board
  PR: pure log/status updates ride in the next PR (docs-only, no Godot jobs).
