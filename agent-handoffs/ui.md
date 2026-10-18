# UI handoff, 2026-10-18 (final)
## State: available (#27 merged c3b7306; worktree removed)
Look A "Emergency Broadcast" on every screen (D-061), BIOMASS (D-056), our fonts with Block body at 85% (D-058). All in
the #27 body's Board and log, for the merge role.
Kit: scenes/ui_kit.gd (palette incl. ALERT and CRAWL_RED, contrast(), hazard(), ink(), panel/button/bar/tape/backdrop/
slider_look), hazard_box.gd, news_ticker.gd (cycle padded to the strip). Copy for the crawl lives in data/tuning.json
"news". Fonts are rebuilt by tools/fonts/build_fonts.py (STAMP pinned; digits solid in Claw).
Flow checks cover: crawl overlap and contrast, own fonts, no "rubble", label under node, reveal frame and prompt, Back,
end-beat hints.
Tabled for the director: the stats panel's 12 numbers (trim).
Follow-ups worth proposing: HUD crawl reacting to rampage events; species cards as threat dossiers; reveal "THREAT
LEVEL RAISED".
Findings (lead decides what gets recorded):
- A draft PR blocks the merge silently: check isDraft before merging. Today a watcher reported #27 merged while GitHub
  refused it.
- Timed-out or cancelled captures still download their finished shots.
- fontTools stamps "now" into the font head unless pinned.
- Concurrent lavapipe captures double each other's time.
- A label moved into a shared strip needs an overlap check.
