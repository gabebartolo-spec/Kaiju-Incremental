# intro-cinematic-2 handoff, 2026-10-25
## State: done bar met on e6eb2f80 (suites green, 4K clip + stills, pr-body.md); main merged, RampageRise split, final suite run
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

## Since (commits 100a5fd6, 7a.., head)
- Shot data: yaw 45 from his front, distance 9, height 2.5 over water / clearance 1.5 over the ground under the
  eye (Emergence.ground_at), pull_from 1.6, height leads the pull-out (done at 2/3). Stage 3 still: gape open,
  head and shoulders fill the frame over the skyline. Stage 1 jaw reads open at 45 (25 looked under the chin).
- Debris pop: RiverView's break splash used tail=true (street dust puffs on the water) and deck_burst fired at
  the water line while the head was under the deck. Now foam water_ring, and deck_burst when the top reaches 0.
- Ripples were dust-brown: Fx.water_ring with the spray's foam tone.
- Hand-over stutter: real gameplay camera blended onto (above); wade eases in/out (smoothstep, 1.0 s) so the body
  never jolts at 1.8 s; short cut on whole ticks (2/frame, ~1.0 s) - uneven 1-2-1 ticks stuttered.
- ClipGait never counted the roar jaw hold down (maw open for good): BipedHead.tick_hold from both gaits.
- Fount/break ring now over the head's crown: KaijuModel.head_ahead (head1 vs hips, 6.4/7.6/10.3 per scale by
  stage; data aim_ahead 8.8 is only the model-less fallback, used by fade_spawn).
- City fixes from the ported emerge-shore: stand-ins clear of the rise (EmergeReach.fit -> river_bay
  view_clear, EmergeReach.in_view); pavement rings the bay leaves no room for are dropped (Pavements._ring).
- fade_spawn now calls use_species before emerge.start (as Rampage.setup).
- First suite run (100a5fd6): city 5 fails (stand-ins x3, walkers x2), flow 3 (jerk whole 0.018 / short 0.037,
  same-state from my double await), load 1 (stage 1 roar sight, the use_species miss). All addressed after.
- 4K clip method: override.cfg needs borderless + window_width/height_override 3840x2160 or the movie is 1080p.
  ffmpeg: imageio_ffmpeg binary (C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/
  binaries/ffmpeg-win-x86_64-v7.1.exe). Scratch C:/Users/DANTE/AppData/Local/Temp/ic2 (render.sh, sheet.py).

## Final
- e6eb2f80: city 9/9 fns 229 checks, flow 7/7 261, load 8/8 35, all 0 failures. Distance 12, aim at the
  drawn skull+jaw (HeadFrame.head_box); a stand-back fit to the head box was tried and dropped (middle
  distance again, eye behind the quay walls).
- Merged origin/main 83f9c725 (09376648); Rampage hit 406 lines -> RampageRise split + _on_stomp (379).
- Deliverables: C:/Users/DANTE/AppData/Local/Temp/ic2/final (run_intro_stage1_4k.mp4 3840x2160 60 fps
  3.82 s; 1_water_ripple_0.50s, 2_burst_roar_1.25s, 3_hero_frame_1.60s, 4_handover_2.80s; stages sheet).
- pr-body.md in the worktree root (untracked). No PR opened (brief).

## Open decisions
- none (shot angle is a camera choice inside the approved beats; flagged to the lead in the report).
