extends "res://tests/lib/runner.gd"
## Wildlife suite (WildlifeView; director comments 63, 66, 71): pigeons sit on the rooftops and
## gulls circle the water until a roar or a landing section scatters the birds near it (on vs
## off: with no event every pigeon stays on its roof); a roar far away leaves them; the whale
## surfaces two or three times a run, spouts, and dives at once on a roar. Seeded (Seeds
## "wildlife"); the view is stepped by hand at a fixed DT, no clock.
##   godot --headless --path . --script tests/run_wildlife_tests.gd

const DT := 1.0 / 15.0
const TOWERS: Array[Dictionary] = [
	{"x": 0.0, "z": 0.0, "w": 4, "d": 4, "h": 20, "tier": 1, "style": 0},
	{"x": 12.0, "z": 6.0, "w": 4, "d": 4, "h": 16, "tier": 1, "style": 0},
]
const FAR := Vector3(5000.0, 0.0, 5000.0)


func suite_name() -> String:
	return "Wildlife"


func run_checks() -> void:
	await _t("_check_roar_scatters_pigeons")
	await _t("_check_far_roar_leaves_them")
	await _t("_check_whale_surfaces_and_dives")
	await _t("_check_seeded")


func _view() -> WildlifeView:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(
		stats, Content.tuning(), TOWERS.duplicate(true), Seeds.make("army", 0)
	)
	var stage := Node3D.new()
	root.add_child(stage)
	var view := WildlifeView.attach(stage, sim)
	view.set_process(false)
	return view


func _step(view: WildlifeView, seconds: float) -> void:
	for n: int in ceili(seconds / DT):
		view._process(DT)


## The flock's bird positions (the view's own state: headless CI keeps no MultiMesh buffer).
func _positions(view: WildlifeView, kind: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for flock: Dictionary in view._flocks:
		if flock["kind"] == kind:
			for bird: Dictionary in flock["birds"]:
				out.append(bird["pos"])
	return out


func _pigeon_heights(view: WildlifeView) -> Array[float]:
	var out: Array[float] = []
	for pos: Vector3 in _positions(view, "pigeon"):
		out.append(pos.y)
	return out


func _check_roar_scatters_pigeons() -> void:
	var still := _view()
	var roared := _view()
	var before := _pigeon_heights(roared)
	check(before.size() > 0, "pigeons sit on the towers' roofs (%d)" % before.size())
	roared.on_event({"type": "ultimate"}, Vector3.ZERO)
	_step(still, 2.0)
	_step(roared, 2.0)
	check(_pigeon_heights(still) == before, "off: with no roar every pigeon stays on its roof")
	var risen := 0
	var after := _pigeon_heights(roared)
	for i: int in after.size():
		if after[i] > before[i] + 3.0:
			risen += 1
	check(
		roared.scattered >= before.size() and risen == after.size(),
		"on: a roar beside the roofs puts every pigeon up (%d of %d risen)" % [risen, after.size()]
	)
	still.get_parent().queue_free()
	roared.get_parent().queue_free()


func _check_far_roar_leaves_them() -> void:
	var view := _view()
	var before := _pigeon_heights(view)
	view.on_event({"type": "leap"}, FAR)
	_step(view, 1.0)
	check(
		view.scattered == 0 and _pigeon_heights(view) == before,
		"a roar out of range scatters nothing (%d)" % view.scattered
	)
	view.get_parent().queue_free()


func _check_whale_surfaces_and_dives() -> void:
	var view := _view()
	var w: Dictionary = Content.section("wildlife")["whale"]
	var waited := 0.0
	while view.whale_state() == "wait" and waited < Num.f(w["first"][1]) + DT:
		_step(view, DT)
		waited += DT
	_step(view, Num.f(w["rise_seconds"]) * 0.5)
	check(
		view.surfacings == 1 and view.whale.visible and view.whale_state() == "rise",
		"the whale surfaces first within %.0f s (%s)" % [Num.f(w["first"][1]), view.whale_state()]
	)
	view.on_event({"type": "ultimate"}, FAR)
	check(view.whale_state() == "dive", "a roar sends it down at once, however far")
	var run := Num.f(Content.section("kaiju").get("run_seconds", 300.0))
	_step(view, maxf(run, 400.0))
	var most := Num.i(w["surfacings"][1])
	check(
		view.surfacings >= Num.i(w["surfacings"][0]) and view.surfacings <= most,
		"it surfaces %d times in a run (2 or 3)" % view.surfacings
	)
	check(view.whale_state() == "gone" and not view.whale.visible, "then it is gone")
	view.get_parent().queue_free()


func _check_seeded() -> void:
	var a := _view()
	var b := _view()
	_step(a, 30.0)
	_step(b, 30.0)
	var pa := _positions(a, "gull")
	var pb := _positions(b, "gull")
	var same := pa.size() > 0 and pa.size() == pb.size()
	for i: int in mini(pa.size(), pb.size()):
		same = same and pa[i].is_equal_approx(pb[i])
	check(same, "the same seed flies the same gulls")
	a.get_parent().queue_free()
	b.get_parent().queue_free()
