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

## State 2026-10-23 03:00: PR #160 open (claude/ui-title-menu -> claude/ui-redesign history ported), suites green
Worktree ../Kaiju-Incremental-wt/ui-pr is the live one now (ui-redesign = dead lineage, 121 conflicts with look-options).
Title: scenes/title_{backdrop,fires,shore,colossus,sky_smoke,burning_windows,ledge}, far_fire.gd = game Fire at zoom (fire.gd
far dict), facade.gdshaderinc `blackout`, tuning title.*; bake: tools/capture/bake_colossus.gd (yaw 60, closes alpha pinholes,
prints the eye uv); captures: capture_title (--reveal=s, --rest, --variant=dusk, --clip=s, --probe, --hide-3d), capture_boot,
capture_fire_compare. Menu: title_screen.gd (gear, row, exit), HazardBox.plated + UiKit.button = plates, tests/lib/ui_title.gd.
OPEN: PR merge waits on the VFX lead's SHIP (fire, Colossus, water) and a fresh screen-critic PASS on the menu; Colossus
height/camera-tilt is the VFX lead's call (head ~1.8x the right towers now). Queue after (lead's word first): HUD ring capture,
boot cut (engine+autoloads 7.8 s before any script on a loaded machine).
Lessons: GPU sin() hash noise gives block artefacts (use a noise texture / sin-free hash); a ported branch needs
`git diff --binary base..tip | git apply --3way` when look-options was squashed; complexity ratchet + tuning_keys run on CI.

## Rules and tooling
Scratch S = AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/
b2b0bc5b-.../scratchpad; still.sh <dir> [flags] (4K still), uiclip.sh <out> <appdata> <script> <args> (1080p movie).
Godot console exe C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe; timeout every
run, own APPDATA; windowed runs need the untracked override.cfg (in worktree now, gitignored; keep until done) written in
its own Bash call (focus guard). New class_name needs `--headless --import`. gdformat/gdlint in Python314/Scripts; gdformat
writes CRLF: run sed -i 's/\r$//' after (repo is LF). Python open(p,'w') also writes CRLF: use newline=''.
Lint scripts tools/lint/{tuning_keys,complexity_ratchet}.py exist only on main (copy to scratchpad, run with cwd = worktree).
Flow suite can flake (scorch glow) when another Godot runs in parallel. Run ui + flow suites before the push.
