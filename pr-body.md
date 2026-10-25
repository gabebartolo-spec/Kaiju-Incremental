## What the player sees, and why
Once a rampage, at a random moment, the city's leader (Mayor in the baby city, Governor in the adolescent, President in the adult) lifts off a mid-rise roof in a white-and-gold helicopter, flies one banked lap while climbing, then runs for the map edge, about 15 s in all. A BREAKING headline on the news strip announces it and a lower, louder rotor tells you where; no markers. Bring it down (breath, Thunder Beam, a tower toppled across it while it is low, a tentacle's grab while it is low, a thrown tank or car) and you are paid about a city block's biomass; let it escape and only that payout is lost, with a mocking headline. The result screen's news mentions either.

## Assigned in
ROADMAP "Leader's escape helicopter" / D-149 (director go 2026-10-25 via the lead).

## What changes
- `sim/vip_heli.gd` (VipHeli): own file, own seeded stream (0x71B), no draw shifted elsewhere. waiting -> flying -> killed / escaped. Lift-off at a seeded share of the run (`vip.window`) off a seeded standing mid-rise near the kaiju; climbs over `climb_seconds` on a banked lap, then dashes to an edge point away from the kaiju so the flight takes `window_seconds`. Kill rules: any area hit that reaches its height (`hit_air` or `reach_top() >= altitude`, called from `RampageSim.hit_area`), a toppling tower's strip (`fall_start`), a thrown tank/car in flight, a tentacle grab while low, a burning coat. A kill pays `payout[tier]` x rubble_mult; it falls with AirWing's fates (burst / spin / grabbed) under its own id.
- `scenes/vip_view.gd` (VipView): model, own 3D rotor player (the cleared `heli_rotor.ogg` at pitch 0.75, +4 dB, no new audio asset), headlines on the existing `NewsTicker`, its own `HeliWreck`. `HelicopterModel.vip_look` recolours its own copy of the voxels white with a gold band and gold rotors, no gun. `Rampage` routes events through `VipView.on_event` first and includes the leader in the see-through fade.
- `data/tuning.json` "vip" (all numbers, headlines and look) + two result-news lines. `payout` 38 / 40 / 40 = the mean block's worth per city size (measured, `tests/lib/vip_block.gd`).
- Small hooks: `rampage_sim.gd` (vip part, `_step_sky`, `vip.hit` in hit_area, `result()` merges `vip_killed/escaped/paid`), `tentacles.gd` (`_grab_vip`, `_throw` extracted: `_grab` shrank, its complexity baseline row removed), `heli_wreck.gd` (optional event `y`).
- **Overlap with claude/heli-standoff-2:** `sim/air_wing.gd` is untouched. VipHeli reads `sim.air.cfg`, `sim.air._crashing` and calls `sim.air._spin_down(heli)` (private) so the leader falls like any gunship; if the stand-off PR renames those, VipHeli needs the same rename.

## Evidence
- Suites (local, full import first): Vip 13 of 13 functions, 38 checks, 0 failures; Tentacles 9/9, 20 checks; Sim 11/11, 77 checks; Flow 7/7, 249 checks; Powers 12/12, 28 checks; HeliDeaths 9/9, 28 checks (run before the final tidy, unchanged files). Lints: gdlint, gdformat, tuning_keys, complexity_ratchet clean.
- New checks shown biting: with payout 0, hit radius 0, throw_pass 0.1 and a 2 s lap the Vip suite failed 9 checks (breath, grab, thrown, payout fixture, flight time, payout vs block), then passed on restoring the data.
- Fixture / seed: army seeds 0-4 (window), seed 0 (flight, kills), city seed 0 (block payout).
- Player-effect fixture `vip.payout`: the same rampage with the leader shot down vs left to escape differs by exactly payout x rubble_mult (40.00 at the adolescent city).
- Clip (local RTX 4070 SUPER, off-screen no_focus override.cfg, 1920x1080 60 fps, adolescent city, run 1): `C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-AppData-Local-Claude-Data-claude-pzs8sxrjxfjjc-scratch-workspaces-23bb59b2-12fc-455a-80cb-fd98ed0fa64f-09d0f96d-1de0-4dfb-abe6-339b1dce6b9f-scratch-2026-10-24-a0833f/0d5932cd-964c-411a-968f-8ed9f5e3aa8c/scratchpad/vip_clip/vip.avi` (lift-off, breath kills it 1.1 s in, wreck falls; rubble 85.2). A still at 1.5 s shows the white body with gold band and rotors (judged only by the builder; needs the lead's art-qa-critic).

## Not exercised
- The croc has no grab or throw (those are tentacle powers), so grab and thrown kills are proven on the cephalopod's sim only; the croc's claw and stomp reach it only while it is low over the roofs (rule shared with the hit-height rule).
- Rotor sound heard by ear, headline placement over the biomass figure (bottom strip, 8 s), headline copy, the white/gold look at day, a day-time and 4K capture, a rampage that ends on the clock mid-flight, save round trip (nothing persisted).
- Kill by a toppled building proven with a synthetic `fall_start` event, not a real carved tower.

## Board and log
- ROADMAP "Leader's escape helicopter": Owner vip-heli builder, Status: built, awaiting art-qa-critic and review.
- D-TBD-vip-numbers (lead to confirm): payout = mean city block per city size (38 / 40 / 40 biomass); one leader a rampage inside 12-50% of the run; ~15 s window; headline copy is a builder draft.

## [MERGE NOTE]
- Hot files touched: sim/rampage_sim.gd (392 of 400 lines), scenes/rampage.gd, sim/tentacles.gd, data/tuning.json, tools/lint/complexity_baseline.txt (one row removed)
- Floors: none (suites found by filename); new suite `vip`, about 50 s
- Review needed: kaiju-sim-review by the lead's reviewer (new sim part, result keys, seeded stream)
- Director gate: look approval pending (white and gold VIP look, headline strip)
- Ordering with other PRs: rebase-free merge; coordinate with claude/heli-standoff-2 over `AirWing._spin_down`
