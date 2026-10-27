# Kaiju Incremental: working rules for every Claude Code session

Godot 4.7.2, GDScript (static typing on). Read this file, then `docs/DESIGN.md` in full (the one design document),
then your handoff (`~/.claude/handoffs/kaiju/<role>.md`, outside git), then only your assigned `docs/ROADMAP.md` section (never whole).
Shared rules: `~/.claude/CLAUDE.md` and its rulebook; this file holds only what is true for Kaiju Incremental.

## Philosophy
- **Designed by a person, developed with AI, never designed by AI.** **You are the disaster: every rampage must feel
  bigger than the last**; a system that does not change what the player sees, decides or remembers is cut.
- A roadmap item is context, not authorisation: start only what your lead (or the director) assigns; when done,
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
7. **Proof before "done":** the evidence (what the game did) is in the PR body.
8. **Change method after two failed fixes.**

## Machine and repo (project detail on the rulebook)
- Captures and clips render on the local GPU (RTX 4070 SUPER) always, even while he games, in a no_focus
  override.cfg window (it may show on his screen so he can watch, 2026-10-26; it never steals focus; `blender -b`), ONE
  Godot window at a time PC-wide via `bash C:/kt/gpu_slot.sh <command>` (D-340, hook-enforced; headless runs need no
  slot), until he says pause (2026-10-21, comment #41).
  CI captures (`tools/capture/ci_capture.sh`, xvfb, software: ~25-35 min a clip) only for gl_compatibility checks or
  while paused. GPU jobs share the card by VRAM budget (rulebook: Machine and screen).
- No speed runs in the day (D-331): while `C:/kt/SPEED_DAY_HOLD` exists the tool-gate hook refuses them; the lead
  deletes it when the director says he is done for the day, 01:00 at the latest, then runs `C:/kt/NIGHT_QUEUE.txt` one
  line at a time (D-333). Builders, Cascadeur, suites, captures and builds run freely in the day.
- Speed runs get the PC to themselves (D-299): while a `C:/kt/BENCH_WINDOW_<owner>` under 20 min old exists, start no
  Godot (headless included); run it behind `bash C:/kt/wait_window.sh && <command>`. The tool-gate hook refuses
  otherwise; a run that saw another Godot (`others>0`) is void, and so is one taken while League is in a game.
  `~/.claude/focus-pause` (his pause) stops every Godot start until it is gone.
- Resolution (D-339, Kaiju only): 1080p is the baseline. Text, look and the 60 fps Medium bar are judged at 1080p;
  stills and clips for him are 1080p; 4K is checked at each playtest build. Replaces the rulebook's 4K-first check.
- Tests: `tools/run_tests.sh` isolates APPDATA; a direct run sets `APPDATA=<your scratch dir>`.
- Worktrees: `git worktree add -b claude/<topic> ../Kaiju-Incremental-wt/<topic> origin/main`; remove
  when the PR merges; `tools/lint/worktrees.sh` flags merged and idle ones (D-053). Revert `.import` churn.
- Only the lead edits `docs/DECISIONS.md` and `docs/DESIGN.md`; `docs/STATUS.md` is generated (`python tools/status.py`,
  never by hand) after merges. Other PRs state their
  board and log changes in the body.

## Skills
`.claude/skills/kaiju-*` extend the general skills; each has a `references/learnings.md` (evidence bar in
`~/.claude/CLAUDE.md`). General lessons go to the general skill's log.
