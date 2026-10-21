# UI handoff, 2026-10-18 18:40 (final)
## State: available (D-077 MERGED #51 997f516; this session is now "Board & decision log", see board.md)
Look A "Emergency Broadcast" (D-061), BIOMASS (D-056), our fonts (D-058) in #27; D-077 plain-word tree stats in #51:
the panel lists only the node's stats from data/tuning.json "stat_text", words then "now -> next" in a fixed arrow
column, Level / Cost / "Press Enter / pad A to buy" pinned to the bottom (flow check).
Kit: scenes/ui_kit.gd, hazard_box.gd, news_ticker.gd; crawl copy in data/tuning.json "news"; fonts built by
tools/fonts/build_fonts.py (STAMP pinned).
Tabled (lead): a HUD hit flash for big hits only (tank shells)? Taste; ask the director after the demo (D-083).
Follow-ups worth proposing: a HUD crawl that reacts to rampage events; species cards as threat dossiers; a "THREAT LEVEL
RAISED" line on the reveal.
Findings (the lead decides what gets recorded):
- A draft PR blocks the merge silently, so check isDraft before merging.
- Concurrent lavapipe captures double each other's run time; pin --renderer=gl_compatibility for UI-only captures.
- Base floors move with every merge: resync once, right before the merge, in the lead's merge order.
