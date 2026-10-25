extends "res://tests/lib/powers_base.gd"
## Structures suite (standing rule since 2026-10-20, roadmap 2026-10-20-build2-playtest #6: "ALL
## buildings in the play area must be destroyable"; the director 2026-10-25 on the railway: "Yes,
## all of it"). Nothing enforced it, so this does: every structure the city or any system places
## inside the play area is listed by the sim (Structures.all) and can be destroyed through the
## carve/break path. A system that puts structures in the world without registering them fails
## here, whatever it is called and whenever it is added:
##   - every sim part that declares `func structures()` is reached by the registry (found by a
##     scan of sim/*.gd, no hand-kept list);
##   - every structure the registry lists inside the arena is destroyed by Structures.destroy and
##     reads as gone afterwards (the city's buildings, the railway's pillars, spans, station);
##   - the railway has parts to break at all, and the city's layout is all in the registry.
##   godot --headless --path . --script tests/run_structures_tests.gd


func suite_name() -> String:
	return "Structures"


func run_checks() -> void:
	await _t("_check_registry_reaches_every_declaring_part")
	await _t("_check_every_structure_in_the_play_area_is_destroyable")
	await _t("_check_city_layout_is_all_registered")


func _city_sim() -> RampageSim:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var sim := RampageSim.new(
		stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0)
	)
	sim.kaiju_pos = Vector2(-40.0, -40.0)
	return sim


## The registry, loaded by path so this suite also runs (red) on a sim that has none.
func _api() -> Script:
	return load("res://sim/structures.gd")


func _structures_api() -> bool:
	return ResourceLoader.exists("res://sim/structures.gd")


## sim/*.gd files that declare `func structures()` must each be a registered source.
func _check_registry_reaches_every_declaring_part() -> void:
	check(_structures_api(), "the sim has a structure registry (sim/structures.gd)")
	if not _structures_api():
		return
	var sim := _city_sim()
	var reached: Array = _api().sources(sim).map(
		func(src: Object) -> String: return src.get_script().resource_path
	)
	var declaring: Array[String] = []
	for file: String in DirAccess.get_files_at("res://sim"):
		if not file.ends_with(".gd"):
			continue
		var path := "res://sim/" + file
		if FileAccess.get_file_as_string(path).contains("\nfunc structures()"):
			declaring.append(path)
	check(not declaring.is_empty(), "some sim part registers structures: %s" % [declaring])
	for path: String in declaring:
		check(reached.has(path), "%s declares structures() but no sim part holds it" % path)


func _check_every_structure_in_the_play_area_is_destroyable() -> void:
	if not _structures_api():
		check(false, "the sim has a structure registry")
		return
	var sim := _city_sim()
	var all: Array = _api().all(sim)
	var kinds := {}
	for entry: Dictionary in all:
		kinds[str(entry["kind"])] = true
	for kind: String in ["building", "pillar", "span", "station"]:
		check(kinds.has(kind), "the registry lists %ss: %s" % [kind, kinds.keys()])
	var inside := 0
	var failed: Array[String] = []
	for entry: Dictionary in all:
		if not _api().in_play_area(sim, entry):
			continue
		inside += 1
		if not _api().destroy(sim, entry) or _api().alive(sim, entry):
			failed.append("%s %s" % [entry["kind"], entry["id"]])
		sim.step(DT, Vector2.ZERO, false, 0)
	check(inside > 100, "the play area holds many structures: %d" % inside)
	check(failed.is_empty(), "structures that cannot be destroyed: %s" % [failed.slice(0, 8)])


func _check_city_layout_is_all_registered() -> void:
	if not _structures_api():
		check(false, "the sim has a structure registry")
		return
	var sim := _city_sim()
	var buildings := 0
	for entry: Dictionary in _api().all(sim):
		buildings += int(str(entry["kind"]) == "building")
	check(
		buildings == sim.buildings.size(),
		"every building of the layout is registered: %d of %d" % [buildings, sim.buildings.size()]
	)
