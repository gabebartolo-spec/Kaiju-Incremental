extends "res://tests/lib/runner.gd"
## City suite: the seeded layout reads as a real city, not a grid of isolated towers
## (director, 2026-10-16), the street plan presentation builds on is fixed by the config, and a
## landmark stands, pays and is placed in its own shape (tests/lib/city_landmarks.gd).
## Headless and seeded.
##   godot --headless --path . --script tests/run_city_tests.gd

const Coverage := preload("res://tests/lib/city_coverage.gd")
const Green := preload("res://tests/lib/city_green.gd")
const RiverBody := preload("res://tests/lib/city_river_body.gd")
const Trample := preload("res://tests/lib/city_trample.gd")
const TreeApart := preload("res://tests/lib/city_tree_apart.gd")
const StadiumFar := preload("res://tests/lib/city_stadium_far.gd")
const Kerb := preload("res://tests/lib/city_kerb.gd")
const BreathTrees := preload("res://tests/lib/city_breath_trees.gd")
const CityLandmarks := preload("res://tests/lib/city_landmarks.gd")
const RiverStart := preload("res://tests/lib/city_river.gd")
const EdgeMark := preload("res://tests/lib/city_arena_edge.gd")
const SpawnView := preload("res://tests/lib/city_spawn_view.gd")
const RiseForms := preload("res://tests/lib/city_rise_forms.gd")
const Reach := preload("res://tests/lib/city_reach.gd")
const BridgeLand := preload("res://tests/lib/city_bridge_land.gd")
## Three different street plans (city.map_seed), so the coverage rule holds for cities other
## than the one we ship today.
const COVERAGE_SEEDS: Array[int] = [7301, 1234, 98765]


func suite_name() -> String:
	return "City"


func run_checks() -> void:
	await _t(
		"_check_city_layout", [CityGen.generate(Seeds.make("city", 0), Content.section("city"))]
	)
	await _t("_check_calm_streets")
	await _h("CityLandmarks", func() -> void: CityLandmarks.new(check).run())
	await _t("_check_no_empty_ground")
	await _h(
		"city_diag_fill",
		func() -> void: preload("res://tests/lib/city_diag_fill.gd").new(check, root).run()
	)
	await _h("city_rise_forms", func() -> void: RiseForms.check(COVERAGE_SEEDS, check))
	await _t("_check_reach_is_real")
	await _t("_check_emerge_cap")
	await _t("_check_river_sites")
	await _t("_check_bridges_meet_land")
	await _h(
		"city_light_pool",
		func() -> void: preload("res://tests/lib/city_light_pool.gd").check(root, check)
	)
	await _h(
		"city_footfall_dust",
		func() -> void: preload("res://tests/lib/city_footfall_dust.gd").check(check, root)
	)


## The city reads as a real city, not a grid of isolated towers (director, 2026-10-16): lots
## line the blocks and share party walls, nothing stands in a street, the plan is fixed by
## the config alone, and the kaiju starts in the street.
func _check_city_layout(layout: Array[Dictionary]) -> void:
	var cfg := Content.section("city")
	var rects: Array[Rect2] = []
	for e: Dictionary in layout:
		var w := Num.f(e["w"])
		var d := Num.f(e["d"])
		rects.append(Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d))
	var overlaps := 0
	var touching := 0
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			if rects[i].intersection(rects[j]).get_area() > 0.001:
				overlaps += 1
			elif rects[i].grow(0.01).intersection(rects[j]).size.length() > 0.5:
				touching += 1  # a shared wall at least half a unit long
	check(overlaps == 0, "no two buildings overlap (%d do)" % overlaps)
	check(
		touching > layout.size() * 0.5,
		(
			"buildings share party walls: %d touching pairs for %d buildings"
			% [touching, layout.size()]
		)
	)
	var plan := CityGen.map(cfg)
	var nodes: Array[Vector2] = plan["nodes"]
	var in_street := 0
	for street: Dictionary in plan["streets"]:
		var half_w := Num.f(street["width"]) * 0.5
		# The street between its crossings (a block corner may meet the crossing square).
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var trim := (b - a).normalized() * (Num.f(cfg["avenue_width"]) * 0.5 + 0.5)
		if a.distance_to(b) <= trim.length() * 2.0 and str(street["kind"]) != CityGen.DIAGONAL:
			continue  # all of it lies inside its two crossings
		a += trim
		b -= trim
		for r: Rect2 in rects:
			var closest := Geometry2D.get_closest_point_to_segment(r.get_center(), a, b)
			var inside := Rect2(r.position, r.size).grow(half_w - 0.01)
			if str(street["kind"]) != CityGen.DIAGONAL and inside.has_point(closest):
				in_street += 1
		if str(street["kind"]) == CityGen.DIAGONAL:
			for r: Rect2 in rects:
				var corners: Array[Vector2] = [
					r.position,
					r.end,
					Vector2(r.position.x, r.end.y),
					Vector2(r.end.x, r.position.y)
				]
				for corner: Vector2 in corners:
					if CityGen.diagonal_distance(plan, corner) < half_w - 0.01:
						in_street += 1
	check(in_street == 0, "no building stands in a street (%d do)" % in_street)
	check(CityGen.map(cfg) == plan, "the street plan is the same every time from the city config")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var spawn := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0)).kaiju_pos
	var on_lot := false
	for r: Rect2 in rects:
		on_lot = on_lot or r.has_point(spawn)
	check(not on_lot, "the kaiju starts in the street, not inside a building: %s" % spawn)


