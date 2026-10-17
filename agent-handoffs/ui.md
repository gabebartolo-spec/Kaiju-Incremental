# UI handoff, 2026-10-18 (late)
## State: awaiting lead (screen-critic round 2 on 4k125-r2; lead merges #27 at 4e64281 on PASS)

## Task
Director (2026-10-18, chat): "you are User Interface, buttons, menus; make the game UI thematically
rich, beautiful and intuitive; full licence to create our own assets". Lead = "Kaiju: Lead"
(local_106fc100); holds QA gates and merges. Report <=8 lines. Director asleep: no questions.

## Freeze
Lead: no pushes to claude/ui-broadcast until #27 merges at 4e64281. This handoff commit is LOCAL
only; push it (or redo it on look-options) after the merge.

## Decisions in #27 (PR body "Board and log")
- D-TBD-ui-look-broadcast: look A "Emergency Broadcast" (director picked from mockups A/B/C).
- D-056: currency reads BIOMASS on screen; keys/save unchanged.
- D-058: body Kaiju Block (85% width, approved 05:58), headings Kaiju Claw, capitals only.

## Branch / PR
claude/ui-broadcast, worktree ../Kaiju-Incremental-wt/ui-broadcast, PR #27 into
claude/look-options, Auto-fix on. Synced through #22 (8065ebd). Floors: flow 126, clips 14.
Every base move = floor conflict: base flow + 9 (title fit, currency, fonts x2, demo controls,
end-beat hints, species Back, reveal frame x2); the label-under-node rule lives inside the
existing tree fit check (no new count).

## Built (see PR body for the full list)
hazard_box.gd, news_ticker.gd, ui_kit.gd (palette, hazard, ink, panel/button/bar/tape/backdrop/
slider_look, buttons keep Sfx click); tree/title/HUD/results/settings/species/reveal/demo card
restyled; biomass strings; fonts (glyphs.py clean zero, STAMP, Block D_SX 0.85; project font);
data/tuning.json "news" (title + report reactions); EvolutionReveal.frame_view shared with DemoEnd;
species select BACK (Esc/B); demo controls rows filtered by Demo.allows; end beat clears
CityView.FLOAT_TEXT; tree caption in the first free band spot.
Captures: docs/captures/2026-10-18-ui-broadcast/ mockup_*, body_font_*, 1080/, 4k125/, 4k125-r2/.

## Next
1. If the critic FIXes: fix, ask the lead before any push (freeze).
2. After merge: remove the worktree (`git worktree remove ../Kaiju-Incremental-wt/ui-broadcast`),
   push this handoff via a docs PR or hand it to the lead.

## Not mine / tabled by the lead
Stats panel's 12 numbers (design trim for the director); "Croc Titan" naming (keep).

## Follow-ups worth proposing
HUD crawl reacting to rampage events; species cards as threat dossiers; reveal "THREAT LEVEL RAISED".

## Findings for the lead
- Timed-out or cancelled captures still download finished shots: usable for early QA.
- fontTools stamps head.created/modified with "now": pin them or rebuilds never match.
- Concurrent lavapipe captures double each other's time and hit the 3000 s limit.
- Moving a label into a shared strip needs an overlap check: nodes from the row above can
  reach into it (caught by the r2 capture, now a test).
