# croc-contact-dash handoff (green-up of PR #89), 2026-10-20
## Done (pushed to claude/croc-contact, merged origin/claude/look-options first)
- doc-caps: fixed by the merge (lead.md is look-options' version, 118 lines).
- flow "upgraded reptilian shows deflect / each upgrade has a sound": cause = with #89 the kaiju
  clears the city by ~50 s (tanks_destroyed 0, tanks hold standoff 24 m+ outside reach 14 m), so
  autoplay never drew a tank_fired event. Fix (test only): tests/lib/flow_tanks.gd walks the kaiju
  to the nearest tank at 30 s if none has fired (called from _check_powers). State it in the PR body.
- military "no two tanks as drawn ever touch (5 pairs, closest 4.90 m)": a #50 convoy defect that #89's
  path exposed (sim/army.gd, convoy.gd untouched). Tier 1 seed 2 steps 531-535: tank 4 parks at entry
  node (42,4), tank 0 parked 4.9 m away inside each other's `clear` margin; the pivot rule only blocked
  a NEW clash, so from inside one any pivot was allowed and both swung until drawn hulls touched.
  Fix: sim/tank_spacing.gd blocker() pivot branch also blocks a pivot whose drawn parts touch with 0
  margin (new hull_touch(), no threshold changed). Named case: tests/run_military_tests.gd
  _check_pivot_beside_parked (failed first: 5 touching of 828 close pair-steps; now 0).
## Verify
`GODOT=<console exe> tools/run_tests.sh --quick military flow sim` all passed locally; gdformat/gdlint
clean on touched files. Not run: full suite (CI).
## Left
- Watch tests + lint on the new head; PR body must mention the flow test change and the convoy fix.
- Earlier open items in croc-contact.md (capture review, PR body evidence).
