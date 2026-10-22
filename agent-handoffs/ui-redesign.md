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

## State 2026-10-23 02:40: PR #160 (claude/ui-title-menu), D-158 option C + critic round 2 in flight
Worktree ../Kaiju-Incremental-wt/ui-pr (ui-redesign = dead lineage). Merged look-options (feedback button, Are-you-sure, 0.1-demo
kept beside my pause menu: END RAMPAGE + "You keep the biomass" note; tests/lib/ui_report.gd holds the base's report checks).
Code done (commits 696cf071, d2663e6e, 4ff8f15f): camera look y 38.1 (tilt ~7.5 deg), colossus card 185 m, shore.ledge_depth 26 (the tilt
alone does not thin the water band, it moves it down: the deeper ledge lifts the rail), title.tower_cap 90 (city.far_tower_cap, one
value; CitySkyline._capped), menu: BUTTON_HEIGHT 110 (face 104 = 208 px at 4K), ROW_INSET 4, POINTERLESS_ROOM 16, scratches only in the
top/bottom 16% strips (HazardBox.scuff_lines), exit right margin = row left margin, colossus.crown (shader warm 2.5 px rim on the
skull and snout top, VFX lead's fix). tools/capture/title_measure.gd prints tower/head/shore/plate clearance (--measure).
TODO after the Godot ban (director: none until 02:57): ui suite only (no full suite on this PC), captures at --size=3840x2160 into
final_rest/final_reveal/final_dusk + head_2x + buttons_crop + clip12 (6 s), tune tower_cap/tilt to head 1.5-2x tower, check plate
clearance >= 100 px (raise COLUMN_TOP by <= 15 if not), push, PR body, report to lead (lead relays to the VFX lead for SHIP).
Lessons: override.cfg initial_position is ignored here (window opened at 0,0): capture_title moves it to x=-12000 in _initialize and
--size=WxH grows it (a 4K window opens 63 px short: 3840x2097). A python heredoc turns "
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
