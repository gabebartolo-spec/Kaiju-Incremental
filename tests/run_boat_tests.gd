extends "res://tests/lib/runner.gd"
## Boat suite (BoatView, D-404): boats moor at the piers, in the bay and on the river; with the
## kaiju far away they only rock on the swell and stay put (off), with him close they rock harder
## and are pushed away from him (on), and one he wades into rolls over and sinks. Seeded (Seeds
## "boats"); the view is stepped by hand at a fixed DT, no clock.
##   godot --headless --path . --script tests/run_boat_tests.gd

const DT := 1.0 / 15.0
const FAR := Vector2(5000.0, 5000.0)

const WALK := 2.5  # his opening walk, u/s (measured)


func suite_name() -> String:
	return "Boats"


func run_checks() -> void:
	await _t("_check_moored_everywhere")
	await _t("_check_far_kaiju_leaves_them")
	await _t("_check_wake_pushes_away")
	await _t("_check_wade_capsizes")
	await _t("_check_walk_catches_boat")
	await _t("_check_seeded")


func _view() -> BoatView:
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
	return view


func _step(view: BoatView, seconds: float, kaiju: Vector2) -> void:
	for n: int in ceili(seconds / DT):
		view.step(DT, kaiju)


func _where(view: BoatView, place: String) -> int:
	return view.boats.filter(func(b: Dictionary) -> bool: return b["where"] == place).size()


func _node(b: Dictionary) -> Node3D:
	var n: Node3D = b["node"]
	return n


func _pos(b: Dictionary) -> Vector2:
	var p: Vector2 = b["pos"]
	return p


func _sunk(b: Dictionary) -> bool:
	var s: bool = b["sunk"]
	return s


func _check_moored_everywhere() -> void:
	var view := _view()
	for place: String in ["pier", "bay", "river"]:
		check(_where(view, place) > 0, "boats moored: %s (%d)" % [place, _where(view, place)])
	var nodes := view.boats.all(func(b: Dictionary) -> bool: return _node(b).get_child_count() == 1)
	check(nodes, "every boat draws its voxel model")


func _check_far_kaiju_leaves_them() -> void:
	var view := _view()
	var start: Array[Vector2] = []
	for b: Dictionary in view.boats:
		start.append(b["pos"])
	var max_roll := 0.0
	for n: int in 90:
		view.step(DT, FAR)
		for b: Dictionary in view.boats:
			max_roll = maxf(max_roll, absf(_node(b).basis.get_euler().z))
	var moved := 0
	for i: int in view.boats.size():
		if _pos(view.boats[i]).distance_to(start[i]) > 0.001:
			moved += 1
	check(moved == 0, "no kaiju near: no boat drifts (%d moved)" % moved)
	check(max_roll > 0.001, "no kaiju near: the boats still rock on the swell")
	var gentle := deg_to_rad(Num.f(Content.section("boats")["rock_deg"]) + 1.0)
	check(max_roll < gentle, "the swell's rock stays gentle")
	check(view.capsized == 0, "no kaiju near: none capsizes")


func _check_wake_pushes_away() -> void:
	var view := _view()
	var cfg := Content.section("boats")
	var b: Dictionary = view.boats[0]
	var at: Vector2 = b["pos"]
	var kaiju := at + Vector2(Num.f(cfg["capsize_radius"]) * 2.0, 0.0)
	var before := at.distance_to(kaiju)
	_step(view, DT, kaiju)
	var wake := Num.f(b["wake"])
	_step(view, 3.0, kaiju)
	var after := _pos(b).distance_to(kaiju)
	check(after > before + 0.1, "his wake pushes the boat away (%.2f -> %.2f)" % [before, after])
	check(wake > 0.5, "his wake rocks the boat harder (wake %.2f)" % wake)
	check(not _sunk(b) and Num.f(b["flip"]) == 0.0, "outside capsize reach it stays upright")


func _check_wade_capsizes() -> void:
	var view := _view()
	var cfg := Content.section("boats")
	var b: Dictionary = view.boats[0]
	_step(view, DT, _pos(b))
	check(view.capsized == 1, "the boat he wades into rolls over")
	_step(view, Num.f(cfg["capsize_s"]) + Num.f(cfg["sink_s"]) + 1.0, FAR)
	check(_sunk(b) and not _node(b).visible, "then it sinks out of sight")


## Director 2026-10-31: a boat used to flee at ~8.8 u/s and he never caught one. Walking after a
## river boat from 14 u at his opening pace (2.5 u/s, measured in capture_boats), he capsizes it.
func _check_walk_catches_boat() -> void:
	var view := _view()
	var b: Dictionary = view.boats.filter(func(x: Dictionary) -> bool: return x["where"] == "river")[0]
	var kaiju := _pos(b) + Vector2(14.0, 0.0)
	for n: int in ceili(12.0 / DT):
		var to := _pos(b) - kaiju
		kaiju += to.limit_length(WALK * DT)
		view.step(DT, kaiju)
		if view.capsized > 0:
			break
	check(view.capsized == 1, "walking after a boat he catches and capsizes it")


func _check_seeded() -> void:
	var a := _view()
	var b := _view()
	var same := a.boats.size() == b.boats.size()
	for i: int in mini(a.boats.size(), b.boats.size()):
		same = (
			same and a.boats[i]["id"] == b.boats[i]["id"] and a.boats[i]["pos"] == b.boats[i]["pos"]
		)
	check(same and a.boats.size() > 0, "the same seed moors the same boats (%d)" % a.boats.size())
