# blender-reptile handoff, 2026-10-18 08:30
## State: running a check. #22 ROUND 3 (lead 07:50 FIX; P3 PAUSED until #22 lands). Code committed
## locally ce44bb3 on claude/croctitan-clips (#22 remote still 439d8d3). Probe-gated numbers sent.
## Captures br14pqabg from temp branch claude/croctitan-cards-tmp (= ce44bb3): ci8/after_game then
## ci8/before_game (--procedural, same commit). Then: 3 s game-cam clips walk/turn/roar, before/after
## (aligned), 2x slam + turn crops, PR body, merge look-options, ONE push, delete tmp, SHA to lead.
## Lead = "Kaiju: Lead" local_106fc100-d2a4-4091-bc9a-4bda31df13ac. Auto-fix ON for #22.

## Round 3 (probe: godot --headless --path . --script tools/capture/capture_clips.gd -- --probe)
- Walk: TAIL_WALK (1.0, 2.5), TAIL_WALK_PERIOD 84 (4 waves / 7 strides), FRAMES 336 (walk 7 cycles):
  period 1.84 s, sweep 21.6 m. Turn: TAIL_SPRING (14, 0.36), TAIL_WHIP (7.8, 10.0), turn clip tail has
  no walk sway and its body gait fades f100-116; game lag spring only in walk: settle 0.42 s,
  overshoot 4.3. Roar: ROAR_REST (71, 99), exported 108 frames: ends 17.47 s. Slam TAIL_SLAM_STRENGTH
  5: dust 7.4, ring 9.5, dip 71.5 px. TAIL_IDLE (0.4, 0.2). Capture dip eased (_dip_shown).

## P2 (#22, claude/croctitan-clips, this worktree) - done unless the lead sends FIX
- v2 croc titan (Tripo c8185166) on the hand rig, skin, kvox, .kclip; ClipGait plays the clips.
- Tail: walk S-wave over 1.5 walk cycles (TAIL_WALK (2,5), TAIL_LAG 0.42, TAIL_WALK_PERIOD 72; walk
  clip baked as 3 cycles, header "cycles", KaijuClips.cycles_of); roar arc lift TAIL_LIFT (6,-9),
  TAIL_TRAIL 12, slam TAIL_SLAM (1.15, 0.85), lands f47 = head peak; ClipGait emits
  rig.foot_planted("tail", 1.6, tip) at ROAR_SLAM_FRAME (dust, ring, camera dip); turn spring
  TAIL_SPRING (14, 0.25), TAIL_WHIP (6.5, 8.3), TURN_SETTLE 24; game lag spring for walking curves
  (soft limit TAIL_MAX 0.008). The clips own tail0..8 (BipedSwing clamp never runs for the adult).
- Species cards (scenes/species_select.gd): sway +-40 deg around PI*0.62, camera fits the skin over
  the sway (width 0.92, height with 6% margin, 30 deg lens).
- Tests: clips suite 14. Floors line `clips 14` sits above `smoke` (avoids flow-bump conflicts).
- Evidence: docs/captures/2026-10-18-croctitan-clips/*; MP4s in the lead notes folder
  C:/Users/DANTE/.claude-desktop-work/side-session-notes/local_9fac90d2-fae7-4940-b4ac-144a87f28e6e/
  blender-reptile/d047/ (round2/ is current).
- Nits listed in the PR: turn settle ~0.6 s; slam dust small at the game cam; side cam crops the tip.
- CI captures: one at a time (concurrent runs hit capture.yml's 3000 s timeout); capture_screens
  --only=select for a 4K still.

## P3 (lead OK'd in this session): croc titan baby (stage_for tier 1) + adolescent (tier 2)
- GLBs (never commit): ~/Downloads/kaiju_tripo/rep_croctitan_{baby,adolescent}.glb; scratch copies
  p3/baby.glb, p3/adol_rot.glb (adolescent turned +90 deg Z by p3/rot.py so it faces -Y).
- Sheets: docs/captures/2026-10-17-reptile-design/croctitan_{baby,adolescent}_six_view.png; approved
  line croctitan_stage_line.png. Cadence: baby quick and bouncy; adolescent gangly, long stride.
- Done: grid renders p3/g_*_{side,front,top}.png; slices p3/slice.py -> v_*.npy. Auto fit rough on
  baby (tail on top, pelvis off), fails on adolescent -> hand-measure KNOWN entries.
- Baby: T-pose arms straight out x +-67 at z 56-60; huge head (snout y0 z~83); tail to y 211.
- Adolescent: hips z~48-52 at y~70; tail level at z 63-66 to y 208 (strong carry-down needed).
- Plan: new branch claude/croctitan-stages from claude/croctitan-clips (stacked on #22 until it
  merges); KNOWN["CB"], KNOWN["CA"] in motion_test.py; #19 recipe per stage (export 160, rig_voxel,
  skin_faces, rig_from_skin mouth line, bake_all, clips) -> assets/kaiju/reptilian_{baby,adolescent}.*;
  clips suite: each stage ClipGait + fit; stage board (baby/adolescent/adult, same camera and height
  scale, labels top-left) + in-game clips per stage -> PR into claude/look-options -> lead.
- Recipe: notes folder blender-reptile/refit.md.

## Findings for the lead (theirs to record)
- Concurrent lavapipe captures double each run (25 -> 50 min) and trip the 3000 s timeout.
- Windows CRLF writes (and gdformat) break byte-hashed stamps: write LF explicitly.
- The focus guard flags `set -e` as Godot's editor flag.
