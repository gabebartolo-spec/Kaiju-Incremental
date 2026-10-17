# Demo-slice handoff, 2026-10-18 04:45
## State: awaiting lead (#23 head 25f518a: jaw fix + D-051 pushed; clip roar waits on #22)

## Task
Demo phase P5 "demo slice" (brief from "Game demo planning", local_106fc100, 03:35; plan
C:\Users\DANTE\.claude\plans\pasted-content-id-a4a2-i-want-glistening-bubble.md). Code only, no
models. Croc titan (reptilian) only; the demo ends after the first evolution (Behemoth) on a
"demo complete" card teasing the adult roaring. #11 stays paused (D-044), not in the demo.

## Branch and commit
claude/demo-slice from origin/claude/look-options dbff208; worktree
C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/demo-slice. Pushed.
- 63c5df5 failing-first flow checks + tuning "demo" section (red: 3 failures, 82 checks).
- 954e3b0 implementation; all 8 suites green locally (flow 91, floor raised 76 -> 91).
PR #23 into claude/look-options (opened 04:05). Lead is now "Game demo planning" (local_106fc100). Balance D (claude/balance-d) and
D-047 may land first: merge look-options in when they do (never rebase/force-push).

## What it does
- data/tuning.json "demo": enabled, species ["reptilian"], end_node evolve1, tease_size 3 (adult),
  end_title "DEMO COMPLETE", end_line "You become the Croc Titan" (no text table in the project).
- sim/demo.gd `Demo`: enabled / allows / species / is_end / complete (pure, reads Content).
- scenes/species_select.gd lists Demo.species() (others absent).
- scenes/main.gd: end node's reveal.done -> _show_demo_end (deferred); Continue on a save that owns
  the end node -> end card; a save of a species the demo leaves out shows no Continue.
- scenes/reveal_stage.gd `RevealStage`: the reveal's set/camera/tower, shared by the reveal and
  scenes/demo_end.gd `DemoEnd` (adult roars on arrival and every 240 frames; TITLE / QUIT).
- tests/lib/flow_demo.gd: demo checks on shipping data; the rest of the flow suite runs with the
  demo switched off in the cached tuning (demo_off / demo_restore), so the full game stays covered.
- tools/capture/capture_demo.gd: real-input run title -> select; save -> Continue -> buy Behemoth
  -> reveal -> end card -> Title -> Continue (end card again).

## Running jobs
none. Evidence: CI 39051576948 (stills), 39051911218 (clip), 39054107256 (recut after lead QA)
in side-session-notes/local_9fac90d2.../demo-slice/{stills,clip,stills2}.

## Lead QA round (done, 25f518a)
- End card roars only via ClipGait (DemoEnd.has_clip_roar, by class name: ClipGait is in #22),
  every 360 frames; else idle (the procedural roar dropped the jaw straight down).
- D-051: reveal headline = node data name after the colon (EvolutionReveal.title_of; main sets
  reveal.title). Flow 92. #21 merged in (377f87c).

## Next (lead's job: real clip roar on the end card)
1. When #22 (claude/croctitan-clips) merges: merge origin/claude/look-options in (floors conflict:
   keep flow 92 and add clips 13), switch has_clip_roar to `gait is ClipGait`, suites, push.
2. CI clip: ci_capture.sh --movie --fps=30 --resolution=1920x1080 capture_demo.gd -- --clip; check
   the clip roar on the end card; report to the lead (local_106fc100) in <=8 lines.
Local throwaway branch tmp/clip-roar-check (#22 merged in, not pushed) showed clip_roar=true,
flow 92 + clips 13 green; delete it when done (git branch -D tmp/clip-roar-check).

## Open points for the lead
- A dev save of insectoid/cephalopod is hidden in demo mode (no Continue; New Kaiju then overwrites
  it without the "start over" prompt). P6 should export with its own user dir so dev saves stay apart.
- Worktrees: 6 live after removing city-growth, game-flow, kaiju-look-test (cap 4). kaiju-motion
  (paused) and this one are mine.

## Rules learnt
- A fresh worktree's first Godot import can segfault on the LFS fonts; the second import passes.
- Strict typing: `bool(variant)` is a parse error; compare `== true` instead.
