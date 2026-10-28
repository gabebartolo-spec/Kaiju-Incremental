extends RefCounted
## Only the landmarks' sides are fixed (director 2026-10-28: "so i want maps to be randomised as
## you know, but if we need to make certain constants like stadium is west, wheel is east, thats
## ok, as long as the rest of the city is random"). Over several map seeds at the grown city
## (stage 3, both landmarks in): the stadium's site lies west of the centre line and north of the
## river's row, the wheel's east of it; and every two seeds differ in their street lines, their
## districts' blocks and their buildings (the landmarks left out). The stadium and the wheel are
## the city's only landmarks (city "landmarks"), so no other landmark is pinned. The sides are a
## placement rule for a landmark in the run, never a promise it is there (director 2026-10-28:
## "landmarks will be picked at random from a pool of many", "so the stadium and wheel are no
## certainty to appear"): check_without builds the cities with neither.

const SEEDS: Array[int] = [7301, 1234, 98765, 42, 2024]
const TIER := 3  # Colossus: the grown city, the wheel's stage reached


static func check(check_fn: Callable) -> void:
	var lines := {}
	var blocks := {}
	var buildings := {}
	for map_seed: int in SEEDS:
		var base: Dictionary = Content.tuning().duplicate(true)
		var city: Dictionary = base["city"]
		city["map_seed"] = map_seed
		var cfg: Dictionary = CityGrowth.tuning_for(base, TIER)["city"]
		var plan := CityGen.map(cfg)
		_check_sides(plan, cfg, map_seed, check_fn)
		lines[str(plan["xs"]) + str(plan["zs"])] = true
		blocks[_blocks_key(plan)] = true
		buildings[_buildings_key(CityGrowth.layout(base, TIER, Seeds.make("city", 0)))] = true
	for row: Array in [["street lines", lines], ["districts' blocks", blocks]]:
		var seen: Dictionary = row[1]
		check_fn.call(
			seen.size() == SEEDS.size(),
			(
				"the %s differ between every two of %d map seeds: %d kinds"
				% [row[0], SEEDS.size(), seen.size()]
			)
		)
	check_fn.call(
		buildings.size() == SEEDS.size(),
		(
			"the buildings (landmarks left out) differ between every two of %d map seeds: %d kinds"
			% [SEEDS.size(), buildings.size()]
		)
	)


static func _check_sides(
	plan: Dictionary, cfg: Dictionary, map_seed: int, check_fn: Callable
) -> void:
	var zs: Array[float] = plan["zs"]
	var row := CityRiver.river_row(zs, cfg)
	var river_z := zs[row] if row >= 0 else INF
	var found := {}
	for site: Dictionary in plan.get("sites", []):
		var rect: Rect2 = site["rect"]
		found[str(site["id"])] = rect
	for id: String in ["stadium", "wheel"]:
		check_fn.call(found.has(id), "map_seed %d: the %s has a site" % [map_seed, id])
	if found.has("stadium"):
		var r: Rect2 = found["stadium"]
		check_fn.call(
			r.end.x < 0.0 and r.end.y <= river_z + 0.01,
			(
				"map_seed %d: the stadium lies west, north of the river (%s, river z %.0f)"
				% [map_seed, r, river_z]
			)
		)
	if found.has("wheel"):
		var r: Rect2 = found["wheel"]
		check_fn.call(r.position.x > 0.0, "map_seed %d: the wheel lies east (%s)" % [map_seed, r])


static func _blocks_key(plan: Dictionary) -> String:
	var parts: PackedStringArray = []
	for block: Dictionary in plan["blocks"]:
		parts.append("%s:%s:%s" % [block["rect"], block["use"], block.get("district", -1)])
	return ";".join(parts)


static func _buildings_key(layout: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for e: Dictionary in layout:
		if str(e.get("landmark", "")) == "":
			parts.append("%s,%s,%s,%s,%s" % [e["x"], e["z"], e["w"], e["d"], e["h"]])
	return ";".join(parts)


## A run with neither landmark (city "landmarks" empty) builds cleanly at every stage: its plan
## has the bay and the rise but no site, its city stands, the rise lies in the bay's water and
## the sim starts there.
static func check_without(check_fn: Callable) -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	for tier: int in [1, 2, 3]:
		for map_seed: int in SEEDS.slice(0, 2):
			var base: Dictionary = Content.tuning().duplicate(true)
			var city: Dictionary = base["city"]
			city["map_seed"] = map_seed
			city["landmarks"] = []
			var tuning := CityGrowth.tuning_for(base, tier)
			var cfg: Dictionary = tuning["city"]
			var plan := CityGen.map(cfg)
			var layout := CityGrowth.layout(base, tier, Seeds.make("city", 0))
			var sites: Array = plan.get("sites", [])
			var spawn: Vector2 = plan.get("rise_spawn", Vector2.INF)
			var name := "stage %d, map_seed %d, no landmarks" % [tier, map_seed]
			check_fn.call(
				sites.is_empty() and plan.has("harbour") and CityHarbour.holds(plan, spawn),
				(
					"%s: no site, the bay and its rise (%d sites, rise %s)"
					% [name, sites.size(), spawn]
				)
			)
			var marked := layout.filter(
				func(e: Dictionary) -> bool: return str(e.get("landmark", "")) != ""
			)
			check_fn.call(
				layout.size() > 100 and marked.is_empty(),
				(
					"%s: the city stands (%d buildings, %d landmarks)"
					% [name, layout.size(), marked.size()]
				)
			)
			var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
			check_fn.call(
				sim.buildings.size() == layout.size(),
				"%s: the sim starts on it (%d buildings)" % [name, sim.buildings.size()]
			)
