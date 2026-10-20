# Handoff: croc-contact-dash (builder, playtest notes 2 + 4, D-091)

Updated: 2026-10-19 04:00
State: awaiting lead (#89 D-091 rework pushed, round-2 clips on CI; #90 resynced, evolve1 425 provisional)

## Work
- Worktree: .claude/worktrees/blender-reptile-f5388e. Branches claude/croc-contact (#89, head f53482c)
  and claude/croc-dash (#90, head 5ca3c68 = a merge commit whose tree is the dash rebased on #89; no
  force-push allowed here, so updates to #90 go the same way: commit-tree with both parents).
- Both target claude/look-options, synced 2026-10-19. Suites green locally: #89 sim 58 / flow 153,
  #90 sim 59 / flow 155.

## Design (see #89 / #90 bodies for the full story)
- sim/body_contact.gd: disc chain per stage in "contact"."bodies"."reptilian"[i] = {"snout", "discs"}.
  Outsized buildings break outright (pay_mult 0.2); dwarfing ones (Growth.dwarf_mult =
  (size/tier)^dwarf_exp 1.5) are chewed at bite_dps 140 x mult and hold the body (`held`, `_hold`
  slides or stays). Chewed chunks pay in full. No "tough" event / TOO STRONG anywhere (D-091).
- scenes/body_bite.gd: a bite lifts the cells (lift_piece), tumbles them out, bursts debris.
  scenes/ruin_yard.gd: ruins moved out of city_view.gd; heap waits until body.over(index) is false.
- sim/dash.gd (#90): Dash.BUTTON 4; "contact"."dash" lengths 1.5, seconds 0.4, cooldown 4,
  tank_damage 60; a dash stops at a wall that holds the body. Pacing bot dashes.
- File caps: rampage_sim.gd 397, rampage.gd 392, city_view.gd ~358.
- gdformat on Windows writes CRLF: run `sed -i 's/\r$//'` on files after it, and before python edits.

## Pacing (40 runs, synced head; bar e1 0.26 h ±5%, young defeats 8/14 ±2)
- #89 bite 140: e1 0.26 h, young defeats 3/13 (low; army session retunes after merge).
- #90 + evolve1 425: e1 0.26 h, defeats 6/13. (Lead said A: keep the dash, move evolve1 cost;
  final number in ONE joint retune by the "Biomass + army ramp" session local_b38b3a6f.)

## Evidence (notes folder croc-contact-dash/)
- Round 1: contact_before_after_r2.mp4, board_contact_2x.png (in docs/captures too), dash_*.
- Round 2 (CI, software render): r2_tower_topple_ci.mp4, r2_tower_sheet.png, r2_tower_crops.png;
  walk on/off clips were rendering (capture.yml runs after 39142260893).
- Capture: tools/capture/capture_contact.gd -- --body=on|off [--tower] [--dash=N] (#90 has --dash).

## Open for the lead
- Tower clip: while tunnelling, the floors above hide the croc's front half from the high camera,
  and the toppling tower falls south across the croc (drawn through it). Fade or crush rules?
- Young defeats 3/13 with #89.

## Next
1. Lead 2x / fresh sim reviewer on #89; fixes as asked. Then #90 review.
2. After #89 merges: sync #90 (merge look-options in), rerun flow + pacing.
3. Follow-ups: insectoid/cephalopod volumes; gamepad B test; tank knockdown capture.
