State: stood down at 300k (2026-10-20); lead told; restart fresh from this file.

# Builder helper (Phase A, build 2 playtest) handoff — 2026-10-20, life 1 at 300k

Brief: lead 8's Phase A items, one PR each, base claude/look-options: b2-6, b2-21, b2-26, b2-2 (first half).
Worktree: .claude/worktrees/awesome-germain-673166 (currently on claude/b2-21-stadium-far).

## Done
- b2-6 PR #110, head de4a8560650811e5241979f2dde11fcc645268c3, ready, auto-fix on. Real band: every block within
  city.view_beyond past the arena edge is real buildings (sim/city_band.gd); stand-ins beyond. Building.in_arena keeps
  destruction % / city_fallen / nearest_standing to the arena. Local green: city, growth, sim, smoke, load, flow,
  military. Rest of suites: CI. Full kaiju reach was infeasible (stage-3 breath ~110 u past edge).

## b2-21 (stadium far from spawn) — FINDING, needs lead/director call
- Branch claude/b2-21-stadium-far, WIP e25b62f (not a PR): anchor "far" = search every first-district site, pick the one
  furthest from the river rise; test tests/lib/city_stadium_far.gd (exhaustive search vs real river spawn).
- Result: the OLD anchor [22,-24] already gives the furthest site the stadium fits in the stage-1 city: 75.6 / 75.0 /
  77.8 u from the rise (map seeds 7301/1234/98765); the "far" search picks the same site. So the check cannot fail first.
- Farther needs a rule change. Options: (a) let it sit in district 1 / the north band (after #110 it is real but out of
  walking reach at stage 1: breath only, so far less farmable); (b) move the spawn instead (river north); (c) cap the
  stadium's crowd biomass. Recommend (a)-lite: allow the stadium across the north ring into district 1 only from the
  Behemoth, keep stage 1 as is. Lead to decide.
- Branch missing tests/lib/city_stadium_far.gd.uid (generated, untracked in worktree): add it if the branch lives.

## b2-26 (atomic blast vs trees) — not started
- Trees are CityDecor props (scenes/city_decor.gd crush(at, radius), city_greenery.gd). Breath is sim BreathCone
  (sim/breath_cone.gd) -> event "ability" kind "cone" in rampage_sim _signature; check whether presentation calls
  CityView.crush along the cone (powers_view / ability_fx). Likely fix: crush props along the cone on the ability event.

## b2-2 tail swipe — partial reading, probe not run
- Sim: species_powers.after_move fires _tail_sweep only if stat tail_damage > 0 (base 0: needs node r_tail, "Tail
  Sweep", cost 51, requires claws) AND accumulated turn _turn >= powers.tail_turn_rad 0.9 (decays exp(-3 dt)) while
  moving, cooldown 1.2 s. Reach (6 + tail_reach) * body_scale = 3 u at young scale, arc behind/beside (dot <= 0.35),
  floors 1..1+ceil(3*bs*2). Visual: powers_view "tail_sweep" -> KaijuModel.tail_sweep -> BipedSwing.whip (ClipGait
  extends BipedGait, so it plays). Suspects: player never bought r_tail, or 3 u reach behind a street-bound kaiju
  rarely touches a building so nothing visibly breaks.
- Probe ready: notes folder b2-2_tail_probe.gd (copy to tests/_probe/, run headless with own APPDATA): stage-1 city,
  60 s, inputs keys90/keys45/stick/straight, with and without r_tail; prints sweeps and chunks cut.

## Gotchas
- Working tree files are CRLF (autocrlf); python edits must normalise (scratchpad ed.py did).
- A new class_name needs a full import run (no --quick). rampage_sim.gd is at the 400-line cap exactly.

## Running jobs
None. PR #110 auto-fix was on in the old session; the successor re-binds it.
