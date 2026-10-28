# Lead how-to (moved out of the lead handoff 2026-10-29; grep when a task needs it)

## How to run things
- Every Godot run: `bash C:/kt/gq.sh run <owner> <speed|window|headless> <secs> <dir> <cmd>`; dispatcher
  `bash C:/kt/gq_run.sh` (STOPPED now; restart run_in_background when Godot work resumes) + watch C:/kt/gq/FROZEN.txt.
- Suite gate `bash C:/kt/suite_gate_v4.sh`; builder cap `python ~/.claude/hooks/builder-cap.py release <name>`.
- Cascadeur: bridge 127.0.0.1:8765 under `bash C:/kt/casc_lock.sh`; <=5 tabs per job, 20 s gaps, probes never switch
  scene; he never opens its window while jobs run (crashes it). Restart only with his yes.
- Merge: `gh pr merge N --squash --match-head-commit <full sha>`. doc-caps: DECISIONS 400 lines (roll oldest to
  docs/archive/decisions_2026-10.md), ROADMAP 600.
- Native DLL per worktree: `bash tools/native_dll.sh fetch`. Game camera = capture_rampage_kaiju (dist 32.3, pitch 28, FOV 60).
- TaskStop kills only the wrapper: find the inner script by command line, stop by PID.
- Main checkout stays on main; its untracked captures and agent-handoffs/ are his.
- Tripo balance 5,695 (D-297 + D-309), via subagent only. No other spend.

## Rulings easy to get wrong
- Never fade out destruction (D-283, D-326). Runs start at the beach (D-270, D-373; river intro nixed). D-330 camera behind.
- Serpent branches frozen (D-246), never delete. D-371: no never-touch rules on Dracorex/Defender/his tabs.
- D-376 GPU load check (<=3 windows) replaced D-340's one-window rule. D-347 keyed moves reach him as .casc tabs.
- Questions are not requests: answer only (memory questions-are-not-requests.md).
