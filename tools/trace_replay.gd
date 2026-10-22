extends SceneTree
## Replay-trace hash for refactors of sim code that must not change behaviour: seeded scripted
## runs at growth stages 1-4 (all three species), every tick's state and events folded into one
## SHA-256 per run, plus a hash of the generated city layouts. Two checkouts that print the same
## lines behave the same (same RNG draws, same floats). No clock; every stream is Seeds.make.
##   godot --headless --path . --script tools/trace_replay.gd -- [--seeds=2] [--max-steps=2500]
##     [--no-native] [--tier=k] [--species=id]

const DT := 1.0 / 15.0

var _seeds := 2
var _max_steps := 2500
var _only_tier := 0
var _only_species := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = arg.substr(8).to_int()
		if arg.begins_with("--max-steps="):
			_max_steps = arg.substr(12).to_int()
		if arg.begins_with("--tier="):
			_only_tier = arg.substr(7).to_int()
		if arg.begins_with("--species="):
			_only_species = arg.substr(10)
		if arg == "--no-native":
			VoxelSupport.use_native = false
	print("native: ", VoxelSupport.native() != null)
	_layouts()
	for tier in range(1, 5):
		if _only_tier != 0 and tier != _only_tier:
			continue
		for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
			if _only_species != "" and species_id != _only_species:
				continue
			for seed_k in _seeds:
				_run(tier, species_id, seed_k)
	quit()


func _layouts() -> void:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for tier in range(0, 5):
		var tuning := CityGrowth.tuning_for(Content.tuning(), tier)
		var cfg: Dictionary = tuning["city"]
		for seed_k in 6:
			var layout := CityGen.generate(Seeds.make("city", seed_k), cfg)
			ctx.update(var_to_bytes(layout))
			ctx.update(var_to_bytes(CityGen.map(cfg)))
	print("layouts ", ctx.finish().hex_encode())


func _run(tier: int, species_id: String, seed_k: int) -> void:
	var species := Content.species_def(species_id)
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {}, species_id)
	)
	stats["size"] = tier
	stats["stage_growth"] = 0.0
	var tuning := CityGrowth.tuning_for_stats(Content.tuning(), stats)
	var cfg: Dictionary = tuning["city"]
	var layout := CityGen.generate(Seeds.make("city", seed_k), cfg)
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 1000 + seed_k))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.body.use_species(species_id)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var steps := 0
	var falls_seen := 0
	var target := Vector2(INF, INF)
	while not sim.over and steps < _max_steps:
		if steps % 8 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
			move = (target - sim.kaiju_pos).normalized()
		var held := RampageSim.HELD if steps % 30 < 15 else 0
		var evs := sim.step(
			DT, move, sim.ability_ready_in <= 0.0, held | RampageSim.ULTIMATE | Dash.BUTTON
		)
		ctx.update(_state(sim, evs))
		falls_seen += sim.falls.size()
		steps += 1
	var res := sim.result()
	ctx.update(var_to_bytes(res))
	print(
		(
			"t%d %s s%d steps=%d rubble=%s destr=%s falls=%d %s %s"
			% [
				tier,
				species_id,
				seed_k,
				steps,
				str(res["rubble"]),
				str(res["destruction"]),
				falls_seen,
				sim.end_reason,
				ctx.finish().hex_encode().substr(0, 20),
			]
		)
	)


func _state(sim: RampageSim, evs: Array[Dictionary]) -> PackedByteArray:
	var s: Array = [sim.kaiju_pos, sim.facing, sim.hp, sim.rubble, sim.chunks_destroyed]
	s.append(sim.tanks_destroyed)
	s.append(sim.stand_y)
	for b: RampageSim.Building in sim.buildings:
		s.append(b.frame.alive_count)
	for t: RampageSim.Tank in sim.tanks:
		s.append([t.id, t.pos, t.hp])
	for f: RampageSim.Fall in sim.falls:
		s.append([f.id, f.building, f.kind, f.t, f.cells.size(), f.pivot, f.dir])
	s.append(evs)
	return var_to_bytes(s)
