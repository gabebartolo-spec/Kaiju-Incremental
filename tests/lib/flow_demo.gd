extends RefCounted
## The flow suite's demo checks (D-050, D-145, D-152, D-153), on the shipping data/tuning.json
## "demo" section: species select offers only the demo's species; buying the final upgrade shows
## the thanks screen (the sim's totals, Leave feedback, Try Endless mode, Keep playing) and unlocks
## Endless mode; normal mode stays replayable. Every step is real input (mouse, keys, gamepad).
## The rest of the flow suite runs with the demo switched off (demo_off), so the full game stays
## covered.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FlowLayout := preload("res://tests/lib/flow_layout.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const LEFT_OVER := 100
const EMERGE_CAP := 1200

var t: SceneTree
var check: Callable
var layout: FlowLayout
var _enabled: bool


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check
	layout = FlowLayout.new(runner, p_check)


## Switches the demo off in the cached tuning, for the full-game checks.
func demo_off() -> void:
	var demo := Content.section("demo")
	_enabled = demo.get("enabled", false) == true
	if demo.has("enabled"):
		demo["enabled"] = false


func demo_restore() -> void:
	var demo := Content.section("demo")
	if demo.has("enabled"):
		demo["enabled"] = _enabled


func run() -> void:
	var demo := Content.section("demo")
	check.call(
		demo.get("enabled", false) == true and demo.get("endless") is Dictionary,
		"the shipping data runs the demo, with its Endless mode rows: %s" % [demo]
	)
	SaveFile.delete_save()
	await _check_species_filter()
	await _check_thanks_flow()
	await _check_thanks_endless()
	await _check_continue_after()
	await _check_other_species_save()
	await _check_controls_rows()
	SaveFile.delete_save()


## Loaded, and past the river rise that holds the sim back (D-083), so its clock runs.
func _settled(run: Rampage) -> void:
	await run.wait_loaded()
	var frames := 0
	while run.sim.emerge.active and frames < EMERGE_CAP:
		await t.physics_frame
		frames += 1


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


## New Kaiju: the select screen shows the demo's species only (the others are absent, not
## greyed), and CHOOSE starts it.
func _check_species_filter() -> void:
	var main := await _main()
	await GuiInput.click(t, GuiInput.button(_screen(main), "NEW KAIJU"))
	await _frames(2)
	var select := _screen(main)
	var picks: Array[Node] = []
	var names: Array[String] = []
	if select != null:
		picks = select.find_children("*", "Button", true, false).filter(
			func(b: Node) -> bool: return (b as Button).text == "CHOOSE"
		)
		for node: Node in select.find_children("*", "Label", true, false):
			names.append((node as Label).text)
	check.call(
		picks.size() == 1 and names.has("REPTILIAN") and not names.has("INSECTOID"),
		"the demo's species select offers the reptilian only: %d cards" % picks.size()
	)
	await GuiInput.click(t, GuiInput.button(select, "CHOOSE"))
	await _frames(3)
	var rampage := _screen(main) as Rampage
	check.call(
		rampage != null and str(rampage.species["id"]) == "reptilian",
		"choosing it starts a reptilian rampage"
	)
	main.queue_free()
	await _frames(2)


## A reptilian save one level short of the whole tree (every node owned but the last one nobody
## else needs), able to afford it. Returns that last node's id through `last_out[0]`.
func _near_final_save(last_out: Array[String]) -> Dictionary:
	var defs: Array = Content.upgrades()
	var needed: Dictionary = {}
	for def: Dictionary in defs:
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			needed[req] = true
	var levels: Dictionary = {}
	var last := ""
	for def: Dictionary in defs:
		if def.has("species") and def["species"] != "reptilian":
			continue
		levels[str(def["id"])] = Num.i(def["max_level"])
		var effects: Dictionary = def.get("effects", {})
		if not needed.has(str(def["id"])) and not effects.has("size"):
			last = str(def["id"])
	levels[last] = Num.i(levels[last]) - 1
	var tree := UpgradeTree.new(defs, levels, "reptilian")
	var save := SaveFile.new_save("reptilian")
	save["rubble"] = tree.cost(last) + LEFT_OVER
	save["runs"] = 3
	save["demo"] = true
	save["levels"] = levels
	last_out.append(last)
	return save


