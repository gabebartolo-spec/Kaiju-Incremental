# 15 Minimal in-run HUD for Kaiju Incremental (researched 2026-10-21)

Scope: how to build a really minimal rampage HUD that still meets the director's rulings and 4K-TV readability. The
fixed rulings (docs/roadmap/2026-10-20-build2-playtest.md, read in full for rows 10, 12, 13, 23) are:
- **b2-10:** "The timer at the top is good." Biomass is a boxless figure in the bottom right. No button or keyboard
  tutorials on screen: show them once at the start of the game and in a controls menu.
- **b2-12:** The atomic breath cooldown is "just an icon with a circular load bar around the edges".
- **b2-13:** The health bar at the bottom of the screen is "removed/repurposed".
- **b2-23:** Tooltips in the upgrade tree keep one width, so the screen does not change shape.

Code read for grounding (read only):
- `scenes/rampage_hud.gd` (274 lines, all of it).
- `scenes/ui_kit.gd`: constants, `label()`, `bar()`.
- `scenes/upgrade_screen.gd`: the side panel.
- `scenes/city_view.gd`: `float_text()`.
- `sim/rampage_sim.gd`: the cooldown fields.
- `scenes/settings_menu.gd`: it already has a CONTROLS list.
- `project.godot`: 1920x1080 base, `canvas_items` stretch, `expand` aspect.

## Key findings

1. **Four interface types, from two questions.** Fagerholt & Lorentzon (Chalmers, 2009, "Beyond the HUD") cross two
   questions: is the element part of the fiction, and is it placed in the 3D world? That gives four types:
   - diegetic: in the world and in the fiction;
   - non-diegetic: a classic overlay;
   - spatial: in 3D space but not a world object;
   - meta: in the fiction but not placed in space, such as blood on the screen.

   The labels are now standard in game UI design, and the original thesis is hosted at
   http://publications.lib.chalmers.se/records/fulltext/111921.pdf. Definitions as summarised in a lecture deck:
   https://www.slideshare.net/slideshow/game-design-2-lecture-7-immersion-through-ui-slideshare/27866402 and the
   Packt UI book: https://www.oreilly.com/library/view/mastering-ui-development/9781787125520/78296d1f-f5be-4af9-8ed6-b47ece9c8bda.xhtml.
   What this means here: a kaiju HUD is mostly non-diegetic (the timer and biomass). Health is the best candidate to
   go meta (a red screen edge) or diegetic (damage on the kaiju).
2. **Dead Space puts the HUD on the hero's body.** Health is a segmented bar along Isaac's spine, and inventory,
   weapon select and the locator are holograms in the world. The aim was to remove the "wall of safety" between
   player and game.
   - Lead UI designer Dino Ignacio's GDC 2013 talk: https://gamedeveloper.com/design/video-designing-i-dead-space-i-s-immersive-user-interface
   - Overview: https://www.hudsandguis.com/2012/08/22/dead-space-2-diegetic-interface-design
   - Per the fan wiki, the spine bar steps through aqua, green, yellow and red as health falls, and blinks near
     death: https://deadspace.fandom.com/wiki/Resource_Integration_Gear

   Lesson: the meter is redundant by both colour and length, and it sits where the eye already is (the over-shoulder
   camera looks at the back).
3. **Show a meter only when it changes, and next to the action.** Breath of the Wild's stamina wheel is hidden until
   stamina is used, and it sits beside Link rather than in a corner. Nintendo's stated direction was to display
   information only when necessary, and the "Pro HUD" was added to strip even more.
   - https://zeldawiki.wiki/wiki/Talk:Inventory
   - https://www.thefamicast.com/2017/12/part-2-immersive-impressionable-ui.html
   - https://mechanicsofmagic.com/?p=16556

   Journey uses the scarf: its length is your flight capacity and its glow fades as you fly, so there is no numeric
   meter: https://www.psu.com/review/14565/Journey-Review, https://godisageek.com/?p=69621. Shadow of the Colossus
   removed most HUD elements as deliberate subtraction:
   https://www.animeclick.it/game/8450/shadow-of-the-colossus/recensioni,
   https://blakecrosley.com/fr/blog/design-philosophy-fumito-ueda. The specific grip and health circle behaviour was
   NOT verified (see the gaps).
