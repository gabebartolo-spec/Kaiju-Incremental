# Lead handoff, 2026-10-17 12:50
## State: awaiting director (make repo public: GitHub Actions blocked by billing)

## Task
Lead for Kaiju Incremental: kaiju sculpts/skins, art and motion QA of every helper before the director,
director decisions (D-022..D-042 in docs/DECISIONS.md), helper coordination. Credits unlimited for Tripo
(D-023); log every task in docs/provenance/tripo.md.

## Branch and commit
claude/look-options (integration; PR #3 to main on HOLD until the director signs off). Latest: 30682ae
(LFS checkout in capture/tests/build, from game-flow 7777974/35be8e9), then this handoff.

## D-044 LOCOMOTION PAUSED (director 12:46) until models are decided
species-motion, kaiju-motion told to stop (PR #11 open, unmerged); kaiju-look-test skips octopus captures.
Director saw octopus local capture: "head detached, limbs a static, awkward mesh" (I had not caught it).
D-043/D-044 logged (efa6756). Blender motion test (blender-reptile) decides the model pipeline first.

## BLOCKER: CI billing (12:35)
- Every Actions job refuses: "recent account payments have failed or your spending limit needs to be increased".
- Director chose "make the repo public" (free minutes). My `gh repo edit --visibility public` was DENIED by
  the auto-mode classifier, so the director flips it himself (Settings > General > Danger Zone, or the command).
- Pre-flight clean: no secrets, no Tripo GLBs in any ref (only our Blender .blend/.glb); commit email
  gabebartolo@gmail.com becomes visible.
- AFTER the flip: protect main (github-hygiene: test, doc-caps, gitleaks required; squash only; no force push),
  log D-043 (repo public, director 12:35), rerun failed jobs (#11 `gh run rerun 38935875288 --failed`, #14,
  #15, #16, #17, #18), tell helpers to dispatch their captures.
- If he raises the limit instead: log that as D-043 and rerun.

## Open PRs into look-options (all green locally; CI red = billing only)
- #11 species locomotion (mantis + octopus). species-motion r3d: holds fixed (contrast 4.6x), big rest moves
  00284f3 not yet rendered. Needs: game + side mantis clips, octopus adult side, then FRESH motion-critic, then
  merge at reviewed SHA.
- #14 game-flow: screenshots FAILED review (blank buttons/values) -> cause LFS pointer font, fixed 7777974, flow
  67. Needs new stills (1080p + 4K at 125%) + clip, then review, mark ready, merge.
- #15 voxel skin (D-041): reptile + mantis before/after clips and 2x joint crops ready in
  side-session-notes/<lead>/kaiju-voxel-skin/ -> REVIEW THEM NEXT. Octopus captures local, after species-motion.
- #16 city-growth (D-039): 4 nested cities, pacing ceph 2.94 h / rep 3.94 h / insect 1.93 h. Stage 3-4 stills
  pending CI. Told it: target all species 3.5-4 h within +-20%, keep insectoid fastest in-run; prepare a
  proposal only. Balance is a director question after #16 review.
- #17 Blender tank (D-042, 2x, desert tan) in game; #18 helicopter (stacked on #17). Board
  blender-heli/heli_board.png to QA. Decided: helis fixed 2x scale, no growth multiplier.
- #8 SFX paused; #3 to main on hold.

## Captures plan while CI is out
Local windowed capture (off-screen override.cfg; focus guard allows only when the director isn't fullscreen),
ONE GPU job at a time: species-motion octopus first, then kaiju-look-test octopus. Everyone merges look-options
for the LFS fix before capturing.

## Blender direction (director 12:39)
- Board: Tripo adult looks better; Blender adult "promising", "more original, less a blatant Godzilla copy"
  (memory: original-not-godzilla). Blender wins only if it ANIMATES better than Tripo.
- blender-reptile (local_bce75838-34da-4991-a74e-b37ed5781547) briefed: one hand-weighted armature (deform vs
  control bones, spline-IK tail, 3-5 loops per joint) fitted to BOTH meshes (A Blender, B Tripo olive copy in
  scratch, never committed), walk + 90 deg turn + roar, headless Blender renders side by side, foot slide cm,
  2x joint crops, volume loss per joint. Answers: mesh or rig at fault. Clips come to me first.
- Research on animatable Blender models given to the director and to blender-reptile (sources: Blender wiki,
  Blender Studio, Rigify docs, MCP reviews: MCP is good for ~80% of a rig, weak on weights, timing, sculpt).

## Helpers (ids)
- species-motion local_87c25bd4-a526-4731-b18e-7c728966a2df (mantis/octopus, PR #11)
- kaiju-look-test local_c9f2ad5f-c2d8-444e-be1e-bc4d838f23cc (PR #15)
- game-flow local_9e7bf3f2-b85d-489b-987f-b9e45b8bfb55 (PR #14)
- city-growth local_abf1bce5-336a-4fc8-942a-ff8f84538b7a (PR #16)
- blender-tank local_5c21d3fa-ab76-4f0b-98ae-360caff8c60d (PR #17/#18, available)
- blender-reptile local_bce75838-34da-4991-a74e-b37ed5781547 (motion test)
- kaiju-motion local_fd14d508-6453-459d-b05c-fb22af37d14f (keeps #11 in sync)
- ability-vfx paused (PR #8); real-city tabled (D-029).

## Next (mine)
1. Review #15 reptile/mantis clips + joint crops (art-qa-critic; fresh motion-critic before the director).
2. QA heli board and #17/#18.
3. After the flip: protect main, D-043, rerun CI.
4. Fresh motion-critic on mantis r3d + octopus when clips land; merge #11.
5. Cephalopod skins (3 stages); 4K TV UI check.

## Rules learnt the hard way
- Tripo: default export name; `find` refs; stay in the signed-in tab; Remove Lighting per page; inspect every texture.
- Merge only the reviewed SHA (`--match-head-commit`).
- Windowed Godot: separate command writes override.cfg (mode=0, no_focus, -20000) first; guard blocks while a
  fullscreen app is in front. Never set fullscreen in project.godot.
- CI checkout needs `lfs: true` (fonts are LFS). Heavy software-rendered captures burn minutes: render locally.
- `rm` with variables: "${VAR:?}". After merges that add classes: `godot --headless --import`.
- Subagents without a shell can't read private PRs: stage the diff for them.

## Running jobs
None of mine. No override.cfg left. Helpers: blender-reptile working; others blocked on CI.