## Continue, then buy the last node by click: the thanks screen (or null).
func _buy_final(main: Node, last: String) -> DemoEnd:
	await GuiInput.click(t, GuiInput.button(_screen(main), "CONTINUE"))
	await _frames(3)
	var tree := _screen(main) as UpgradeScreen
	check.call(
		tree != null and GuiInput.button(tree, "ENDLESS MODE") == null,
		"before the final upgrade Endless mode is not offered"
	)
	await GuiInput.click(t, tree.node_button(last))
	await _frames(EvolutionReveal.END_FRAME + 4)
	return _screen(main) as DemoEnd


## Buying the final upgrade (every tree node owned) shows the thanks screen; nothing else does.
## Behemoth's reveal plays and the tree stays. Real input all the way.
func _check_thanks_flow() -> void:
	var save := SaveFile.new_save("reptilian")
	save["rubble"] = UpgradeTree.new(Content.upgrades(), {}, "reptilian").cost("evolve1") + LEFT_OVER
	save["runs"] = 2
	save["demo"] = true
	save["levels"] = {"claws": 1, "hide": 1, "rage": 1}
	SaveFile.save_game(save)
	var main := await _main()
	await GuiInput.click(t, GuiInput.button(_screen(main), "CONTINUE"))
	await _frames(3)
	var tree := _screen(main) as UpgradeScreen
	await GuiInput.click(t, tree.node_button("evolve1"))
	await _frames(EvolutionReveal.END_FRAME + 4)
	check.call(_screen(main) == tree, "buying Behemoth plays its reveal and stays on the tree")
	main.queue_free()
	await _frames(2)
	var last: Array[String] = []
	save = _near_final_save(last)
	SaveFile.save_game(save)
	main = await _main()
	var card := await _buy_final(main, last[0])
	check.call(card != null, "buying the final upgrade (%s) shows the thanks screen: %s" % [last[0], _screen(main)])
	if card != null:
		await _thanks_card(main, card)
	main.queue_free()
	await _frames(2)


func _thanks_card(main: Node, card: DemoEnd) -> void:
	await _frames(2)
	var texts: Array[String] = []
	for node: Node in card.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	var demo := Content.section("demo")
	check.call(
		texts.has(str(demo["end_title"])) and texts.has(str(demo["end_line"])),
		"the thanks screen says %s / %s: %s" % [demo["end_title"], demo["end_line"], texts]
	)
	var rows := Demo.rows(card.totals)
	var shown := true
	for row: PackedStringArray in rows:
		shown = shown and texts.has(row[0]) and texts.has(row[1])
	check.call(shown and rows.size() == 6, "it lists the six rampage totals: %s" % [rows])
	var saved := SaveFile.load_game()
	check.call(saved["demo_done"] == true, "the thanks is banked on disk (Endless mode unlocked)")
	check.call(
		card.stage == "adult" and card.species_id == "reptilian",
		"it stages the reptilian adult (%s)" % card.stage
	)
	var clip: Variant = card.clip_roar
	check.call(
		(
			clip is bool
			and (card.roars >= 1 if clip else card.roars == 0)
			and card.roar_sounds == card.roars
		),
		"it roars only from a clip, every roar heard (clip %s, %d roars)" % [clip, card.roars]
	)
	check.call(
		(
			GuiInput.button(card, "LEAVE FEEDBACK") != null
			and GuiInput.button(card, "TRY ENDLESS MODE") != null
			and GuiInput.button(card, "KEEP PLAYING") != null
		),
		"it offers Leave feedback, Try Endless mode and Keep playing"
	)
	await layout.fits_at_scales(card, "thanks screen")
	layout.listen(card, "thanks screen")
	layout.fonts_ours()
	await _feedback_inputs(card)
	# Keep playing by pad: back to the tree (normal mode), now offering Endless mode.
	GuiInput.button(card, "KEEP PLAYING").grab_focus()
	await GuiInput.pad(t, JOY_BUTTON_A)
	await _frames(3)
	var tree := _screen(main) as UpgradeScreen
	check.call(tree != null, "the pad's A on Keep playing returns to the tree: %s" % _screen(main))
	if tree == null:
		return
	var endless := GuiInput.button(tree, "ENDLESS MODE")
	check.call(endless != null, "the tree now offers Endless mode")
	if endless != null:
		await GuiInput.click(t, endless)
		await _endless_run(main)


