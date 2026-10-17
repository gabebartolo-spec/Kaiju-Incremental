# UI handoff, 2026-10-18 05:35
## State: running a check (full local suites after syncing look-options with #8)

## Task
Director (2026-10-18, chat): "you are User Interface, buttons, menus; make the game UI thematically
rich, beautiful and intuitive; full licence to create our own assets". Lead = session "LEAD"
(local_106fc100); it holds QA gates and merges, relays director decisions. Report <=8 lines.

## Decisions in this PR (#27, for the merge role, all in the PR body's Board and log)
- D-TBD-ui-look-broadcast: look A "Emergency Broadcast" (director picked from mockups A/B/C).
- D-056 (director 05:08): currency reads BIOMASS on screen; keys/save unchanged.
- D-058 (director 05:13): body text Kaiju Block (our plain face); headings Kaiju Claw; capitals only.

## Branch
claude/ui-broadcast in ../Kaiju-Incremental-wt/ui-broadcast; PR #27 (draft) into
claude/look-options, Auto-fix on. Merged look-options at 9b52e83 (#23 demo) and again after #8
(47e1b30); flow floor resolved to 104 (100 base + my 4) pending the full run's real count.
#22 lands before #27: sync again after it.

## What is built
- scenes/hazard_box.gd: StyleBox (fill setter emits changed, solid/dashed edge, tape band, focus
  ring drawn INSIDE the edge: an outside ring covered the Reach bar on species select).
- scenes/news_ticker.gd: BREAKING crawl, label full strip height, text centred.
- ui_kit.gd: palette A (+ALERT), hazard(), ink(), panel/button/bar/tape/backdrop+Scanlines.
- upgrade_node.gd, title_screen.gd (kicker, tape, crawl), rampage_hud.gd (plates, clock block),
  results_screen.gd (crawl from ResultsScreen.news()).
- Biomass strings: main.gd, pause_menu, rampage_hud, upgrade_screen (counter, costs, stat row),
  results_screen (row, verdict), data/upgrades.json Hoarder desc, docs/VISION.md.
- Fonts: build_fonts.py STAMP pins head timestamps (A-C byte-identical, cmp), style D Block ->
  assets/fonts/kaiju_block.ttf; project.godot gui/theme/custom_font = kaiju_block; licence row.
- Tests (flow): crawl overlap in fits_at_scales + title fit; FlowLayout.listen() over HUD, pause,
  results, title, tree, demo end card -> currency_named() and fonts_ours(). All shown failing
  first (crawl 12 misses with a planted 700 px crawl; currency 7 hits; fonts 70 texts).
- Captures: docs/captures/2026-10-18-ui-broadcast/ mockup_{A,B,C}.png, body_font_{1080_2x,4k125}.png.

## Next
1. Full suites green -> set flow floor to the real count -> push.
2. CI: ci_capture.sh --resolution=1920x1080 capture_flow.gd -- --species=reptilian
   --out=docs/captures/2026-10-18-ui-broadcast/1080; capture_demo.gd (1080);
   --resolution=3840x2160 capture_flow.gd -- --ui-scale=1.25 --ui-only (4k125). One at a time.
3. Own 2x pass (art-qa-critic), then send the lead the paths; lead runs the screen-critic.
4. Watch: Kaiju Block caps are wider than the old body font; tree nodes and the side panel may
   pick smaller sizes; the layout checks will catch overflow.

## Follow-ups worth proposing
HUD crawl reacting to rampage events; species cards as threat dossiers; reveal "THREAT LEVEL RAISED".

## Findings for the lead
- A capture cancelled mid-run still downloads its finished shots (4 of 11): usable for early QA.
- fontTools stamps head.created/modified with "now": pin them or font rebuilds never match.

## Running jobs
Full local suite run (background shell in this session).
