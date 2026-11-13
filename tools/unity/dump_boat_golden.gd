extends SceneTree
## Writes where Godot's boats (scenes/boat_view.gd) moor and how they move with the kaiju
## chasing three of them in turn (the first in the bay, at a pier, on the river), so the Unity
## port (unity/Assets/Scripts/Rampage/Boats.cs) can be checked against it step for step.
##
##   godot --headless --path . --script tools/unity/dump_boat_golden.gd
##
## Output: unity/SimTests/golden/boats.txt, read by BoatCheck
## (`dotnet run --project unity/SimTests`). B: a moored boat (index, id, where, x, z, yaw, y, hz,
## phase); S: every boat every EVERY steps (step, index, x, y, z, basis x and y columns, sunk);
## END: how many capsized.

const OUT := "res://unity/SimTests/golden/boats.txt"
const DT := 1.0 / 15.0
const STEPS := 600
const EVERY := 15
const WALK := 2.5  # his opening walk, u/s (the boat suite's)
const START := 14.0  # he starts this far east of each boat he chases (the boat suite's)

var _lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(stats, Content.tuning(), [], Seeds.make("army", 0))
	var stage := Node3D.new()
	root.add_child(stage)
	var view := BoatView.attach(stage, sim)
	view.set_process(false)
	for i: int in view.boats.size():
		var b: Dictionary = view.boats[i]
		var p: Vector2 = b["pos"]
		_lines.append(
			(
				"B %d %s %s %.4f %.4f %.4f %.4f %.4f %.4f"
				% [i, b["id"], b["where"], p.x, p.y, b["yaw"], b["y"], b["hz"], b["phase"]]
			)
		)
	var chased: Array[Dictionary] = [
		_first(view, "bay"), _first(view, "pier"), _first(view, "river")
	]
	var kaiju := Vector2.ZERO
	for s: int in STEPS:
		var b: Dictionary = chased[s * chased.size() / STEPS]
		var at: Vector2 = b["pos"]
		if s % (STEPS / chased.size()) == 0:
			kaiju = at + Vector2(START, 0.0)
		kaiju += (at - kaiju).limit_length(WALK * DT)
		view.step(DT, kaiju)
		if s % EVERY == 0:
			_dump(view, s)
	_lines.append("END capsized %d" % view.capsized)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("wrote %s (%d lines)" % [OUT, _lines.size()])
	quit()


func _first(view: BoatView, place: String) -> Dictionary:
	for b: Dictionary in view.boats:
		if b["where"] == place:
			return b
	return {}


func _dump(view: BoatView, s: int) -> void:
	for i: int in view.boats.size():
		var b: Dictionary = view.boats[i]
		var n: Node3D = b["node"]
		var p := n.position
		var bx := n.basis.x
		var by := n.basis.y
		_lines.append(
			(
				"S %d %d %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %s"
				% [s, i, p.x, p.y, p.z, bx.x, bx.y, bx.z, by.x, by.y, by.z, b["sunk"]]
			)
		)