## Leave feedback opens the data URL, by mouse, by pad (focus moved with the d-pad) and by key.
func _feedback_inputs(card: DemoEnd) -> void:
	var opened: Array[String] = []
	card.opener = func(url: String) -> int:
		opened.append(url)
		return OK
	var url := Demo.feedback_url()
	await GuiInput.click(t, GuiInput.button(card, "LEAVE FEEDBACK"))
	check.call(opened == [url], "a click on Leave feedback opens the data URL: %s" % [opened])
	GuiInput.button(card, "TRY ENDLESS MODE").grab_focus()
	await GuiInput.pad(t, JOY_BUTTON_DPAD_LEFT)
	check.call(
		t.root.gui_get_focus_owner() == GuiInput.button(card, "LEAVE FEEDBACK"),
		"the pad's d-pad moves focus from Try Endless mode to Leave feedback"
	)
	await GuiInput.pad(t, JOY_BUTTON_A)
	check.call(opened == [url, url], "the pad's A on Leave feedback opens it: %d" % opened.size())
	await GuiInput.key(t, KEY_ENTER)
	check.call(opened == [url, url, url], "Enter on Leave feedback opens it: %d" % opened.size())
	check.call(
		url.begins_with("https://") and url == str(Content.section("demo")["feedback_url"]),
		"the link is the one data string: %s" % url
	)


## An Endless run (already started from a button): no clock, nothing banked, End Rampage goes
## back to the tree through the report.
func _endless_run(main: Node) -> void:
	var run := _screen(main) as Rampage
	check.call(run != null and run.sim.endless != null, "Endless mode starts an endless rampage")
	if run == null:
		return
	await _settled(run)
	var before := SaveFile.load_game()
	await _frames(60)
	check.call(not run.sim.over and run.sim.elapsed > 0.5, "Endless mode has no clock to run out (over %s, elapsed %s)" % [run.sim.over, run.sim.elapsed])
	await GuiInput.key(t, KEY_ESCAPE)
	var menu := GuiInput.find_script(run, PauseMenu)
	await GuiInput.click(t, GuiInput.button(menu, "END RAMPAGE"))
	await _frames(RampageHud.BEAT_MIN_FRAMES)
	await GuiInput.key(t, KEY_ENTER)
	await _frames(2)
	var results := GuiInput.find_script(run, ResultsScreen) as ResultsScreen
	await GuiInput.click(t, GuiInput.button(results, "SKIP"))
	await GuiInput.click(t, GuiInput.button(results, "BACK"))
	await _frames(3)
	var after := SaveFile.load_game()
	check.call(_screen(main) is UpgradeScreen, "ending Endless mode goes back to the tree: %s" % _screen(main))
	check.call(
		after["rubble"] == before["rubble"]
		and after["runs"] == before["runs"]
		and after["totals"] == before["totals"]
		and after["best"] == before["best"],
		"an Endless run banks nothing: %s vs %s" % [after, before]
	)


