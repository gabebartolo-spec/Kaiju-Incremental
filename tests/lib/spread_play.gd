extends RefCounted
## Rampages played in the real 1.5x cities (D-254) for the spread suite (tests/run_spread_tests.gd):
## the paired balance fixture (the same kaiju, bot and seeds in the shipped stage-1 city and in
## the stage-1 city as it stood before D-254) and the bridge breaking under stomps.
## Seeded by design: Seeds.make("city", 0) and Seeds.make("army", 1), the shipped tuning.

const Rings := preload("res://tests/lib/fixture_rings.gd")

const DT := 1.0 / 15.0
## The young kaiju fully bought (stage 1's own nodes).
const YOUNG := {"claws": 5, "hide": 5, "stride": 4, "quake": 4, "rage": 5}
## The Behemoth stage 2 opens with (tools/capture/capture_kit.gd STAGE_LEVELS[1]).
const BEHEMOTH := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}
## The stage-1 city before D-254 (main at 6e4d6a5d): half-widths, coast, skyline and diagonal.
const OLD_HALVES: Array[int] = [50, 80, 150]
const OLD_COAST := -120
## Seconds the kaiju stomps at the bridge.
const BRIDGE_SECONDS := 20.0


## Paired: the same young kaiju, bot and seeds, 1.5x on (the shipped city) vs off (the old
## stage-1 city). On: a bigger city (more chunks), the same result from the same seed twice. The
## razed shares are printed, not checked (D-389: a balance number, D-385).
static func paired(check: Callable) -> void:
	var on_tuning := Content.tuning()
	var off_tuning := _old(on_tuning)
	var on := _play(on_tuning)
	var again := _play(on_tuning)
	var off := _play(off_tuning)
	print(
		(
			(
				"  paired stage 1: 1.5x on %d chunks, %.0f%% razed, %s at %.0f s;"
				+ " off %d chunks, %.0f%% razed, %s at %.0f s"
			)
			% [
				on["chunks"],
				Num.f(on["destruction"]) * 100.0,
				on["reason"],
				on["seconds"],
				off["chunks"],
				Num.f(off["destruction"]) * 100.0,
				off["reason"],
				off["seconds"],
			]
		)
	)
	check.call(str(on) == str(again), "paired: the same seeds play the same stage-1 rampage twice")
	check.call(
		Num.i(on["chunks"]) > Num.i(off["chunks"]),
		"paired: the 1.5x stage-1 city is bigger (%d vs %d chunks)" % [on["chunks"], off["chunks"]]
	)


## The bridge (stage 2's city, map 7301) breaks in its baked shape under a Behemoth's stomps: it
## is in the rampage as a landmark and loses chunks.
static func bridge_breaks(check: Callable) -> void:
	var layout := CityGrowth.layout(Content.tuning(), 2, Seeds.make("city", 0))
	var sim := _sim(Content.tuning(), 2, layout, BEHEMOTH)
	var n := -1
	for i: int in sim.buildings.size():
		if sim.buildings[i].landmark == "bridge":
			n = i
	check.call(n >= 0, "the shipped stage-2 city has the bridge in its rampage")
	if n < 0:
		return
	var b := sim.buildings[n]
	var at := Vector2(b.x, b.z)
	for s: int in int(BRIDGE_SECONDS / DT):
		sim.kaiju_pos = at
		sim.step(DT, Vector2.ZERO, false)
	var left := b.frame.alive_count
	print(
		(
			"  bridge: %d of %d chunks left after %.0f s of stomps"
			% [left, b.start_chunks, BRIDGE_SECONDS]
		)
	)
	check.call(
		b.start_chunks > 0 and left < b.start_chunks,
		"stomps break the bridge (%d of %d chunks left)" % [left, b.start_chunks]
	)


static func _old(tuning: Dictionary) -> Dictionary:
	var out: Dictionary = tuning.duplicate(true)
	var city: Dictionary = out["city"]
	city["half"] = OLD_HALVES[0]
	city["districts"] = OLD_HALVES.duplicate()
	city["coast_z"] = OLD_COAST
	city["cores"] = Rings.CORES.duplicate(true)
	city["outer_cores"] = Rings.OUTER_CORES.duplicate(true)
	city["outer_half"] = Rings.OUTER_HALF
	city["diagonal_through"] = Rings.DIAGONAL_THROUGH.duplicate()
	var growth: Dictionary = out["growth"]
	var stage: Dictionary = growth["stages"][0]
	var stage_city: Dictionary = stage["city"]
	stage_city["half"] = OLD_HALVES[0]
	stage_city["coast_z"] = OLD_COAST
	return out


static func _play(tuning: Dictionary) -> Dictionary:
	var layout := CityGrowth.layout(tuning, 1, Seeds.make("city", 0))
	var sim := _sim(tuning, 1, layout, YOUNG)
	var target := Vector2(INF, INF)
	var steps := 0
	while not sim.over:
		if steps % 8 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and not sim.body.stomp_reaches(target):
			move = (target - sim.kaiju_pos).normalized()
		sim.step(DT, move, sim.ability_ready_in <= 0.0)
		steps += 1
	var out := sim.result()
	out["chunks"] = sim.chunks_total
	return out


static func _sim(
	tuning: Dictionary, tier: int, layout: Array[Dictionary], levels: Dictionary
) -> RampageSim:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var sim := RampageSim.new(
		stats, CityGrowth.tuning_for(tuning, tier), layout, Seeds.make("army", 1)
	)
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	return sim
