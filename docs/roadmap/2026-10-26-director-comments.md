# Director comments 2026-10-26 night (D-278 to D-300)

His words during the render plan (D-276), one row each, the same night. Decision text is in DECISIONS.

| Time | His words | What it is | Owner, next step | Status |
|---|---|---|---|---|
| 23:00 | "mayne frozen" (screenshot, bench A_high_1) | High preset hangs on current main: endless engine error flood (self_list.h add/remove) from the first frame; Medium clean; old main 8ec83f5e clean | lead -> perf-p0 bisect (insectoid #213 / VIP #246 / strike #212 / High graphics settings), then a fix brief | recurred 23:36 (B_high_2; 2 of ~14 High). Cause found in engine code: a material changed on a worker thread can trap Godot's material update loop forever. Fix PR #254 (render resources made on the main thread only); merges after 20 clean GitHub runs (D-282) and a speed bench |
| 23:05 | "i think the night sky looks kind of strange / maybe too much white in the blue?" "i think its the lighting or the fog making the night sky too light" | Night look (looks.json times.night) | lead -> perf-p1c stills (4 variants: A current, B fog_color 0c1428 = sky_top, C ambient 1.4 -> 0.9, D B+C) | decided D-279: B (fog matched to sky), ships in perf-p1c PR |
| 23:10 | "im not convinced the rubble is good enough, its kind of an eyesore ... what can we do?" | Rubble look = D-245 never built (W121): "Pancaked floors + debris", "Well below his knees", "Crunches flatter" | lead: Opus rubble builder AFTER the render plan (asked: "After the render plan"); clip straight to him | queued |
| 00:25 | "add to roadmap to revisit this vfx effect" (screenshot docs/captures/2026-10-26-clips/glow_cracks_revisit.png) | Impact mark with glowing orange ground cracks (scenes/fx_decals.gd: crack decal with emission) | lead -> VFX builder; first step: ~6 s game-camera clip of the effect straight to him, his words become the fix list | open: queued after the render plan (D-276) |
| 00:30 | "we should probably revisit the stomp attack and replace it with something else, make stomp damage weaker and automatic / a stationary stomp goes against the croc's power fantasy as an athletic kaiju"; "stomp fits the dragon more than the croc" | Croc kit: footfalls crush street-level things; tail lash on the button; charged stomp goes to the dragon (D-280, D-281) | lead -> builder + Cascadeur tail-lash clip after the render plan | queued |
| 00:45 | "see why we need the bubble" (2 screenshots: a building wall fills the whole frame with only damage numbers showing; the screen-door dither fade over the croc at night) | Camera bubble #238 (CONFLICTING, 1 red check) + planned rework (solid by default, cut away only the 0-3 buildings inside the bubble, keep shadow); D-270 "i dont like the buildings coming into the camera" | lead: D-283 "After the render plan"; Opus rework of #238, his two screenshots are the pass bar (no wall fills the frame, no screen-door over the kaiju); clip straight to him | queued |
| 00:50 | "the biomass numbers also visible THROUGH te buildings and kaiju isnt great" | Floating +biomass numbers draw on top of everything (city_view.gd float_text no_depth_test, greybox 8d02a024, no decision) | lead: D-284 first "Hidden behind it"; 00:55 "i dont want to see the numbers. i want to see kaiju" (numbers_over_kaiju.webp) -> "Remove them entirely", "With the bubble" (D-283) after the render plan | queued |
| 01:5x | Picks on the 20 render stills: "New grading", "Both" | Render items 3+4 (clarity: deband + sharpen; tone: AgX 1.6, post 1.0) | lead -> perf-p1c: all on by default in #257 (D-285), prepush, merge | building |
| 02:0x | "are any of those new roadmap items code jobs we can smash out?" -> picked Army balance, Death overload #240, Faster pre-push check | Unlanded rows (2026-10-27 audit) | lead: one Sonnet builder in 1b's freed slot, in order: prepush-deps, #240 (briefs/brief-death-land.md), army (briefs/brief-army-land.md) | building |
| 01:5x | "i dont like your time estimates, times should be based on evidence" | lead | rulebook | recorded |
| 01:5x | "if you ever think of a way to improve our workflow, but the idea contradicts a prior rule, i still want to hear the new idea and decide" | lead | rulebook | recorded |
| 01:5x | D-286 merge freeze fix at speed check; D-287 six builders | lead | #254, P2b, P2c | doing |
| 02:1x | D-288 death upgrade names + costs kept (#240) | lead | #240 | recorded |
| 02:2x | "when a building gets carved anywhere, its whole facade changes texture, so even if you carve the bottom of a tower, the top of the tower is changing appearance too" | lead -> facade-carve builder (D-289, next free slot) | - | briefed |
| 02:3x | "the governers heli sometimes blends into the buildings, as if it is translucent" (screenshot: governor heli over a lit tower, windows visible through its body) | lead (diagnose) | - | investigating |
| 02:3x | "sometimes the windows have flickering horizontal black bars across them, it creates a lot of visual noise" (crop: dark bars across lit windows) | lead (diagnose) | - | investigating |
| 02:3x | on the vehicle see-through fade: "why would any vehicle ever go see through?" | lead -> builder (D-290, remove VehicleFade) | - | queued |
| 02:3x | "im certain id never have agreed to that if id understood what you were proposing" | lead -> rule-audit reader (D-291) | - | running |
| 02:4x | "sometimes a hallucinated guardrail will handcuff our progress even though i never would have wanted to use that guardrail" | lead | D-292, D-293 | doing |
| 02:5x | death clip: "i dont like the pale blocks that come out of the explosion" | lead -> death fix builder (#240) | #240 | queued |
| 02:5x | shard order: "Shards first" | lead -> death fix builder | D-294, #240 | queued |
| 02:5x | "does our project have a proper tech stack and good codebase hygeine??" then "I want the FULL list of debt items, i want them all actioned" | lead -> debt builders | D-295 | doing |
| 02:5x | "why are there no godot runs going rn" (lead's speed check held the bench flag 02:30-02:41 waiting for zero Godot) | lead | D-292 driver fix | done |
| 03:0x | "so what are these slots ? is it a guardrail hallucination?" -> "idc how many, use 100 if its not going to ruin the tests use as many as is feasible" | lead | D-296 | done (12 builders) |
| 03:0x | "i think our helis and tanks look untextured too, they look procedurally drawn rather than proper models" (built from shapes in Blender scripts build_tank.py/build_heli.py 10-17, flat colour per voxel) | lead -> Tripo session | D-297 (600 credits) | queued |
| 03:1x | "priorities are 1. render plan 2. debt fixes 3. everythin else" | lead | D-298 | done |
| 03:2x | Speed runs: "Yes, PC to itself (Recommended)" (tests beside moved a run 22%) | lead | D-299 (hook + driver) | done |
| 03:2x | "yeah it froze before" (P2c bench hit the known self_list freeze, 1.6 GB log) | lead | #254 | doing |
| 03:2x | "maybe we should prioritise the debt fixes" -> "Debt first (Recommended)" | lead | D-300 | done |
| 03:27 | "no godot for 30min" | lead | pause to 03:58: focus-pause marker + hook + guard (C:/kt/no_godot_guard.ps1) | doing |