## Try Endless mode on the thanks screen, by the keyboard.
func _check_thanks_endless() -> void:
	var last: Array[String] = []
	SaveFile.save_game(_near_final_save(last))
	var main := await _main()
	var card := await _buy_final(main, last[0])
	check.call(card != null, "the thanks screen shows again for a second save")
	if card != null:
		check.call(
			t.root.gui_get_focus_owner() == GuiInput.button(card, "TRY ENDLESS MODE"),
			"focus starts on Try Endless mode (the pad's A starts it)"
		)
		await GuiInput.pad(t, JOY_BUTTON_A)
		await _frames(3)
		await _endless_run(main)
	main.queue_free()
	await _frames(2)


## A finished demo save: Continue lands on the tree (normal mode) with Endless mode offered; a
## normal demo rampage adds to the totals the thanks screen shows.
func _check_continue_after() -> void:
	var last: Array[String] = []
	var save := _near_final_save(last)
	var owned: Dictionary = save["levels"]
	owned[last[0]] = Num.i(owned[last[0]]) + 1
	save["demo_done"] = true
	save["runs"] = 9
	SaveFile.save_game(save)
	var main := await _main()
	await GuiInput.click(t, GuiInput.button(_screen(main), "CONTINUE"))
	await _frames(3)
	var tree := _screen(main) as UpgradeScreen
	check.call(
		tree != null and GuiInput.button(tree, "ENDLESS MODE") != null,
		"Continue on a finished demo lands on the tree with Endless mode offered: %s" % _screen(main)
	)
	if tree == null:
		main.queue_free()
		return
	await GuiInput.click(t, GuiInput.button(tree, "RAMPAGE"))
	var run := _screen(main) as Rampage
	await _settled(run)
	check.call(run.sim.endless == null, "RAMPAGE is the normal mode")
	run.sim.time_left = 0.05
	await _frames(RampageHud.BEAT_MIN_FRAMES + 20)
	await GuiInput.key(t, KEY_ENTER)
	await _frames(2)
	var hud := GuiInput.find_script(run, RampageHud) as RampageHud
	var sim_totals := Demo.add({}, hud.result())
	var results := GuiInput.find_script(run, ResultsScreen) as ResultsScreen
	await GuiInput.click(t, GuiInput.button(results, "SKIP"))
	await GuiInput.click(t, GuiInput.button(results, "EVOLVE"))
	await _frames(3)
	var saved := SaveFile.load_game()
	check.call(
		saved["totals"] == sim_totals and Num.i(saved["runs"]) == 10,
		"a normal rampage adds the sim's counters to the demo totals: %s vs %s (runs %s, demo %s)" % [saved["totals"], sim_totals, saved["runs"], saved["demo"]]
	)
	main.queue_free()
	await _frames(2)


## A save from a species the demo leaves out is not offered: no Continue into a hidden kaiju.
func _check_other_species_save() -> void:
	var save := SaveFile.new_save("insectoid")
	save["runs"] = 3
	SaveFile.save_game(save)
	var main := await _main()
	check.call(
		GuiInput.button(_screen(main), "CONTINUE") == null,
		"the demo does not continue a save of a species it leaves out"
	)
	main.queue_free()
	await _frames(2)


## Settings' controls list only what the playable species can do: the croc-only demo shows no
## insectoid Glide row; the full game does (lead, 2026-10-18).
func _check_controls_rows() -> void:
	var with_demo := await _control_names()
	var demo := Content.section("demo")
	demo["enabled"] = false
	var full_game := await _control_names()
	demo["enabled"] = true
	var glide := func(names: Array[String]) -> bool:
		return names.any(func(n: String) -> bool: return n.containsn("glide"))
	check.call(
		not glide.call(with_demo) and glide.call(full_game),
		"the demo's controls list has no insectoid Glide; the full game's has: %s" % [with_demo]
	)


func _control_names() -> Array[String]:
	var menu := SettingsMenu.new()
	t.root.add_child(menu)
	await _frames(2)
	var names: Array[String] = []
	for node: Node in menu.find_children("*", "Label", true, false):
		names.append((node as Label).text)
	menu.queue_free()
	await _frames(1)
	return names
