# blender-reptile handoff, 2026-10-17 23:15
## State: running a check (v2 evidence: 7 CI captures bxk6uh1b8 + Blender board render bx23u6epq)
## Task (lead 22:47): D-047 on the croc titan v2 (D-048), one pass, then open the PR
Re-fit the hand rig to Tripo c8185166 (GLB ~/Downloads/kaiju_tripo/rep_croctitan_adult_v2.glb ->
scratch v2/croctitan.glb, never commit); re-export the skin; re-bake the .kclip; swap the adult
kvox/skin in game; open the D-047 PR into claude/look-options with: BEFORE/AFTER at the game camera,
per-frame PNG diff (seams, blends), 2x crops of feet at contact and jaw at roar peak, a 4K species-select
still, plus a Blender walk/turn/roar render of v2 for the board. One self-check, list nits, no loops.
Auto-fix off. Don't merge. Send the lead the head SHA.
## Branch and commit
claude/croctitan-clips (this worktree; claude/blender-reptile-f5388e is pushed and kept).
Merged look-options dbff208 (D-048 docs). Head e560001 pushed: v2 re-fit + data.
Earlier: 7dca14d player/data/tests, 3706b4e capture frames + --procedural, 22a620a skin.json LF.
## v2 re-fit (done, e560001)
- KNOWN["C"] replaced (v1 in history): measured on 1 m grid renders (scratch v2/grid.py, legshot.py,
  head_grid). Hip (14,72,50), short arm shoulder (16,44,71) -> claws (28,33,55), mouth (1,84)->(27.5,
  87.3), hinge (30,85.5), 10 tail bones over 185 m to (271,3), belly 31.
- New landmark keys: hands (hand targets as offsets from the rest wrist: low (1,-1,1), high (3,2,7));
  tail_lift 3, tail_roar_lift 5, tail_breathe 0.15 (the long tail went below the street: tip min z
  -4.7 idle / -2.9 walk / -13.9 roar -> 9.4 / 6.7 / 10.1 m). Other models keep their defaults.
- Data rebuilt (#19 recipe): export 160 (5,362 positions), rig_voxel 160 jaw 0 (90,709 voxels),
  skin_faces (10,559 tris), rig_from_skin mouth -79,84,-52.5,87.3 (gap median 0.20 m), bake_all
  (only reptilian_adult.vskin changes), clips (135,552 B; FK worst 2.84 m = collapsed foot tip).
- All suites green on v2: smoke 27, sim 39, powers 24, tentacles 18, city 5, growth 24, load 6,
  flow 76, clips 11; harness self-test passes.
## Player (unchanged since 3706b4e): scenes/kaiju_clips.gd, scenes/gait_clip.gd (see PR body)
## Evidence pipeline (scratch)
ci2/{after,before}_{game,jaw,feet}/frames + logs, ci2/select4k; v2b/ (Blender board: r/, comp/,
clips/, meas/, crops/). ev/compose_ba.py, ev/pngdiff_game.py, ev/encode_intra30.py, r6/encode_intra.py.
BEFORE = same branch with --procedural (ClipGait.off): the v2 mesh on the procedural gait, same seed.
## Nits found in self-check (list in the PR, don't loop)
- Blender render only: at the roar peak, low-poly inner lip faces of the upper jaw show as shards.
- Turn clips play only for a standing turn (heading error > 0.6 rad); curves use walk + IK planting.
## Attempts (fix-loop record)
- First drift 0.425 (idle-locked feet, walk from f0): walk entry matched to feet + re-step guard.
- Debug "hang" = compile error (CATCH_SECONDS clash) -> RESTEP_*.
- Stale skin from CRLF working copies (Blender/Windows writes): exporter writes LF; check eol.
- Local GPU blocked by the focus guard (League of Legends) -> CI captures with PNG frames.
- Focus guard: write override.cfg in a separate command; `set -e` in a command reads as -e (editor).
## Findings for the lead (theirs to record)
- Windows CRLF writes break byte-hashed stamps (skin.json, rig.json): write LF explicitly.
- The focus guard flags `set -e` as Godot's editor flag.
