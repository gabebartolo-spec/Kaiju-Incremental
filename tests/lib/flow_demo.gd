extends RefCounted
## The flow suite's demo checks (D-050), on the shipping data/tuning.json "demo" section: species
## select offers only the demo's species; buying the demo's end evolution plays its reveal and
## then the demo end card (the adult roaring, Title / Quit); the save stays valid, so Continue
## lands on the end card again. Every step is real input. The rest of the flow suite runs with
## the demo switched off (demo_off), so the full game stays covered.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FlowLayout := preload("res://tests/lib/flow_layout.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const LEFT_OVER := 100

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
		demo.get("enabled", false) == true and str(demo.get("end_node", "")) == "evolve1",
		"the shipping data runs the demo, ending on evolve1: %s" % [demo]
	)
	SaveFile.delete_save()
	await _check_species_filter()
	await _check_end_card()
	await _check_other_species_save()
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


static func _is_end_card(node: Node) -> bool:
	if node == null:
		return false
	var script: Script = node.get_script()
	return script != null and script.get_global_name() == "DemoEnd"


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
		picks = select.find_children("*", "Button", true, false)
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


## A reptilian save that can afford Behemoth: Continue, buy it by click, the reveal plays first,
## then the end card (adult reptilian roaring, the demo lines, Title / Quit). Title, then
## Continue: the end card again, never the tree.
func _check_end_card() -> void:
	var save := SaveFile.new_save("reptilian")
	var tree_def := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	save["rubble"] = tree_def.cost("evolve1") + LEFT_OVER
	save["runs"] = 2
	save["levels"] = {"claws": 1, "hide": 1, "rage": 1}
	SaveFile.save_game(save)
	var main := await _main()
	await GuiInput.click(t, GuiInput.button(_screen(main), "CONTINUE"))
	await _frames(3)
	var tree := _screen(main) as UpgradeScreen
	if tree == null:
		check.call(false, "Continue on a played demo save opens the tree")
		main.queue_free()
		return
	await GuiInput.click(t, tree.node_button("evolve1"))
	await _frames(2)
	var reveal := GuiInput.find_script(tree, EvolutionReveal) as EvolutionReveal
	check.call(
		reveal != null and _screen(main) == tree,
		"buying Behemoth plays the evolution reveal first, over the tree"
	)
	await _frames(EvolutionReveal.END_FRAME + 4)
	var card := _screen(main)
	check.call(_is_end_card(card), "when the reveal finishes the demo end card shows: %s" % card)
	if not _is_end_card(card):
		main.queue_free()
		await _frames(2)
		return
	await _frames(2)
	var texts: Array[String] = []
	for node: Node in card.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	var demo := Content.section("demo")
	check.call(
		texts.has(str(demo["end_title"])) and texts.has(str(demo["end_line"])),
		"the end card says %s / %s: %s" % [demo["end_title"], demo["end_line"], texts]
	)
	check.call(
		str(card.get("stage")) == "adult" and str(card.get("species_id")) == "reptilian",
		"the end card stages the reptilian adult (%s)" % card.get("stage")
	)
	# Only a baked clip roar (ClipGait, D-047) plays: the procedural roar drops the jaw straight
	# down (lead QA on #23), so without clips the adult stands idle.
	var clip: Variant = card.get("clip_roar")
	var roars := Num.i(card.get("roars"))
	check.call(
		clip is bool and (roars >= 1 if clip else roars == 0),
		"the end card roars only from a clip (clip roar %s, roars %d)" % [clip, roars]
	)
	check.call(
		GuiInput.button(card, "TITLE") != null and GuiInput.button(card, "QUIT") != null,
		"the end card offers Title and Quit"
	)
	await layout.fits_at_scales(card as Control, "demo end card")
	layout.listen(card, "demo end card")
	layout.fonts_ours()
	var saved := SaveFile.load_game()
	var levels: Dictionary = saved.get("levels", {})
	check.call(
		Num.i(levels.get("evolve1", 0)) == 1 and saved["species"] == "reptilian",
		"the save holds Behemoth: %s" % [levels]
	)
	await GuiInput.click(t, GuiInput.button(card, "TITLE"))
	await _frames(2)
	var title := _screen(main)
	check.call(title is TitleScreen, "Title on the end card goes to the title screen")
	await GuiInput.click(t, GuiInput.button(title, "CONTINUE"))
	await _frames(3)
	check.call(_is_end_card(_screen(main)), "Continue on a finished demo lands on the end card")
	main.queue_free()
	await _frames(2)
	var again := await _main()
	await GuiInput.click(t, GuiInput.button(_screen(again), "CONTINUE"))
	await _frames(3)
	check.call(
		_is_end_card(_screen(again)), "after a relaunch, Continue still lands on the end card"
	)
	again.queue_free()
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
