# ui-redesign handoff, 2026-10-21
## State (2026-10-22): critic fix pass done, captured, reviewed at 2x, lint clean, pushed; pr-body.md final. Done.
## Task
Lead-10 builder. In-run HUD (b2-10..13, R 15.1-15.7) and menus (title, pause, settings, results, species
select, loading) in UI look A "Emergency Broadcast" with bespoke drawn assets; fonts Claw/Block; one shared
outlined text style; fixed tooltip width (b2-23); copy rule. UI only, values in data. Push, no PR.
Director (via lead): dash + ultimate as small rings either side of breath; CITY DESTROYED a thin text-less
tape meter under the timer. Both built.
## Branch and commit
claude/ui-redesign (worktree ../Kaiju-Incremental-wt/ui-redesign) from claude/look-options f4fedeec.
fc1391b6 capture_flow loading shot; 6df247f0 the redesign; b1fc5ba6 capture waits for the end beat (the
river rise held the clock, so --ui-only never reached the report); 010a2dd5 fixes from my own capture
review (cards clear corner marks, breath ring centred via invisible placeholders, species 2x2 meters and
390x220 preview so 3 cards fit 125% title-safe, "EVOLVE" without ">", bigger alert triangle).
Scratch refs and the ui-before worktree: deleted.
## What changed (6df247f0)
data/tuning.json "ui" (safe margin 96/54, text style, hud, hurt, controls_card, tooltip_width, spin rate,
loading news). UiKit text_style/safe_area/header/panel_box; UiMarks (tape, ticks, alert tag, scanlines);
HazardBox corner brackets + focus chevron. RampageHud rewrite + HudRing, HurtVignette(.gdshader),
ControlsCard (first run, PlayerSettings.controls_seen in settings.cfg "ui"); Settings CONTROLS page;
Dash row added to CONTROLS. Species select turntable spin about the footprint middle. Results/pause/loading/
title alert headers; results "Tallest tower toppled" N STOREYS (no "floors"); tree details panel fixed width,
role label wraps, "BRANCH"/"CAPSTONE" copy gone. Loading word LOADING -> INCOMING.
## Evidence so far
Suites (local, --quick, 010a2dd5): ui 3/3 fn 18 checks, flow 7/7 fn 203 checks, smoke 13/13 fn 30 checks.
Known-bad: model shifted 3 m -> centring check FAILS; old role copy without wrap -> panel 330/399/400/415 px
FAILS (b2-23 reproduced: r_beam 399). Faint-outline contrast case fails inside the suite itself.
Captures: NOTES/ui-redesign/before-125, before-100, after-125, after-100 (logs before.log, after.log).
## Not done / not exercised
R 15.8 stage-up notice (no in-run stage event exists); heartbeat SOUND (no asset; vignette beats visually);
hit flash is on the screen edge, not on the kaiju model; species ability name "Atomic Breath" still in
species.json (D-108 says never "atomic"; not my string). Tree screen look untouched (waits for bigger tree).
## Running jobs
none. Captures (Forward+ on lavapipe, 3840x2160): before-125/-100 runs 39562381681/39562385358 (fc1391b6
code), after-125/-100 runs 39570807066/39570816803 (010a2dd5). 1280x720 review copies: NOTES/ui-redesign/review.
## Findings for the lead
gdformat/gdlint are in ~/AppData/Roaming/Python/Python314/Scripts (not on PATH).
## Rules learnt the hard way (under 10 lines)
python open(p,'w') on Windows writes CRLF: always newline=''.

## ui-fix round 2 (critic-r1 items 1-8), commits after c0f24fdb
1 species card wide (58% share, cells meter UiMarks.Cells, 32 px stats, one per row, gap above BACK);
D-112 Lightning Breath / Thunder Beam in species/tuning/upgrades. 2 HUD key caps (SPACE/SHIFT/E or A/B/Y by last
device), tape meter 360x18, biomass label 32, hurt alpha 0.42/flash 0.3. 3 first-run card 3 rows + PRESS ANY KEY,
centred under timer; "Keyboard only" -> "-". 4 tree node font 24-30, LOCKED colour 7c7c84, caption "X POWERS".
5 pause "END RAMPAGE" + note. 6 end beat BEAT_TOP 64. 7 reveal hazard frame (EvolutionReveal.frame_around),
skip hint 30. 8 verdict "N BIOMASS SHORT, BUT NEW RECORDS" when another row is a record.
ui suite: new checks each shown failing first. capture_flow: skips river rise, meter 40%, 12_demo_complete shot.
Local runner: scratchpad/ui/suite.sh <suite>.

## Round 2 fix pass (critic r2), done and pushed
Beat hides clock+meter; DemoEnd/RevealStage camera back 1.25 + shift 0.1 (croc clear of edges); first-run card bottom
left; tree band starts below row above, caption under band ("Reptilian powers: only the Reptilian can grow these"),
side panel text 24; hurt alpha 0.28 / flash 0.2; results "N SHORT OF YOUR BEST BIOMASS, BUT NEW RECORDS" + 20 px pad;
controls card +20 px; capture_flow: clean 04/06 frames, hurt at beat peak, 11_tree_after = full game (demo flag off)
after the card (the demo never reaches a tree after its end evolution), 12_demo_complete = the card.
Captures (local RTX 4070 SUPER, 3840x2097 window): side-session-notes/.../ui-redesign/after3-125, after3-100.
Suites green: ui 52, flow 203, smoke 30. Not run locally: powers, full suite (CI does).

## Minimal HUD pass (director 2026-10-21), done and pushed
Rings 16/12 px radius bottom-left corner (breath, dash, ultimate), NO key labels, plain outlined 44 px clock (white, red
in last 10 s), 220x6 strip, biomass 44 px + 24 px word swelling on gains >= 3. First-run controls card kept as is, lifted
90 px above the rings (lead to ask the director). tools/capture/capture_hud.gd measures HUD share (before 3.19%, after
1.37% at 100% 4K; 1.31% at 125%). Captures: side-session-notes/.../ui-redesign/hud-after, hud-after-125 (before design:
after3-100/04_rampage.png); 2x crops in crops3/hudA_*. Suites green: ui 53, flow 203, smoke 30.

## Critic fix pass (2026-10-22), done and pushed
Rings both 80 px (radius 16) on one line; icons separate TextureRect nodes from data/tuning.json ui.hud.icons
(assets/ui/icons/*.png by tools/ui/build_icons.py, LICENSING_REGISTER row); biomass number 28 px (lead 2026-10-22:
keep 28, the brief's "44" was superseded); one 60 logical (120 px 4K) bottom margin for rings and biomass.
Captures (this code, RTX 4070 SUPER): NOTES/ui-redesign/hud-final-100, -125, -first (+ 04_rampage_nohud.png);
2x crops NOTES/ui-redesign/crops5. Measured: rings 80 px, bottom gap 117-118 px both corners (2097 px window),
125%: rings 99 px, gap 147 px. HUD share 1.02% (100%), 1.27% (125%), 9.05% with the first-run card; before 3.19%.
Lint pass: branch .gd files were NOT gdlint clean (long lines, var order, a literal newline inside split("\n")
in run_ui_tests.gd, suite 430 lines): fixed; tree checks moved to tests/lib/ui_tree.gd. Suites after:
ui 8/8 fn 57 checks, flow 7/7 fn 203 checks, 0 failures. pr-body.md updated (before/after, share, Not exercised).
Left: nothing; the lead asks the director about the first-run controls card.
