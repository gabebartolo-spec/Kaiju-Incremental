# atmosphere-lead handoff (D-189), 2026-10-23

## State
Booted; the director answered 16 questions in this session (rulings A1-A16 in the shared notes folder,
side-session-notes/local_a16cd984-.../atmosphere-lead-rulings-2026-10-23.md; the lead logs them as D-n).
First report sent to the lead. No builder started yet; none running.

## Task
M1 atmosphere end to end (D-155, D-168, D-154, D-189): rampage escalation, weather looks, sky and sea life.
Lead = "Status check" local_a16cd984-128a-4b5f-8bdf-05556e046cd4. Peer: VFX lead (fire, explosions, kaiju motion).
Not mine: sim/ rules, data balance, music, city sound, merges, DECISIONS/DESIGN.

## Branch
claude/atmosphere-lead from origin/claude/look-options (6e88723a). Base is look-options, not main (main is stale).

## Key finding
#167 built only the weather pick (sim/weather.gd, Content.weather_id(), options row). Nothing draws weather.

## Order (A12) and pass bars
1. Escalation: haze and sky tint follow the share of the city destroyed (A5); smoky amber by day, full orange at
   dusk/night (A6); ruin shows through any weather late (A8); blackouts spread floor by floor round damage at
   dusk/night only (A7). Needs from the lead: a destroyed-share value the view can read (probably exists; check).
2. Weather looks, all five (A1): heavy rain thinned round kaiju (A13), low fog banks he towers over (A14), storm
   near dusk-dark by day with distant bolts in the croc's lightning look (A10, A15), wet sheen (A16), overcast.
3. Sky and sea life: soft smoke-family clouds (A9, stills first), gulls + pigeons scatter on roar/tower fall (A2),
   boats flee and rock (A3), whale surfaces 2-3x per run between play city and distant city (A4, D-168), roar:
   whale dives with tail slap, boats flee (A11). Motion critic at game speed for every mover (D-177).

## Rules in force
2 engine builders max (D-189); engine_slot.sh + timeout + own APPDATA; stall_watch.sh armed over builders;
D-186 local suites only; D-188 critics until pass, two fails in a row = change method; SHIP + sha to the lead.
