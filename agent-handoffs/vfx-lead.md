# vfx-lead handoff (VFX lead, the lead's second in command), 2026-10-23, WRAP-UP

## State
Director (via lead, evening): "get the other two chats to merge what they can and archive. i wanna go 1 on 1 with
you". Wrap-up done: no PR of mine was SHIP-ready (night fog SHIP is already #172, the lead's to merge); every WIP
branch is committed and pushed; all builders and critics stopped. A respawned VFX lead restarts from this file.
Role: I own every visual item end to end (decide, brief Sonnet builders in own worktrees, art QA, SHIP final); the
lead owns sim, gameplay, UI, tests, merges, docs. D-189: 2 engine builders per lead (6 total); the atmosphere lead
(local_3dbe2472) owns sky/sea life, weather looks and rampage escalation (D-154 haze, orange sky, blackouts).
Every run: `bash ~/.claude/tools/engine_slot.sh || exit 3` per launch, inside loops too (it fails while
~/.claude/focus-pause exists; a builder's run script relaunched Godot under a pause on 2026-10-23).

## Director rulings that bind my work
- D-190: fire = "Smooth flames" on EVERY fire (style mix approved); breath = "Slow chest-and-neck heave" (replaces
  the old movement caps); claw swipe = "Keep it straight ahead" (trail + sparks carry it; no side hit).
- D-193 (d8d1533d): kaiju ANIMATION moves to a commercial animation tool pipeline (lead researching; I own putting
  its clips on the rig). PARKED: breath heave, claw ARM motion, D-187 turn recapture. Effects carry on.
- D-188: no round cap, bar "I have to love it"; two failed rounds in a row = stop, find why, change the method.
- D-189: helicopters "Never block your view" (camera side ok, never between camera and kaiju).
- Earlier: one look per effect; blast = Fire's own rising flames; smoke lit from below; Taskforce one electric blue;
  visual direction list in docs/VFX_STYLE.md.

## Branches (all pushed; notes = side-session-notes/local_a16cd984-.../vfx-lead/)
| branch | tip | holds | left |
|---|---|---|---|
| claude/fire-smooth | 4e6e90d9 | flame.gdshader on Fire, FarFire, heli fires, HeliFx.fireball; Fire.flame_mesh(); suite 9/9; cream 9.4/5.4 %, heart 4.7/2.8 % | art critic r1 FIX (notes fire_smooth/critic_art.md): r2 per scratchpad brief_fire_smooth_r2.md (copied below) |
| claude/heli-fall | 5aee3cb6 | fall r3 merged with look-options + fire-smooth: fall_seconds 1.4, ballistic arc, Fx.dust_ring, chutes clear; helideaths 10/10; descent 5.07 px/f, pop 62 px | fire area 1391 vs 6000 px (hull behind roofs?), dust ring 114 vs 150 px at +7 f; fall motion critic unrun; resync from fire-smooth after r2 |
| claude/claw-rake | 2d176ff4 | r3: snout-line hit, ClawSweep ribbon, flash, line sparks, glint; young elbow-out (now PARKED, D-193) | re-run claw_rake + croc_standing (last 129/129, 37/37 before FLASH_MIN_SIZE); stage-2 stills; motion critic r3; split effects from arm code |
| claude/living-predator | ec4bb919 | heave default (PARKED, D-193); croc_breath 32/0, croc_idle 29/0 | critic r3 PARTIAL: back/neck below claims (Colossus back < 2 px) |
| claude/heli-r7-wip | 82801eb6 | fire board v4 WIP (parked: C picked) | none |
| claude/heli-look-r4 | 9f311538 | heli deaths r6 (art+motion FIX) | superseded by heli-fall + fire-smooth |
| claude/city-explosives-v2 | 9158d219 | explosions r10 base (mine, unmerged) | adopt Fire.flame_mesh() after fire-smooth merges |
| claude/one-look | 849d9e06 | D-163 one look phase 1 (parked) | fold ground_blocks into atmosphere's ground_slab.gdshader; resync on top of atm branches |
| claude/thunder-beam | 6dbe10e5 | round 6, critic FIX | r7 after reassessment (D-188); atmosphere copies bolt.gdshader/bolt_shape.gd byte-identical |
| claude/vfx-lead-2 | (this) | this handoff | |

## Fire r2 brief (critic r1 items, measured from frames)
1 base widest (last 15 % >= 80 % of max width, 3-5 stubs, seated within 2 px of its surface); 2 heart = soft
horizontal band >= 60 % base width, 3-step fade, lower third; 3 tongues: no hair texture, width 2-6 px, >= 2 lean
10-20 deg, curved tips, one dominant 1.4-1.6x, red+dark <= 33 % night; 4 night glow pool 1-1.5x flame width, R+25;
5 heli burst recomposed: radial, white core >= 20 % first 4 f, no downward tips, in frame (top margin >= 5 %), no hard
brown disc; 6 no cool rim at noon (flame on/off pair). Proof: sheets, crops, bands, one 6 s clip, title FarFire,
chunk fire, 4K still.

## Shared-file agreements with the atmosphere lead
smoke clearing -> view_clear.gdshaderinc (atm-rain); ground -> ground_slab.gdshader with `wet` (one-look folds into
it); building_baked dark_to/dark_color + BuildingView.set_dark_to (atm-escalation; lift_piece pieces must inherit
dark_to; item 4 resyncs on top). They go first on city_environment.gd / city_ground.gd.

## Queue after the restart (ask the director before anything he did not name)
1 fire r2 -> art critic r2 · 2 heli fall r3 fixes + motion critic · 3 claw effects split from the arm + critic r3 ·
4 new animation tool clips on the rig (D-193, when the lead names the tool) · 5 explosions r10 on Fire.flame_mesh ·
6 item 4 open-box pieces (scratchpad brief_item4.md) · 7 dust billows + deflect unify · 8 D-183 heli bank/pitch view ·
9 Thunder Beam r7 (reassess first) · 10 tower see-through cross-hatch, weak night silhouette · after demo: heads
(D-171), skins redo (D-180).

## Open findings
- The camera step 25 f after a rake hit = a building-collapse shake kick (trauma 0.3), not the rake.
- A ~5 px yellow-green glyph on the kaiju's lower back in claw stills: source not found.
- Deflect has two looks (AbilityFx.deflect 4-ray star vs round white core): unify in dust billows.
- CityView.ring still draws the cephalopod ink ring; charcoal smoke invisible at night.
- Croc standing SHIP ca148fd7 merged (#169); gait #175 merged 3a3ee03d.

## Item 4 (collapse defect, BuildingView.lift_piece): diagnosed, brief scratchpad brief_item4.md
A toppling piece is an open box: lift_piece reuses the building's outer shell + slabs masked per piece, so broken
sides have no face. Fix: bake the piece its own mesh from its cells, cut faces in carved slab colour 8a8780 (D-101).

## Rules learnt the hard way
- Builders measure every claim from the rendered mp4 (ffmpeg frames), never probes; critics caught claimed sparks,
  swipes and kicks absent from the clip three times.
- Effects tied to a body part hidden from the camera must be authored for the camera (claw r2 trail parked on the
  hip because it followed the hidden hand).
- A fresh worktree needs `git lfs pull`, the carve dll in native/bin and a headless --import before captures.
- The default rampage clock ends a long capture: set sim.time_left. override.cfg (no_focus, off-screen) in its own
  Bash call. GDScript warnings are errors (Num.i, typed assigns).
- Subagent transcripts: <session>/subagents/agent-<id>.jsonl; point stall_watch.sh at the .jsonl. The focus-guard
  hook blocks any Bash command containing the engine name in a heredoc: write scripts with Write.
