# Lighting handoff, 2026-10-18
## State: running a check (CI capture of 4 looks; director decision next)

## Who
Role: lighting (director 2026-10-18: "beautiful realistic lighting and ways to add atmosphere";
then "investigate night scenes with dramatic lighting while keeping playable visibility").
Assigned by the director in chat, not yet on docs/STATUS.md: the lead/merge role adds it.

## Branch
claude/lighting off claude/look-options (80ff088), worktree ../Kaiju-Incremental-wt/lighting.
Commit 3429e6e pushed; no PR yet (open it after the director picks a look).
Worktree count was already 6 before mine (cap 4): flagged to the director.

## What is built (3429e6e)
- scenes/city_lighting.gd: sky, ambient, fog, grade, sun moved out of city_view.gd (file cap).
- New optional look keys, defaults = old behaviour (concrete renders unchanged): exposure,
  sky_energy, sun_yaw, fog_height, fog_height_density, fog_sun_scatter, vol_fog (+ _albedo,
  _glow, _glow_energy, _anisotropy, _length, _ambient), fire_light, rim_color, rim_energy.
- sim/content.gd: a look may name "base" and list only what it changes.
- data/looks.json: golden (G), dusk (B, deepened blue hour), night (N), all base concrete.
- capture_looks.gd --looks=a,b filter. Sim check "variant takes every key from its base"
  (floor sim 39->40), shown failing with inheritance removed. All 8 suites green locally.

## Audit of the current look (concrete)
Flat: ambient 1.15 flat colour vs sun 0.7, so shadows barely read and everything is one cyan
value; fires and lamps do not stand out; smoke is unlit grey; no aerial depth.

## Night: how to keep it playable (investigation)
Built in round 1: moon key with shadows (cool, 0.55), ambient floor 0.38, kaiju-only rim light
(cull mask RIM_LAYER) at 4.0, windows 60% lit, lamps 5.0, fires x2, faint volumetric city glow,
exposure 1.25.
Not built, candidates: army searchlights (SpotLight3D on tanks/helis locking on the kaiju:
drama + threat direction); tank headlights/beacons; species accent glow pulsing; destruction
lights the city (fires accumulate = escalation); lightning flashes; a luminance floor check on
captures (playfield p50 luminance >= a threshold) as the readability guard.

## Next
1. CI run output -> scratchpad/looks1 (log looks1.log). Build a labelled board
   (concrete/golden/dusk/night, city + skyline shots), 2x crops, art-qa-critic self-check.
2. Measure playfield luminance per look for the night readability claim.
3. Ask the director one question: which base light. Then PR, tune, night extras if wanted.
