# Military AI handoff, 2026-10-20 (r7: proof tool fixed, hull-edge standoff, fall-back capture)
## State: r7 pushed (see PR #50 checks); local clips done; CI capture dispatched. Awaiting lead.
## Local headless allowed (director 2026-10-20): tools/run_tests.sh --quick military, GODOT wrapper
## adding --audio-driver Dummy. Director away 2026-10-20 ~11:00: local windowed renders allowed. Don't merge.

## r7 done (military suite 12 checks green locally; both new failures shown first)
- Overlay bug: Camera3D.unproject_position returns CANVAS coords (1920x1080 under the project's
  canvas_items stretch), the stills were 1280x720 -> boxes scaled 1.5x, paired with wrong tanks.
  capture_military now: stills after RenderingServer.frame_post_draw (what was drawn is measured),
  outlines from each part's MultiMeshInstance3D voxels x its global transform, scaled to still px;
  POSE lines (off deg, lat, kerb, hull-to-body m, screen angles) and KERB lines (road kerbs/centre).
  --probe = POSE only, headless. --mode=fallback = entry camera, then fixed cam on the first tank
  falling back + m/s readout (capture only).
- Item 2 not real: parked hulls 0.0 deg off, tracks >= 0.56 m inside the carriageway (perspective).
- Item 3 real: tank 6 hull corner 6.5 m from the body edge (centre 9.3). Fix: danger() adds the
  hull half-diagonal; fall_back never picks a way ending nearer the body than holding (one tank
  drove back up its stub). View check now from the hull: 6.1 m old -> 8.1 m; tank cornered on its
  entry stub at the box edge holds at 7.8 m (LEAD call A: named check, never drives nearer).
- Scratch: <scratchpad>/r7 (overlay2.py, game2/clip.mp4 1080p30 18 s, fb4/clip.mp4, ov2/, crops).

## r6 done (local military suite 11/11 green at the push; old sim fails 4, shown failing first)
- Merge of look-options (d26b5ea): floors and shard registry deleted; military suite uses _t.
- Standoff from the body EDGE + 8 m, braking before it: Convoy tracks kaiju_vel; FiringPosts.body()
  = tail root to snout swept along the walk for army.convoy.lookahead 3 s (new tunable); to_body,
  near_body, roads_by_body and crosses_danger use it. fall_back picks the road and way at a crossing
  that leaves the tank furthest from the body after lookahead, counting hull-swing time.
  View: closest to body edge 8.8 m (was 4.6; lookahead 2 s gave 8.0 exactly).
- Falling back at 3-4 m/s: retreat_speed 3.5 now forward too (was 2.5 forward). New check
  (military_view RETREAT_PACE): >= 90% of fall-back steps in 3-4 m/s, max <= 4: 41/42, 2.6-3.5
  (old code 0/30 at 2.5).
- Parked squared: skewed 0 of 3268 (was 86/3521). Causes: a pivot was blocked by a neighbour's
  turret/gun clash (TankSpacing.hull_clash: a pivot in place checks only the swinging hull), and
  _settle now falls back to any road under it at a crossing. Driving skewed 0 of 30894:
  RoadGraph.square_leg re-squares each leg as driven. In band 100% of 144 (was 90%).
- Right-of-way functions moved Convoy -> TankSpacing (yielding/give_way/back_off; 400-line cap).
- Run prints VIEW and RAMPAGES lines (numbers above).

## Left for the fresh builder
1. Confirm CI green on #50 at the pushed head (tests.yml).
2. One CI clip: ci_capture.sh --movie --fps=60 --resolution=1920x1080 --renderer=gl_compatibility
   capture_military.gd -- --out=<dir> (check gh run list -w capture.yml first: one at a time).
3. Hull/turret overlays at frames 750 and 1050 from the clip log's OUTLINE lines: scratch script
   overlay.py (log, stills dir, out dir, frames) draws hull red / turret cyan / barrel yellow and
   prints each hull's screen long-axis angle; 2x crops. Lead checks them.
4. Pacing line on CI: a throwaway tools/capture/pacing_military.gd (extends res://tools/pacing.gd)
   on a tmp branch, via ci_capture.sh. Base (83af6d6): evolve1 0.26 h, young 6/8, tree 4.82 h.
   The wider standoff cuts tank damage: the tank_damage retune is the lead's/director's call.
5. PR body: evidence above + "Not exercised" (other species' body lines, dash/glide velocity
   spikes in kaiju_vel, helicopters).
6. Delete tmp branch claude/tmp-military-diag if still there.

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". LEAD = session
"Kaiju: LEAD" (local_106fc100...). #50 is tanks only; helicopters on claude/heli-flight.
CI only while the director plays (no local Godot). capture.yml one at a time (gh run list -w
capture.yml first). LEAD merges.

## Branch
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options, synced to c64fa34. r5 verified head 98d21cc (CI green, clip_r5, pacing).

## Helicopters (LEAD 2026-10-19 call 2): B clip, NOT YET RUN
claude/heli-flight head 20b06ff adds tools/capture/capture_heli_b.gd: camera eased to x1.4
while a pair is up (capture only; air.space.view zoom pulled with it), roof-cleared pair.
Dispatch (when captures are allowed):
  ci_capture.sh --ref=claude/heli-flight --movie --fps=60 --resolution=1920x1080
    capture_heli_b.gd -- --pull=1.4 --seconds=15 --out=<notes>/heli_b
  then the same with --pull=1.0 and no --movie, for today's camera stills at the same frames.
Design note sent: notes military-ai/heli-design-note.md (D can't be built: 8 m facades).

## Findings for the lead
- Screen-space part outlines settle "hull or turret" at once (r5 item 1 was the turret).
- kaiju_pos is the croc's tail root; anything "near the kaiju" must use the body line.
- A new class_name needs an --editor --import before a headless script can see it.
- Pushing to the PR branch cancels the running tests.yml run (concurrency): push a
  failing-first commit and wait for its result before the fix.

## Rules learnt the hard way
- gdformat on Windows writes CRLF: sed -i 's/\r$//' after it. Python: open(..., newline='').
- Warnings are errors: Variant from a Dictionary/Array into a typed param needs a typed var.
- Kill orphaned Godot children by PID after TaskStop (match start time).
