extends RefCounted
## Walks Kaiju Creation (D-207) the way a player does, for checks that start a new game through
## Main: click the croc genome, wait for the pour, click INJECT KAIJU JUICE, then wait out the
## takeover, the zoom and the black until Main shows the next screen (the run). Real input only.

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


static func walk(tree: SceneTree, main: Node) -> void:
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
			return
		await tree.physics_frame
