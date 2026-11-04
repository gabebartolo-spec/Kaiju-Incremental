extends RefCounted
## Walks Kaiju Creation (D-207) the way a player does, for checks that start a new game through
## Main: click the croc genome, wait for the pour, click INJECT SPECIAL K, then wait out the
## takeover, the zoom and the black until Main shows the next screen. Real input only. That screen
## is the globe (D-463); `to_run` goes on from it to a plain rampage the way the tree's START does
## (Main._start_rampage), for the checks about the run.

const GuiInput := preload("res://tests/lib/gui_input.gd")
## Ticks a step may take at most (a hang ends the walk instead of the suite).
const STEP_CAP := 60 * 20


## The rack's genome buttons on `lab`, in rack order (croc, Komodo, serpent).
static func genomes(lab: Node) -> Array[Button]:
	var out: Array[Button] = []
	for prefix: String in ["CROC", "KOMODO", "SERPENT"]:
		var b := GuiInput.button(lab, prefix)
		if b != null:
			out.append(b)
	return out


static func walk(tree: SceneTree, main: Node, to_run := true) -> void:
	var lab: Node = main.call("screen")
	await GuiInput.click(tree, GuiInput.button(lab, "CROC"))
	for _i: int in STEP_CAP:
		var inject := GuiInput.button(lab, "INJECT")
		if inject != null and not inject.disabled:
			await GuiInput.click(tree, inject)
			break
		await tree.physics_frame
	for _i: int in STEP_CAP:
		var now: Node = main.call("screen")
		if now != lab:
			if to_run and now is GlobeView:
				main.call("_start_rampage")
			return
		await tree.physics_frame


## Continue lands on the globe (D-463): on from it to the tree the way a city's end does.
static func globe_to_tree(tree: SceneTree, main: Node) -> void:
	if main.call("screen") is GlobeView:
		main.call("_show_tree")
	for _i: int in 3:
		await tree.process_frame


## The tree's START opens the globe (D-463: the globe is the loop); the checks about a run go on
## from it to the plain rampage the globe's city is (Main._start_rampage banks it the same way).
static func globe_to_run(tree: SceneTree, main: Node) -> void:
	for _i: int in 3:
		await tree.process_frame
	if main.call("screen") is GlobeView:
		main.call("_start_rampage")
	for _i: int in 3:
		await tree.process_frame
