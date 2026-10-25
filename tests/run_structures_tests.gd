extends "res://tests/lib/runner.gd"
## Structures suite, the class fix for "carve is a universal feature for all buildings" (the
## director
## 2026-10-26, a standing rule; after the railway was found breaking by whole bays that vanished,
## PR #209). Two checks:
##  - every destructible structure type in every city stage (each building kind, each landmark,
##    the railway, the river bridges) is a building the shared voxel carve takes (Carving), whose
##    first blow carves cells (cells_carved) and empties chunks only through it;
##  - no other path removes or hides structure geometry: no sim script outside the shared carve
##    keeps its own hit points for a structure, and no view branch frees or hides a node on a
##    structure-loss event that the shared carve did not send.
## KNOWN lists the types still waiting (each has its roadmap row, docs/ROADMAP.md C): they must
## still fail (delete the entry once one passes); any other failing type fails the suite.
## Seeded by design: city layouts from Seeds.make("city", stage); no other randomness.
##   godot --headless --path . --script tests/run_structures_tests.gd

## Type -> why it is waiting (roadmap C, "Carve is universal").
const KNOWN := {
	"landmark": "landmarks break by chunks (Carving.takes skips them); roadmap C, after PR #209",
	"bridge": "river bridges are a flat ground deck, not destructible; roadmap C, after PR #209",
}
## The shared carve: the only sim scripts that may keep structure strength or send its losses.
const SHARED: Array[String] = [
	"structure.gd",
	"carving.gd",
	"carving_cells.gd",
	"collapse.gd",
	"rampage_sim.gd",
	"voxel_frame.gd",
	"voxel_support.gd",
	"cell_grid.gd",
	"building_cells.gd",
	"landmark_cells.gd",
	"cell_promoter.gd",
	"arcs.gd",
]
## Events about units, not structures (they free their own models).
const UNITS: Array[String] = ["tank_", "heli_", "rooftop_", "train_", "agent_", "brood_"]
const LOSS := "(broken|collapsed|crushed|destroyed|smashed|gone|razed)"


func suite_name() -> String:
	return "Structures"


func run_checks() -> void:
	await _t("_check_every_structure_carves")
	await _t("_check_no_other_removal_path")


## The structure types of one city stage: type -> [buildings of it].
func _types(sim: RampageSim) -> Dictionary:
	var out := {}
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		var type := "building"
		var rail: Variant = b.get("rail")  # read by name: the suite also runs on older revisions
		if b.landmark != "":
			type = "landmark"
		elif rail != null and rail != {}:
			type = "railway"
		if not out.has(type):
			out[type] = [] as Array[int]
		var list: Array[int] = out[type]
		list.append(n)
	return out


## Why building n is not on the shared carve, or "" when it is: the carve takes it, its first
## blow carves cells, and the chunks it empties are the ones the carve reports.
func _carve_fault(sim: RampageSim, n: int) -> String:
	if not sim.carving.takes(n):
		return "the shared carve does not take it"
	var b := sim.buildings[n]
	var chunk := Vector3i(-1, -1, -1)
	for y: int in b.height:
		for z: int in b.d:
			for x: int in b.w:
				if chunk.x < 0 and b.frame.alive(Vector3i(x, y, z)):
					chunk = Vector3i(x, y, z)
	if chunk.x < 0:
		return "it has no standing chunk"
	var start := sim.events.size()
	var before := b.frame.alive_count
	sim.damage_chunks(n, [chunk] as Array[Vector3i], INF)
	var carved := false
	var reported := 0
	for event: Dictionary in sim.events.slice(start):
		if Num.i(event.get("building", -1)) != n:
			continue
		carved = carved or str(event["type"]) == "cells_carved"
		if str(event["type"]) in ["chunks_broken", "fall_start"]:
			var cells: Array = event["cells"]
			reported += cells.size()
	if not carved:
		return "a blow on it carves no cells"
	if before - b.frame.alive_count != reported:
		return "%d chunks went, %d reported" % [before - b.frame.alive_count, reported]
	return ""


