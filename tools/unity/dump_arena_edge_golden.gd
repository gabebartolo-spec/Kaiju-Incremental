extends SceneTree
## Writes Godot's arena edge bollards (scenes/arena_edge.gd), so the Unity port
## (unity/Assets/Scripts/GameLogic/ArenaEdge.cs) can be checked against it.
##
##   godot --headless --path . --script tools/unity/dump_arena_edge_golden.gd
##
## Each case builds the city the way tests/run_city_tests.gd does (stage, map_seed), plants
## CityDecor's street trees and asks ArenaEdge where the bollards stand.
##
## Output: unity/SimTests/golden/arena_edge.txt, read by ArenaEdgeCheck
## (`dotnet run --project unity/SimTests`). CASE (stage, map_seed, arena_half, the line's half),
## then TREE (a street tree near the line: x z), ROAD (from, to, reach), POST (x y z), and
## SIDE (n s e w bollards) and DRY (n s e w dry metres: tests/lib/city_arena_edge.gd _dry).

const OUT := "res://unity/SimTests/golden/arena_edge.txt"
const STAGES: Array[int] = [1, 2, 3, 4]
## tests/run_city_tests.gd COVERAGE_SEEDS.
const MAP_SEEDS: Array[int] = [7301, 1234, 98765]
## Trees this far past ArenaEdge.BAND from the line are left out: spots() never looks at them.
const TREE_SLACK := 0.5
const EdgeMark := preload("res://tests/lib/city_arena_edge.gd")

var _lines: PackedStringArray = []


func _initialize() -> void:
	QuitGame.release_sims_at_exit(self)
	SaveFile.pinned_seed = 0
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var cfg: Dictionary = Content.tuning()["arena_edge"]
	for tier: int in STAGES:
		for map_seed: int in MAP_SEEDS:
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
			var half := sim.arena_half + Num.f(cfg["out"])
			_lines.append("CASE %d %d %s %s" % [tier, map_seed, _f(sim.arena_half), _f(half)])
			var trees := ArenaEdge.trees_of(decor)
			for tr: Vector2 in trees:
				if absf(maxf(absf(tr.x), absf(tr.y)) - half) < ArenaEdge.BAND + TREE_SLACK:
					_lines.append("TREE %s %s" % [_f(tr.x), _f(tr.y)])
			var plan := CityGen.map(sim.city)
			for road: Array in ArenaEdge._roads(plan, sim.city, half):
				var a: Vector2 = road[0]
				var b: Vector2 = road[1]
				_lines.append(
					"ROAD %s %s %s %s %s" % [_f(a.x), _f(a.y), _f(b.x), _f(b.y), _f(road[2])]
				)
			var sides := {"n": 0, "s": 0, "e": 0, "w": 0}
			for p: Vector3 in ArenaEdge.spots(sim, trees):
				_lines.append("POST %s %s %s" % [_f(p.x), _f(p.y), _f(p.z)])
				var on_x := is_equal_approx(absf(p.x), half)
				var on_z := is_equal_approx(absf(p.z), half)
				if on_z and not on_x:
					sides["s" if p.z > 0.0 else "n"] += 1
				elif on_x and not on_z:
					sides["e" if p.x > 0.0 else "w"] += 1
			_lines.append("SIDE %d %d %d %d" % [sides["n"], sides["s"], sides["e"], sides["w"]])
			var dry := []
			for side: String in ["n", "s", "e", "w"]:
				dry.append(_f(EdgeMark._dry(plan, half, side)))
			_lines.append("DRY %s" % " ".join(dry))
			holder.free()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("arena edge golden: %d lines" % _lines.size())
	quit()


func _f(x: Variant) -> String:
	return "%.9f" % [x]