## Calm streets (director, 2026-10-18: "remove the level crossing hellscape"): zebra crossings
## only at the city.zebra_junctions junctions where two avenues cross, nearest the centre.
func _check_calm_streets() -> void:
	var cfg := Content.section("city")
	var ground := CityGround.new(cfg)
	var zebras := ground.zebra_junctions()
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var far := 0.0
	for n: int in zebras:
		far = maxf(far, nodes[n].length())
	check(
		zebras.size() == Num.i(cfg["zebra_junctions"]) and far <= Num.f(cfg["half"]),
		(
			"zebras at %d junctions (tuning %d), furthest %.0f from the centre"
			% [zebras.size(), Num.i(cfg["zebra_junctions"]), far]
		)
	)
	ground.free()


## No empty ground (D-062, director 2026-10-18: "there should never be vast empty spaces with
## nothing to smash or kill"): at stage 1 and the Behemoth, in three cities, every
## city.coverage_cell cell on or beside a street holds something to smash inside the arena,
## and past its edge, as far as the game camera shows (city.view_beyond), a stand-in building,
## a parked car or a street tree: never bare asphalt.
func _check_no_empty_ground() -> void:
	for tier: int in [1, 2]:
		for map_seed: int in COVERAGE_SEEDS:
			var base: Dictionary = Content.tuning().duplicate(true)
			var city_cfg: Dictionary = base["city"]
			city_cfg["map_seed"] = map_seed
			var stats := UpgradeTree.run_stats(
				Content.section("kaiju"),
				Content.species_def("reptilian"),
				UpgradeTree.new(Content.upgrades())
			)
			var sim := RampageSim.new(
				stats,
				CityGrowth.tuning_for(base, tier),
				CityGrowth.layout(base, tier, Seeds.make("city", 0)),
				Seeds.make("army", 0)
			)
			var holder := Node3D.new()
			root.add_child(holder)
			var decor := CityDecor.new(sim, Seeds.make("decor", 0))
			holder.add_child(decor)
			var fx := Fx.new()
			holder.add_child(fx)
			var street := StreetLife.new(sim, fx, Seeds.make("civilians", 0))
			holder.add_child(street)
			var ground := CityGround.new(sim.city)
			holder.add_child(ground)
			var skyline := CitySkyline.new(ground, Seeds.make("skyline", 0))
			holder.add_child(skyline)
			var got: Dictionary = Coverage.measure(sim, decor, street, skyline)
			check(
				Num.i(got["arena_empty"]) == 0 and Num.i(got["band_empty"]) == 0,
				(
					(
						"stage %d, map_seed %d: no empty ground (%d cells: %d empty in the arena,"
						+ " %d past the edge, at %s)"
					)
					% [
						tier,
						map_seed,
						Num.i(got["cells"]),
						Num.i(got["arena_empty"]),
						Num.i(got["band_empty"]),
						got["empty"]
					]
				)
			)
			RiverBody.check(tier, map_seed, sim, check)
			RiverStart.check(tier, map_seed, sim, check)
			RiverStart.check_look(tier, map_seed, sim, decor, check)
			EdgeMark.check(tier, map_seed, sim, decor, check)
			SpawnView.check(tier, map_seed, sim, skyline, check)
			Green.check_city(tier, map_seed, sim, decor, check)
			TreeApart.check(tier, map_seed, sim, decor, check)
			Trample.check_tail(tier, map_seed, sim, decor, check)
			StadiumFar.check(tier, map_seed, sim, check)
			Kerb.check(tier, map_seed, sim, decor, check)
			Kerb.check_walkers(tier, map_seed, sim, street, check)
			BreathTrees.check(tier, map_seed, sim, decor, check)
			Reach.check_city(tier, map_seed, sim, skyline, check)  # last: it breaks every building
			holder.free()


## Every block the kaiju can reach is real, destroyable buildings at every stage
## (tests/lib/city_reach.gd; director, build 2 note 6).
func _check_reach_is_real() -> void:
	Reach.check_plan(COVERAGE_SEEDS, check)


## The run's start can never stall in the river (tests/lib/city_river.gd check_cap).
func _check_emerge_cap() -> void:
	RiverStart.check_cap(check)


## No landmark's site in the river (tests/lib/city_river.gd check_sites).
func _check_river_sites() -> void:
	RiverStart.check_sites(check)


## Every bridge meets land on both banks, stages 1-3 (tests/lib/city_bridge_land.gd; director,
## build 4 comments 2026-10-21 #12).
func _check_bridges_meet_land() -> void:
	BridgeLand.check(COVERAGE_SEEDS, check)
