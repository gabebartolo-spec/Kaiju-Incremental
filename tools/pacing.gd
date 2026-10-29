extends SceneTree
## Pacing estimate for the upgrade tree (target about 2 hours to the last
## unlock, 90 min to 2 h, D-156; zero AFK, D-035, D-039): a scripted
## player plays seeded rampages (walk to the nearest building, signature and ultimate when
## ready, glide half the time) and between runs buys the cheapest affordable upgrade until none
## is left. The city grows with each evolution (CityGrowth). Prints, per species, the play time
## at which each evolution and each branch node lands, a table per growth stage (runs, hours,
## rubble per run, city destroyed, how runs ended) and when the tree is complete.
## Play time = rampage seconds + TREE_SECONDS per visit. The shopping and the cadence bars are
## TreePacing's (tuning "tree" "pacing"): a species with rings prints each bar it misses over the
## first window and its ring sizes against their targets.
##   godot --headless --path . --script tools/pacing.gd -- [--species=id] [--runs=400]
##     [--verbose] [--flat] [--seed=k]  (--flat: one fixed city and army, as before D-039;
##     --seed: another army stream per run; --verbose prints every run: what it paid, what it
##     bought, how it ended; --landmark=id: the player heads for that landmark first, then the
##     nearest building, as a player who has learnt where the bonus is)

const DT := PacingPlayer.DT
const TREE_SECONDS := 20.0
const MILESTONES: Array[String] = ["evolve1", "evolve2"]
const STAGE_NAMES: Array[String] = ["young", "Behemoth", "Colossus"]

var _runs := 400
var _only := ""
var _verbose := false
var _flat := false
var _seed := 0
var _landmark := ""
var _cities: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = arg.substr(7).to_int()
		if arg == "--flat":
			_flat = true
		if arg.begins_with("--landmark="):
			_landmark = arg.substr(11)
		if arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
		if arg == "--verbose":
			_verbose = true
		if arg.begins_with("--species="):
			_only = arg.substr(10)
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		if _only == "" or _only == species_id:
			_pace(species_id)
	quit()


func _pace(species_id: String) -> void:
	var species := Content.species_def(species_id)
	var tree := UpgradeTree.new(Content.upgrades(), {}, species_id)
	var shop := TreePacing.new(TREE_SECONDS)
	var marks: Array[String] = []
	var stages: Dictionary = {}  # tier -> {runs, seconds, rubble, destruction, ends}
	var run := 0
	var first_power := -1
	var city_seconds := 0.0  # the Taskforce's clock, carried run to run as the save does (D-160)
	while run < _runs and tree.levels_owned() < tree.levels_total():
		var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
		var tier := Num.i(stats["size"])
		var city: Array = _city(tier)
		var tuning: Dictionary = city[0]
		if not _flat:
			tuning = CityGrowth.hardened(
				tuning, Content.tuning(), tier, Num.f(stats.get("stage_growth", 0.0))
			)
		var layout: Array[Dictionary] = city[1]
		var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", run + 100000 * _seed))
		var ability: Dictionary = species["ability"]
		sim.ability_type = str(ability["type"])
		sim.body.use_species(species_id)
		sim.army_units.taskforce.carried = city_seconds  # as scenes/rampage.gd: the Taskforce joins
		var steps := PacingPlayer.play(sim, _goal(sim))
		var res := sim.result()
		city_seconds = sim.army_units.taskforce.city_seconds()
		sim.dispose()  # its parts point back at it: else every run's sim stays in memory
		run += 1
		_tally(stages, tier, steps * DT + TREE_SECONDS, res)
		var picks := shop.visit(tree, steps * DT, Num.i(res["rubble"]))
		var bought := picks.size()
		for pick: String in picks:
			var def: Dictionary = tree.defs[pick]
			var branch := str(def.get("species", "")) != ""
			if branch and first_power < 0:
				first_power = run
			if pick in MILESTONES or (branch and tree.level(pick) == 1):
				marks.append(
					(
						"%s at %.2f h (run %d, %.0f%% city)"
						% [pick, shop.clock / 3600.0, run, Num.f(res["destruction"]) * 100.0]
					)
				)
		if _verbose:
			print(
				(
					"  run %d (%s): +%d rubble in %.0f s, %.0f%% city, %s, bought %d"
					% [
						run,
						STAGE_NAMES[mini(tier, STAGE_NAMES.size()) - 1],
						Num.i(res["rubble"]),
						steps * DT,
						Num.f(res["destruction"]) * 100.0,
						res["reason"],
						bought,
					]
				)
			)
	print("== %s%s" % [species_id, " (flat city)" if _flat else ""])
	for line: String in marks:
		print("  " + line)
	print("  first species power bought after run %d" % first_power)
	print("  | stage | runs | hours | rubble/run | city destroyed | ended: time/defeated/city |")
	for tier: int in stages:
		var s: Dictionary = stages[tier]
		var n := Num.i(s["runs"])
		var ends: Dictionary = s["ends"]
		print(
			(
				"  | %s | %d | %.2f | %d -> %d | %.0f%% -> %.0f%% | %d/%d/%d |"
				% [
					STAGE_NAMES[mini(tier, STAGE_NAMES.size()) - 1],
					n,
					Num.f(s["seconds"]) / 3600.0,
					Num.i(s["first_rubble"]),
					Num.i(s["last_rubble"]),
					Num.f(s["first_destruction"]) * 100.0,
					Num.f(s["last_destruction"]) * 100.0,
					Num.i(ends.get("time", 0)),
					Num.i(ends.get("defeated", 0)),
					Num.i(ends.get("city_fallen", 0)),
				]
			)
		)
	print(
		(
			"  tree %d/%d levels after %d runs, %.2f h"
			% [tree.levels_owned(), tree.levels_total(), run, shop.clock / 3600.0]
		)
	)
	_bars(tree, shop)