4. **Diegetic-only cues fail some players in some scenes.** Ghost of Tsushima replaced the minimap and waypoints with
   the Guiding Wind: https://www.gamerevolution.com/?p=653064,
   https://www.androidcentral.com/ghost-tsushima-creative-director-interview. Can I Play That found the white wind
   streaks lose contrast on the snowy northern map, which turns the feature into a barrier late in the game:
   https://caniplaythat.com/2020/07/29/ghost-of-tsushima-accessibility-review/. For us, a red edge vignette for low
   health can vanish against a burning, red-orange city unless it also has a shape and a sound.
5. **Never rely on one sense.** Game Accessibility Guidelines (Basic): "Ensure no essential information is conveyed
   by a fixed colour alone" and "...by sounds alone". Intermediate: "Indicate / allow reminder of controls during
   gameplay" and "Avoid placing essential temporary information outside the player's eye-line". Advanced: "Provide an
   option to turn off / hide all non interactive elements". Source: https://gameaccessibilityguidelines.com/full-list/.
   The controls reminder is satisfied by b2-10's controls menu, as long as pause leads to it. The settings menu
   already lists CONTROLS (`scenes/settings_menu.gd:70`).
6. **Text size has a hard floor, and caps-only text measures smaller.** Xbox Accessibility Guideline 101 sets minimum
   default sizes, measured as body height from the highest ascender to the lowest descender, outline pixels included
   only above 2:1 contrast: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101.
   - Console (the 10-foot case, closest to a TV): 26 px at 1080p, 52 px at 4K.
   - PC: 18 px at 1080p, 36 px at 4K.
   - Glyphs inside icons must also meet the minimum.

   Our fonts are capitals only (D-058, `ui_kit.gd:38`), so the measured height is about the cap height, smaller than
   the font size. A 24 px label at 2x stretch is a 48 px font at 4K, which probably measures in the mid-30s px, near
   the PC floor and below the console floor. This is an inference: Kaiju Block's cap height was not measured. The
   current HUD also uses `SIZE_SMALL = 20` for the HP text and "CITY DESTROYED", which breaks the director's 24 px
   base outright.
7. **Contrast is measured against the worst patch behind the text.** XAG 102 sets 4.5:1 for standard text and HUD
   elements, 3:1 for large text, and 7:1 in a high-contrast mode. Large text means 36 px at 1080p on PC (72 px at 4K)
   or 52 px on console. Over a moving background, measure against the lowest-contrasting area:
   https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102.
   Its listed remedies are an optional solid or adjustable backplate, border outlines, a black outline plus a white
   outline on symbols (For Honor), and player-chosen HUD colours. A boxless biomass figure over fire therefore needs a
   thick dark outline plus a shadow. The yellow WARN text (`ffd84a`) has almost no contrast against an explosion
   unless the outline carries it.
8. **TV safe area is still real.** Xbox docs put title UI inside the title-safe area, the inner 90% (1720x1000 at
   1080p, 3456x1944 at 4K): https://devdocs.xbox.com/build/core-features/graphics/overviews/screen-areas. Some
   modern TVs still overscan and others do not: https://www.shawnhargreaves.com/blog/overscan-title-safe-areas-and-test-cost.html.
   - Our HUD margin is 28 logical px on every side (`rampage_hud.gd:61`), well inside the about 100 px side and
     40 px top/bottom border that title-safe implies at 1080p logical.
   - Godot's multiple-resolutions page does not cover overscan, so this is ours to handle:
     https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html.
