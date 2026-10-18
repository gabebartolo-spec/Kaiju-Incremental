extends SceneTree
## Pacing estimate for the upgrade tree (target 3-5 hours, zero AFK, D-035, D-039): a scripted
## player plays seeded rampages (walk to the nearest building, signature and ultimate when
## ready, glide half the time) and between runs buys the cheapest affordable upgrade until none
## is left. The city grows with each evolution (CityGrowth). Prints, per species, the play time
## at which each evolution and each branch node lands, a table per growth stage (runs, hours,
## rubble per run, city destroyed, how runs ended) and when the tree is complete.
## Play time = rampage seconds + TREE_SECONDS per visit.
##   godot --headless --path . --script tools/pacing.gd -- [--species=id] [--runs=400]
##     [--verbose] [--flat] [--no-jets] [--dodge]  (--flat: one fixed city and army, as before
##     D-039; --no-jets: no jets at any stage (D-072); --dodge: once a jet warns, the player
##     walks off its line across the camera's view, toward the arena's middle (a jet's line runs
##     across the screen), and keeps away until that jet has gone and its bombs have landed)

const DT := 1.0 / 15.0
const TREE_SECONDS := 20.0
const MILESTONES: Array[String] = ["evolve1", "evolve2", "evolve3"]
const STAGE_NAMES: Array[String] = ["young", "Behemoth", "Colossus", "Apex Titan"]

var _runs := 400
var _only := ""
var _verbose := false
var _flat := false
var _no_jets := false
var _dodge := false
var _cities: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = arg.substr(7).to_int()
		if arg == "--flat":
			_flat = true
		if arg == "--verbose":
			_verbose = true
		if arg == "--no-jets":
			_no_jets = true
		if arg == "--dodge":
			_dodge = true
		if arg.begins_with("--species="):
			_only = arg.substr(10)
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		if _only == "" or _only == species_id:
			_pace(species_id)
	quit()


func _pace(species_id: String) -> void:
	var species := Content.species_def(species_id)
	var tree := UpgradeTree.new(Content.upgrades(), {}, species_id)
	var rubble := 0
	var clock := 0.0
	var marks: Array[String] = []
	var stages: Dictionary = {}  # tier -> {runs, seconds, rubble, destruction, ends}
	var run := 0
	var first_power := -1
	while run < _runs and tree.levels_owned() < tree.levels_total():
		var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
		var tier := Num.i(stats["size"])
		var city: Array = _city(tier)
		var tuning: Dictionary = city[0]
		var layout: Array[Dictionary] = city[1]
		var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", run))
		var ability: Dictionary = species["ability"]
		sim.ability_type = str(ability["type"])
		var played := _rampage(sim)
		var steps := Num.i(played[0])
		var res := sim.result()
		res["jet_hits"] = played[1]
		clock += steps * DT + TREE_SECONDS
		rubble += Num.i(res["rubble"])
		run += 1
		_tally(stages, tier, steps * DT + TREE_SECONDS, res)
		if _verbose and run % 5 == 1:
			print(
				(
					"  run %d (%s): +%d rubble in %.0f s, %.0f%% city, %s"
					% [
						run,
						STAGE_NAMES[mini(tier, 4) - 1],
						Num.i(res["rubble"]),
						steps * DT,
						Num.f(res["destruction"]) * 100.0,
						sim.end_reason
					]
				)
			)
		while true:
			var pick := _cheapest(tree, rubble)
			if pick == "":
				break
			rubble -= tree.buy(pick, rubble)
			var def: Dictionary = tree.defs[pick]
			var branch := str(def.get("species", "")) != ""
			if branch and first_power < 0:
				first_power = run
			if pick in MILESTONES or (branch and tree.level(pick) == 1):
				marks.append(
					(
						"%s at %.2f h (run %d, %.0f%% city)"
						% [pick, clock / 3600.0, run, Num.f(res["destruction"]) * 100.0]
					)
				)
	var notes := (" (flat city)" if _flat else "") + (" (no jets)" if _no_jets else "")
	print("== %s%s%s" % [species_id, notes, " (dodging jets)" if _dodge else ""])
	for line: String in marks:
		print("  " + line)
	print("  first species power bought after run %d" % first_power)
	print(
		(
			"  | stage | runs | hours | rubble/run | city destroyed | ended: time/defeated/city"
			+ " | jet hits/run |"
		)
	)
	for tier: int in stages:
		var s: Dictionary = stages[tier]
		var n := Num.i(s["runs"])
		var ends: Dictionary = s["ends"]
		print(
			(
				"  | %s | %d | %.2f | %d -> %d | %.0f%% -> %.0f%% | %d/%d/%d | %.1f |"
				% [
					STAGE_NAMES[mini(tier, 4) - 1],
					n,
					Num.f(s["seconds"]) / 3600.0,
					Num.i(s["first_rubble"]),
					Num.i(s["last_rubble"]),
					Num.f(s["first_destruction"]) * 100.0,
					Num.f(s["last_destruction"]) * 100.0,
					Num.i(ends.get("time", 0)),
					Num.i(ends.get("defeated", 0)),
					Num.i(ends.get("city_fallen", 0)),
					Num.f(s["jet_hits"]) / maxf(1.0, n),
				]
			)
		)
	print(
		(
			"  tree %d/%d levels after %d runs, %.2f h"
			% [tree.levels_owned(), tree.levels_total(), run, clock / 3600.0]
		)
	)


