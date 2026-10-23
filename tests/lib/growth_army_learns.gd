extends RefCounted
## The growth suite's army-learns checks (D-069): inside a stage the army scales with the levels
## the kaiju owns, evolving resets that growth, and a full Behemoth loses more health to the army
## that learnt. `play` is the suite's seeded rampage: play(tuning, layout, levels) -> result.

## The cities the learning army is measured in, summed: one seeded rampage swings by a quarter
## from platform to platform (city seed 0 alone read 280 vs 182 hp here and 230 vs 182 on CI,
## ratios 1.54 and 1.26), the six together hold 1.7 (1.45 to 2.17 each).
const LEARN_SEEDS := 6

## Every Behemoth-tier node bought, the evolution to Colossus not yet.
const BEHEMOTH_FULL := {
	"claws": 5,
	"hide": 5,
	"stride": 4,
	"quake": 4,
	"rage": 5,
	"greed": 5,
	"frenzy": 4,
	"evolve1": 1,
	"r_tail": 4,
	"r_momentum": 4,
	"sig_power": 5,
	"tail": 5,
	"titan_hide": 5,
	"scales": 4,
	"sig_recharge": 4,
	"r_shear": 3
}


static func check(check: Callable, play: Callable) -> void:
	var species := Content.species_def("reptilian")
	var young := {"claws": 5, "hide": 5, "rage": 5, "evolve1": 1}
	var fresh := UpgradeTree.new(Content.upgrades(), young, "reptilian")
	var fresh_stats := UpgradeTree.run_stats(Content.section("kaiju"), species, fresh)
	check.call(
		Num.i(fresh_stats["size"]) == 2 and Num.f(fresh_stats["stage_growth"]) == 0.0,
		(
			"evolving resets the stage's growth to 0 (tier %d, stage growth %.0f)"
			% [fresh_stats["size"], fresh_stats["stage_growth"]]
		)
	)
	var tiers := "Armoured Scales is a young node, Regeneration Colossus, evolve1 its own tier"
	check.call(
		(
			fresh.tier_of("scales") == 1
			and fresh.tier_of("regen") == 3
			and fresh.tier_of("evolve1") == 1
		),
		tiers
	)
	var grown := UpgradeTree.new(Content.upgrades(), BEHEMOTH_FULL, "reptilian")
	var grown_stats := UpgradeTree.run_stats(Content.section("kaiju"), species, grown)
	var stage_growth := Num.f(grown_stats["stage_growth"])
	check.call(stage_growth >= 20.0, "a full Behemoth owns 20+ stage levels (%.0f)" % stage_growth)
	var off := CityGrowth.tuning_for(Content.tuning(), 2)
	var on := CityGrowth.tuning_for_stats(Content.tuning(), grown_stats)
	check.call(
		(
			Num.f(on["army"]["tank_hp"]) > Num.f(off["army"]["tank_hp"]) * 1.3
			and Num.f(on["army"]["tank_damage"]) > Num.f(off["army"]["tank_damage"]) * 1.3
			and Num.f(on["army"]["start_interval"]) < Num.f(off["army"]["start_interval"])
			and Num.f(on["air"]["damage"]) > Num.f(off["air"]["damage"])
		),
		(
			"the army learns: tanks %.0f -> %.0f hp, %.1f -> %.1f damage, every %.1f -> %.1f s"
			% [
				off["army"]["tank_hp"],
				on["army"]["tank_hp"],
				off["army"]["tank_damage"],
				on["army"]["tank_damage"],
				off["army"]["start_interval"],
				on["army"]["start_interval"]
			]
		)
	)
	var soft_lost := 0.0
	var hard_lost := 0.0
	for city_seed: int in LEARN_SEEDS:
		var layout := CityGrowth.layout(Content.tuning(), 2, Seeds.make("city", city_seed))
		var soft: Dictionary = play.call(off, layout, BEHEMOTH_FULL)
		var hard: Dictionary = play.call(on, layout, BEHEMOTH_FULL)
		soft_lost += Num.f(soft["hp_lost"])
		hard_lost += Num.f(hard["hp_lost"])
	(
		check
		. call(
			hard_lost > soft_lost * 1.3,
			(
				"a full Behemoth loses more health to the army that learnt (%.0f vs %.0f hp over %d cities)"
				% [hard_lost, soft_lost, LEARN_SEEDS]
			)
		)
	)
