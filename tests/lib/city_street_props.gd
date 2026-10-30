extends RefCounted
## The Tripo street props (D-266, D-398): with city.street_props on, the city's pavements carry
## furniture, its crossings traffic lights, its lamps the lamp model and some of its cars Tripo
## cars; off (no weights, no signal or lamp id), none stand and the decor's own lamps and cars
## take their place. Each prop flattens under the kaiju like any other.

const STAGE := 2  # growth stage of the fixture city


static func check(root: Node, check_fn: Callable) -> void:
	var on := _decor(root, true)
	var off := _decor(root, false)
	var placed: Dictionary = on._street.placed
	var cfg: Dictionary = Content.tuning()["city"]["street_props"]
	var kerb := 0
	for id: String in cfg["kerb"]["weights"]:
		kerb += Num.i(placed.get(id, 0))
	check_fn.call(kerb > 20, "street props: pavement furniture stands (%d)" % kerb)
	check_fn.call(
		Num.i(placed.get(str(cfg["signals"]), 0)) > 0, "street props: traffic lights at crossings"
	)
	check_fn.call(Num.i(placed.get(str(cfg["lamps"]), 0)) > 0, "street props: lamp model on lamps")
	check_fn.call(off._street.placed.is_empty(), "street props: none when off")
	check_fn.call(
		on._street.field.vox.cells.size() > 0 and off._street.field.vox.cells.size() == 0,
		"street props: their cells draw only when on"
	)
	var group: Dictionary = on._street.field._groups[0]
	var at: Vector3 = group["at"]
	on.crush(at, 0.5)
	check_fn.call(group.get("crushed", false), "street props: a prop flattens when crushed")
	on.get_parent().queue_free()
	off.get_parent().queue_free()


static func _decor(root: Node, on: bool) -> CityDecor:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var tuning: Dictionary = CityGrowth.tuning_for(Content.tuning(), STAGE).duplicate(true)
	var city: Dictionary = tuning["city"]
	if not on:
		var cfg: Dictionary = city["street_props"]
		cfg["kerb"]["weights"] = {}
		cfg["parked"] = {}
		cfg["lane"] = {}
		cfg["signals"] = "none"
		cfg["lamps"] = "none"
	var sim := RampageSim.new(
		stats, tuning, CityGen.generate(Seeds.make("city", 0), city), Seeds.make("army", 0)
	)
	var holder := Node3D.new()
	root.add_child(holder)
	var decor := CityDecor.new(sim, Seeds.make("decor", 0))
	holder.add_child(decor)
	return decor