## Plays one rampage to its end; [steps, jet hits taken].
func _rampage(sim: RampageSim) -> Array[int]:
	var target := Vector2(INF, INF)
	var steps := 0
	var warned := {}  # jets the player is keeping out of the way of (--dodge)
	var off_line := Vector2.ZERO
	var jet_hits := 0
	while not sim.over:
		if steps % 8 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
			move = (target - sim.kaiju_pos).normalized()
		var held := RampageSim.HELD if steps % 30 < 15 else 0
		if not warned.is_empty() or (_dodge and not sim.strike.bombs.is_empty()):
			move = off_line
			held = 0  # let go of the signature to run
		var flags := held | RampageSim.ULTIMATE
		for event: Dictionary in sim.step(DT, move, sim.ability_ready_in <= 0.0, flags):
			var kind := str(event["type"])
			if kind == "jet_inbound" and _dodge:
				if warned.is_empty():
					off_line = _off_line(sim)
				warned[Num.i(event["jet"])] = true
			if kind == "jet_left" or kind == "jet_destroyed":
				warned.erase(Num.i(event["jet"]))
			if (kind == "jet_strafe" or kind == "jet_bomb") and event["hit"]:
				jet_hits += 1
		steps += 1
	return [steps, jet_hits]


## Off a jet's line: along the camera's axis (square to every pass), toward the arena's middle so
## a kaiju on its edge is never pinned against it.
func _off_line(sim: RampageSim) -> Vector2:
	var out := Vector2.from_angle(deg_to_rad(Num.f(sim.strike.cfg["camera_bearing"])))
	return -out if sim.kaiju_pos.dot(out) > 0.0 else out


func _tally(stages: Dictionary, tier: int, seconds: float, res: Dictionary) -> void:
	if not stages.has(tier):
		stages[tier] = {
			"runs": 0,
			"seconds": 0.0,
			"first_rubble": res["rubble"],
			"first_destruction": res["destruction"],
			"ends": {},
			"jet_hits": 0,
		}
	var s: Dictionary = stages[tier]
	s["runs"] = Num.i(s["runs"]) + 1
	s["seconds"] = Num.f(s["seconds"]) + seconds
	s["jet_hits"] = Num.i(s["jet_hits"]) + Num.i(res["jet_hits"])
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
		if _no_jets:
			tuning = tuning.duplicate(true)
			tuning["jets"]["max"] = 0
		var cfg: Dictionary = tuning["city"]
		_cities[stage] = [tuning, CityGen.generate(Seeds.make("city", 0), cfg)]
	return _cities[stage]


func _cheapest(tree: UpgradeTree, rubble: int) -> String:
	var best := ""
	var best_cost := rubble + 1
	for id: String in tree.order:
		if tree.can_buy(id, rubble) and tree.cost(id) < best_cost:
			best = id
			best_cost = tree.cost(id)
	return best
