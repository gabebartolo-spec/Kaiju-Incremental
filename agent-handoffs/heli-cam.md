# heli-cam handoff (2026-10-20)

State: done, awaiting lead (fresh motion critic round 3, then the A/B question to the director).
Task: heli-cam option B round-2 FIX (slide-target pop, ghost heli), re-render A/B clips.
Branch/commit: claude/heli-cam at 7a83af8 (pushed). No PR (3-PR cap).
Unfinished changes: none. Capture-only; game code untouched. tuning.json gained `heli_cam`.
Clips + proof: C:/Users/DANTE/AppData/Local/Temp/claude/heli-cam3/ (A_today.mp4, B_eased.mp4,
frame_diff_table.txt, crops/). B diff at count changes 1.02-1.54x median (was ~3.6x).
Attempts: exponential lerp of the slide left a speed step (diff 8-10 then decay); critically
damped smooth-time fixed it. Popping helis out of sim.air.helis, or clear_dead() between steps,
leaves a ghost: sim events are rebuilt each step, so kill inside a step (coat_t + coat_dps).
Open decisions: none (A vs B is the lead's question to the director).
Running jobs: none.
