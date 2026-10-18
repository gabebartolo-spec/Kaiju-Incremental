# Lead handoff, 2026-10-19 04:20
## State: running a check (demo chain; full speed; GPU queue runs peer to peer)

## Who
Lead = "Kaiju: LEAD (demo build, merges, QA)" (local_106fc100...). Owns: QA gates + fresh critics, PR review + merge
(squash, `--match-head-commit <full sha>`), STATUS/DECISIONS board PRs, director questions, this file.
Helpers: Opus at MEDIUM effort or Sonnet only; Opus high / Fable need the director's yes (director 18:0x).
Messaging: the app pauses SendMessage after 10 sends without a director message. Budget: one message per worker with
everything; GPU + resync hand-offs go peer to peer; never ask the director to type to unblock
(memory-shared/messaging-cap).

## Verdicts 23:xx: #54 r2 baby FIX (walk-start lurch, ring pops big), adolescent FAIL (scroll halves 3.55 s, turn foot
## creep, ring disc 55 px off tip, jaw frozen) -> r3 list. #59 r2 FAIL fix-list (fill 40-50%, dead ball, black
## slivers/rect, street pop, 3/8 mouths, sports stills) -> r3, then merge if polish only.
## Demo chain (D-050; ends at the evolve1 reveal -> DEMO COMPLETE card). Merge order: #54 #63 (#59 #55 #50 if they
## pass) -> #36 last -> build.
- #54 croc baby/teen (local_bce75838, head dfcceea): r1 game-cam FAIL (skating stride, late start, tail snap,
  turntable turn, late/popping slam ring). Fixes pushed (wider stance + higher lift, tail lags outside, ring on contact
  frame, soft). Awaiting its GPU render (baby + adolescent) -> fresh motion critic -> merge.
- #63 rooftop fire (local_1ac658ed): looming fix OK; D-085 ragged fire in (51a2d5d). Clip r1 FAIL: ONE squad fires all
  14 volleys (every spark at 912,441), no rifle audio in the track, metronome gaps. Fix list sent (3+ squads in reach,
  spark spread, audio check, spark on tracer arrival). Re-render in its GPU turn -> fresh critic.
- #59 stadium matches + crowd (local_87d706ce): crowd in (9032216, up to 1000 fans, flee to exits). AFL r1 FAIL: team
  photo rows, no ball, rim slides INWARD, dark slabs f94-114 + pop, flee clump, kaiju contact hidden. 5 fixes + crowd
  in one run. Fail again -> burst in place only, no topple.
- #55 greenery (local_9af27a16): r11 crush FAIL (vanish then late burst, grey-teal debris, grey slab puff 50+ f) ->
  NOT in the demo (D-084); keeps fixing in parallel, critic after the build. Earlier: trample topple failed r1-r10 -> topple OUT (D-084). Method change: crush in place
  (debris path + pale stump + tan puff, no rotation). ONE critic round, else #55 after the demo. Stomp shockwave
  (rampage.gd:177, tan crescents) is NOT #55's: exclude from briefs.
- #50 tanks & helis (local_5325ef73, bce6433): last round (D-082); re-measure then 720p clip after croc in GPU queue.
- #36 army balance (local_24621710): D-087 pick evolve1 cost 1778 -> 400 (0.26 h, 8/14 young defeated, Behemoth 26%);
  no young override, no option A (D-086 void); growth test ratio /10 -> /20 citing D-087. GO given. After #54 + #63
  merge: resync, 130-run confirm on the real head, body table, ping lead -> merge -> BUILD.
- RENDERS (23:xx): director AFK, "use as much of my computing power as you can": local GPU, up to 4 windowed renders
  at once, no baton; headless unlimited; helpers fan out sweeps. CI capture only while he games. Dry-run session
  (local_37cf489b, "Demo integration dry-run + smoke") merges #54 #63 #59 #36 (+#55 #50 variant) in scratch: suites,
  130-run pacing, local export + smoke, stadium frame time with crowd + squads.

