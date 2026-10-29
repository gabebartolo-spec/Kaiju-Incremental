extends "res://tests/lib/runner.gd"
## Growth suite (D-039): the city grows with each evolution and the costs pace the tree for
## 3-5 hours of active play. Player-effect fixtures (growth on vs off changes the city and
## what a rampage achieves), the stages' cities and defences, the cost curve and the early
## hook, and determinism. Headless and seeded.
##   godot --headless --path . --script tests/run_growth_tests.gd

const DT := 1.0 / 15.0
## Upgrades owned at the start of each stage (enough body to be that stage's kaiju).
## How much more of the city (a share, 0..1) the young city loses than the grown one.
const GROWTH_MARGIN := 0.2
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
	await _t("_check_stages_grow")
	await _t("_check_districts_kept")
	await _t("_check_edges")
	await _t("_check_defences")
	await _h(
		"growth_army_learns",
		func() -> void: preload("res://tests/lib/growth_army_learns.gd").check(check, _play)
	)
	await _t("_check_growth_matters")
	await _t("_check_cost_curve")
	await _t("_check_early_hook")
	await _t("_check_determinism")
	await _t("_check_young_pace")


func _tuning(tier: int) -> Dictionary:
	return CityGrowth.tuning_for(Content.tuning(), tier)


func _layout(tier: int) -> Array[Dictionary]:
	return CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))


## Every evolution opens a bigger city with taller towers: more ground, buildings and chunks
## (the tallest off the fixed beachfront and not a landmark: both stand the same at every stage).
func _check_stages_grow() -> void:
	var stages := CityGrowth.stage_count(Content.tuning())
	check(stages == 3, "one growth stage per body, young to Colossus (%d, D-135)" % stages)
	var evolutions := 0
	for def: Dictionary in Content.upgrades():
		var effects: Dictionary = def["effects"]
		evolutions += 1 if effects.has("size") else 0
	var bodies: Array = Content.section("contact")["bodies"]["reptilian"]
	check(
		evolutions + 1 == stages and bodies.size() == stages,
		"evolutions + 1 = growth stages = bodies (%d, %d, %d)" % [evolutions, stages, bodies.size()]
	)
	var last := {"half": 0.0, "buildings": 0, "chunks": 0, "tallest": 0}
	var grows := true
	var lines: Array[String] = []
	for tier: int in range(1, stages + 1):
		var cfg: Dictionary = _tuning(tier)["city"]
		var layout := _layout(tier)
		var chunks := 0
		var tallest := 0
		var front := CityHarbour.rect_of(cfg)  # its hotels stand the same at every stage (D-381)
		for e: Dictionary in layout:
			chunks += Num.i(e["w"]) * Num.i(e["d"]) * Num.i(e["h"])
			if not (e.has("landmark") or front.has_point(Vector2(Num.f(e["x"]), Num.f(e["z"])))):
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
	var adult: Dictionary = _tuning(3)["city"]
	var young_plan := CityGen.map(young)
	var adult_plan := CityGen.map(adult)
	var same: bool = young_plan["xs"] == adult_plan["xs"] and young_plan["zs"] == adult_plan["zs"]
	check(same, "the street plan is the same at every stage")
	var footprints := {}
	for e: Dictionary in _layout(3):
		footprints[Vector4(Num.f(e["x"]), Num.f(e["z"]), Num.f(e["w"]), Num.f(e["d"]))] = true
	# The beachfront is the same at every stage (D-381); its hotel blocks are built or stand-ins
	# by the stage's band, so the front is left out. The blocks by the landing give their lots to
	# its quay sheds (CityRiver.off_quay).
	var sea := CityHarbour.rect_of(adult)
	var quays: Array[Rect2] = []
	for block: Dictionary in young_plan["blocks"]:
		if str(block["use"]) == "built" and CityRiver.on_quay(young_plan, block, young):
			var rect: Rect2 = block["rect"]
			quays.append(rect)
	var moved := 0
	for e: Dictionary in _layout(1):
		var foot := Rect2(
			Num.f(e["x"]) - Num.f(e["w"]) * 0.5,
			Num.f(e["z"]) - Num.f(e["d"]) * 0.5,
			Num.f(e["w"]),
			Num.f(e["d"])
		)
		if sea.intersects(foot) or quays.any(func(q: Rect2) -> bool: return q.intersects(foot)):
			continue
		if not footprints.has(Vector4(Num.f(e["x"]), Num.f(e["z"]), Num.f(e["w"]), Num.f(e["d"]))):
			moved += 1
	check(moved == 0, "every lot of the young city is still there at Colossus (%d moved)" % moved)


