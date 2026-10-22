# director-cleanup handoff, 2026-10-23 (builder 2)
## State: PR #162 open and ready (claude/director-cleanup). Touched suites green after the final merge; CI runs the full suite. Nothing running.
## Task (lead, D-136 and D-145)
1. Rename the croc's beam to "Thunder Beam" everywhere player-facing, from ONE data string.
2. D-136: cut the breath camera swing. 3. D-136: remove the BRANCH/CAPSTONE labels. 4. D-136: cut the headline "AIR FORCE GROUNDS ALL HELICOPTERS".
5. D-145: roar on every ultimate and every dash (existing roar sound), rate-limited by a data cooldown.
## Built
- data/tuning.json "names": {"beam": "Thunder Beam"}; Content._fill replaces "{beam}" in tuning, upgrades and species text at load. species.json ability name, upgrades.json r_beam ("ULTIMATE: {beam}") and tuning beam_dps line use it. A rename is that one line. (D-112 had called the signature "Lightning Breath" and the ultimate "Thunder Beam"; the data still said Atomic. Both now read the one name, so the HUD signature and the tree ultimate both say Thunder Beam: flagged to the lead.)
- BreathCamera deleted, Rampage no longer offsets the camera on the breath; fx orbit_* keys gone; tests/lib/stream_view.gd lost its swing phases (rest, walks and dash stay; margin check is now margin >= shake).
- TreeArea caption "X BRANCH - only the X can grow these" gone (CAPTION_HEIGHT room too); upgrade screen role text: branch "", ultimate "ULTIMATE".
- tuning news report: the helis line gone (the "helis" stat stays in saves).
- Roar: RampageSim emits {"type":"ultimate"} from SpeciesPowers.ultimate(); RoarCue (scenes/roar_cue.gd, owned by PowersView; dash and ultimate events) plays Sfx.roar, and the roar pose on an ultimate only (a roar clip would hold a charging body still); at most one per sfx.roar_cooldown 5.0 s of run clock (sim.time_left). Test: tests/lib/flow_dash.gd _check_roars. tests/lib/flow_names.gd: the tree shows "ULTIMATE: <names.beam>".
## Not exercised
No clip. The roar sound itself was not listened to (counted, not heard).
