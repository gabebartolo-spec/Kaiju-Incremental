extends RefCounted
## The pause menu's bug / feedback button (D-145), driven the way a player does it: real mouse
## clicks at the button's screen position and real key presses into the text box, then the report
## folder read back from disk. `problems` is the one reader of a report folder, so the planted
## bad folders in the suite prove the same reader the real report is judged by.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const TYPED := "the tank at the bridge ate my kaiju, wasd e shift space, pause"
const FACTS: Array[String] = [
	"Species:",
	"City:",
	"Growth step:",
	"Run time:",
	"OS:",
	"GPU:",
	"Graphics preset:",
	"Resolution:"
]
const PLAY_STEPS := 120
const DT := 1.0 / 30.0

static var png_signature := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])


## What is wrong with the report folder `folder` (absolute), empty when it is a good report of a
## player who typed `typed`.
static func problems(folder: String, typed: String) -> Array[String]:
	var out: Array[String] = []
	var text_path := folder.path_join(FeedbackReport.TEXT_FILE)
	if not FileAccess.file_exists(text_path):
		out.append("report.txt is missing")
	else:
		var text := FileAccess.get_file_as_string(text_path)
		var first := text.split("\n")[0]
		var version := str(ProjectSettings.get_setting(FeedbackReport.VERSION_KEY, ""))
		if not first.begins_with("Version: ") or version.is_empty() or not first.ends_with(version):
			out.append("the first line is not the Version line (%s)" % first)
		if not typed.is_empty() and not text.contains(typed):
			out.append("the typed text is not in report.txt")
		for label: String in FACTS:
			if not ("\n" + text).contains("\n" + label):
				out.append("no %s line" % label)
	var shot_path := folder.path_join(FeedbackReport.SHOT_FILE)
	if not FileAccess.file_exists(shot_path):
		out.append("screenshot.png is missing")
	else:
		var head := FileAccess.get_file_as_bytes(shot_path).slice(0, png_signature.size())
		var image := Image.load_from_file(shot_path) if head == png_signature else null
		if image == null or image.is_empty():
			out.append("screenshot.png is not a picture")
	return out


## Pauses a fresh menu over a sim that has played a few seconds, then runs the whole path.
static func run(tree: SceneTree, check: Callable) -> void:
	var sim := played_sim()
	var menu := PauseMenu.new()
	menu.sim = sim
	menu.species_id = "reptilian"
	tree.root.add_child(menu)
	var probe := Probe.new()  # sees any key that falls through every control
	tree.root.add_child(probe)
	var rampage_probe := Probe.new()  # stands in for the rampage and its HUD: pausable
	rampage_probe.process_mode = Node.PROCESS_MODE_PAUSABLE
	tree.root.add_child(rampage_probe)
	tree.paused = true
	await frames(tree, 3)
	var label := str(Content.section("feedback")["label"])
	var open := GuiInput.button(menu, label)
	check.call(open != null, "the pause menu lists a button labelled from data (%s)" % label)
	if open == null:
		menu.queue_free()
		tree.paused = false
		return
	check.call(
		open.custom_minimum_size == GuiInput.button(menu, "SETTINGS").custom_minimum_size,
		"the report button is as big as the other pause buttons"
	)
	var panel := await _open(tree, menu, open)
	check.call(
		panel != null and panel.box.has_focus() and tree.paused,
		"clicking the button opens the panel with the cursor in its box, still paused"
	)
	check.call(
		GuiInput.button(menu, "RESUME") == null,
		"the pause buttons are hidden behind the panel (no stray click)"
	)
	await _leak(tree, check, sim, panel, [probe, rampage_probe])
	await GuiInput.key(tree, KEY_ESCAPE)
	await frames(tree, 2)
	check.call(
		not is_instance_valid(panel) and tree.paused and is_instance_valid(menu),
		"Esc in the panel closes only the panel: still paused, pause menu still up"
	)
	check.call(reports().is_empty(), "closing the panel wrote nothing")
	panel = await _open(tree, menu, GuiInput.button(menu, label))
	await GuiInput.click(tree, GuiInput.button(panel, "CANCEL"))
	await frames(tree, 2)
	check.call(
		not is_instance_valid(panel) and reports().is_empty() and tree.paused,
		"CANCEL closes the panel and writes nothing"
	)
	await _send(tree, check, menu, GuiInput.button(menu, label), probe)
	check.call(rampage_probe.keys == 0, "the paused rampage's stand-in saw no key all along")
	probe.queue_free()
	rampage_probe.queue_free()
	menu.queue_free()
	tree.paused = false


