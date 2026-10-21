extends "res://tests/lib/runner.gd"
## Empty space suite (R 6.1; director 2026-10-18: "there should never be vast empty spaces with
## nothing to smash or kill"): at every growth stage, for three street plans, every district's
## built blocks are mostly buildings, no built block stands empty, and no street inside the arena
## runs far with nothing to smash beside it (tests/lib/empty_space.gd). One timing line per stage
## (printed, never checked: a clock in a check is a flaky test).
## Seeded by design: the stage tunings, city.map_seed per plan and fixed city/army/decor seeds.
##   godot --headless --path . --script tests/run_empty_space_tests.gd

const Space := preload("res://tests/lib/empty_space.gd")
## The street plans checked (the shipped city.map_seed first; the city suite's three).
const SEEDS: Array[int] = [7301, 1234, 98765]
## Lowest built footprint share of a district's built blocks, any stage and plan.
## Measured 2026-10-21 (stages 1-4, the three plans): lowest 0.736 (map_seed 1234, district 1,
## the ring past the young arena), most districts 0.78-0.94; 0.65 leaves room for the river and
## diagonal changes in flight. A third of district 0's blocks emptied (stage 1) measures 0.518.
const SHARE_FLOOR := 0.65
## Longest street stretch inside the arena with nothing to smash within reach (world units).
## Measured 2026-10-21: longest 10.2 (map_seed 98765, stages 3-4, the ring avenue at z = 42
## by the river), 1.0-9.2 elsewhere; a stripped street (stage 1, the z = -42 ring) measures 25.5.
const GAP_CAP := 12.0
## Reach past a street's half width + sidewalk that still counts as beside the street.
const REACH_PAD := 1.5


func suite_name() -> String:
	return "EmptySpace"


func run_checks() -> void:
	for tier: int in [1, 2, 3, 4]:
		await _t("_check_stage", [tier])
	await _h(
		"junction_island",
		func() -> void: preload("res://tests/lib/junction_island.gd").new(check, root).run()
	)


## One stage, every plan: footprint share per district, no empty built block, the street gap.
func _check_stage(tier: int) -> void:
	var t_gen := 0
	var t_decor := 0
	var buildings := 0
	for map_seed: int in SEEDS:
		var base: Dictionary = Content.tuning().duplicate(true)
		var city_cfg: Dictionary = base["city"]
		city_cfg["map_seed"] = map_seed
		var tuning := CityGrowth.tuning_for(base, tier)
		var cfg: Dictionary = tuning["city"]
		var t0 := Time.get_ticks_usec()
		var layout := CityGrowth.layout(base, tier, Seeds.make("city", 0))
		var plan := CityGen.map(cfg)
		t_gen += Time.get_ticks_usec() - t0
		buildings += layout.size()
		var rows := Space.districts(plan, layout, cfg)
		var low := INF
		var low_k := -1
		var empty: Array = []
		for k: int in rows:
			var row: Dictionary = rows[k]
			var none: Array = row["empty"]
			if Num.f(row["share"]) < low:
				low = Num.f(row["share"])
				low_k = k
			empty.append_array(none)
		check(
			low >= SHARE_FLOOR,
			(
				(
					"stage %d, map_seed %d: every district's built blocks are at least %.2f buildings"
					+ " (lowest %.3f, district %d)"
				)
				% [tier, map_seed, SHARE_FLOOR, low, low_k]
			)
		)
		check(
			empty.is_empty(),
			(
				"stage %d, map_seed %d: no built block without a building (%d: %s)"
				% [tier, map_seed, empty.size(), empty]
			)
		)
		t0 = Time.get_ticks_usec()
		var stats := UpgradeTree.run_stats(
			Content.section("kaiju"),
			Content.species_def("reptilian"),
			UpgradeTree.new(Content.upgrades())
		)
		var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
		var decor := CityDecor.new(sim, Seeds.make("decor", 0))
		root.add_child(decor)
		t_decor += Time.get_ticks_usec() - t0
		var gap := street_gap(plan, cfg, sim, decor)
		check(
			Num.f(gap["max"]) <= GAP_CAP,
			(
				(
					"stage %d, map_seed %d: no street runs over %.0f with nothing to smash beside it"
					+ " (longest %.1f, a %s at %s)"
				)
				% [tier, map_seed, GAP_CAP, Num.f(gap["max"]), gap["kind"], gap["at"]]
			)
		)
		decor.free()
	print(
		(
			"  timing: stage %d, %d plans: generate %.0f ms, sim + decor %.0f ms, %d buildings"
			% [tier, SEEDS.size(), t_gen / 1000.0, t_decor / 1000.0, buildings]
		)
	)


## The street gap of a built city: buildings, parked cars and decor props are the smashables.
static func street_gap(
	plan: Dictionary, cfg: Dictionary, sim: RampageSim, decor: CityDecor
) -> Dictionary:
	var rects: Array[Rect2] = []
	for b: RampageSim.Building in sim.buildings:
		rects.append(Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d))
	rects.append_array(decor.cars)
	var points: Array[Vector2] = []
	for g: Dictionary in decor._props._groups:
		var at: Vector3 = g["at"]
		points.append(Vector2(at.x, at.z))
	return Space.street_gap(plan, cfg, sim.arena_half, rects, points, REACH_PAD)
