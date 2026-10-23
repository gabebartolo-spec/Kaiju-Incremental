# atmosphere-lead handoff (D-189), 2026-10-23, final (wrap-up; director: "merge what they can and archive")

## State
Session wound up on the director's word. Builders stopped. Nothing is half-run on the PC.
Lead = "Status check" local_a16cd984-128a-4b5f-8bdf-05556e046cd4. Peer: VFX lead (fire, explosions, kaiju motion).
Scope (D-189): M1 rampage escalation, weather looks, sky and sea life. Not mine: sim/ rules, data balance, music,
city sound, merges, DECISIONS/DESIGN.

## Branches (all from origin/claude/look-options)
- claude/atmosphere-lead: this handoff only.
- claude/atm-escalation: see "Escalation" below (status filled at wrap-up).
- claude/atm-rain: see "Rain" below (WIP, pushed).

## Director rulings, 16 answers (logged by the lead as D-191, b049ff06)
Finding: #167 built only the weather PICK (sim/weather.gd, Content.weather_id(), options row); nothing drew weather.
A1 all five weathers get looks in M1 · A2 gulls over the water + pigeons off rooftops, scatter on roars and tower
falls · A3 boats flee and rock, his wake can tip one, spectacle only (no biomass) · A4 whale surfaces 2-3x per
run in the water between play city and distant city (D-168) · A5 escalation follows the share destroyed
(sim.destruction()) · A6 smoky amber-brown by day, full orange dusk/night · A7 blackouts dusk/night only ·
A8 ruin wins late over any weather · A9 clouds soft like the smoke (labelled stills to him first) · A10 storm
bolts = the croc's lightning look, thin and far · A11 roar: whale dives with a tail slap, boats flee ·
A12 order: escalation, weather, sky and sea life · A13 heavy rain, thinned round the kaiju and screen centre ·
A14 low fog, he towers above · A15 daytime storm near dusk-dark · A16 wet street sheen (no SSR).

## Escalation (claude/atm-escalation, pushed 85e010c6e00bc8a7548638ace61db9d9704f066f, NOT mergeable yet)
Suite green (8 fn, 52 checks; planted bug fails 3). Evidence INVALID except dusk: BuildingView keeps baked meshes
(lit windows baked per time) across runs in one process, so night/morning/noon stills reused dusk windows; the
shader-identity diff (max 245/185) and the contrast numbers below are therefore unproven. Fix in the capture
script (BuildingView.begin_city()/end_city() between times), not yet run. Resume: ~10 min re-capture (old-shader
night/noon baseline, 12 stills, sheet), then the identity bar, the night clip, a fresh critic, PR.
Not exercised: blackouts by eye, falling pieces from a dark building, stream-rebuilt buildings mid-blackout, far
skyline windows (they never go dark: a gap).
scenes/escalation_view.gd (one line in city_view.gd; city_environment.gd untouched, the view stores base values),
data/tuning.json "escalation", building_baked.gdshader dark_to/dark_color + BuildingView.set_dark_to (lifted
pieces keep the blackout, VFX lead's condition), read-only Content.time_id() (lead OK'd), suite
tests/run_escalation_tests.gd (52 checks green; planted "blackouts always on" fails 3), capture
tools/capture/capture_escalation.gd + escalation_sheet.py. Kaiju contrast >= 0.91 of d0 at d0.8, all four times.
Not done: night clip (the motion of the easing and blackout spread), critic SHIP.
Known concerns: the game camera barely shows the sky, so the orange reads only through fog and light; fog is only
1.15-1.4x, may read polite not inferno (power pillar). Next method: tint the far haze and skyline band, and
consider an orange glow band at the horizon line the camera does see.

## Rain (claude/atm-rain, WIP, pushed 87fbcff7ffcaaf83b6db46bd67fa19ab2138321b)
Unstaged in its worktree: the new .uid files (ground_slab/rain/rain_splash.gdshader.uid): add them on resume.
scenes/weather_view.gd (one WeatherView, one line in CityView._ready; rain + thunderstorm "like" rain),
rain.gdshader streaks, rain_splash.gdshader rings, smoke clearing moved to view_clear.gdshaderinc (smoke.gdshader
includes it), ground_slab.gdshader with one `wet` uniform (replaces CityGround's StandardMaterial3D; VFX lead:
it becomes THE ground shader, one-look folds into it), looks.json weather.layers, tuning.json "rain",
tools/capture/capture_rain.gd. Imports clean. Not done: weather suite run, planted bug, smoke identity check
(<=1/255), ground identity (mean <0.5/255, max <3/255, else revert to StandardMaterial3D), 8 stills, night clip,
frame time (<1.5 ms Medium 4K), kaiju contrast (>=0.9).

## Not started (briefs ready in side-session-notes/<lead id>/atmosphere-lead-next-briefs.md)
Fog banks + overcast, thunderstorm (copy bolt.gdshader + bolt_shape.gd byte-identical from 6dbe10e5; never merge
that branch), clouds (stills first), birds, boats, whale. Hooks: no sim roar event; add a presentation-only
signal on scenes/roar_cue.gd (sim "dash"/"ultimate"; rampage.gd "ability"; "kaiju_emerged"); tower falls =
collapse "fall_start" kind "topple" / "fall_land".

## M1 survey draft (atmosphere)
1 Did the sky and haze change as you wrecked the city; did a late rampage feel like an inferno? (1-5)
2 Could you always see your kaiju and the streets late in a rampage? 3 At night, did blocks going dark round the
damage feel like the city failing? 4 Rain: real heavy rain? did it hide anything? 5 Fog: did he tower over it
well? Storm: dark and dramatic by day; did the far lightning feel like the sky answering him? 6 Did each run's
weather feel different enough? 7 Clouds: alive or flat? 8 Birds scattering at roars and falling towers: too many,
too few? 9 Boats fleeing; did you see the whale, how many times, did it feel special? 10 Anything in sky or water
that looked off, repeated or broke the mood?

## Rules learnt
- A builder told to hold must be told before it starts: briefs sent before the slot check let one import run.
- Director pauses come often; every builder brief carries "if ~/.claude/focus-pause appears, stop by PID, hold".
- Fresh worktree: git lfs pull, copy native/bin, one import segfault then fine.