func _check_every_structure_carves() -> void:
	var tuning := Content.tuning()
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	)
	var faults := {}
	var seen := {}
	for stage: int in range(1, CityGrowth.stage_count(tuning) + 1):
		var city_tuning := CityGrowth.tuning_for(tuning, stage)
		var layout := CityGrowth.layout(tuning, stage, Seeds.make("city", stage - 1))
		var sim := RampageSim.new(stats, city_tuning, layout, Seeds.make("army", 0))
		var types := _types(sim)
		if sim.get("rail") != null and not types.has("railway"):
			faults["railway"] = "the railway is not among the city's structures"
		seen["railway"] = true
		var city: Dictionary = city_tuning["city"]
		if not CityRiver.bridges(CityGen.map(city), city).is_empty():
			seen["bridge"] = true
			faults["bridge"] = "the river bridges are not among the city's structures"
		for type: String in types:
			seen[type] = true
			var list: Array[int] = types[type]
			for n: int in [list[0], list[list.size() - 1]]:
				var why := _carve_fault(sim, n)
				if why != "" and not faults.has(type):
					faults[type] = "%s (building %d, stage %d)" % [why, n, stage]
	for type: String in seen:
		var known := KNOWN.has(type)
		var failing := faults.has(type)
		if known:
			check(
				failing,
				"%s still waits (%s); it passes now: drop it from KNOWN" % [type, KNOWN[type]]
			)
		else:
			check(
				not failing,
				(
					"carve.universal: %s is carved like every building: %s"
					% [type, faults.get(type, "ok")]
				)
			)
	check(
		seen.has("building") and seen.has("railway"),
		"the stages hold buildings and the railway: %s" % [seen.keys()]
	)


## Static: a script under sim/ outside SHARED keeping an array of hit points, or a view match
## branch that frees or hides a node on a structure-loss event sent from outside SHARED.
func _check_no_other_removal_path() -> void:
	var senders := {}  # event type -> sim script that sends it
	var pools: Array[String] = []
	var hp_pool := RegEx.create_from_string(
		"var \\w*hp\\w*\\s*[:=].*(Array|Dictionary|\\{\\}|\\[\\])"
	)
	var sends := RegEx.create_from_string('"type": "(\\w+)"')
	for file: String in DirAccess.get_files_at("res://sim"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://sim/" + file)
		for m: RegExMatch in sends.search_all(text):
			senders[m.get_string(1)] = file
		if not file in SHARED and hp_pool.search(text) != null:
			pools.append(file)
	check(pools.is_empty(), "carve.universal: no structure keeps its own hit points: %s" % [pools])
	var loss := RegEx.create_from_string("^\\w+_%s$" % LOSS)
	var branch := RegEx.create_from_string('^(\\t+)"(\\w+)":\\s*$')
	var hides := RegEx.create_from_string("queue_free\\(\\)|\\.visible = false|\\.hide\\(\\)")
	var rogue: Array[String] = []
	for file: String in DirAccess.get_files_at("res://scenes"):
		if not file.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string("res://scenes/" + file).split("\n")
		for i: int in lines.size():
			var m := branch.search(lines[i])
			if m == null:
				continue
			var event := m.get_string(2)
			var sender := str(senders.get(event, ""))
			if sender == "" or sender in SHARED or loss.search(event) == null or _unit(event):
				continue
			var depth := m.get_string(1).length()
			for j: int in range(i + 1, lines.size()):
				var line := lines[j]
				if line.strip_edges() != "" and line.length() - line.lstrip("\t").length() <= depth:
					break
				if hides.search(line) != null:
					rogue.append("%s:%d %s (sent by sim/%s)" % [file, j + 1, event, sender])
	check(
		rogue.is_empty(),
		"carve.universal: no view hides structure geometry the carve did not take: %s" % [rogue]
	)


func _unit(event: String) -> bool:
	for prefix: String in UNITS:
		if event.begins_with(prefix):
			return true
	return false
