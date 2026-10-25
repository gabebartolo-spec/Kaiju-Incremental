# intro-cinematic-2 handoff, 2026-10-25
## State: port done and compiling; re-shooting the camera to the brief's beats
## Task (lead brief 2026-10-25, TOP PRIORITY)
Run intro (#11): "a quick, dramatic camera shot, zoomed in on the water which begins to ripple and fount before our
kaiju emerges, roaring with rage before the camera zooms out into the play angle ... no longer than 3 seconds".
Also #17 (faces the city, walks straight in), #27 (nothing hides the rise), #38 (bank slab, wall block: "Leave
them"), D-105 (ends on Camera C), burst through a deck over the rise. Director 2026-10-25: "im sick of watching it
from middle distance, side on". Beats: 0-0.8 close+low on the water, push-in, ripple/fount; 0.8-1.6 burst + roar,
low-angle hero frame, head and shoulders big; 1.6-3.0 one smooth pull-out onto the gameplay camera, HUD fades in.
Done-bar: flow + city suites green locally, lints clean, two known defects fixed (debris pop ~frame 57, hand-over
stutter ~165-170), ONE 4K game-speed clip + 4 stills, push, pr-body.md (kaiju-pr). No PR, no merge.

## Branch and worktree
claude/intro-cinematic-2, C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/intro-cinematic-2, from origin/main
1f23937a. Scratch: C:/Users/DANTE/AppData/Local/Temp/ic2 (patch, scripts, APPDATA dirs, logs).
Native dll copied from ../komodo-clips (same native/src tree b5eacd45).

## Done
- emerge-shore (#17 face the city + sand shore + bay, deck burst, bay fits biggest body) was never merged either:
  cherry-picked 411b584b 1d1ee8bb caee6589 1498501e (aec7cc15..98f5df1c). Pavements bay offset moved to
  scenes/pavements.gd (main split it out of StreetLife); city_river_bay test reads street._pavements.
- building-fade (#27) is on main already.
- Intro port 7144ab44: squashed 3-way of de7453f8..9d795e26 minus the IntroFade/revert pair.
- Hand-over: Rampage._place_camera computes the real gameplay camera every frame (CameraFollow eye, HeadFrame
  aim, fov) and RunIntro.shot(sim, body, [eye, aim, fov], frac) blends onto it; no look-ahead while emerging.
  CameraFollow.hold/rest removed.
- New shot: front three-quarter (yaw_deg from his facing), low and close, push-in, then smootherstep pull-out
  orbiting about the body in cylinder coordinates onto the gameplay eye (never through him).
- flow_intro: pop vs the real gameplay eye; new jerk check (second difference of camera position per frame,
  break to handover+30, <= 0.01 of offset).

## Next
Probe geometry + tune "intro" data; run city + flow + load suites; fix debris pop; 4K clip + 4 stills; pr-body.

## Open decisions
- none (shot angle is a camera choice inside the approved beats; flagged to the lead in the report).
