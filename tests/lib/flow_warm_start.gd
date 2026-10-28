extends RefCounted
## The flow suite's warm-start check (split out of run_flow_tests.gd to keep files small): nothing a
## rampage shows for the first time stalls a frame on a build.


static func run(t: SceneTree, check: Callable) -> void:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	t.root.add_child(rampage)
	var half := deg_to_rad(Num.f(rampage.sim.city["cone_half_angle_deg"]))
	check.call(
		FxDecals.is_drawn(FxDecals.Shape.WEDGE, {"half_angle": half}),
		"the breath's scorch for this run's %.2f rad cone is drawn before the first breath" % half
	)
	rampage.queue_free()
	await t.process_frame
	var a := TankModel.new()
	var b := TankModel.new()
	var hull_a: MultiMeshInstance3D = a.get_child(0)
	var hull_b: MultiMeshInstance3D = b.get_child(0)
	check.call(hull_a.multimesh == hull_b.multimesh, "a second tank reuses the first one's voxels")
	a.free()
	b.free()
