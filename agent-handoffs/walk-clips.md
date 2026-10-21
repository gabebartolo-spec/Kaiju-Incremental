# walk-clips handoff, 2026-10-21
## State: done, reported to lead 10
## Task
Lead 10: exactly 4 CI clips (game camera, ~6 s): adult straight, adult turn90, baby straight,
baby turn90, saved to notes walk-m2/clips/; self-review at 2x for foot slide, head lead, step-turn,
shoulder motion. No PRs, no code change unless a capture-tool bug blocks the render.
## Branch and commit
claude/walk-m2 517fa36c (over 0f9e0d2c): capture_walks.gd gains --cam=game (the tool had only
side/front34; the brief asks game camera only). Game cam = CameraTuning offset x zoom(bs), eased
focus (Rampage.FOCUS_FOLLOW), look at focus + 3.5 bs; no step dip or shake.
## Unfinished changes
none
## Evidence so far
Headless smoke: adult turn90 game 6 s, worst planted-foot drift 3.6 cm.
## Attempts (fix-loop record)
none
## Open decisions
none
## Running jobs
none. CI runs 39553732159 (adult straight), 39553814056 (adult turn90), 39553885824 (baby straight),
39553961753 (baby turn90), Forward+ on lavapipe, 1920x1080 60 fps 6.0 s. Clips: notes
walk-m2/clips/walk_<stage>_<course>.mp4. Headless drift: adult 3.6 cm both, baby 0.0 both.
## Review (2x crops, 10 fps)
- Turn: head leads about 0.1 s, then the whole body swings 90 deg in about 0.4 s (3.6-4.0 s) with
  no visible step-turn; reads close to the "swivel" he flagged (both stages).
- Straight (game cam is behind): tail hides hips and legs; slight side sway of head/shoulders only;
  foot slide along the view axis cannot be judged from this angle. Baby ~60 px tall, hard to read.
## Findings for the lead
ci_capture.sh can track another agent's run when dispatches overlap (it took camera-growth's
39553730239); gh workflow run prints its own run URL, parse that instead.
capture_walks steps the sim 1/60 s per frame: CI clips need --fps=60 to play at game speed.
## Rules learnt the hard way (under 10 lines)
