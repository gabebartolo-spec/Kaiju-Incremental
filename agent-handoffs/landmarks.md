# Landmarks handoff, 2026-10-18 15:30
## State: running a check (full suite on claude/stadium-matches; CI stills + clip wait for the slot)

## Task
Landmarks role, reporting to LEAD ("Kaiju: Lead", local_106fc100...). PR bodies <= 8 lines, never
merge, LEAD does QA, critics and the director. Two PRs now, both in the demo chain:
1. #57 landmark sites (A stadium city 1, D Sky Wheel Behemoth; D-071), branch claude/landmarks,
   base claude/look-options, head fd0e67c, open, CI pending. The app turned Auto-fix ON for it
   (brief said off): told LEAD, left the switch alone.
2. D-078 stadium matches, branch claude/stadium-matches (this worktree, cut from fd0e67c),
   stacked on #57 (base claude/landmarks; retarget to look-options after #57 merges).
E spire / F megatower bake is a later PR (F needs a Performance look at ~816k voxels).

## D-078 (director via LEAD)
A match inside the stadium, one sport per run at random (AFL, NFL, soccer, cricket), "not high
effort, just a visual flavour". Presentation only. When the wall caves in every player runs.
Evidence asked: flow check (shown failing first), a game-camera still per sport + 2x crops, one
720p ~6 s clip of an AFL wall caving in and players fleeing. CI slot: after the rooftop clip
(CI order: shell-hit -> military 720p -> croc P3 -> rooftops -> everyone else).

## Done on claude/stadium-matches (8264d21 + uids)
- data/sports.json: "pitch" (stadium, half 7.6 x 4.6, top 1.25 measured from the kvox, pace,
  kicks) + 4 sports (shape, posts, colours, kits, ball, per_side 11).
- scenes/pitch_props.gd (PitchProps: markings + posts as one voxel mesh, 8 cells per unit),
  scenes/stadium_match.gd (StadiumMatch: formation, nearest player runs onto the ball, kick or
  pass; panic on the stadium's first lost chunk -> tunnel farthest from the kaiju; crush()).
- StreetLife creates one per stadium and forwards crush; CityView passes
  Seeds.derive(_rng, 0x5907) (run fx stream) as the sport stream; city_view stays at 400 lines.
- VoxelPerson.dressed(outfit, pose, voxel); Content.sports().
- Flow +3 (tests/lib/flow_stadium.gd), floor 137. Fail-first log: scratchpad
  flow_failfirst_evidence.log ("no match in the stadium", 135 checks, 1 failure); wired: 137/0.
- tools/capture/capture_matches.gd: stills afl/nfl/soccer/cricket (Rampage + game camera, kaiju
  at the stadium's south kerb), --clip = AFL, kaiju walks in at frame 45, wall gives at ~84
  (30 fps), 11-13 of 22 out by frame 180.
- PR body drafted: scratchpad pr_matches.md (EVIDENCE_LINE, SUITES_LINE, HEADSHA to fill).

## Next
1. Suite green -> open the stadium-matches PR (draft body), send LEAD both heads.
2. When LEAD's CI order reaches me: ci_capture.sh --resolution=1920x1080 capture_matches.gd
   -- --out=<dir>; then ci_capture.sh --movie --resolution=1280x720 --fps=30
   capture_matches.gd -- --clip --out=<dir>. 2x crops of each sport; own check; commit to
   docs/captures/2026-10-18-matches/; fill the PR body.

## Findings for the lead
- voxelize.py shells surfaces only: a solid disc bakes as a cap; build open parts as rings.
- Rotated geometry and slow tapers alias at 8 voxels per floor; axis-aligned boxes bake clean.
- Godot --script with new class_names needs --import first; wrap probes in `timeout`.
- Probe the sim events before changing a rule: the "landmark vanishes" still was the capture's
  stage-2 signature, not a sim bug.
- Ruin.build's office-wall stubs suit towers only; a landmark now leaves its heap only.
- An "until nothing is running" capture watcher can jump a lead-set queue in a gap: hold by hand.

## Rules learnt the hard way
- gdlint caps files at 400 lines and functions at 4 arguments; gdformat writes CRLF on Windows.
- A failing check must run (not fail to parse): land the classes first, wire them second.
