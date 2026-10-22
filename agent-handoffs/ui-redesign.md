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

## State 2026-10-23 00:50 (committed bc04eb0a + uncommitted menu work; NOT yet pushed after bc04eb0a)
Title scene done and looked at: colossus = baked silhouette PNG (assets/title/colossus_0.png, yaw 60 side-3/4 profile with
croc head, bake tool tools/capture/bake_colossus.gd; tuning title.colossus: height, eye uv/colour/pulse, smog, rim),
red eye = additive glow at bake-computed uv; smog shader on the card; smoke/flame draw order via render_priority (sky smoke
-1, fire smoke 0, colossus 1, flames+eye 2). Fires = the game's own Fire at zoom (Fire._init(size, seed, far dict:
zoom/smoke_share/density/wind/puff); tuning title.fires.far/window); far_flame/far_smoke shaders deleted. Water smooth at rest
(capture --rest proves it). Stray white box = a lit window of the near city 10 m from the camera: camera near=15. Block
artefacts in sky = sin() hash noise on the GPU: use no-sin hash or a noise texture. Lamps amber, ledge shader lit.
Boot measured (machine loaded): engine+autoloads 7.8 s, first title frame 8.7 s after launch, city stands 5.2 s later
(build start->built 1.5 s sync + 3.6 s async); preprocess cut via fixed_fps 12.
Director's new MENU layout (replaces column): gear top-left, logo, row [CONTINUE GAME
SPECIES, N RAMPAGES | NEW KAIJU?],
no save = one wide NEW KAIJU, exit "RUN FOR YOUR LIFE!?" bottom-right above ticker; HazardBox.plated = worn plate look for
every UiKit.button (rivets, bevel, scuffs, shadow, plate_text.gdshader); new scenes/gear_icon.gd. tests/lib/ui_title.gd
written (register in run_ui_tests.gd), flow_screens.gd uses the Gear button, capture_flow presses gear by tooltip.
TODO: register ui_title, run ui+flow suites green, capture still (reveal), still (rest), 2x crops (head, buttons),
fire compare still (tools/capture/capture_fire_compare.gd), clip only if needed, push, open ready PR (lead says).

## Rules and tooling
Scratch S = AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/
b2b0bc5b-.../scratchpad; still.sh <dir> [flags] (4K still), uiclip.sh <out> <appdata> <script> <args> (1080p movie).
Godot console exe C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe; timeout every
run, own APPDATA; windowed runs need the untracked override.cfg (in worktree now, gitignored; keep until done) written in
its own Bash call (focus guard). New class_name needs `--headless --import`. gdformat/gdlint in Python314/Scripts; gdformat
writes CRLF: run sed -i 's/\r$//' after (repo is LF). Python open(p,'w') also writes CRLF: use newline=''.
Lint scripts tools/lint/{tuning_keys,complexity_ratchet}.py exist only on main (copy to scratchpad, run with cwd = worktree).
Flow suite can flake (scorch glow) when another Godot runs in parallel. Run ui + flow suites before the push.
