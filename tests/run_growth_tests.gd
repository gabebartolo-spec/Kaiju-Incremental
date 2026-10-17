extends "res://tests/lib/runner.gd"
## Growth suite (D-039): the city grows with each evolution and the costs pace the tree for
## 3-5 hours of active play. Player-effect fixtures (growth on vs off changes the city and
## what a rampage achieves), the stages' cities and defences, the cost curve and the early
## hook, and determinism. Headless and seeded.
##   godot --headless --path . --script tests/run_growth_tests.gd

const DT := 1.0 / 15.0
## Upgrades owned at the start of each stage (enough body to be that stage's kaiju).
const COLOSSUS := {
	"claws": 5,
	"hide": 5,
	"stride": 4,
	"quake": 4,
	"rage": 5,
	"scales": 4,
	"greed": 5,
	"frenzy": 4,
	"evolve1": 1,
	"sig_power": 5,
	"regen": 4,
	"tail": 5,
	"titan_hide": 5,
	"sig_recharge": 4,
	"evolve2": 1
}


func suite_name() -> String:
	return "Growth"


func run_checks() -> void:
	_check_stages_grow()
	_check_districts_kept()
	_check_edges()
	_check_defences()
	_check_growth_matters()
	_check_cost_curve()
	_check_early_hook()
	_check_determinism()


func _tuning(tier: int) -> Dictionary:
	return CityGrowth.tuning_for(Content.tuning(), tier)


func _layout(tier: int) -> Array[Dictionary]:
	return CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))


## Every evolution opens a bigger city with taller towers: more ground, buildings and chunks.
func _check_stages_grow() -> void:
	var stages := CityGrowth.stage_count(Content.tuning())
	check(stages == 4, "one growth stage per size tier, young to Apex Titan (%d)" % stages)
	var last := {"half": 0.0, "buildings": 0, "chunks": 0, "tallest": 0}
	var grows := true
	var lines: Array[String] = []
	for tier: int in range(1, stages + 1):
		var cfg: Dictionary = _tuning(tier)["city"]
		var layout := _layout(tier)
		var chunks := 0
		var tallest := 0
		for e: Dictionary in layout:
			chunks += Num.i(e["w"]) * Num.i(e["d"]) * Num.i(e["h"])
			tallest = maxi(tallest, Num.i(e["h"]))
		var now := {
			"half": Num.f(cfg["half"]),
			"buildings": layout.size(),
			"chunks": chunks,
			"tallest": tallest
		}
		for key: String in now:
			grows = grows and Num.f(now[key]) > Num.f(last[key])
		lines.append("%d: %s" % [tier, now])
		last = now
	check(grows, "each stage's city is bigger, fuller and taller than the last: %s" % [lines])


## An evolution adds districts round the one the kaiju knows: the street plan is the same at
## every stage, and every lot of the young city stands where it stood (only taller or not).
func _check_districts_kept() -> void:
	var young := Content.section("city")
	var apex: Dictionary = _tuning(4)["city"]
	var young_plan := CityGen.map(young)
	var apex_plan := CityGen.map(apex)
	var same: bool = young_plan["xs"] == apex_plan["xs"] and young_plan["zs"] == apex_plan["zs"]
	check(same, "the street plan is the same at every stage")
	var footprints := {}
	for e: Dictionary in _layout(4):
		footprints[Vector4(Num.f(e["x"]), Num.f(e["z"]), Num.f(e["w"]), Num.f(e["d"]))] = true
	var moved := 0
	for e: Dictionary in _layout(1):
		if not footprints.has(Vector4(Num.f(e["x"]), Num.f(e["z"]), Num.f(e["w"]), Num.f(e["d"]))):
			moved += 1
	check(moved == 0, "every lot of the young city is still there at Apex (%d moved)" % moved)