9. **Godot 4.7 has every piece built in** (all pages are the 4.7 stable docs):
   - `TextureProgressBar.fill_mode = FILL_CLOCKWISE` (4), with `radial_initial_angle`, `radial_fill_degrees`,
     `texture_under`, `texture_progress`, `texture_over` and per-texture tints:
     https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html
   - `LabelSettings` has `outline_size`, `outline_color`, `shadow_size`, `shadow_color` and `shadow_offset`, plus
     stacked outlines and stacked shadows (for example a dark outline under a light rim), on one shared resource:
     https://docs.godotengine.org/en/stable/classes/class_labelsettings.html
   - `canvas_items` stretch plus `content_scale_factor` can be exposed as a UI-scale option, with anchors for
     corners: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
   - `Camera3D.unproject_position()` and `is_position_behind()` place 2D controls over 3D points:
     https://docs.godotengine.org/en/stable/classes/class_camera3d.html
10. **The active incrementals show little in a run, but the source is thin.** Nodebuster's run is a short "breach
    session" with currency drops (bits, nodes), and health is an upgrade-tree stat:
    https://mancunion.com/2025/05/08/nodebuster-review-a-short-and-sweet-incremental-game/. I found no source that
    describes its in-run HUD layout, nor Astro Prospector's or Chef Knight's. Treat "the genre shows timer, currency,
    health and nothing else" as plausible and unverified.

## Element -> how to show it minimally -> Godot implementation

| Element | How to show it minimally | Godot 4.7.2 implementation |
|---|---|---|
| Timer (top centre; b2-10 says keep it) | Keep the current boxed number: he said it is good. For the last 10 s, add redundancy beyond the existing colour swap: a scale pulse once a second plus a tick or siren sound, so it does not rely on colour alone. Optionally a faint edge pulse of the screen in the last 5 s. | It exists (`_time`, `_clock_box`). Add a `create_tween()` scale pulse 1.0 -> 1.15 -> 1.0 on each whole-second change while `time_left < 10`. Set `pivot_offset` to half the size. Trigger the SFX from the same change. |
| Biomass (bottom right, boxless; b2-10) | A big white or yellow number with a thick dark outline and a soft shadow, and no plate. It rolls toward the true value, pops (scale) on big gains, and has a small "BIOMASS" word or icon beside it. | Anchor the Label bottom-right (`PRESET_BOTTOM_RIGHT`) inside the safe-area margin. Use one shared `LabelSettings` (outline about size/5, black at 0.9, plus a shadow offset of 3-4 px). In `_process`, set `shown = lerp(shown, sim.rubble, 1 - exp(-k*dt))` and format with `Num.i`. On a gain above a threshold, tween scale to 1.2 and back. One tween per pop, killed before a new one starts. |
| Breath cooldown (b2-12) | One icon with a ring that fills clockwise while charging. When ready: a full bright ring, one flash or pulse, and a "ready" sound. No seconds text and no key label by default (b2-10). | Simplest, with no texture assets: a `Control` whose `_draw()` calls `draw_arc(c, r, -PI/2, -PI/2 + TAU*ratio, 64, col, w, true)` and `queue_redraw()` each frame. Here `ratio = 1 - sim.ability_ready_in / max(0.5, sim.stat("ability_cooldown"))`, mirroring `rampage_sim.gd:219`. Alternative: `TextureProgressBar` with `FILL_CLOCKWISE` and two ring PNGs (licensing register entries needed). The centre icon is a `TextureRect` or a drawn glyph. |
| Health (b2-13: removed or repurposed) | Remove the bar. Show damage on the screen edge and the body: a red edge vignette whose width and opacity grow as HP falls (shape plus colour), a heartbeat or low-growl loop below about 30% (sound), and a short flash on the kaiju when hit. Optional "repurposed" form: a thin bar that appears only when hit and fades after about 2 s (the BotW pattern). | A full-rect `ColorRect` with a small `canvas_item` shader: radial falloff from the centre, `uniform float hurt`, `MOUSE_FILTER_IGNORE`. Tween `hurt` toward `1 - hp/max_hp`. Works in Forward+ and Compatibility. Heartbeat through the existing SFX layer. The hit flash is a material `emission` or `albedo` tween in presentation only. |
| Controls (b2-10) | Not on the HUD. A one-time controls card at the start of the first rampage that fades out on the first input or after N s, plus the existing CONTROLS list in settings, reached from pause. | Delete the `hint` label (`rampage_hud.gd:119-123`). Add a centred `PanelContainer` card shown when a `PlayerSettings` "controls_seen" flag is false, then set the flag (save field: sim-review if it touches the save schema). The settings menu already renders `PlayerSettings.CONTROLS`. |
| Tooltips (b2-23, upgrade tree) | One fixed width for every node's detail panel. Long names wrap or shrink to fit and never widen the panel. | `side.custom_minimum_size` is a minimum (`upgrade_screen.gd:85`), so any non-wrapping child can widen it. Inference from reading, not reproduced: likely culprits are `_info_role` (no autowrap) and the stat-row HBox. Fix: set `autowrap_mode` on every label, wrap the panel in a fixed-size parent (set `size` and clip contents, or cap the width in a `custom_minimum_size`-only column with `SIZE_SHRINK_BEGIN`), and fit the title font like `upgrade_node.gd` already does. Test: the panel width is equal for every node, including ULTIMATE ATOMIC BEAM. |
| Stage-up / upgrade notices | The centre-screen slam already used by the end beat: a big headline that scales in with TRANS_BACK, holds about 1.2 s, then fades. Pair it with a sound sting. Small world gains use the existing Label3D float text. | Reuse the `show_end_beat` pattern (`rampage_hud.gd:180-207`) as a `notice(text)` function without the slow motion. Place over 3D points with `Label3D` billboards (`city_view.gd:364`) or `camera.unproject_position()`, skipping when `is_position_behind()` is true. |

