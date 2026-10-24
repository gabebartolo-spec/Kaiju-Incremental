# Lead handoff, 2026-10-24 (lead session "Status check"; for the OTHER Claude account at the weekly-cap switch)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), docs/ROADMAP.md ("Director comments", Playtest milestones D-146, Engineering upkeep D-159),
## DECISIONS D-186..D-224 (newest first), and the art-qa-critic learnings (3 new 10-24 entries).

## Director state and rules in force
- Game is "Kaiju Evolution". Three equal visual pillars (beauty, consistency, power fantasy). Bar: "I have to love it".
- D-146: no per-change director gates; he plays only at milestones M1-M4 (export to Desktop\Kaiju Builds\M<n>, survey
  as a web page). D-177 MOTION FIRST. D-186: builders run 1-2 local suites, GitHub runs the rest.
- D-188: no round cap, but two failed rounds in a row = stop, find why, change method. He hates waste: "8 rounds for
  komodo skins? cmon what a waste"; "try not to use a billion tokens ... chasing minute improvements".
- D-209 goal: all nine reptilian models (croc, Komodo, serpent x baby/teen/adult) + skins + the models page
  (artifact https://claude.ai/artifact/8vi6tHEPh9e6dzBYHcNKb9, v7; source scratchpad models_page/, update_v6.py).
- Tripo: browser only; budget D-204+D-213 (10,000 total); spend only on his written yes.
- Every agent-made number or claim is checked on the RENDER (learnings: makers report rig numbers; a periodic floor
  hides a follow camera; judge the build against DESIGN's words).

## Done this session (10-24)
- Models: all nine textured. Croc adult REMADE sleek (D-219, adult3 a3174b0f, ridge kept D-221). Mecha boss look B
  lab-white 3D made (D-217, mecha/b3d/tex/mechB_59e6e6c4_ivory.glb). Serpent hood + eyes fixed (D-218, "a lot better",
  branch claude/serpent-hood 84ce8d63 on top of claude/serpent-slither: PROTOTYPE, no PR by design).
- Skins chosen: Komodo Wild Olive + Melanistic Black + Bone White (D-220/D-221, blue dropped); croc Wild Olive + Pale
  Banded; serpent Olive + Copper + Albino (D-224). GLBs: C:/Users/DANTE/cascadeur_bridge/skins/<titan>/glb/. How a
  player gets a skin is NOT decided (ask him before building any unlock).
- Komodo animation (casc-anim, Cascadeur): teen walk v14 SHIPPED by him (D-222); D-223 tails are a living limb
  (balance swing, mood signals, attack wind-up, ground contact): turn v16, teen walk v15, teen idle v7, adult walk
  v10 all critic SHIP. Adult idle v19 FIX (side-view flick, tongue clearance) -> v20 in progress at casc-anim.
- Merged #176 (sim leak) and #171 (beam cost x0.3, D-167). CAUTION: #171's pacing check never ran: both pacing runs
  (39910488328, 39920885597) died at ~45 min ("runner received a shutdown signal"), so the 2.15-2.35 h last-unlock
  bar is unverified on look-options. Next account: rerun the pacing workflow with fewer RUNS (or split) and report.
- Disk: C: 2 -> 405 GB free. HuggingFace cache and asset-forge/models moved to D:\moved_from_C\ with junctions.

## In flight / next
- casc-anim (local_2c36c792, handoff casc-anim.md): adult idle v20 -> fresh Sonnet motion critic on the mp4 -> on
  SHIP show him ONE clip; AutoPhysics on the walk (bridge, snapped 10-24, verify) and the .ktrack re-bake (bake_heavy_tracks.gd on
  claude/komodo-test from the w5+ joints fbx). Croc animations on adult3 come after (brief not written).
- Main: claude/look-options is ~200 commits ahead of main. He asked (10-24) to "get main merged" at wind-down.
- Parked branches: claude/turn-weight-d187 3483c993 (A/B turn clip faab304d), claude/heli-standoff 2c0c2688,
  claude/komodo-test 00d86a08 (D-208 bar met), claude/serpent-slither b022be85, claude/strike-delay (stopped).
- Stomp DEFECT (bug fix under D-166, no ask): sim stomp centres on kaiju_pos, the view rings at the delivering foot
  (5-12 u apart); fix = stomp centre at the delivering foot.
- Next queue: Kaiju Creation opening (D-207, demo; ask the lab look first), music integration (D-184, brief in
  scratchpad music_brief.md), sky and sea life (D-168), damage on impact (D-166), sim speed-ups (D-159).

## Sessions
- casc-anim local_2c36c792 (Cascadeur). AutoPhysics is NOT his click: bridge call_action("AutoPhysicsTool.Switch Auto
  Physics"), wait, then call_action("AutoPhysicsTool.Snap to Auto Physics"). Never drive his screen while he is present.
- tripo-komodo local_2d9f45c9, tripo-serpent local_cebec3c3: idle, no open work.

## Tools
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detach at origin/claude/look-options; python edits newline='';
  commit [skip ci]; push HEAD:claude/look-options). DECISIONS.md cap 400: scratchpad add_d224.py is the template.
- Cascadeur bridge: `python -I C:/Users/DANTE/cascadeur_bridge/cs.py job.py` -> 127.0.0.1:8765/run. Reuse ONE scene;
  save to new file names. Render camera: komodo/anim/work/render_move_blend.py (hips-follow; game view = 3/4 front;
  the real game camera has a fixed bearing, so also judge a 3/4-rear view).
- Lead board: Kaiju-Incremental-wt/lead-board/ (to-/from- files). Suno and ElevenLabs notes: memory files.

Lead = "Kaiju: LEAD 10". Owns routing, merges, DECISIONS/DESIGN/STATUS, director questions, milestones, this file.
