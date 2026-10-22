# Wave 1 common brief (lead, 2026-10-22)

Read in full first: C:/Users/DANTE/Documents/GitHub/Kaiju Incremental/CLAUDE.md, docs/DESIGN.md (in your worktree),
C:/Users/DANTE/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/side-session-notes/local_df2c2989-951e-4b20-9998-9c23b0a37f42/BRIEF-COMMON.md
and RULES-NOW.md in the same folder, the kaiju-godot-tests and kaiju-proof-evidence skills (.claude/skills/ in your worktree),
then your task's own handoff/task file (named in your brief). Your first report lists the files you read.

## The base moved (applies to every branch)
`origin/claude/look-options` (= origin/main) is now 95f01083, a SQUASH of the old look-options history. Your branch sits on
the old history. Before finishing: `git fetch -q origin`, then rebuild your branch as ONLY your own commits cherry-picked onto
origin/claude/look-options (`git rev-list --reverse <old-base>..HEAD` minus merge commits; keep a backup ref
`claude/<topic>-pre-rebase` first). Resolve conflicts yourself; if a conflict is in another builder's area, stop and report.

## Rules
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe. Headless only, at most
  2 Godot processes at once, each with its own APPDATA dir in your scratch space. Clips/stills render on the LOCAL GPU per
  RULES-NOW.md (off-screen no_focus override.cfg); never a visible window or dialog. Stop only PIDs you started.
- gdlint: C:/Users/DANTE/AppData/Roaming/Python/Python314/Scripts/gdlint.exe. Before any push run: gdlint on changed .gd
  files, `python tools/lint/tuning_keys.py`, `python tools/lint/complexity_ratchet.py`, `tools/check_scripts.sh` (GODOT=...).
- Commit by file name (never `git add -A`, never `git stash`), commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Never force-push. Push your rebuilt branch under its normal name only if the remote branch does not exist or is an ancestor;
  otherwise push to `claude/<topic>-v2`. Do NOT open PRs (max 3 open; the lead opens them).
- No magic numbers (data/tuning.json). Determinism: seeded, no clocks in tests. Change method after two failed fixes.
- Proof before done: smallest local suite that exercises the change, then the full suite once
  (`tools/run_tests.sh`, ~25-40 min; run it in the background and keep working).
- Edit your agent-handoffs/<task>.md (edit, not append, under 120 lines) and commit it with your work.

## Director rulings for this wave (2026-10-22)
- NEWEST (comment #60): "cpu and gpu and screen and all godot slots are yours to use as you see fit": no 2-Godot cap,
  run as many Godot processes as help; visible windows are allowed while this stands.
- The base moves on every merge (squash-only repo): PR #147 crowds merged as c07c50ae. Rebuild on the newest origin tip.
- "Speed-ups first": perf and clean-up jobs come before visible changes.
- Landmarks: out-of-view landmarks MAY be unloaded like ordinary buildings, ONLY if a game-camera test shows no visible
  landmark pop-in while turning ("Yes, if no pop-in").
- The sim clean-up (audit-sim) is separated from fire spread: it goes on the base by itself.
- Standing: perf work must not change visuals AT ALL (comment #37) - prove pixel identity where the task says so.

## Report (to the lead, 6 lines or fewer)
Branch + pushed sha, what is done, evidence (suite counts, measurements, diff results), Not exercised, anything blocked.
