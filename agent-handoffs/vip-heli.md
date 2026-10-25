# Handoff: vip-heli (leader's escape helicopter, D-149)

## State
Building. Sim, view, data, tests written; local suites and the clip pending (see Unfinished).

## Task
ROADMAP "Leader's escape helicopter" (D-149), director go 2026-10-25 via the lead. Branch claude/vip-heli,
worktree ../Kaiju-Incremental-wt/vip-heli, no PR (the lead opens it; body in pr-body.md).

## Design as built
- sim/vip_heli.gd (VipHeli, own seeded stream 0x71B): waiting -> flying -> killed/escaped/none. Lift-off at
  a seeded share of the run (tuning vip.window) off a mid-rise roof; banked lap, then a dash to the edge,
  ~15 s total. Kills: hit_area (breath, beam, ink, limbs; reach rule hit_air or reach_top >= altitude),
  tower topple strip (fall_start), thrown tank/car in flight, tentacle grab while low, burn coat.
  Falls via AirWing._spin_down (private call; the heli-standoff PR must keep it).
- Hooks: rampage_sim.gd (vip field, _step_sky, hit_area, result), tentacles.gd (_grab_vip, _throw extract).
- View: scenes/vip_view.gd (model, rotor 3D player from heli_rotor.ogg at pitch 0.75, NewsTicker strip,
  own HeliWreck); HelicopterModel.vip_look; Rampage routes events through VipView.on_event first.
- Data: tuning.json "vip" (payout per tier ~ mean block worth: 38/40/40, measured by tests/lib/vip_block.gd).
- Tests: tests/run_vip_tests.gd (+ tests/lib/vip_block.gd, vip_view_check.gd). Capture: tools/capture/capture_vip_heli.gd.

## Unfinished
Run touched suites (tentacles helideaths sim powers vip flow); clip (--windowed, override.cfg off-screen);
pr-body.md; push; report to lead.

## Rules learnt
gdformat on Windows writes CRLF: sed -i 's/\r$//' after it. Warnings are errors in GDScript here (type every var).