## The edges still read (D-024) at every size: the bay lies past the north ring with room for
## the waterfront, the outskirts run on past the last district, and the kaiju starts in the
## street.
func _check_edges() -> void:
	var bad: Array[String] = []
	for tier: int in range(1, 5):
		var tuning := _tuning(tier)
		var cfg: Dictionary = tuning["city"]
		var half := Num.f(cfg["half"])
		if -Num.f(cfg["coast_z"]) - half < 60.0:
			bad.append("%d: bay only %.0f past the edge" % [tier, -Num.f(cfg["coast_z"]) - half])
		if Num.f(cfg["outer_half"]) < half + 100.0:
			bad.append(
				"%d: outskirts end %.0f past the edge" % [tier, Num.f(cfg["outer_half"]) - half]
			)
		var layout := _layout(tier)
		var stats := UpgradeTree.run_stats(
			Content.section("kaiju"),
			Content.species_def("reptilian"),
			UpgradeTree.new(Content.upgrades())
		)
		var spawn := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0)).kaiju_pos
		for e: Dictionary in layout:
			var w := Num.f(e["w"])
			var d := Num.f(e["d"])
			if Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d).has_point(spawn):
				bad.append("%d: the kaiju starts inside a building" % tier)
		var plan := CityGen.map(cfg)
		var built := 0
		for block: Dictionary in plan["blocks"]:
			var rect: Rect2 = block["rect"]
			var inside := maxf(
				maxf(absf(rect.position.x), absf(rect.end.x)),
				maxf(absf(rect.position.y), absf(rect.end.y))
			)
			if str(block["use"]) == "built" and inside >= half:
				bad.append("%d: a built block past the ring" % tier)
			built += 1 if str(block["use"]) == "built" else 0
		if built == 0:
			bad.append("%d: no built blocks" % tier)
	check(bad.is_empty(), "every stage's city has believable edges: %s" % [bad])
	var fog_ok := true
	for tier: int in range(2, 5):
		var now: Dictionary = _tuning(tier)["city"]
		var before: Dictionary = _tuning(tier - 1)["city"]
		var thinner := Num.f(now["fog_scale"]) < Num.f(before["fog_scale"])
		fog_ok = fog_ok and thinner and Num.f(now["far_haze"]) < Num.f(before["far_haze"])
	check(fog_ok, "the fog thins as the city grows, so its far edge still reads as skyline")


## Defences harden with each stage: no helicopters for the young kaiju, helicopters from the
## Behemoth on, tougher tanks that come faster every stage.
func _check_defences() -> void:
	var air_ok := Num.i(_tuning(1)["air"]["max"]) == 0
	var harder := true
	for tier: int in range(2, 5):
		var now := _tuning(tier)
		var before := _tuning(tier - 1)
		air_ok = air_ok and Num.i(now["air"]["max"]) > Num.i(before["air"]["max"])
		harder = harder and Num.f(now["army"]["tank_hp"]) > Num.f(before["army"]["tank_hp"])
		harder = (
			harder
			and Num.f(now["army"]["start_interval"]) < Num.f(before["army"]["start_interval"])
		)
	check(air_ok, "helicopters arrive from the Behemoth on, more each stage")
	check(harder, "each stage's tanks are tougher and come faster")
	check(
		Num.i(Content.section("air")["max"]) > 0,
		"the base tuning keeps its helicopters (the stages override, never edit it)"
	)


## Player-effect fixture: a Colossus in the young city flattens it before the clock runs out;
## in its own grown city the same rampage runs to the clock, earns more and leaves city
## standing: growth on vs off changes the city and the outcome.
func _check_growth_matters() -> void:
	var off := _play(Content.tuning(), _layout(1), COLOSSUS)
	var on := _play(_tuning(3), _layout(3), COLOSSUS)
	check(
		Num.i(on["chunks"]) > Num.i(off["chunks"]) * 4,
		(
			"growth on: the Colossus's city is far bigger (%d vs %d chunks)"
			% [on["chunks"], off["chunks"]]
		)
	)
	check(
		str(off["reason"]) == "city_fallen" and str(on["reason"]) == "time",
		(
			"growth off the Colossus flattens the city; on, it rampages to the clock (%s vs %s)"
			% [off["reason"], on["reason"]]
		)
	)
	check(
		Num.i(on["rubble"]) > Num.i(off["rubble"]) and Num.f(on["destruction"]) < 1.0,
		(
			"growth on: more rubble (%d vs %d) and city left to destroy (%.0f%%)"
			% [on["rubble"], off["rubble"], Num.f(on["destruction"]) * 100.0]
		)
	)