## Sources

- Fagerholt & Lorentzon 2009 (original, not opened): http://publications.lib.chalmers.se/records/fulltext/111921.pdf
- Taxonomy summaries: https://www.slideshare.net/slideshow/game-design-2-lecture-7-immersion-through-ui-slideshare/27866402 ; https://www.oreilly.com/library/view/mastering-ui-development/9781787125520/78296d1f-f5be-4af9-8ed6-b47ece9c8bda.xhtml
- Dead Space: https://gamedeveloper.com/design/video-designing-i-dead-space-i-s-immersive-user-interface ; https://www.hudsandguis.com/2012/08/22/dead-space-2-diegetic-interface-design ; https://deadspace.fandom.com/wiki/Resource_Integration_Gear (fan wiki)
- Breath of the Wild: https://zeldawiki.wiki/wiki/Talk:Inventory ; https://www.thefamicast.com/2017/12/part-2-immersive-impressionable-ui.html ; https://mechanicsofmagic.com/?p=16556
- Journey: https://www.psu.com/review/14565/Journey-Review ; https://godisageek.com/?p=69621 ; https://strategywiki.org/wiki/Journey_(2012)
- Shadow of the Colossus / Ueda: https://www.animeclick.it/game/8450/shadow-of-the-colossus/recensioni ; https://blakecrosley.com/fr/blog/design-philosophy-fumito-ueda
- Ghost of Tsushima: https://www.androidcentral.com/ghost-tsushima-creative-director-interview ; https://www.gamerevolution.com/?p=653064 ; https://caniplaythat.com/2020/07/29/ghost-of-tsushima-accessibility-review/
- Nodebuster: https://mancunion.com/2025/05/08/nodebuster-review-a-short-and-sweet-incremental-game/
- Xbox Accessibility Guidelines: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101 ; https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102
- Xbox screen areas: https://devdocs.xbox.com/build/core-features/graphics/overviews/screen-areas ; overscan: https://www.shawnhargreaves.com/blog/overscan-title-safe-areas-and-test-cost.html
- Game Accessibility Guidelines: https://gameaccessibilityguidelines.com/full-list/
- Godot 4.7 docs: https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html ; https://docs.godotengine.org/en/stable/classes/class_labelsettings.html ; https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html ; https://docs.godotengine.org/en/stable/classes/class_camera3d.html

## For Kaiju Incremental (ranked, simplest viable first)

