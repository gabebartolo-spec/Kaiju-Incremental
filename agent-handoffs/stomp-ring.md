# stomp-ring handoff (2026-10-20)

Task: director "why the shockwave lands beneath the crocs tail ... remove it or make it make sense", plus
"shockwaves look amateurish, tone down". Branch claude/stomp-ring (into claude/look-options).

## Cause (measured, tools/capture/probe_stomp_ring.gd, young reptilian, 25 s autoplay, 28 stomps)
rampage.gd drew the stomp ring, cracks and crush at _kaiju_at (body root) the instant the sim stomp event
fired; the sound waited for the next foot. Old ring sat mean 3.35 from the foot that then landed and
mean 5.1 from the tail tip, with no foot down. New: ring/cracks/crush at the delivering foot, 27 of 27
(probe's last line) stomps landed on a foot, ring-to-foot 0.00.

## Fix (committed)
- rampage.gd: stomp event sets _stomp_wait (0.6 s); _on_footfall (non-tail) -> _land_stomp(at): cracks,
  sfx.stomp, crush at the foot, ring sized by the stomp radius. No foot in time: sound only, no ring.
- Ripples: shockwave.gdshader now soft dust (blend_mix, feathered, no glow); fx.shockwave(at, radius, tail)
  lost its tint arg; values in data/tuning.json fx.shockwave (radius_scale 0.6, seconds 0.35, alpha 0.22, soft 0.4).
- Dropped: leap takeoff ring, leap land second ring, ready_pulse ring, ink ring (it has _city.ring).
- Callers fixed incl. tools/capture/capture_motion.gd (FOOTFALL_TINT removed).

## Evidence so far
flow 7/7 functions 157 checks 0 failures; smoke 13/13 30 checks 0 failures; powers passed. (no data suite exists)

## Left
- Before/after clips (1920x1080, 60 fps): capture_shockwaves.gd. CI runs: BEFORE 39372265695 (branch
  tmp-before-ripples), AFTER 39372265557 (claude/stomp-ring), both were in_progress at hand-off.
  Download: gh run download <id> -D docs/captures/2026-10-20-ripples/{before,after}; check clips (footfall, stomp,
  leap slam), 2x crops, then add to PR. ci_capture.sh mixed up the two runs' logs; use the ids above.
- Then delete scratch branch tmp-before-ripples (remote + local) and remove worktree ../Kaiju-Incremental-wt/tmp-before.
- Lead: look is the director's; art-qa-critic pass on the clips first. Not exercised: tentacle/insect stomps visually.
