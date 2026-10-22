# ui-redesign handoff (UI builder), updated 2026-10-22 23:15
Worktree ../Kaiju-Incremental-wt/ui-redesign, branch claude/ui-redesign (push, no PR). Last pushed a651cf85.
Role: HUD + menus in UI look A "Emergency Broadcast"; now the TITLE SCREEN (D-140/141/145). Queue after title (lead's word
first): HUD ring capture, plates board (#97), boot cut.

## Done earlier (all pushed, suites green then: ui 8/8, flow 7/7, smoke)
HUD minimal pass (rings 80 px, biomass 28, clock 44, HUD share 1.02%); headers/tags/centred; hazard-stripe buttons both
sides; renamed Kaiju Evolution (save folder kept via use_custom_user_dir); first-run controls card; tree/species/results/
pause/loading screens. Details in git log + NOTES/ui-redesign.

## Title screen, what exists (scenes/)
title_backdrop.gd (SubViewport + CityView, still camera, builds async behind the menu; headless skips it: TitleScreen.live_city),
far_fire.gd + far_flame.gdshader + far_smoke.gdshader (window/roof flames and smoke columns, GPUParticles3D),
far_flash.gd (gunshot/explosion flashes), title_ambience.gd (all sound, thud every 2.8 s +-0.25, signal stomped -> water
shiver), title_shore.gd + title_shore.gdshader (far sea wall, lamps, reflections sheet, near ledge, railing, kerb, posts),
title_ledge.gdshader (paving + lamp pools + fire light on the lip), title_sky_smoke.gd + .gdshader (static smoke cards),
title_colossus.gd + .gdshader (baked silhouette card), tools/capture/{capture_title,capture_boot,bake_colossus}.gd.
All numbers in data/tuning.json "title" (variants night|dusk, shore, fires, colossus, sky_smoke, ripple, ambience).
Director rulings: left menu column (logo above buttons), still camera, scene from boot, reflections KEPT, ripple on each
footfall audio, fire = ragged flames out of windows with heavy smoke (not candles), occasional explosions reveal the
reptilian colossus silhouette; no music. Poster reference: kaiju towering over skyline, orange fire glow, smoke sky.

## State 2026-10-23 05:40: PR #160 (claude/ui-title-menu), D-158 option C + critic rounds 2 and 3 DONE, waiting on the fresh critic
Worktree ../Kaiju-Incremental-wt/ui-pr (ui-redesign = dead lineage). Base merged four times (#155 post-fx, #158 feedback + Are-you-sure +
0.1-demo, #156 time of day, #162 cleanup); settings = the base's inline controls with my plates, trimmed (HazardBox.trim_height) so BACK fits
the 4K TV at 125% (the flow suite turns the demo off: one more control row than a bare probe sees).
Option C is data: camera.look y 38.1 (7.5 deg), colossus.height 185, title.tower_cap 90 (soft knee; TitleBackdrop copies it to
city.far_tower_cap, 0 = off), shore.ledge_depth 26.5 (a tilt alone moves the water band down: 476 -> 502 px; the deeper ledge gives 319),
colossus.crown (warm 2.5 px rim on skull/snout top). Menu: BUTTON_HEIGHT 110 (face 208 px at 4K), ROW_INSET 6 (plate edge x=128, logo ink 127),
POINTERLESS_ROOM 16 + shadow on the right (label 35/35 px), scratches in the top/bottom 16% strips, exit margin = row margin.
Round 3 (critic FIX at d5b349a2): the Colossus card is a full BILLBOARD (tilt lifts its crest: it was at y=36, not 125) so colossus.ground_y
-12 (crest y 130-139, tape ends 35) and title_measure.gd projects the billboard; lattice tower takes tower_cap too (CitySkyline._capped, 89 m);
crown px 8 (rim 6-7 px, 3.6:1 vs sky); capture_title --all also saves dusk_reveal.png; title-safe: column at UiKit.safe_margin (96 px = 192 at
4K), gear/exit share it, NewsTicker.TAG_WIDTH 290 (BREAKING at 195); shade centre_x 0.24. Measured (4K): head 1382 px above shore vs tallest
tower 832 px = 1.66x (lattice 752 px = 1.84x); band 319; nearest block 133.7 px; logo 199, plates 200, gear 200, exit 202, BREAKING 195.
Planted-defect pattern: scratchpad mutate_run.sh (sed, run ui, git checkout).
Suites at 05:08: ui 150 checks 0 failures (planted-defect run: 4 new checks FAIL by name), flow 225 checks 0 failures at 1b7299ec.
Stills: scratchpad final_rest|final_reveal|final_dusk/title.png, final_reveal/head_2x.png, buttons_crop.png (one run: capture_title --all
--measure --size=3840x2160). No new clip (lead: minimum captures).
NEXT (lead's word first): HUD ring capture, boot cut (engine+autoloads 7.8 s before any script).
WINDOW FLAGS TRIED (a windowed run still flashes ~0.6 s at 0,0; a later fix starts here). Probe: winwatch.ps1 (EnumWindows class Engine,
SetProcessDPIAware, 8 ms) + a 320x180 run. Ignored: override.cfg initial_position(_type) -20000; `--position -12000,0` (window first seen at
0,0, vis True 414 ms, moved at 1051 ms); `--borderless` (no effect on the 63 px clamp). Works: DisplayServer.window_set_position(-12000,0) in
_initialize (after the flash); root.size = 3840x2160 two ticks after the window is up. Not tried: window mode minimised (Godot skips drawing),
a launch with STARTUPINFO SW_HIDE, a transparent window, rendering into a SubViewport with --no-window (not in the 4.7 binary), movie clips
(need the final size at launch: 1080p flash). Focus guard (hooks/focus-guard.py) only sees a launch written in the command text and blocks
when ~/.claude/focus-pause exists and the foreground window is fullscreen: run captures inline, never hide them in a script.
Lessons: rm a log before waiting on it (a stale file made me read an old pass); a bare probe can differ from the suite (demo off); a python
heredoc turns "\n" into a real newline: use an Edit; check a new check by planting the old behaviour (scripts/mutate_run.sh pattern: sed,
run, git checkout) and make it read its own number, not the code's constant.

## Rules and tooling
Scratch S = AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/
b2b0bc5b-.../scratchpad; still.sh <dir> [flags] (4K still), uiclip.sh <out> <appdata> <script> <args> (1080p movie).
Godot console exe C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe; timeout every
run, own APPDATA; windowed runs need the untracked override.cfg (in worktree now, gitignored; keep until done) written in
its own Bash call (focus guard). New class_name needs `--headless --import`. gdformat/gdlint in Python314/Scripts; gdformat
writes CRLF: run sed -i 's/\r$//' after (repo is LF). Python open(p,'w') also writes CRLF: use newline=''.
Lint scripts tools/lint/{tuning_keys,complexity_ratchet}.py exist only on main (copy to scratchpad, run with cwd = worktree).
Flow suite can flake (scorch glow) when another Godot runs in parallel. Run ui + flow suites before the push.
