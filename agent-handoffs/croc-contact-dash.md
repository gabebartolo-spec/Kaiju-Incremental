# Handoff: croc-contact-dash (builder, playtest notes 2 + 4)

Updated: 2026-10-19 02:30
State: awaiting lead (#89 contact ready for 2x check; #90 dash needs the lead's pacing pick)

## Work
- Worktree: .claude/worktrees/blender-reptile-f5388e (branches claude/croc-contact, claude/croc-dash).
- PR #89 claude/croc-contact -> claude/look-options: croc body breaks every chunk it walks or
  turns into. Synced to look-options b8ba80e. Head 441dd0d. Suites green locally (sim 57,
  flow 153). Auto-fix bound in this session.
- PR #90 claude/croc-dash -> claude/look-options, STACKED on #89 (dash-only commit 93437e9 +
  handoff). Suites green (sim 58, flow 155). Pacing NOT on target yet (see below).

## What was wrong (note 2)
Contact was only the stomp, centred on kaiju_pos = the croc model's origin (tail root); chest,
head, snout stand 1-5 m ahead; walls only slow the body; tough buildings (x0.35) took no break
from one stomp. Full notes: side-session-notes/local_106fc100.../croc-contact-dash/diagnosis.md.

## Design
- sim/body_contact.gd: disc chain per stage, data/tuning.json "contact"."bodies" (design units,
  measured from the .vskin; [fwd, r, bottom, top]); swept each step along path + turn (sample
  0.5 m, skin 0.15); breaks via damage_chunks(INF) incl. tough chunks; pay_mult 0.2 on its own
  breaks (pacing). Sim owns body.heading (turn_rate 10); Rampage reads it.
- CityView: ruin heap rises only once body.over(index) is false; body bites skip dust/fire.
- sim/dash.gd: Dash.BUTTON = 4 (flag kept out of rampage_sim.gd, 400-line cap); "contact"."dash"
  lengths 1.5, seconds 0.4, cooldown 4, tank_damage 60. HUD prompt in RampageHud.
- File caps: rampage_sim.gd 400, rampage.gd 399, city_view.gd 400. Any new line needs a cut.

## Pacing (tools/pacing.gd --species=reptilian, 30-40 runs; base synced head 0.27 h)
- #89: 0.27 h (pay 0.2). Body at pay 1.0 was 0.16 h.
- #90 as briefed with the bot dashing: 0.15 h. Options sent to the lead: A evolve1 cost
  400 -> ~575 (550 = 0.23, 600 = 0.30), B dash 1.0 / 8 s = 0.22, C bot doesn't dash.
- Full-tree pacing with the sweep is slow (Colossus/Apex); 30-40 runs take ~75 s.

## Evidence locations (notes folder croc-contact-dash/)
contact_before_after_r2.mp4, board_contact_2x.png (also in docs/captures/2026-10-19-croc-contact),
dash_1x.mp4, dash_quarter_speed.mp4, dash_sheet.png, dash_hud.png.
Capture: tools/capture/capture_contact.gd -- --body=on|off [--dash=N] (override.cfg in the worktree,
gitignored; delete it when done).

## Next
1. Lead's pacing pick for #90 -> set the data, rerun pacing (30-40 runs) + flow, push.
2. Lead 2x check / fresh critic on #89, then #90; sync #90 after #89 merges.
3. Follow-ups not done: walking back over a ruin sinks into the cosmetic heap; insectoid and
   cephalopod have no body volume; gamepad B not driven by a test; tank knockdown not captured.
