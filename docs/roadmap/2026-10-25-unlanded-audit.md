# 2026-10-25 audit: finished work that never reached the game

Why: the far-city insectoid sat flag-off on an unmerged branch for 4 days. Director: "do you think im asking you to
build these things just for the heck of it? no, im asking you to build features and put them in the game"; "Make a
rule so that this never happens again". Rule (RULEBOOK, Working): BUILT MEANS IN THE GAME, merged to main and on by
default. Method: every remote branch with work not on main (136), checked by content against main and the decision log.

## Approved, built, NOT in the game: each lands (owner, next step, target)

| Feature (branch) | Decision | Owner | Next step | Target |
|---|---|---|---|---|
| Far insectoid rampage (skyline-rampage) | D-120, "yes bring it back" | lead (builder far-insectoid) | port onto main, flag ON, haze via set_far_haze | 10-26 |
| Damage lands on impact (strike-delay) | D-166, D-175 | lead | rebase, two sim reviews, PR | 10-26 |
| Behemoth/Colossus heavier turns (turn-weight-d187) | D-187 "A: short steps" | lead | rebase body_contact + tuning, gait/motion suites | 10-26 |
| City parks, 8% green lots (green-lots) | D-075 | lead | rebase, green-lot test, look check | 10-27 |
| Walking into big buildings gives way (dash-burst, D-118 part) | D-118, #34 | lead | port the walk-in give-way only (the dash itself became the leap) | 10-27 |
| Explosive sites (city-explosives-3, was -v2) | D-126, #19/#20 | VFX lead (+ lead sim review) | after fire-smooth-2; sim review; critic | 10-27 |
| Smooth flames (fire-smooth-2) + heli fall on top (heli-fall) | D-190 | VFX lead | r2 queued; heli fall after | 10-27 |
| Thunder Beam lightning look (thunder-beam-2) | D-136, VFX_STYLE | VFX lead | r8 after r7 FIX | 10-27 |
| One look: haze, far blur, block ground (one-look-2) | D-163 | VFX lead | P0 running | 10-26 |
| New claw rake (claw-rake-2) | D-185, D-190 | VFX lead | r4 after claw-anim #194 | 10-26 |
| Breaking rubble (rubble-break) | D-110, #24-26 | VFX lead | folded into the D-245 rubble redesign (reuse its slabs/contact code) | 10-27 |
| Living-predator idle (living-predator) | D-165, D-190 | lead + casc-anim | check against the Cascadeur idles; land what still applies | 10-27 |
| Run intro (intro-cinematic-2; emerge-shore folded in) | #17, R 20 | lead + VFX lead | intro water r2, then merge first | 10-26 |
| Rain (atm-rain-2), escalation + far haze (atm-escalation-2) | D-155, D-189 | atmosphere lead | critics, merge | 10-26 |
| VIP chopper (vip-heli), gunships (heli-standoff-2), Komodo in game (komodo-clips) | D-149, D-183, D-201 | lead | finishing; PRs | 10-26 |

## Correctly not landed
Jets (D-072, parked until after the demo); old lighting (D-057 kept the look); real Melbourne (D-029 tabled);
perf-tiles ("Park it"); ui-art icons (D-127); look boards (D-163 picks ported); croc-neck (NECK_SHARE on main);
serpent branches (D-246 freeze); older copies superseded by the -2/-3 ports. In game already: title redesign,
camera growth, clumsy army, city memory, carving core, Blender croc.

## Asked the director (answers 2026-10-25)
- Fire onto landmarks (agent-added off-flag `powers.fire.spread_landmarks`): "Yes, landmarks burn" -> flag ON (lead, with strike-delay).
- walk-m2 walk weight (#4): "Drop it" (the Cascadeur clips are the weight). Branch closed out.
- audit-sim refactor: no player change; lands only if a touched function needs it.
