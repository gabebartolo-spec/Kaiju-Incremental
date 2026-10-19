# Director playtest of demo exe 1 (recorded 2026-10-20)

Cap: 150 lines.

Source: the director's own messages in the lead session transcript, 2026-10-18 11:44-14:48 (he typed them while
playing; STATUS.md dates the fixes 2026-10-19). Quotes are verbatim. Numbers are the order of his bullets; "playtest N"
in `docs/STATUS.md` uses them. Status as of 2026-10-20. Update this table when a PR merges (rule: every comment of his
goes here with owner, PR and status).

His opening: "ill drop feedback here as i play:" ... closing: "ive seen enough to pause the playtest, its not shippable
as is. its a very good start though, well done". Also: "Send the fix briefs now; keep adding my notes as they come."

| # | His words | Owner / PR | Status |
|---|-----------|-----------|--------|
| 1 | "rooftop gun chatter sounds like a type writer, its really annoying" | #80 rifle crack (merged); #86 hits on legs and tail (open, post-demo) | merged (#80) |
| 2 | "kaiju model phasing in and out of the buildings doesnt look good" and "to be clear the baby kaiju breaking in and walking around a building - hollowing it out - feels really cool, but it needs to be smoother and feel less janky/like you are phasing through solid surfaces without destroying them" | #89 croc contact (D-091 body breaks what it walks into; D-095 claw swipe; D-096 swipes undermine towers) | open PR, green at 8e7f2d2 plus later fixes |
| 3 | "atomic breath doesnt feel aimed, its hard to know where its going to land" | #83 breath from the snout (merged) | merged |
| 4 | "need a charge/dash" | #90 dash (stacked on #89) | open PR |
| 5 | "stadium audience shouldnt disappear so suddenly, let us kill them" | #78 crowd killable, #79 stadium 1.5x (D-090) | merged |
| 6 | "load times when you start a run could be quicker" | #84 next rampage loads about 3x faster | merged |
| 7 | "gunfire audio kicks in while the visuals are still loading" | #82 no rampage sound until the city has loaded | merged |
| 8 | "my first death only got me enough biomass for one upgrade which is fine, but my second death let be buy around 8 upgrades which felt like an unearned leap - my next death again only afforded me 1 upgrade, the cadence is wrong" | claude/young-retune (#85 closed, ramp carried); D-098 option A steady upgrades | built, awaiting PR |
| 9 | "smaller building ssouth of the spawn position dont seem destructible?" | Not the tier gate: backdrop boxes south of the old spawn point were not destructible | #88 (run start moves to the river, away from those boxes) | Fixed by #88 (verify in play after merge) |
| 10 | "my graphics card fan makes insane noises ive never heard before while running the game - frame rate is fine, however" | #77 frame cap, #92 Graphics Balanced at 4K (D-093) | merged |
| 11 | "military/roofdefence response is way too high from the word go, it should be more gradual to reflect a city caught unaware - have our reptilian emerge from a river to start each run" | river start #88 (open); army ramp #85 (draft); tanks #50 (D-066, open, paused) | open PRs |
| 12 | "Overall destruction doesnt look as natural as id like. its fine for a demo, but not a finished game, i want real dynamic destruction, actual physics and buildings than can be carved by giant monsters" (2026-10-18 14:48) | D-094 option A, spike #91 merged; build starts after demo exe 2 | decided; not started (by order) |

Also from the same playtest, bundled into the fixes above: smoke "probably still too much" (#81, merged).

## Notes with no PR yet

- 9: building south of the spawn not destructible. No PR names it.
- 12: real carving destruction, planned after demo exe 2 (claude/destruction-plan), not started.

Not found in the transcripts: any further numbered notes beyond these 12; if he gave more by voice or elsewhere, add them here.
