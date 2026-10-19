# Landmarks handoff, 2026-10-19 12:10
## State: working (#76 resynced for merge; then a windowed off-screen stall check on look-options)

## Task
Landmarks role, reporting to LEAD ("Kaiju: LEAD (demo build, merges, QA)", local_106fc100...).
PR bodies <= 8 lines, never merge. Local Godot allowed (headless first; windowed only
off-screen with the no_focus override.cfg written in its own call, removed after). LEAD can
pause local Godot at any time (director playtesting): then CI only.

## Done
- #57 landmark sites, #59 stadium matches (D-078): merged.
- #75 stadium stall (Structure.settle per-floor rescans): merged, in demo exe (D-089).
  sim.step per stadium hit 70-80 -> 10.6-12.9 ms (CI); local 57 -> 10 ms.
- #76 stall probe --no3d: 1500 frames on CI, sim.step worst 6.9 ms, no event over 16.7 ms.
  LEAD merges on green. Worktree ../Kaiju-Incremental-wt/stall-probe (remove when merged).

## Director playtest fixes (D-083, demo exe 2)
1. Crowd ("stadium audience shouldnt disappear so suddenly, let us kill them"): PR #78 MERGED
   (f0634ee, LEAD's 2x PASS),
   branch claude/crowd-kills, worktree ../Kaiju-Incremental-wt/spawn-south (named before the
   split; holds the crowd branch).
   - crowd.gdshader: fans run to the back (exit_r) then sink `sink` m out of sight at the exit.
   - tuning crowd: flee_speed 3.0 -> 1.3, flee_delay 0.5 -> 2.5, sink 2.0, check_per_frame 400,
     max_puffs 4.
   - StadiumCrowd.running_at(fan) mirrors the shader; crush() kills where fans run; fallen
     check: round robin 400 fans/frame after any chunk loss, vs the as-built chunk strengths
     (a chunk standing then and gone now has fallen); dust puffs capped per blow.
   - StadiumMatch.crush returns kills; StreetLife.civilians_killed() = street + players + fans
     (killed + fallen), used by RampageHud.result; panicking() adds running fans.
   - flow 148 -> 150: "fans stay in view ... 2 s after the panic" and "a blow on a running fan
     kills it there and counts it", both failed first (0 of 3965; civilians 0 -> 0).
   - Clip: capture_matches.gd --kills (11 s, one breath 45 frames after the wall goes, counts
     each second). Notes landmarks/crowd_kills_720p.mp4 + crowd_kills_clip.log. In stands:
     +1 s 3530, +4 s 1941, +7 s 25; 68 killed by breath, 456 fell, 3441 out; civilians 525.
   - Captures docs/captures/2026-10-19-crowd-kills/ (kills_sheet.png, far_stand_2x.png).
   - Full suite green at 17dd62b (sim 53, growth 31, flow 150).
2. South of spawn ("smaller buildings ... dont seem destructible"): no sim building ignores
   stomps. Spawn (0, 42); playable edge z=44.5; skyline stand-ins (never destroyed) in rows at
   z=48/52/57, nearest 6 m away, in the camera's foreground; nearest sim buildings 20 m north.
   LEAD chose A (make the first row past the south edge playable) and gave it to the greenery
   session (it edits the same city edge). Not mine.

## Next
- LEAD: merge #76 once green (LEAD delegated this merge), then a windowed off-screen stall
  check on the local GPU at current look-options (render-thread costs), stadium collapse
  driven by script: worst frame ms and any frame over 33 ms with its cause. <= 5 lines.
- Then post-demo work from LEAD: rubble polish (broken wheel, ragged stadium stumps, heaps),
  landmarks E (spire) / F (megatower, needs a Performance look at ~816k voxels).

## Findings for the lead
- A per-settle check that loops over every floor above every floor is O(h^2 w d): fine for a
  3x3 tower, ~100 ms on a 28x28x13 landmark. Profile the sim with the biggest building in it.
- CI's software renderer runs ~4 s a frame: CPU timing probes there need 3D off (disable_3d).
- gh shares one 5,000/h API budget across all agents: wait for the reset, never poll in a loop.
- A presentation-only crowd counted nowhere: kills a view counts must reach the one counter
  the HUD reads (StreetLife.civilians_killed), or they silently do not exist.

## Rules learnt the hard way
- gdlint: 400 lines per file, 4 arguments; gdformat writes CRLF on Windows (sed it off) and
  must run after the last edit (CI runs gdformat --check).
- A failing check must run (not fail to parse): land the API first, show the check failing,
  then change the behaviour.
- Never stash; stage by name; kill Godot only by recorded PID.
