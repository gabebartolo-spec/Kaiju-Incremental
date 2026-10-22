# Feedback-button handoff, 2026-10-23
## State: available (PR #158 open, ready, awaiting CI and merge role)
## Task
Pause-menu bug / feedback button (D-145; ROADMAP "Playtest milestones" M3, the demo end screen and feedback
button). Button "Report a bug / feedback" (label in data) opens a panel (text box, SEND, CANCEL); SEND writes
user://reports/<timestamp>/report.txt + screenshot.png; a confirmation line says where, OPEN FOLDER opens it.
No network calls. Sim untouched. Not touched: scenes/main.gd demo-end logic, the title screen.
## Branch and commit
claude/feedback-button, cut from origin/claude/look-options (95f01083). Worktree
.claude/worktrees/agent-ae24d88f8a5a9e54d. PR #158 against claude/look-options, pushed 9a5b949d.
## What changed
- data/tuning.json "feedback": label, title, prompt, send/cancel/done/open_folder, saved/failed lines, box size.
- project.godot: `config/version="0.1.0-demo"` (the first version string the project had; report line 1 reads it).
- scenes/feedback_report.gd (FeedbackReport: version, facts, compose, write, grab), scenes/feedback_panel.gd
  (FeedbackPanel), scenes/pause_menu.gd (button + screenshot before the panel; `sim`, `species_id` set by
  RampageHud.pause in scenes/rampage_hud.gd, 2 lines).
- tests/run_ui_tests.gd (new suite "ui"), tests/lib/ui_feedback.gd, tests/lib/gui_input.gd (`type` helper),
  tests/README.md row. tools/capture/capture_feedback.gd (the 4K still).
## Evidence so far
- D-153 (gamepad, added mid-task): autoload/settings.gd now gives ui_accept pad A and ui_cancel pad B (the engine
  defaults had keys only here: a pad's A never pressed any menu button). FeedbackPanel hands a pad's down / A
  in the box to SEND (a TextEdit keeps d-pad and stick), up from the buttons returns. tests/lib/ui_feedback_pad.gd
  drives it with joypad events only (focus read from the viewport); mutation (no hand-off) fails 9 checks.
- ui: 2 of 2 functions, 49 checks, 0 failures (was 34 before the pad checks). smoke 13/42, flow 7/206 passed after the pad work too. Mutations shown failing: writer emitting "Edition:" for the
  version line (2 FAIL); panel not focusing its box (8 FAIL, 62 keys leaked to the probe); planted bad
  report folders flagged by name (7 cases) in the suite itself.
- 4K still (RTX 4070 SUPER, off-screen no_focus override.cfg): feedback_panel.png in the PR body path.
  First render caught a real defect: the report screenshot carried the empty pause box (hazard-tape strip);
  fixed by hiding the whole pause panel before the grab, re-rendered and the picture is clean.
## Attempts (fix-loop record)
- Headless: `await RenderingServer.frame_post_draw` never fires in headless, so the menu skips it there.
- Headless has no picture: write() saves a 64x36 black placeholder and says so in report.txt.
## Open decisions
- Version string "0.1.0-demo" is a placeholder number (lead/director to set). D-TBD-version in the PR body.
## Running jobs
none. override.cfg deleted. Still image: docs/captures/2026-10-23-feedback-button/feedback_panel_4k.png.
## Findings for the lead
- BUG FOUND: engine ui_accept / ui_cancel had no pad A / B in this project, so a pad's A pressed no menu button
  (settings.gd fix in this PR). A pad cannot type; the box takes any pad input to SEND, text is keyboard only.
- Not broken but worth knowing: END RAMPAGE has no confirm; Settings opened from pause leaves the empty
  pause box behind its 0.92 dim (invisible in practice).
- playbook: nothing new beyond: a capture of "the picture a feature saves" found a defect no test saw.
## Rules learnt the hard way
- godot_quiet.sh from the brief does not exist here; the focus-guard override.cfg and a wrapper script were used.
- gdformat on Windows rewrites files with CRLF; convert back to LF before committing.
