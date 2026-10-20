# Director playtest of carving build 2 (recorded 2026-10-20)

Cap: 150 lines.

Source: the director's message to lead 8, 2026-10-20, after playing carving build 2 (3998051). Quotes are verbatim
(typos kept). Numbers are the order of his bullets; "build2-N" elsewhere uses them. The Phase column points at the
phase in `docs/ROADMAP.md` "Post-demo plan (2026-10-20)" that carries it. Rule: every comment of his goes here with
owner, PR and status; update the row when a PR merges.

| # | His words | Phase | Owner / PR | Status |
|---|-----------|-------|-----------|--------|
| 1 | "claw animation/arms in general are glitchy, with the arms twitching in a silly way rather than a swipe" | D | - | open |
| 2 | "tail swipe doesnt seem to be occuring? it should be acting autonomously, like an extra limb, make it a part of the upgrade tree" | A (is it firing?), D (autonomous limb), E (tree node) | - | open |
| 3 | "frame rate issues, not serious, but some slow frames during periods of heavy destruction" | C | - | open |
| 4 | "carving is improved but not perfect yet - it should feel effortless for even a baby Kaiju to destroy building matter - a building shouldnt have a health bar, it should be a phyiscal structure which obeys the laws of physics and simply must be dismantled" | C | - | open |
| 5 | "buildings seem to ALWAYS collapse toward our kaiju, i dont care if its realistic, make the collapse directions more varied" | C | - | open |
| 6 | "there are a lot of indestructible buildings in the game, they must be removed from the play area if theyre indestructible, ALL buildings in the play area must be destroyable" | A | - | open |
| 7 | "the camera doesnt let us see much of the city, reconsider its angle and distance" | B (director picks) | - | open |
| 8 | "the stadium attendants still disappear too quickly, visually, maybe theyre still there in code, but it makes no sense how tens of thousands of people disappear in a heart beat" | C | - | open |
| 9 | "stomping tanks should feel more responsive, not like you're whittling a health bar down, tanks should be shoved or flung out of the way into buildings, civilians, and other military vehicles" | D | - | open |
| 10 | "reassess our UI. The timer at the top is good. Biomass can be a boxless figure in the bottom right. we dont need button/keyboard tutorials on screen, just once at the start of the game/a controls menu" | F | - | open |
| 11 | "more ui: choose your kaiju screen the kaiju spins off camera/is not centred" | F | - | open |
| 12 | "atomic breath cooldown timer should just be an icon with a circular load bar around the edges" | F | - | open |
| 13 | "health bar also should be removed/repurposed at the bottom of screen" | F | - | open |
| 14 | "all UI elements should be bespoke designs (boxes, cards), original assets" | F | - | open |
| 15 | "some copy issues: tail sweep upgrade text says "cutting a band of floors", dont use 'floors' like that, it makes no sense and no human would just say 'floors', implying that the reader will automatically assume that means floors of a building is misguided" | E | - | open |
| 16 | "repetitive text in the upgrades: "moves faster... moves faster" etc. the description can be less scientific, more humorous or referential, for example "Long Stride > "gotta go fast" > Move faster"" | E | - | open |
| 17 | ""towers now fall to you" - this sentence makes no sense and is an over explain, we dont need to explain building physics, players just need to smash, buy upgrades, smash some more" | E | - | open |
| 18 | "more visual feedback for atomic breath required, needs a VFX pass" | D | - | open |
| 19 | "investigate whether lowering/increasing our voxel count will create better visuals" | B (director picks) | - | open |
| 20 | "investigate whether abandoning the voxel aesthetic will create better visuals" | B (director picks) | - | open |
| 21 | "the stadium is free biomass, it needs to be placed as far away from our spawn spot as possible to make it less farmable" | A | - | open |
| 22 | "building surfaces which are touching other buildings seem to be plain with no features or art, so when you destroy the building its touching, you see a big blank rectangle instead of a building" | C | - | open |
| 23 | "when you highlight the ULTIMATE ATOMIC BEAM in the upgrade tree, the whole shape of the screen changes because the size of the tooltip is wider than other abilities" | F | - | open |
| 24 | "copy issue: "reptilian branch capstone", over explain, stop explaining every single thing in opaque language the player wont understand it, thats copy that you should only show me, not the player" | E | - | open |
| 25 | "pc fans still go kinda crazy during gameplay, needs to be performance audited but do not do this until we've perfected our visuals" | G (after visuals, by his order) | - | open |
| 26 | "atomic blast seemingly having no impact on trees?" | A | - | open |
| 27 | "what is the meaning of "reptilian branch" on the upgrade tree? the entire upgrade tree is reptilian..." | E | - | open |
| 28 | "we need a lot more upgrade nodes, ideally double or even triple" | E | - | open |
| 29 | "quitting the game freezes the screen for 2-3 seconds" | C (end) | - | open |
| 30 | "starting a run freezes the screen for 2-3 seconds" | C (end) | - | open |

His instruction with it: "do not attempt to address all of the above at once: sort it into the roadmap, put it in a
chronological order which makes sense, so that we do not waste time working on something which is dependent on
something else and thus subject to change ... make sure EVERY point in this message is on the roadmap".

Copy rule taken from 15, 16, 17, 24, 27 (applies to every player-facing string from now): no mechanics explained, no
internal names ("branch", "capstone", "floors" as a unit), short and playful; the player smashes, buys, smashes more.
