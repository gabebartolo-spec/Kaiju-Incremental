extends SceneTree
## Pacing estimate for the upgrade tree (target 3-5 hours, zero AFK, D-035): a scripted player
## plays seeded rampages (walk to the nearest building, signature and ultimate when ready,
## glide half the time) and between runs buys the cheapest affordable upgrade until none is
## left. Prints, per species, the play time at which each evolution and the ultimate land and
## when the tree is complete. Play time = rampage seconds + TREE_SECONDS per visit.
##   godot --headless --path . --script tools/pacing.gd -- [--species=id] [--runs=400] [--verbose]

const DT := 1.0 / 15.0
const TREE_SECONDS := 20.0
const MILESTONES: Array[String] = ["evolve1", "evolve2", "evolve3"]

var _runs := 400
var _only := ""
var _verbose := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = arg.substr(7).to_int()
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
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var ultimate := ""
	for id: String in tree.order:
		if str(tree.defs[id]["name"]).begins_with("ULTIMATE"):
			ultimate = id
	var rubble := 0
	var clock := 0.0
	var marks: Array[String] = []
	var run := 0
	while run < _runs and tree.levels_owned() < tree.levels_total():
		var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
		var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", run))
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
			var held := RampageSim.HELD if steps % 30 < 15 else 0
			sim.step(DT, move, sim.ability_ready_in <= 0.0, held | RampageSim.ULTIMATE)
			steps += 1
		clock += steps * DT + TREE_SECONDS
		rubble += Num.i(sim.result()["rubble"])
		run += 1
		if _verbose and run % 5 == 1:
			print(
				(
					"  run %d: +%d rubble in %.0f s, %.0f%% city, %s"
					% [
						run,
						Num.i(sim.result()["rubble"]),
						steps * DT,
						Num.f(sim.result()["destruction"]) * 100.0,
						sim.end_reason
					]
				)
			)
		while true:
			var pick := _cheapest(tree, rubble)
			if pick == "":
				break
			rubble -= tree.buy(pick, rubble)
			if pick in MILESTONES or (pick == ultimate and tree.level(pick) == 1):
				marks.append(
					(
						"%s at %.2f h (run %d, %.0f%% city)"
						% [pick, clock / 3600.0, run, Num.f(sim.result()["destruction"]) * 100.0]
					)
				)
	print("== %s" % species_id)
	for line: String in marks:
		print("  " + line)
	print(
		(
			"  tree %d/%d levels after %d runs, %.2f h"
			% [tree.levels_owned(), tree.levels_total(), run, clock / 3600.0]
		)
	)


func _cheapest(tree: UpgradeTree, rubble: int) -> String:
	var best := ""
	var best_cost := rubble + 1
	for id: String in tree.order:
		if tree.can_buy(id, rubble) and tree.cost(id) < best_cost:
			best = id
			best_cost = tree.cost(id)
	return best