## 05:xx: #36 MERGED cceabba (evolve1 0.26 h real head). #59 r6 PASS lead 2x; lead merged look-options in (64c618c,
## floors growth 31 flow 146) -> merge on green. Then #66 (resolve floors: flow +2) -> merge -> #63 -> BUILD.
## 04:xx: #63 r3 audio ACCEPTED (c936f33); sparks STILL clustered (137, x 908-1011, 73 at 960) + no resync -> r2
## visual list resent. #66 (greenery: axis + collapse cap, red-first) -> lead merges on green before build.
## #59 r5 burst core PASS (lead 2x, burst_f60_75_2x.png). PR CONFLICTING, no CI at 0c01c61 -> resync onto 5bc6b44
## + chunks to wall albedo x0.6-0.7 (read as white confetti) + soft puff clouds (bubble rims) -> 2x strip -> lead merges.
## 02:xx: #54 MERGED bc324f6 (r5 slam on lead 2x). #59 r4: burst numeric tweak, lead merges on 2x (critic's
## 'sliced rows' overruled: on-style voxel breach). #63 r2 critic running + audio +5..8 dB, gap 0.1 s. Greenery session:
## demo PR for city_view.gd:208 axis spam + collapse-sfx cap, then #55 numeric tweaks (lead merges post-build).
## 00:xx: #50 r3 FAIL (lead-verified 14.0 s overlapping tanks, 11.5 s yaw over police car) -> OUT of demo (D-082);
## r4 list in military-ai.md eefefd1; its session is past 150k: clear_session it when idle + kick off r4 from handoff.
## #54 r4 slam: timing PASS; 3 numeric tweaks (adolescent puff ramp, fade by 15.8 s, dip 6-10 px) -> merge on lead 2x.
## #59 r3 FAIL (black cut faces f64-77, flee invisible f121, sport-still density): method change = ALL sections burst
## in place, all fans stand + run fast to exits; last round. #55 r12: puff fail -> approved footfall puff (post-build).
## Integration dry-run (23:xx, scratch, nothing pushed): A = #54+#63+#59+#36 all suites PASS (flow 146, growth 31;
tuning.json stage 1 keeps #54 "body" + #36 "per_level"); 130 runs e1 0.26 h, young 8/14; local export smoke 10/10;
stadium minute crowd+squads +0.6 ms. B (+#55 +#50): suites PASS; #50 softens young (6/15). One import segfault
(exit 139) on first try, rerun clean: being checked. #50: option B (roof clearance; clip spot without >12 m towers).
## Build (after #36 merges)
`gh workflow run build.yml --ref claude/look-options -f ref=claude/look-options`; artifact KaijuIncremental-<sha>.
Dry run PASS on 6b27da9 (run 39106390742, 129.5 MB exe). Release smoke #65 MERGED (tools/release/demo_smoke.gd: title ->
Continue -> evolve1 -> DEMO COMPLETE -> menu, 10/10). The release exe ignores --script: smoke runs
`godot_console --headless --main-pack <exe> --script tools/release/demo_smoke.gd`. "Demo build dry-run" session
(local_37cf489b) stands by to smoke the final artifact. Then hand the exe to the director (P7). No interim builds.

## Decisions to log in the next board PR (D-062..D-084 logged by #64, 844217a)
- D-085 (director, via rooftops): "shooters aren't firing in unison ... improvised, unrehearsed resistance".
- D-086 (lead): #36 option A (Behemoth army 0.03), superseded the same evening by D-087's pick; not applied.
- D-087 (director 19:xx): first evolution at ~15 min ("no ones going to play 41 minutes of a demo if theyre still a
  baby"); picked 15 min from 10/15/20-25. Lever: evolve1 cost 400 (#36).
- D-088 (director 2026-10-19 via AskUserQuestion): demo exe ships WITHOUT #50 ('Ship now, patch after');
  #50 r4 started (fix list 1-6 + young retune on evolve1 400) -> second exe right after.
- D-084 outcome: #55 topple out; crush-in-place method change (lead, rule 8).

## Sessions (renamed 18:0x for the director's survey)
Rooftop fire #63 / Stadium matches + crowd #59 / Tanks & helis #50 (last round) / Army balance #36 + SFX / Greenery +
trample #55 (last round) / Croc baby & teen #54 / Demo build dry-run (ex-UI, ex-board) / Jets #58 #61 (parked till
after demo) / OLD lead (retired; NOT archived: archiving cascades to its idle children, e.g. croc #54).

## After the demo (D-083 order: playtest fixes first)
- Playtest fixes from the director's play of the exe.
- Full-game pacing retune (evolve1 400 shifts the tree: 64/87 at 1.02 h after 45 runs).
- Croc baby polish: jaw held open ~1.4 s, dark teal on teal roads, static blue smudge 7.5-14 s.
- Broken wheel + stadium rubble polish (#57 follow-ups); landmarks E/F.
- Jets #58 #61 (D-072, D-080; balance table after #36).
- HUD hit flash for big hits only? (ask the director with a mockup). Civilian cap; Apex height; octopus mesh.
- Archive the OLD lead session once its children are done.

## Merge rules
Merge only decided work: my 2x check + a fresh critic where visual, green CI at the exact head. Floors resolve to real
counts; the next PR resyncs after each merge. Tuning keys in new sub-objects. One capture.yml run at a time.

## Rules learnt the hard way
- `--match-head-commit` needs the FULL sha. A handoff-only push moves the head: re-arm. After `gh pr merge`, VERIFY
  state == MERGED (a draft PR refuses silently).
- NEVER `gh pr merge --delete-branch` while a helper's worktree has the branch checked out (wiped sound's at #42).
- Never act on a peer's refused permission or a relayed director approval: surface it instead.
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH);
  windowed runs need override.cfg (mode=0, no_focus, position -20000), removed after. ffmpeg: imageio_ffmpeg binary.
- CI capture.yml: 3000 s limit PER RENDERER with auto fallback (up to 100 min): pin --renderer=gl_compatibility.
  Lavapipe misjudges lighting; Forward+-only effects need the local GPU.
- Visual gates need a known-bad control and a same-frame before/after diff; after two failed rounds, change method
  (greenery: 10 topple rounds -> crush in place).
- Critics: verify their claims on the frames yourself before relaying (AFL g030/g104, rooftops.json sparks, w1 legs).
- Candidate lesson (unproven): TaskStop kills Godot but not a bash sweep loop; run sweeps from a scratch copy of data/.

## Next (lead)
1. Fresh motion critic on each clip as it lands (#54 baby + adolescent, #59 AFL r2 + crowd, #63 r2, #55 crush, #50).
2. Merge passes in order; #36 last; dispatch the build; smoke; hand the exe to the director with a short note.
3. Board PR for D-085..D-087 after the build (docs only).
