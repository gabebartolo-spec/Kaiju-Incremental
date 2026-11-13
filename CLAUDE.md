# Kaiju Incremental: working rules for every Claude Code session

Unity 6000.3 HDRP, C# (D-470, D-471). Godot was retired at U6 (D-484): its last main is tag `godot-final` and branch
`archive/godot-final`; read it there, never restore it to main. Read this file, your worktree's handoff (one file in `~/.claude/handoffs/`, named by the SessionStart hook, outside git), the
`docs/DESIGN.md` sections your task changes or relies on, the `docs/ROADMAP.md` index and only the rows your task names;
grep the rest. No read-receipt message.
Shared rules: `~/.claude/CLAUDE.md`; this file holds only what is true for Kaiju Incremental.

## Philosophy
- **Designed by a person, developed with AI, never designed by AI.** **You are the disaster: every rampage must feel
  bigger than the last**; a system that does not change what the player sees, decides or remembers is cut.
- A roadmap item is context, not authorisation: start only what the director assigns (no roles since 2026-10-29); when done,
  stop, report with evidence, recommend the next step.
- Simplest viable option first (fewer systems, numbers, files). Challenge the director when a request conflicts with
  these rules or DESIGN.md: one paragraph, a better option, then do what the director decides. Ask the director's judgement calls at once:
  show the thing and ask directly (AskUserQuestion or the closing question); never guess at a visual.

## Hard rules
1. **No runtime AI:** no LLM, diffusion or network model in the shipped game.
2. **Determinism:** every sim path seeded and replayable; a clock in a test is a bug; a flaky test is a seed to pin.
3. **Sim is the authority:** `unity/Assets/Scripts/Sim/` has no UnityEngine reference and runs headless under dotnet
   (`unity/SimTests`); presentation reads sim events and never decides outcomes. Its golden logs are frozen from
   Godot: a change that alters a log is a design change and needs the director's ruling.
4. **Data holds content and balance** (`data/`, schema-validated); magic numbers in code are rejected.
5. **Licensing:** nothing enters `assets/` or `tools/` unless `docs/LICENSING_REGISTER.md` lists it CLEARED.
6. **No spend** without the director's written yes in `docs/DECISIONS.md`.
7. **Proof before "done":** the evidence (what the game did) is in the PR body; a new system or rule adds a player-effect
   fixture (on vs off), a bug fix or tuning change the test that shows it fixed.
8. **Change method after two failed fixes.**

## Machine and repo
- Windowed Unity runs (the editor, a player build) go through `bash C:/kt/gpu_slot.sh <command>` (D-376); speed runs
  only at night (D-331) and alone on the PC (D-299). The focus and tool-gate hooks enforce these and their refusal
  says what to do.
- Resolution (D-339, Kaiju only): 1080p is the baseline. Text, look and the 60 fps Medium bar are judged at 1080p;
  stills and clips for the director are 1080p; 4K is checked at each playtest build.
- Tests (D-403): before a push, `python tools/run_touched.py` (`--list` to see what runs): `unity/SimTests` under
  dotnet when the sim side changed. `tools/lint/push_gate.sh` (run on every push by a hook) typechecks the view code
  against the local editor; CI has no Unity editor (sim-csharp: the sim, the DLL, the slice bake). The slice is
  baked with `bash tools/unity/bake_slice.sh assets/kaiju/reptilian_adult`; a fresh clone builds with `unity/README.md`.
- Worktrees: `git worktree add -b claude/<topic> ../Kaiju-Incremental-wt/<topic> origin/main`; remove
  when the PR merges; `tools/lint/worktrees.sh` flags merged and idle ones (D-053). Commit a `.meta` with its asset;
  revert `.meta` churn on files you did not change. `unity/Library/` is never committed.
- A decision goes into `docs/DECISIONS.md` in the PR that acts on it, when the director has ruled (any PR may carry it);
  the same PR edits `docs/DESIGN.md` if the ruling changes what the game is. `docs/STATUS.md` is generated
  (`python tools/status.py`, never by hand) after merges. Main requires checks, so no direct push and no separate board
  PR: pure log/status updates ride in the next PR.
