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

## State 2026-10-23 04:50: PR #160 (claude/ui-title-menu), D-158 option C + critic round 2; head c7b0887b + local fixes
Worktree ../Kaiju-Incremental-wt/ui-pr (ui-redesign = dead lineage). Base merged three times (feedback button, Are-you-sure, 0.1-demo,
time of day, director cleanup {beam}); settings screen = the base's (inline controls) with my plates: HazardBox.trim_height keeps BACK on
the 4K TV at 125% with the demo off (the flow suite turns the demo off: one more control row than a bare probe sees).
Option C is in data: camera.look y 38.1 (tilt 7.5 deg), colossus.height 185, title.tower_cap 90 (soft knee, city.far_tower_cap, 0 = off),
shore.ledge_depth 26.5 (a tilt alone moves the water band down; the deeper ledge thins it 476 -> ~316 px), colossus.crown (warm 2.5 px
rim, skull and snout top). Menu: BUTTON_HEIGHT 110 (face 104 = 208 px at 4K), ROW_INSET 7 (plate outline on the logo's ink, 132 px at
4K), POINTERLESS_ROOM 16, scratches in the top/bottom 16% strips only, exit margin = row margin. title_measure.gd (--measure) prints
tower/head/shore/band/plate clearance; capture_title --size=3840x2160 grows the window once it is up and moves it to x=-12000.
OPEN: stills (rest, reveal, dusk, head 2x, buttons crop, 6 s clip) not taken yet: the focus guard blocks windowed runs while the director
plays fullscreen (guard only sees a visible launch in the command text: run captures inline, never hide them in a script). Probe
2026-10-23: a window opens at 0,0 for ~0.6 s even with --position; use --resolution 320x180 then --size. engine_slot.sh before every run.
Lessons: a stale log file made me read an old pass (rm the log first); flow suite differs from a bare probe (demo off); override.cfg
initial_position is ignored here; a python heredoc turns "
" into a real newline: use an Edit.

## Rules and tooling
Scratch S = AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/
b2b0bc5b-.../scratchpad; still.sh <dir> [flags] (4K still), uiclip.sh <out> <appdata> <script> <args> (1080p movie).
Godot console exe C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe; timeout every
run, own APPDATA; windowed runs need the untracked override.cfg (in worktree now, gitignored; keep until done) written in
its own Bash call (focus guard). New class_name needs `--headless --import`. gdformat/gdlint in Python314/Scripts; gdformat
writes CRLF: run sed -i 's/\r$//' after (repo is LF). Python open(p,'w') also writes CRLF: use newline=''.
Lint scripts tools/lint/{tuning_keys,complexity_ratchet}.py exist only on main (copy to scratchpad, run with cwd = worktree).
Flow suite can flake (scorch glow) when another Godot runs in parallel. Run ui + flow suites before the push.
