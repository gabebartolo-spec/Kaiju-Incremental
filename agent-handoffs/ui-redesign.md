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

## Lead's QA of night still (2026-10-22 23:00) = my task list, in order
1 colossus never seen in frame (old 3D model path: only its tail showed; body transparency bug) -> NOW a baked black
  silhouette card; needs `bake_colossus.gd` run, then place (feet z -400, x ~ screen 0.85, height ~150 m so shoulders clear
  the tallest right-side towers, head well above), glow behind. 2 boot: city took ~13 s (target <= 4.5-6 s): sky smoke
  preprocess replaced by static MultiMesh cards, colossus no longer builds the voxel model; STILL measure
  (TITLE_TIMING prints in title_backdrop._mark: REMOVE before commit) and cut fire preprocess if needed (fixed_fps).
3 flames white blobs -> far_flame.gdshader rewritten (blend_mix, orange-red gradient, pale core only, frayed edge). 4 water
  zigzag comb -> title_shore.gdshader rewritten smooth at rest (banding only with shiver); caution: the lead's still caught
  a footfall mid-shiver; capture flag --rest waits for shiver()==0. 5 stray white box = a lamp head (emissive) on a black
  post at 15 m: head now amber, posts lighter, gap 24 m. 6 shore band: ledge shader (slabs, lamp pools, fire light), rail
  1.6 x 0.45 m. 7 sky smoke heavier, orange under-lit low, near-black high (tuning sky_smoke). 8 re-render dusk.
Deliverables: night 4K still during a reveal (`capture_title --reveal=0.3`), night 4K still between reveals (`--rest`), dusk
4K (`--variant=dusk`), one 6-8 s night clip (uiclip.sh + capture_title --clip=8, cut mp4 with ffmpeg = imageio_ffmpeg
binary), launch-to-title time (capture_boot.gd with --launch=$(date +%s.%N)).
STATE at 23:15: code written for 1,3,4,5,6,7 and the colossus card; NOTHING of it has been run yet (director paused all Godot
until 23:35). First run: bake colossus (`--out=res://assets/title --preview=<png>`), `--headless --import` for new assets,
then the stills. Add a LICENSING_REGISTER row for assets/title/colossus_*.png (ours, baked from our model by tools/capture/
bake_colossus.gd) before commit.

## Rules and tooling
Scratch S = AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/
b2b0bc5b-.../scratchpad; still.sh <dir> [flags] (4K still), uiclip.sh <out> <appdata> <script> <args> (1080p movie).
Godot console exe C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe; timeout every
run, own APPDATA; windowed runs need the untracked override.cfg (in worktree now, gitignored; keep until done) written in
its own Bash call (focus guard). New class_name needs `--headless --import`. gdformat/gdlint in Python314/Scripts; gdformat
writes CRLF: run sed -i 's/\r$//' after (repo is LF). Python open(p,'w') also writes CRLF: use newline=''.
Lint scripts tools/lint/{tuning_keys,complexity_ratchet}.py exist only on main (copy to scratchpad, run with cwd = worktree).
Flow suite can flake (scorch glow) when another Godot runs in parallel. Run ui + flow suites before the push.