## A species with rings: each ring's size against its target, then the cadence bars it misses
## over the first window (TreePacing, tuning "tree" "pacing").
func _bars(tree: UpgradeTree, shop: TreePacing) -> void:
	if tree.rings.is_empty():
		return
	var counts: Dictionary = {}
	for id: String in tree.order:
		counts[tree.ring(id)] = Num.i(counts.get(tree.ring(id), 0)) + 1
	for r: int in range(1, tree.rings.size() + 1):
		var ring_def: Dictionary = tree.rings[r - 1]
		print(
			(
				"  ring %d: %d nodes (target %d)"
				% [r, Num.i(counts.get(r, 0)), Num.i(ring_def["target"])]
			)
		)
	var pacing: Dictionary = Content.section("tree")["pacing"]
	var misses := shop.misses(tree, pacing)
	print("  bars: %s" % ("PASS" if misses.is_empty() else "MISS " + "; ".join(misses)))


func _tally(stages: Dictionary, tier: int, seconds: float, res: Dictionary) -> void:
	if not stages.has(tier):
		stages[tier] = {
			"runs": 0,
			"seconds": 0.0,
			"first_rubble": res["rubble"],
			"first_destruction": res["destruction"],
			"ends": {},
		}
	var s: Dictionary = stages[tier]
	s["runs"] = Num.i(s["runs"]) + 1
	s["seconds"] = Num.f(s["seconds"]) + seconds
	s["last_rubble"] = res["rubble"]
	s["last_destruction"] = res["destruction"]
	var ends: Dictionary = s["ends"]
	var reason := str(res["reason"])
	ends[reason] = Num.i(ends.get(reason, 0)) + 1


## [tuning, layout] for a size tier: the grown city of that stage (or the untouched tuning, --flat).
func _city(tier: int) -> Array:
	var stage := 0 if _flat else tier
	if not _cities.has(stage):
		var tuning := Content.tuning() if _flat else CityGrowth.tuning_for(Content.tuning(), stage)
		var cfg: Dictionary = tuning["city"]
		_cities[stage] = [tuning, CityGen.generate(Seeds.make("city", 0), cfg)]
	return _cities[stage]


## Where the --landmark player heads first (INF when there is none in this city).
func _goal(sim: RampageSim) -> Vector2:
	for b: RampageSim.Building in sim.buildings:
		if _landmark != "" and b.landmark == _landmark:
			return Vector2(b.x, b.z)
	return Vector2(INF, INF)
