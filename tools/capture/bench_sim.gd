extends SceneTree
## The sim alone of bench_heavy's rampage (b2-3): the same autoplay (walk to the nearest standing
## chunk, signature held and fired as Rampage's autoplay does) on a fixed 60 Hz clock, no view and
## no window, so the run is the same every time. Prints each sim step's cost (worst, p99, mean,
## steps over 50 and 100 ms), the worst steps, and a digest of the outcome for determinism checks
## between versions.
##
##   godot --headless --path . --script tools/capture/bench_sim.gd -- --seconds=60

const CYCLE := 90
const HELD := 50

var _seconds := 60.0
var _slow := 50.0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--slow="):
			_slow = arg.substr(7).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var levels := {"claws": 4, "hide": 3, "rage": 3, "quake": 2, "evolve1": 1, "sig_power": 2}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	Content.set_time(Content.time_for_run(2))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 2))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.emerge.start(sim)
	sim.body.use_species(str(species["id"]))
	var dt := 1.0 / 60.0
	var target := Vector2(INF, INF)
	var costs: Array[int] = []
	var worst: Array[Dictionary] = []
	var digest := 0
	var steps := int(_seconds * 60.0)
	for s: int in steps:
		if sim.over:
			break
		if s % 15 == 0 or target.x == INF:
			target = sim.nearest_standing(sim.kaiju_pos)
		var to := target - sim.kaiju_pos
		var move := Vector2.ZERO
		if target.x != INF and not sim.body.stomp_reaches(target):
			move = to.normalized()
		var buttons := RampageSim.ULTIMATE | (RampageSim.HELD if s % CYCLE < HELD else 0)
		var t0 := Time.get_ticks_usec()
		var events := sim.step(dt, move, sim.ability_ready_in <= 0.0, buttons)
		var spent := Time.get_ticks_usec() - t0
		costs.append(spent)
		if spent > _slow * 1000.0:
			var kinds := {}
			for e: Dictionary in events:
				kinds[e["type"]] = Num.i(kinds.get(e["type"], 0)) + 1
			worst.append({"step": s, "ms": spent / 1000.0, "events": kinds})
		for e: Dictionary in events:
			if e["type"] != "cells_promoted":  # when a building is promoted is not an outcome
				digest = hash([digest, str(e["type"])])
	var sorted := costs.duplicate()
	sorted.sort()
	var total := 0
	var over50 := 0
	var over100 := 0
	for c: int in costs:
		total += c
		over50 += int(c > 50000)
		over100 += int(c > 100000)
	print(
		(
			"sim steps %d: mean %.2f ms p99 %.2f ms worst %.1f ms, %d over 50 ms, %d over 100 ms"
			% [
				costs.size(),
				total / 1000.0 / maxi(1, costs.size()),
				sorted[int(sorted.size() * 0.99)] / 1000.0,
				sorted[sorted.size() - 1] / 1000.0,
				over50,
				over100
			]
		)
	)
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ms"] > b["ms"])
	for k: int in mini(10, worst.size()):
		print("  worst ", worst[k])
	var grids := 0
	for n: Variant in sim.carving.grids:
		grids += 1
	print(
		(
			(
				"outcome: chunks %d, carved %d, fallen %d, promoted %d, toppled %d, rubble %.2f,"
				+ " events digest %d, cells digest %d"
			)
			% [
				sim.chunks_destroyed,
				sim.carving.cells_carved,
				sim.carving.cells_fallen,
				grids,
				sim.collapse.toppled,
				sim.rubble,
				digest,
				_cells_digest(sim)
			]
		)
	)
	quit()


func _cells_digest(sim: RampageSim) -> int:
	var keys: Array = sim.carving.grids.keys()
	keys.sort()
	var d := 0
	for n: Variant in keys:
		var g: Carving.Grid = sim.carving.grids[n]
		var cells := g.frame.cells.size() - g.frame.cells.count(0)
		var whole := 0
		for c: int in g.full:
			whole += c
		if cells < whole:  # carved ones
			d = hash([d, n, g.frame.digest()])
	return d