## The edges still read (D-024) at every size: the bay lies past the north ring with room for
## the waterfront, the outskirts run on past the last district, no block past the real band
## the camera shows (CityBand) is built up, and the kaiju starts in the street.
func _check_edges() -> void:
	var bad: Array[String] = []
	for tier: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
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
			if str(block["use"]) == "built" and not CityBand.real(rect, cfg):
				bad.append("%d: a built block past the real band" % tier)
			built += 1 if str(block["use"]) == "built" else 0
		if built == 0:
			bad.append("%d: no built blocks" % tier)
	check(bad.is_empty(), "every stage's city has believable edges: %s" % [bad])
	var fog_ok := true
	for tier: int in range(2, CityGrowth.stage_count(Content.tuning()) + 1):
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
	for tier: int in range(2, CityGrowth.stage_count(Content.tuning()) + 1):
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


## The army learns inside a stage (active-incremental finding 1, 2026-10-18): the levels bought
## on the current tier's nodes harden the tanks and helicopters; an evolution resets that count.
## Player-effect fixture: a fully bought Behemoth in its own city with the escalation on loses
## more health to the army than with it off, so the clock is not the only thing that ends a run.
## Player-effect fixture: a Colossus in the young city flattens it; in its own grown city the same
## rampage does not (with the breath's 1.4 s wind-up it ends on the clock or is defeated), destroys
## at least GROWTH_MARGIN (a share of the city) less, earns more and leaves city standing: growth on
## vs off changes the city and the outcome. Seeded by design: army seed 1.
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
		str(off["reason"]) == "city_fallen" and str(on["reason"]) != "city_fallen",
		(
			"growth off the Colossus flattens the city; on, it does not (%s vs %s)"
			% [off["reason"], on["reason"]]
		)
	)
	check(
		Num.f(off["destruction"]) >= Num.f(on["destruction"]) + GROWTH_MARGIN,
		(
			"growth off destroys at least %.0f points more of the city (%.0f%% vs %.0f%%)"
			% [
				GROWTH_MARGIN * 100.0,
				Num.f(off["destruction"]) * 100.0,
				Num.f(on["destruction"]) * 100.0
			]
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
		if target.x < INF and not sim.body.stomp_reaches(target):
			move = (target - sim.kaiju_pos).normalized()
		sim.step(DT, move, sim.ability_ready_in <= 0.0)
		steps += 1
	var out := sim.result()
	out["chunks"] = sim.chunks_total
	out["hp_lost"] = Num.f(stats["hp"]) - sim.hp
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
	check(e1 < e2, "each evolution costs more (%d, %d)" % [e1, e2])
	var young_total := 0
	for def: Dictionary in Content.upgrades():
		var requires: Array = def["requires"]
		if requires.is_empty() or str(def["id"]) in ["stride", "quake", "rage"]:
			for c: Variant in def["cost"]:
				young_total += Num.i(c)
	check(
		e1 > young_total / 20,  # D-087: first evolution ~15 min; first buy is still run ~14
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
			total >= 1500000 and total <= 4500000,
			"the %s tree costs %d rubble in all (the 3-5 h band, D-049)" % [species_id, total]
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
				if target.x < INF and not sim.body.stomp_reaches(target):
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
	var twice := _tuning(3)
	var grown_city: Dictionary = twice["city"]
	grown_city["half"] = -1
	check(
		JSON.stringify(Content.tuning()) == before,
		"stage tunings are copies: the base tuning is never changed"
	)
	var one := _play(_tuning(2), _layout(2), {"claws": 3, "evolve1": 1})
	var two := _play(_tuning(2), _layout(2), {"claws": 3, "evolve1": 1})
	check(one == two, "a rampage in a grown city replays identically: %s vs %s" % [one, two])


## The young stage is a slow, tough toddler (D-074): the stage's "body" slows the cub so its
## stride reads heavy and gives it more hp to last the slower run; from the first evolution on it
## walks at full speed on its own hp. Walked distance and the sim's hp, not just the stats.
func _check_young_pace() -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var walked: Array[float] = []
	var hp: Array[float] = []
	for tier: int in [1, 2]:
		var sim := RampageSim.new(stats, _tuning(tier), _layout(tier), Seeds.make("army", 0))
		var start := sim.kaiju_pos
		for frame: int in 30:
			sim.step(1.0 / 30.0, Vector2(1, 0), false)
		walked.append((sim.kaiju_pos - start).length())
		hp.append(sim.max_hp)
	var body: Dictionary = _tuning(1)["body"]
	var mult := Num.f(body["speed_mult"])
	check(
		mult < 1.0 and absf(walked[0] / maxf(0.001, walked[1]) - mult) < 0.02,
		(
			"the young stage walks at %.2f of full speed (walked %.2f vs %.2f)"
			% [mult, walked[0], walked[1]]
		)
	)
	var tough := Num.f(body["hp_mult"])
	check(
		tough > 1.0 and absf(hp[0] / maxf(0.001, hp[1]) - tough) < 0.01,
		"the young stage has %.2f of its hp (%.0f vs %.0f)" % [tough, hp[0], hp[1]]
	)
