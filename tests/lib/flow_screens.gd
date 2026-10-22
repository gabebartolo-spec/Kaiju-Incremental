extends RefCounted
## The flow suite's screen checks (tests/run_flow_tests.gd runs them): the main menu, a new
## game through species select into a rampage, pause and End Rampage, the end beat, the results
## count-up, the evolution tree, the evolution reveal, settings, and quit-and-continue on the
## save. Every step is real input (mouse clicks at a control, key presses), not a handler call.

const FlowDash := preload("res://tests/lib/flow_dash.gd")
const GuiInput := preload("res://tests/lib/gui_input.gd")
const FlowLayout := preload("res://tests/lib/flow_layout.gd")
const FlowSave := preload("res://tests/lib/flow_save.gd")
const FlowStats := preload("res://tests/lib/flow_stats.gd")
const FlowFps := preload("res://tests/lib/flow_fps.gd")
const FlowSettingsRows := preload("res://tests/lib/flow_settings_rows.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
## Rubble left after buying the first evolution (costs come from data, so city-growth's
## re-tuning cannot break these checks).
const LEFT_OVER := 100

var t: SceneTree
var check: Callable
var layout: FlowLayout


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check
	layout = FlowLayout.new(runner, p_check)


func run() -> void:
	SaveFile.delete_save()
	await _check_new_game()
	await _check_results_compare()
	await _check_evolution_and_continue()
	layout.reveal_stage_city()
	await layout.reveal_fits()
	await _check_settings()
	layout.currency_named()
	layout.fonts_ours()
	FlowSave.migration(check)
	SaveFile.delete_save()


func _frames(n: int) -> void:
	for _i: int in n:
		await t.process_frame


func _main() -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	t.root.add_child(main)
	await _frames(3)
	return main


func _screen(main: Node) -> Node:
	return main.call("screen")


## No save: the title offers New Kaiju (no Continue); a click goes to species select, a click
## there starts a rampage; Esc pauses it, End Rampage ends it, the end beat plays in slow motion
## and gives way to the results over the city; EVOLVE opens the tree; the run is on disk.
func _check_new_game() -> void:
	var main := await _main()
	var title := _screen(main)
	check.call(
		title is TitleScreen and GuiInput.button(title, "CONTINUE") == null,
		"with no save the title shows no Continue"
	)
	await GuiInput.click(t, GuiInput.button(title, "NEW KAIJU"))
	await _frames(2)
	var select := _screen(main)
	check.call(select is SpeciesSelect, "clicking NEW KAIJU opens species select")
	await layout.fits_at_scales(select as Control, "species select")
	await GuiInput.key(t, KEY_ESCAPE)
	await _frames(2)
	check.call(_screen(main) is TitleScreen, "Esc on species select goes back to the title")
	await GuiInput.click(t, GuiInput.button(_screen(main), "NEW KAIJU"))
	await _frames(2)
	select = _screen(main)
	await GuiInput.click(t, GuiInput.button(select, "CHOOSE"))
	await _frames(3)
	var rampage := _screen(main) as Rampage
	check.call(
		rampage != null and str(rampage.species["id"]) == "reptilian",
		"clicking the first CHOOSE starts a reptilian rampage"
	)
	if rampage == null:
		main.queue_free()
		return
	await rampage.wait_loaded()  # Main builds the run over several frames behind a loading screen
	layout.listen(rampage, "HUD")
	await FlowDash.run(t, check, rampage)
	await GuiInput.key(t, KEY_ESCAPE)
	var menu := GuiInput.find_script(rampage, PauseMenu)
	layout.listen(rampage, "pause")
	check.call(t.paused and menu != null, "Esc pauses the rampage and opens the pause menu")
	check.call(_hint_hidden(rampage), "the HUD hides behind the pause menu (lead review 3)")
	var clock := rampage.sim.time_left
	await _frames(10)
	check.call(rampage.sim.time_left == clock, "the rampage clock stands still while paused")
	await GuiInput.key(t, KEY_ESCAPE)
	check.call(not t.paused, "Esc again resumes")
	await GuiInput.key(t, KEY_ESCAPE)
	menu = GuiInput.find_script(rampage, PauseMenu)
	await GuiInput.click(t, GuiInput.button(menu, "END RAMPAGE"))
	check.call(not rampage.sim.over, "End Rampage asks first (Are you sure?) and the run goes on")
	await GuiInput.click(t, GuiInput.button(menu, "YES"))
	var hud: RampageHud = GuiInput.find_script(rampage, RampageHud)
	check.call(
		rampage.sim.over and rampage.sim.end_reason == "ended" and not t.paused,
		"End Rampage ends the run (reason %s)" % rampage.sim.end_reason
	)
	check.call(
		hud.beat_running() and hud.headline.text == "RAMPAGE ENDED" and Engine.time_scale < 1.0,
		"the end beat slams its headline on in slow motion (%s)" % Engine.time_scale
	)
	await GuiInput.key(t, KEY_ENTER)
	check.call(hud.beat_running(), "a confirm in the first frames does not skip the end beat")
	await _frames(RampageHud.BEAT_MIN_FRAMES)
	await GuiInput.key(t, KEY_ENTER)
	await _frames(2)
	var results := GuiInput.find_script(rampage, ResultsScreen) as ResultsScreen
	check.call(
		results != null and Engine.time_scale == 1.0,
		"after the beat the results show over the city at normal speed"
	)
	check.call(
		not (GuiInput.find_script(rampage, RampageHud) as RampageHud).visible,
		"the HUD hides behind the report"
	)
	if results != null:
		check.call(
			results.verdict() == "YOUR FIRST RAMPAGE" and results.counting(),
			"a first rampage says so, and the results count up"
		)
		await GuiInput.click(t, GuiInput.button(results, "SKIP"))
		check.call(not results.counting(), "clicking SKIP lands every count at once")
		await GuiInput.click(t, GuiInput.button(results, "EVOLVE"))
		await _frames(2)
	check.call(_screen(main) is UpgradeScreen, "EVOLVE opens the evolution tree")
	var saved := SaveFile.load_game()
	check.call(
		Num.i(saved.get("runs", 0)) == 1 and saved.has("best") and saved["species"] == "reptilian",
		"the run is banked on disk: %s" % [saved]
	)
	main.queue_free()
	await _frames(2)


## The results screen beats or misses the best before it, line by line.
func _check_results_compare() -> void:
	var result := {
		"rubble": 300,
		"destruction": 0.25,
		"toppled": 4,
		"tallest_topple": 12,
		"civilians": 12,
		"tanks": 2,
		"helis": 0,
		"reason": "time"
	}
	var best := {"rubble": 200.0, "destruction": 0.3, "toppled": 2.0, "tanks": 5.0}
	var results := ResultsScreen.new(result, best)
	t.root.add_child(results)
	await _frames(3)
	layout.listen(results, "results")
	await layout.crawl_reads(results, "results")
	check.call(
		results.verdict() == "BIGGER THAN LAST TIME  +50% BIOMASS",
		"beating the best by half says +50%%: %s" % results.verdict()
	)
	await GuiInput.key(t, KEY_ENTER)
	var labels: Array[String] = []
	for node: Node in results.find_children("*", "Label", true, false):
		labels.append((node as Label).text)
	check.call(
		labels.has("300") and labels.has("25%") and labels.has("12"),
		"Enter lands the counts on the result: %s" % [labels]
	)
	check.call(
		(
			results.is_new_best("rubble")
			and results.is_new_best("toppled")
			and not results.is_new_best("tanks")
			and labels.count("NEW BEST") == 3
		),
		"new bests are marked, misses are not (%d marked)" % labels.count("NEW BEST")
	)
	var bests := labels.filter(func(l: String) -> bool: return l.begins_with("best "))
	check.call(
		bests.size() + labels.count("NEW BEST") == ResultsScreen.ROWS.size() - 1,
		"every row but the headline's shows its best or NEW BEST once: %s" % [bests]
	)
	var short := ResultsScreen.new({"rubble": 150}, {"rubble": 200.0})
	check.call(short.verdict() == "50 BIOMASS SHORT OF YOUR BEST", "a miss says how far short")
	short.free()
	results.queue_free()
	await _frames(1)


## A save with Endless Rage owned and the first evolution's price plus LEFT_OVER rubble:
## Continue goes to the tree; clicking the first evolution buys it and plays the reveal (baby
## to adolescent, a bigger body, the tower it now topples); Enter skips it
## without buying again. Quit, relaunch, Continue: same tree.
func _check_evolution_and_continue() -> void:
	var save := SaveFile.new_save("insectoid")
	save["rubble"] = _evolve_cost() + LEFT_OVER
	save["runs"] = 2
	save["levels"] = {"claws": 1, "hide": 1, "rage": 1}
	SaveFile.save_game(save)
	var main := await _main()
	var title := _screen(main)
	var cont := GuiInput.button(title, "CONTINUE")
	check.call(cont != null, "with a save the title offers Continue")
	await layout.fits_at_scales(title as Control, "title screen")
	layout.listen(title, "title")
	await GuiInput.click(t, cont)
	await _frames(3)
	var tree := _screen(main) as UpgradeScreen
	check.call(tree != null, "Continue on a played save opens the evolution tree")
	if tree == null:
		main.queue_free()
		return
	var stride := tree.node_button("stride")
	check.call(
		stride.text.contains("BUY %d" % tree.tree.cost("stride")) and stride.state == "buy",
		"an affordable node says BUY and its price: %s" % stride.text
	)
	var copy: Array[String] = []
	for node: Node in tree.find_children("*", "", true, false):
		if node is Button or node is Label:
			copy.append(str(node.get("text")))
		elif node is RichTextLabel:
			copy.append((node as RichTextLabel).get_parsed_text())
	var bad := copy.filter(func(c: String) -> bool: return c.contains("->") or c.contains("need"))
	check.call(
		bad.is_empty(), "the tree uses drawn arrows and keeps 'need' in the side panel: %s" % [bad]
	)
	var ultimate := tree.node_button("i_brood")
	check.call(
		(
			ultimate.role == "ultimate"
			and ultimate.size.y > stride.size.y
			and ultimate.text.contains("[E / Y]")
		),
		"the insectoid's Brood is its branch's capstone, bigger, with its button"
	)
	await layout.fits_at_scales(tree, "evolution tree")
	layout.listen(tree, "tree")
	await FlowStats.plain(t, check, tree)
	await FlowFps.caps(t, check)
	await FlowFps.graphics(t, check)
	FlowFps.graphics_rows(check)
	await preload("res://tests/lib/flow_preset_caps.gd").check(t, check)
	FlowFps.stale_cap(check)
	check.call(
		(
			tree.node_button("i_glide").role == "branch"
			and tree.node_button("evolve1").role == "evolve"
		),
		"branch nodes and evolutions are marked as such"
	)
	await GuiInput.click(t, tree.node_button("evolve1"))
	await _frames(2)
	var reveal := GuiInput.find_script(tree, EvolutionReveal) as EvolutionReveal
	check.call(
		reveal != null and tree.tree.level("evolve1") == 1 and tree.rubble == LEFT_OVER,
		"clicking the evolution buys it (rubble %d) and plays the reveal" % tree.rubble
	)
	if reveal != null:
		check.call(
			(
				reveal.stage_before == "baby"
				and reveal.stage_after == "adolescent"
				and reveal.scale_after > reveal.scale_before
				and reveal.tower_floors == 2 * Num.i(Content.section("city")["tier_height"])
			),
			(
				"the reveal grows a baby into an adolescent beside a %d-floor tower"
				% reveal.tower_floors
			)
		)
		await _frames(EvolutionReveal.SWAP_FRAME + 2)
		check.call(reveal.revealed(), "the new stage is on screen after the swap")
		var shown: Array[String] = []
		for node: Node in reveal.find_children("*", "Label", true, false):
			shown.append((node as Label).text)
		check.call(
			shown.has("BEHEMOTH"), "the reveal is titled by the node bought (D-051): %s" % [shown]
		)
		await GuiInput.key(t, KEY_ENTER)
		await _frames(2)
		check.call(not is_instance_valid(reveal), "Enter skips the reveal")
		check.call(tree.tree.level("evolve1") == 1, "skipping the reveal does not buy again")
	main.queue_free()
	await _frames(2)
	var again := await _main()
	await GuiInput.click(t, GuiInput.button(_screen(again), "CONTINUE"))
	await _frames(3)
	var reloaded := _screen(again) as UpgradeScreen
	check.call(
		(
			reloaded != null
			and reloaded.rubble == LEFT_OVER
			and reloaded.tree.level("evolve1") == 1
			and reloaded.tree.level("rage") == 1
		),
		"after quitting mid-tree and relaunching, Continue shows the same tree and rubble"
	)
	again.queue_free()
	await _frames(2)


## Settings from the title: the fullscreen toggle and the UI scale step by click and stick;
## the controls list covers keyboard and pad; Esc goes back.
func _check_settings() -> void:
	var main := await _main()
	var title := _screen(main)
	Sfx.ui_played.clear()
	await GuiInput.click(t, title.find_child("Gear", true, false) as Button)
	var menu := GuiInput.find_script(title, SettingsMenu) as SettingsMenu
	check.call(menu != null, "clicking the title gear opens the settings")
	check.call(Sfx.ui_played == ["ui_click"], "a menu button clicks: %s" % [Sfx.ui_played])
	if menu == null:
		main.queue_free()
		return
	await layout.fits_at_scales(menu, "settings")
	FlowSettingsRows.run(check, menu)
	var was_full: bool = PlayerSettings.fullscreen
	await GuiInput.click(t, GuiInput.button(menu, "< ON >" if was_full else "< OFF >"))
	check.call(PlayerSettings.fullscreen != was_full, "clicking the fullscreen switch flips it")
	PlayerSettings.set_fullscreen(was_full)
	await GuiInput.click(t, GuiInput.button(menu, "< 100% >"))
	check.call(
		(
			is_equal_approx(PlayerSettings.ui_scale, 1.15)
			and is_equal_approx(t.root.content_scale_factor, 1.15)
		),
		"clicking UI scale steps it to 115%% and scales the UI (%s)" % t.root.content_scale_factor
	)
	await GuiInput.drag(t, menu.effects, 0.1, 0.7)
	var sfx_db := AudioServer.get_bus_volume_db(PlayerSettings.bus("SFX"))
	check.call(
		(
			is_equal_approx(PlayerSettings.sfx_volume, 0.7)
			and is_equal_approx(sfx_db, linear_to_db(0.7))
		),
		(
			"dragging Sound effects to 70%% sets the SFX bus (%s, %.1f dB)"
			% [PlayerSettings.sfx_volume, sfx_db]
		)
	)
	var texts: Array[String] = []
	for node: Node in menu.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	check.call(
		texts.has("Ultimate") and texts.has("E") and texts.has("Y") and texts.has("Start"),
		"the controls list shows keyboard and pad"
	)
	await GuiInput.key(t, KEY_ESCAPE)
	check.call(not is_instance_valid(menu), "Esc closes the settings")
	var cfg := ConfigFile.new()
	check.call(
		(
			cfg.load(PlayerSettings.PATH) == OK
			and is_equal_approx(Num.f(cfg.get_value("display", "ui_scale")), 1.15)
		),
		"the UI scale is saved to settings.cfg"
	)
	PlayerSettings.sfx_volume = -1.0
	PlayerSettings.load_saved(false)
	check.call(
		is_equal_approx(PlayerSettings.sfx_volume, 0.7),
		"the sound-effects volume comes back after a reload (%s)" % PlayerSettings.sfx_volume
	)
	PlayerSettings.set_sfx_volume(Num.f(Content.section("sfx")["default_volume"]))
	PlayerSettings.next_ui_scale()
	PlayerSettings.next_ui_scale()
	check.call(PlayerSettings.ui_scale == 1.0, "UI scale wraps back to 100%")
	main.queue_free()
	await _frames(2)


func _evolve_cost() -> int:
	return UpgradeTree.new(Content.upgrades(), {}, "insectoid").cost("evolve1")


## True when the HUD (its rings and the biomass figure) is not showing.
func _hint_hidden(rampage: Rampage) -> bool:
	var hud: RampageHud = GuiInput.find_script(rampage, RampageHud)
	return not hud.breath_ring.is_visible_in_tree() and not hud.biomass.is_visible_in_tree()
