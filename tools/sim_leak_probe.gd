extends SceneTree
## Leak probe for the rampage sim (D-179): plays seeded rampages back to back, as tools/pacing.gd
## does (PacingPlayer), and prints per run the engine's static memory and object count. A sim
## that stays alive after its rampage shows as a climb. After WARMUP runs both must stay flat
## (static memory within MEMORY_SLACK_MB, object count within OBJECT_SLACK, over the rest of the
## runs); exit code 0 when they do, 1 when not. The checksum is over every run's summary, so a
## teardown change that alters a result shows as a different checksum.
##   godot --headless --path . --script tools/sim_leak_probe.gd -- [--runs=20] [--stage=2]
##     [--species=reptilian] [--seed=0] [--steps=0] [--no-dispose]
## --stage: the growth step played (1 young, 2 Behemoth, 3 Colossus); --steps: stop each rampage
## after that many steps (0: play it out); --no-dispose: drop each sim without RampageSim.dispose(),
## as before the teardown existed (the leak, for comparison).

## Runs before the measuring starts (caches fill, the first sim's allocator pages are taken).
const WARMUP := 3
## What the runs after the warm-up may grow by.
const MEMORY_SLACK_MB := 5.0
const OBJECT_SLACK := 100
const MB := 1048576.0

var _runs := 20
var _stage := 2
var _species_id := "reptilian"
var _seed := 0
var _max_steps := 0
var _dispose := true
var _city: Array = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = arg.substr(7).to_int()
		if arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
		if arg.begins_with("--species="):
			_species_id = arg.substr(10)
		if arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
		if arg.begins_with("--steps="):
			_max_steps = arg.substr(8).to_int()
		if arg == "--no-dispose":
			_dispose = false
	var species := Content.species_def(_species_id)
	var stats := _stats(species)
	var tier := Num.i(stats["size"])
	_city = _make_city(stats, tier)
	print("probe: %s, stage %d, %d runs, dispose %s" % [_species_id, tier, _runs, _dispose])
	var statics: Array[float] = []
	var objects: Array[int] = []
	var checksum := 0
	for run: int in _runs:
		var summary := _play(species, stats, run)
		checksum = (checksum * 31 + summary.hash()) % 1000000007
		statics.append(Performance.get_monitor(Performance.MEMORY_STATIC) / MB)
		objects.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		print(
			(
				"run %2d  static %8.1f MB  objects %7d  result %d"
				% [run + 1, statics[run], objects[run], summary.hash()]
			)
		)
	print("checksum %d" % checksum)
	quit(0 if _verdict(statics, objects) else 1)


## Prints the growth after the warm-up and returns true when it is within the slack.
func _verdict(statics: Array[float], objects: Array[int]) -> bool:
	if _runs <= WARMUP + 1:
		print("too few runs to judge (need more than %d)" % [WARMUP + 1])
		return false
	var from := WARMUP
	var mem_peak := statics[from]
	var object_peak := objects[from]
	for i: int in range(from, _runs):
		mem_peak = maxf(mem_peak, statics[i])
		object_peak = maxi(object_peak, objects[i])
	var mem_growth := mem_peak - statics[from]
	var object_growth := object_peak - objects[from]
	var flat := mem_growth <= MEMORY_SLACK_MB and object_growth <= OBJECT_SLACK
	print(
		(
			"runs %d-%d: static +%.1f MB (max %.1f), objects +%d (max %d): %s"
			% [
				from + 1,
				_runs,
				statics[_runs - 1] - statics[from],
				MEMORY_SLACK_MB,
				objects[_runs - 1] - objects[from],
				OBJECT_SLACK,
				"FLAT" if flat else "LEAK"
			]
		)
	)
	return flat


## One rampage, played out and dropped; the sim is freed when this returns. Returns a summary
## of how it went (the result, the steps, where the kaiju ended and its hit points).
func _play(species: Dictionary, stats: Dictionary, run: int) -> String:
	var tuning: Dictionary = _city[0]
	var layout: Array[Dictionary] = _city[1]
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", run + 100000 * _seed))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.body.use_species(_species_id)
	var steps := PacingPlayer.play(sim, Vector2(INF, INF), _max_steps)
	var summary := (
		"%s|%d|%s|%s" % [JSON.stringify(sim.result(), "", true), steps, sim.kaiju_pos, sim.hp]
	)
	if _dispose:
		sim.dispose()
	return summary


## The run stats of a kaiju at growth step `_stage`: the cheapest upgrades bought, as pacing.gd
## buys them, until the body is that big.
func _stats(species: Dictionary) -> Dictionary:
	var tree := UpgradeTree.new(Content.upgrades(), {}, _species_id)
	var rubble := 1000000000
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	while Num.i(stats["size"]) < _stage:
		var best := ""
		for id: String in tree.order:
			if tree.can_buy(id, rubble) and (best == "" or tree.cost(id) < tree.cost(best)):
				best = id
		if best == "":
			break
		rubble -= tree.buy(best, rubble)
		stats = UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	return stats


## [tuning, layout] of the city this growth step faces (pacing.gd's _city, with the hardening).
func _make_city(stats: Dictionary, tier: int) -> Array:
	var tuning := CityGrowth.tuning_for(Content.tuning(), tier)
	var cfg: Dictionary = tuning["city"]
	var layout: Array[Dictionary] = CityGen.generate(Seeds.make("city", 0), cfg)
	tuning = CityGrowth.hardened(
		tuning, Content.tuning(), tier, Num.f(stats.get("stage_growth", 0.0))
	)
	return [tuning, layout]
