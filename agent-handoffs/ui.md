# UI handoff, 2026-10-18 07:30
## State: running a check (4K-at-125% CI capture queued behind greenery's capture)

## Task
Director (2026-10-18, chat): "you are User Interface, buttons, menus; make the game UI thematically
rich, beautiful and intuitive; full licence to create our own assets". Lead = "Kaiju: Lead"
(local_106fc100); holds QA gates and merges, relays director decisions. Report <=8 lines.
Director asleep from ~06:40: no questions to him; #27 merges on lead check + fresh screen-critic.

## Decisions in #27 (PR body "Board and log"; merge role records them)
- D-TBD-ui-look-broadcast: look A "Emergency Broadcast" (director picked from mockups A/B/C).
- D-056 (05:08): currency reads BIOMASS on screen; keys/save unchanged.
- D-058 (05:13): body text Kaiju Block, headings Kaiju Claw, capitals only; Block ships at 85%
  width so tree names fit at 125% (director approved 05:58).

## Branch
claude/ui-broadcast in ../Kaiju-Incremental-wt/ui-broadcast; PR #27 (draft) into
claude/look-options, Auto-fix on. Head c898eec. Synced through #41 (flow base 113, mine 119).
Every base move = floor conflict: resolve to base + 6, run all suites, push.

## What is built
- hazard_box.gd (tape/edge/inner focus ring), news_ticker.gd (crawl, REPEAT 4), ui_kit.gd
  (palette A, hazard(), ink(), panel/button/bar/tape/backdrop/slider_look; buttons keep #33's
  Sfx.ui("ui_click")), upgrade_node.gd, title/HUD/results/settings restyled.
- Biomass strings; Hoarder desc; VISION.md.
- Fonts: build_fonts.py STAMP (A-C byte-identical), D Block (D_SX 0.85); project.godot
  gui/theme/custom_font = kaiju_block; licence row.
- Settings: CONTROLS row may carry a species id; hidden unless Demo.allows() it.
- End beat clears CityView.FLOAT_TEXT group each frame (city_view.gd 400/400, rampage.gd untouched).
- Tests: crawl overlap + title fit; listen() -> currency_named(), fonts_ours() (screens + demo end
  card); demo controls rows; end-beat hint. All shown failing first. Save checks moved to
  tests/lib/flow_save.gd (flow_screens.gd was 406 > 400 after #33).

## Next
1. 4K125 capture (background task waits for capture 39068644051, then dispatches) ->
   docs/captures/2026-10-18-ui-broadcast/4k125/. 2x pass, send path to the lead.
2. Then 1080 re-shoot (capture_flow) for reveal, tree-after and the fixed crawl/sliders/end beat.
3. Lead runs the screen-critic; fix its findings; lead merges.

## Not mine (reported)
Species card crops the kaiju's head: #22's framing.

## Follow-ups worth proposing
HUD crawl reacting to rampage events; species cards as threat dossiers; reveal "THREAT LEVEL RAISED".

## Findings for the lead
- A cancelled or timed-out capture still downloads its finished shots: usable for early QA.
- fontTools stamps head.created/modified with "now": pin them or rebuilds never match.
- Concurrent lavapipe captures double each other's time and hit the 3000 s limit.