static func _send(
	tree: SceneTree, check: Callable, menu: PauseMenu, open: Button, probe: Probe
) -> void:
	var panel := await _open(tree, menu, open)
	await GuiInput.type(tree, TYPED)
	var opened: Array[String] = []
	panel.opener = func(path: String) -> int:
		opened.append(path)
		return OK
	await GuiInput.click(tree, GuiInput.button(panel, "SEND"))
	await frames(tree, 3)
	var made := reports()
	check.call(made.size() == 1, "SEND wrote one report folder under user://reports (%s)" % [made])
	var folder := panel.report_path
	check.call(
		made.size() == 1 and folder.get_file() == made[0],
		"the panel names the folder it wrote (%s)" % folder
	)
	var bad := problems(folder, TYPED)
	check.call(bad.is_empty(), "the report has the version line, text, facts, picture: %s" % [bad])
	check.call(
		panel.status.visible and panel.status.text.contains(folder),
		"a confirmation line says where it was saved"
	)
	probe.keys = 0
	await GuiInput.key(tree, KEY_W)
	check.call(probe.keys > 0, "control: a key pressed outside the box does reach the probe")
	await GuiInput.click(tree, GuiInput.button(panel, "OPEN FOLDER"))
	check.call(opened == [folder], "OPEN FOLDER opens that folder (%s)" % [opened])
	await GuiInput.click(tree, GuiInput.button(panel, "DONE"))
	await frames(tree, 2)
	check.call(
		not is_instance_valid(panel) and tree.paused and GuiInput.button(menu, "RESUME") != null,
		"DONE returns to the pause menu, still paused"
	)


## Keys typed into the box go to the box: the pause, the move keys and Esc-less typing change
## nothing in the rampage, and the game stays paused.
static func _leak(
	tree: SceneTree, check: Callable, sim: RampageSim, panel: FeedbackPanel, probes: Array
) -> void:
	var at := sim.kaiju_pos
	var left := sim.time_left
	await GuiInput.type(tree, TYPED)
	await frames(tree, 10)
	check.call(panel.box.text == TYPED, "typing lands in the box (%s)" % panel.box.text)
	for found: Probe in probes:
		check.call(found.keys == 0, "no typed key fell through the box (%d did)" % found.keys)
	check.call(
		tree.paused and sim.kaiju_pos == at and sim.time_left == left,
		"typing move, pause and ultimate keys leaves the rampage still and paused"
	)


static func _open(tree: SceneTree, menu: PauseMenu, open: Button) -> FeedbackPanel:
	await GuiInput.click(tree, open)
	await frames(tree, 6)  # one frame to hide the menu, one to draw, then the panel
	return GuiInput.find_script(menu, FeedbackPanel) as FeedbackPanel


static func played_sim() -> RampageSim:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {})
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.body.use_species("reptilian")
	for i: int in PLAY_STEPS:
		sim.step(DT, Vector2.ZERO, false)
	return sim


## The report folders written so far, by name.
static func reports() -> PackedStringArray:
	var root := "user://" + str(Content.section("feedback")["folder"])
	return DirAccess.get_directories_at(root) if DirAccess.dir_exists_absolute(root) else []


static func frames(tree: SceneTree, n: int) -> void:
	for _i: int in n:
		await tree.process_frame


## Counts the key presses that reach unhandled input (what the game's own input code would see).
class Probe:
	extends Node
	var keys := 0

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed:
			keys += 1
