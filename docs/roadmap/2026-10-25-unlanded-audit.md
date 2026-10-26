# 2026-10-25 audit: finished work that never reached the game

Why: the far-city insectoid sat flag-off on an unmerged branch for 4 days. Director: "do you think im asking you to
build these things just for the heck of it? no, im asking you to build features and put them in the game"; "Make a
rule so that this never happens again". Rule (RULEBOOK, Working): BUILT MEANS IN THE GAME, merged to main and on by
default. Method: every remote branch with work not on main (136), checked by content against main and the decision log.

Re-stamped 2026-10-27: the last column says which rows have merged since (PR number, GitHub UTC merge time, from
`gh pr view N --json mergedAt`) and which are still unlanded. The live owner, date and next step of every unlanded row is
in `docs/roadmap/2026-10-27-unlanded-audit.md`. "Not re-checked" = no merge found in this pass; the row keeps its old target.

## Approved, built, NOT in the game: each lands (owner, next step, target)

| Feature (branch) | Decision | Owner | Next step | Target | Status 2026-10-27 |
|---|---|---|---|---|---|
| Far insectoid rampage (skyline-rampage) | D-120, "yes bring it back" | lead (builder far-insectoid) | port onto main, flag ON, haze via set_far_haze | 10-26 | MERGED #213, 2026-10-26 07:11Z, on by default |
| Damage lands on impact (strike-delay) | D-166, D-175 | lead | rebase, two sim reviews, PR | 10-26 | MERGED #212 (strike-delay-2), 2026-10-26 07:04Z |
| Behemoth/Colossus heavier turns (turn-weight-d187) | D-187 "A: short steps" | lead | rebase body_contact + tuning, gait/motion suites | 10-26 | not re-checked (backup/turn-weight-d187 still on origin, no PR) |
| City parks, 8% green lots (green-lots) | D-075 | lead | rebase, green-lot test, look check | 10-27 | not re-checked (no green-lots branch ahead of main in the 07:27 rerun) |
| Walking into big buildings gives way (dash-burst, D-118 part) | D-118, #34 | lead | port the walk-in give-way only (the dash itself became the leap) | 10-27 | not re-checked (backup/dash-burst on origin; the 07:27 rerun shows every file it touches already matches main) |
| Explosive sites (city-explosives-3, was -v2) | D-126, #19/#20 | VFX lead (+ lead sim review) | after fire-smooth-2; sim review; critic | 10-27 | MERGED #236 (the city's red barrels explode), 2026-10-26 01:06Z |
| Smooth flames (fire-smooth-2) + heli fall on top (heli-fall) | D-190 | VFX lead | r2 queued; heli fall after | 10-27 | smooth flames MERGED inside #236, 2026-10-26 01:06Z; heli fall NOT landed (backup/heli-fall on origin, no PR) |
| Thunder Beam lightning look (thunder-beam-2) | D-136, VFX_STYLE | VFX lead | r8 after r7 FIX | 10-27 | not on main; r7 look landing tonight as claude/thunder-land (10-27 audit) |
| One look: haze, far blur, block ground (one-look-2) | D-163 | VFX lead | P0 running | 10-26 | not re-checked (the ground round shipped as #208 one-look-3, 2026-10-25 15:09Z; haze and far blur unverified) |
| New claw rake (claw-rake-2) | D-185, D-190 | VFX lead | r4 after claw-anim #194 | 10-26 | not re-checked (backup/claw-rake-2 on origin, no PR); its prerequisite claw-anim PR #194 was closed, never merged (2026-10-26 06:50Z) |
| Breaking rubble (rubble-break) | D-110, #24-26 | VFX lead | folded into the D-245 rubble redesign (reuse its slabs/contact code) | 10-27 | not re-checked |
| Living-predator idle (living-predator) | D-165, D-190 | lead + casc-anim | check against the Cascadeur idles; land what still applies | 10-27 | not re-checked (backup/living-predator on origin, no PR) |
| Run intro (intro-cinematic-2; emerge-shore folded in) | #17, R 20 | lead + VFX lead | intro water r2, then merge first | 10-26 | not on main: re-ported as PR #245 (OPEN); old #211 closed 2026-10-26 06:44Z; intro water 10f3629c on backup/intro-cinematic-2 |
| Rain (atm-rain-2), escalation + far haze (atm-escalation-2) | D-155, D-189 | atmosphere lead | critics, merge | 10-26 | rain MERGED #239 (atm-rain-3), 2026-10-26 05:52Z (#215 closed 02:28Z); escalation + far haze NOT on main, parked by D-310 (owner lead) |
| VIP chopper (vip-heli), gunships (heli-standoff-2), Komodo in game (komodo-clips) | D-149, D-183, D-201 | lead | finishing; PRs | 10-26 | VIP MERGED #246, 2026-10-26 08:34Z (#214 closed 07:01Z); gunships core MERGED #210, 2026-10-25 14:47Z, phase 3 NOT on main; Komodo NOT on main (claude/komodo-land), parked by D-310 |

## Correctly not landed
Jets (D-072, parked until after the demo); old lighting (D-057 kept the look); real Melbourne (D-029 tabled);
perf-tiles ("Park it"); ui-art icons (D-127); look boards (D-163 picks ported); croc-neck (NECK_SHARE on main);
serpent branches (D-246 freeze); older copies superseded by the -2/-3 ports. In game already: title redesign,
camera growth, clumsy army, city memory, carving core, Blender croc.

## Asked the director (answers 2026-10-25)
- Fire onto landmarks (agent-added off-flag `powers.fire.spread_landmarks`): "Yes, landmarks burn" -> flag ON (lead, with strike-delay).
- walk-m2 walk weight (#4): "Drop it" (the Cascadeur clips are the weight). Branch closed out.
- audit-sim refactor: no player change; lands only if a touched function needs it.