1. **Strip the HUD down to the rulings.** Cost: about 2-3 h, `rampage_hud.gd` only, no sim change.
   - Delete the controls `hint` label, the left HP plate (`_hp`, `_hp_text`, the species name) and both
     `PLATE_ALPHA` plates.
   - Keep the boxed timer exactly as it is (b2-10 "good").
   - Biomass becomes one boxless label anchored bottom-right, at `SIZE_TITLE` (72) or at least `SIZE_HEAD` (36).
   - No HUD text below 24: drop every `SIZE_SMALL` use in the HUD.
   - Raise the root margin from 28 to about 96 px left/right and 54 px top/bottom (title-safe, finding 8). Put those
     values in `data/` per hard rule 4.
2. **Breath as a ring icon (b2-12).** Cost: about 2-3 h plus one icon.
   - A small Control draws its ring with `draw_arc` from `ability_ready_in / stat("ability_cooldown")`, so there are
     no texture assets and no licensing entries.
   - On ready: a pulse and a sound, so the ready state never relies on colour alone.
   - The centre icon needs art: drawn primitives today, an authored icon later through art QC.
   - Placement: bottom-centre, where the ability text was, which repurposes the old health bar's space (b2-13).
   - **Flag for the director:** dash and the ultimate also live in text lines today. The same ring treatment beside
     breath is the consistent option, but he only ruled on breath, so ask with labelled images.
3. **Health as edge vignette, heartbeat and hit flash (b2-13 "removed").** Cost: about half a day; one small shader
   plus the SFX hook.
   - The vignette's width grows (shape), it is red (colour) and the heartbeat plays (sound): three channels per
     finding 5.
   - Test the vignette over the brightest fire frame (findings 4 and 7).
   - If the director prefers "repurposed", add the BotW-style hit-only thin bar instead: about 1 h more. That
     choice is his.
4. **One shared HUD text style.** Cost: about 1 h.
   - A single `LabelSettings` (or the existing `UiKit.label` outline, made thicker and given a shadow) for every HUD
     number.
   - Check a 4K capture with XAG's method (finding 6): measured body height at least 36 px at 4K, aiming for 52 for
     the 10-foot case. Contrast at least 4.5:1 against the worst background patch, using the existing
     `UiKit.contrast()`.
5. **Biomass counter roll and pop.** Cost: about 1 h. An exponential approach in `_process` plus a capped scale pop
   on big gains, with no tween per gain (biomass ticks constantly).
6. **Controls once at the start (b2-10).** Cost: about 2-3 h. A first-run card plus a "controls_seen" flag. A save
   field means a sim-review packet per `kaiju-sim-review`. Pause already reaches the settings CONTROLS list.
7. **Fixed tooltip width (b2-23).** Cost: about 1-2 h plus a test asserting equal panel width across all nodes.
   Autowrap every side-panel label and fix the column width (see the table). Reproduce first: the culprit label is
   inferred, not proven.
8. **Stage-up notice.** Cost: about 1 h. A `notice()` function using the end beat's slam tween, without the slow
   motion.
9. **Later, only if he wants it: a "HUD: minimal / full" setting.** Full shows HP and cooldown seconds; it is the GAG
   advanced option (finding 5). Also a UI-scale slider via `content_scale_factor`. Cost: about half a day.
   **Open, not ruled:** the "CITY DESTROYED" bar has no ruling. Folding it into a small % under the timer, or
   cutting it, is the director's call.

Determinism note: every fade, roll and pulse is presentation only. Tweens read sim fields and never write them, and
the end beat's tween already uses `set_ignore_time_scale(true)`.

Evidence gaps:
- These were not verified from primary sources: Shadow of the Colossus's exact grip and health indicator behaviour,
  Inside and Limbo's no-HUD rationale, Metro's watch and gas mask, Teardown's tool HUD, and the in-run HUD layouts of
  Nodebuster, Astro Prospector and Chef Knight.
- The Fagerholt thesis and Ignacio's GDC talk were known only through secondary summaries.
- Kaiju Block's cap height and the HUD's real 4K body-height measurements are unmeasured.
- The tooltip-widening label is inferred from code, not reproduced.