func _play(tuning: Dictionary, layout: Array[Dictionary], levels: Dictionary) -> Dictionary:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 1))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	var target := Vector2(INF, INF)
	var steps := 0
	while not sim.over:
		if steps % 8 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
			move = (target - sim.kaiju_pos).normalized()
		sim.step(DT, move, sim.ability_ready_in <= 0.0)
		steps += 1
	var out := sim.result()
	out["chunks"] = sim.chunks_total
	return out


## The cost curve: every node costs more each level, each evolution costs more than the last
## and more than anything before it, and the whole tree costs enough for 3-5 hours
## (tools/pacing.gd; the PR #12 / D-039 tables).
func _check_cost_curve() -> void:
	var rising := true
	var bad: Array[String] = []
	for def: Dictionary in Content.upgrades():
		var cost: Array = def["cost"]
		for i: int in range(1, cost.size()):
			if Num.i(cost[i]) <= Num.i(cost[i - 1]):
				bad.append(str(def["id"]))
	rising = bad.is_empty()
	check(rising, "every node costs more each level: %s" % [bad])
	var tree := UpgradeTree.new(Content.upgrades())
	var e1 := tree.cost("evolve1")
	var e2 := Num.i(tree.defs["evolve2"]["cost"][0])
	var e3 := Num.i(tree.defs["evolve3"]["cost"][0])
	check(e1 < e2 and e2 < e3, "each evolution costs more (%d, %d, %d)" % [e1, e2, e3])
	var young_total := 0
	for def: Dictionary in Content.upgrades():
		var requires: Array = def["requires"]
		if requires.is_empty() or str(def["id"]) in ["stride", "quake", "rage"]:
			for c: Variant in def["cost"]:
				young_total += Num.i(c)
	check(
		e1 > young_total / 10,
		(
			"the first evolution is a real goal, not a first-run buy (%d vs young nodes %d)"
			% [e1, young_total]
		)
	)
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		var total := 0
		for def: Dictionary in Content.upgrades():
			var owner := str(def.get("species", ""))
			if owner == "" or owner == species_id:
				for c: Variant in def["cost"]:
					total += Num.i(c)
		check(
			total >= 1500000 and total <= 3000000,
			"the %s tree costs %d rubble in all (the 3-5 h band)" % [species_id, total]
		)


## The early hook: two young rampages pay for the first species power, so the third rampage
## has it (D-035), for every species.
func _check_early_hook() -> void:
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		var first := INF
		for def: Dictionary in Content.upgrades():
			if str(def.get("species", "")) == species_id:
				first = minf(first, Num.f(def["cost"][0]))
		var species := Content.species_def(species_id)
		var earned := 0
		for run: int in 2:
			var tree := UpgradeTree.new(Content.upgrades(), {}, species_id)
			var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
			var sim := RampageSim.new(stats, _tuning(1), _layout(1), Seeds.make("army", run))
			var ability: Dictionary = species["ability"]
			sim.ability_type = str(ability["type"])
			var target := Vector2(INF, INF)
			var steps := 0
			while not sim.over:
				if steps % 8 == 0:
					target = sim.nearest_standing(sim.kaiju_pos)
				var move := Vector2.ZERO
				if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
					move = (target - sim.kaiju_pos).normalized()
				sim.step(DT, move, sim.ability_ready_in <= 0.0)
				steps += 1
			earned += Num.i(sim.result()["rubble"])
		check(
			earned >= first,
			(
				"%s: two young rampages (%d rubble) buy the first power (%d)"
				% [species_id, earned, first]
			)
		)


## Same stage, same city; growing the tuning never edits the shared base tuning.
func _check_determinism() -> void:
	var before := JSON.stringify(Content.tuning())
	var a := _layout(3)
	var b := _layout(3)
	check(a == b, "the same stage builds the same city every time")
	var twice := _tuning(4)
	var grown_city: Dictionary = twice["city"]
	grown_city["half"] = -1
	check(
		JSON.stringify(Content.tuning()) == before,
		"stage tunings are copies: the base tuning is never changed"
	)
	var one := _play(_tuning(2), _layout(2), {"claws": 3, "evolve1": 1})
	var two := _play(_tuning(2), _layout(2), {"claws": 3, "evolve1": 1})
	check(one == two, "a rampage in a grown city replays identically: %s vs %s" % [one, two])
