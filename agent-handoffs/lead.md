# Lead handoff, 2026-10-18 12:20
## State: working (DIRECTOR BACK 10:4x, interviewed; all tabled items answered; executing)

## Who
Lead = session "Kaiju: Lead" (renamed from LEAD 06:3x; local_106fc100...). Owns: QA gates + fresh critics, PR review +
merge (squash, `--match-head-commit`), STATUS/DECISIONS board PRs, director questions, this file, the local GPU slot.
Sessions renamed 06:3x: Kaiju: Military AI / Rooftop defenders / City fill & greenery / Crease shader / Jet models /
Tripo (old lead) / Sound effects / Landmark models / Lighting & breath FX / Croc rig & clips / Demo slice (done) /
UI look & fonts; AFL: Management game research / Kaiju tree research. "Hardrive space balancing" = director's own.

## DIRECTOR ANSWERS 2026-10-18 10:4x-11:1x (log D-068..D-077 in the next board PR)
- Plays the preview exe now (out\demo-preview-c3b7306). D-068 crease B 0.3 (#35 MERGED). Croc clips kept + slam polish.
- D-069 merge #36 army scales (sound session syncing it; lands after #50 military). D-070 all sounds ship + new mix:
  #43 #45 #39 #42 #46 #53 MERGED; #52 shell_hit A/B: director kept A (D-079), PR closed; voice-pool PR next, each resynced by the sound session.
- D-071 landmarks A stadium -> D wheel -> E spire -> F megatower (sites PR with A+D, then E/F). D-072 all four jets;
  strikes wreck buildings, no biomass; jets from Colossus, bomber Apex set-piece; octopus can grab jets.
- D-073 croc baby + adolescent approved; D-074 slow stage 1 (baby reads as toddler; pacing re-measured) in P3 PR.
- D-075 green lots 8% (city session, after greenery (a)). D-076 rooftops: more squads, more often (fresh session card
  proposed; after #50). D-077 trim the tree stats panel (UI session). D-066 heli mix shift OK.
- 11:2x D-069a: soften #36's young stage to ~half early defeats (cause: Armoured Scales moved late). 11:4x D-074
  revised: baby speed ~0.6 + more hp, demo ~35 min. ORDER: #50 -> P3 (art + baby tuning) -> #36 (resync, soften young last).
  13:4x DIRECTOR: final demo build WAITS for rooftops + #36; 14:1x D-078 stadium matches (AFL/NFL/soccer/cricket, random
  per run, presentation only, low effort, players flee when the wall caves) ALSO in the demo (landmarks session).
  Order: #50 -> P3 #54 -> rooftops -> landmark sites -> matches -> #36 -> build. No interim builds.
  Side merges (one floor resync each): #56 voices 8->24 and #51 stats trim right after #50. CI queue: shell-hit ->
  #50 720p -> #51 UI-only -> P3 chain -> rooftops -> matches -> greenery/landmarks/jets. Archived: Kaiju tree research.
  13:2x D-074b: 0.6 h unreachable at 0.6 speed; director picked 0.6 speed / hp 1.15 (~43 min, 45% def, 87% city).
- Rooftop density (local_1ac658ed): cause = rifle reach from kaiju centre; plan approved (reach from edge + more
  squads + shorter interval, tank_damage offset ±5%); branches after #50; PR needs volleys/run table + clip.
  D-076a = A (chip scaled down per tier, tanks unchanged); no HUD change; hide spark is the hit (2x crops).
  To ask the director: a HUD hit flash for big hits only (tank shells)? (UI session; taste).
- #54 P3 open: sim review PASS (my comment). Baby jaw 2x shows torn upper-jaw flap at mouth corner; gate = clean
  in-game jaw_baby crop at roar peak, then fresh critic on clips. CI capture order: shell-hit -> #50 720p -> P3 ->
  rooftops -> greenery/landmarks/jets. Local GPU slot: landmarks stills (after greenery).
- UNSENT (messaging paused 15:1x) to landmarks: #57 r3 critic FAIL (2nd round) -> change method: fix only
  floating slab 2x(1230-1290,720-830) support, olive/yellow off-palette rubble, plaza spill; stumps/heaps/seat rubble
  = post-demo follow-up with the wheel; cave-in judged on #59 AFL clip by fresh motion critic. Greenery: trample
  clip FAIL (no felled prop visible; contact radius?), GPU slot granted for re-shoot.
- UNSENT to military (#50 fresh motion critic FAIL; I verified the tank frames myself in pair clip t=17 and 21.5 s):
  tanks skewed 30-40 deg mid-street and hulls overlapping building corners/lots -> keep hull centre >= half-width
  inside road polygon incl. corners, finish turn before deploying; helis fire while nose points away (8.6-8.8 s) ->
  fire only within ~30 deg of bearing; hover-yaw against tower top (3.3-4 s) -> tower clearance + travelling arc;
  add bank roll in turns. Re-shoot 720p gl_compat. Greenery: stomp-dust haze (ability_fx.gd:134) -> sound session.
- UNSENT to UI (#51 screen-critic FAIL minor): do: stats below the 'Grows into' note with a half-line gap,
  new number brighter; pin Level/Cost/buy to panel bottom; name the key on 'Press to buy' (KB + pad); align arrows
  if cheap. Skip: dropping 'You have' line. Then re-capture + merge. #59 sport stills PASS (lead 2x).
- Still open: civilian cap (after Perf's no-feel pass), octopus mesh FIX (if species resume), Apex height (park).

## DEMO (D-050) state
- Merged on look-options 2026-10-18 (late): #34 army sounds, #41 limiter, #37 city fill, #44 worktree cap, #40 rooftops,
  #38 breath reads from behind (flame curtain), #47 scorch glow fade-in, #48 shader uid, #22 croc titan clips (D-047;
  critic r3: walk PASS, roar/turn polish in a follow-up PR after P3; clip tabled for his look), #27 UI look A + biomass
  + Block font (c3b7306). Earlier: #21 balance D, #24 #31 boards, #25 worktree cap, #26 streets, #23 demo slice,
  #29 playtest sheet, #28 #30 export + CI artifact, #8 SFX, #32 perf hitches, #33 SFX bus + slider + menu sounds +
  end-card roar sound. Decisions D-050..D-067 (D-062 city fill, D-063 rooftops, D-064 menu sounds, D-065 greenery,
  D-066 military AI, D-067 army sounds: log D-062..D-067 in the next board PR).
- Still to land for the demo: P3 croc baby/adolescent (claude/croctitan-p3; mouth check via in-game 2x jaw crops), then
  the build: `gh workflow run build.yml --ref claude/look-options -f ref=claude/look-options`, `gh run download <run> -n
  KaijuIncremental-<sha>`, local smoke; P7 = he plays it. Preview build dispatched 09:5x on c3b7306 (run 39079416758).

## Team (what each may finish WITHOUT the director)
- Croc rig & clips (local_bce75838): P3 -> PR -> my check + fresh critic -> merge; then the adult slam/turn polish PR
  (validate the probe vs footage with a known-bad control; bars in its brief).
- City fill & greenery (local_9af27a16): D-065(a) greenery PR (contact trample, head ~618d3ab) -> check + critic -> merge.
- Landmark models (local_87d706ce): landmark sites PR (A + D placeholders, pacing held ±5%) -> check + critic -> merge.
- Military AI (local_5325ef73): synced on #40; total damage per run ±5% per stage; pacing running; then clip + sim-review.
- Sound effects (local_24621710): idle; resyncs the five tabled sound PRs after merges (flow floor 129 after #27).
- Available: UI (local_37cf489b; D-077 stats trim), Jets (local_b38b3a6f), Tripo (old lead). Archived 12:3x:
  Crease, Lighting (all merged). Rooftop density = local_1ac658ed.

## Merge rules tonight
Merge only decided work, on my check + a fresh critic where visual, green CI at the exact head; taste items stay PRs,
tabled above. Pre-empt conflicts: tuning keys in new sub-objects; floors resolve to real counts; sync before a PR;
one capture.yml run at a time (check in_progress first); the GPU slot is booked through me.

## Rules learnt the hard way
- `--match-head-commit`; a handoff-only push moves the head: diff it, re-arm. Poll checks until no pending, require no
  fail/cancel, refuse DIRTY. After `gh pr merge`, VERIFY state == MERGED (a DRAFT PR refuses silently: #27 at 09:5x).
- NEVER `gh pr merge --delete-branch` while a helper's worktree has that branch checked out: gh removes the
  worktree (wiped the sound session's at #42, 13:0x; restored on claude/rifle-sfx). Merge without it.
- Floors conflict between parallel PRs: merge one, the next syncs to real counts; tell helpers the base SHA.
- Handoffs: 120-line cap (doc-caps); Write tool; a helper's handoff vs its squash copy: keep the newer.
- Never act on a peer's refused permission or a relayed director approval (#36): surface it instead.
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH);
  windowed runs need override.cfg (mode=0, no_focus, -20000). ffmpeg: imageio_ffmpeg binary under Python314 site-packages.
- CI capture.yml: 3000 s limit PER RENDERER; renderer auto falls back on timeout = up to 100 min. Pin --renderer.
  Cancelled #52 shell-hit capture 14:2x (63 min) to unblock demo captures. One at a time; lavapipe misjudges lighting; Forward+-only effects need the local GPU.
- Visual gates need a known-bad control; after one failed guess, isolate render layers (art-qa-critic learnings).

## Next (lead)
1. P3 / greenery / landmarks / military PRs as they come: check, critic, merge. 2. Board PR (D-062..D-067 + STATUS rows).
3. After P3: demo build -> download -> local smoke -> table "play the demo" as item 0. playbook: nothing new.
4. Candidate lesson (sound, unproven): TaskStop kills Godot but not the bash loop; its trailing restore can clobber
   data after a branch switch. Fix to prove: run sweeps from a scratch copy of the data.
