extends SceneTree
## His death from the game camera (DeathOverload, director 2026-10-26): a seeded day rampage (city
## seed 0) with the croc at --stage (baby, adolescent, adult; default adult) and --nodes Death
## Blast nodes (0-3, the stat set directly). He rises, walks --walk seconds into the city, then dies
## (killed); the movie runs --seconds past that. It prints "film from frame N": the movie's frames
## before N are the rise and the walk; cut there. Record with Godot's --write-movie:
##
##   godot --path . --windowed --resolution 3840x2160 --fixed-fps 30 --write-movie <dir>/death.avi \
##     --script tools/capture/capture_death.gd -- --nodes=3 --seconds=6.5

const STAGES := {
	"baby": {},
	"adolescent": {"claws": 1, "hide": 1, "rage": 1, "evolve1": 1},
	"adult":
	{
		"claws": 1,
		"hide": 1,
		"rage": 1,
		"evolve1": 1,
		"sig_power": 1,
		"tail": 1,
		"titan_hide": 1,
		"evolve2": 1,
	},
}
## Seconds of the walk filmed before he dies, so the clip opens on him alive.
const LEAD_IN := 0.5

var _nodes := 0
var _stage := "adult"
var _walk := 2.5
var _seconds := 6.5
var _time := "noon"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--nodes="):
			_nodes = clampi(arg.substr(8).to_int(), 0, 3)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--walk="):
			_walk = arg.substr(7).to_float()
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Content.set_time(_time)
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), STAGES.get(_stage, {}), "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["death_blast"] = _nodes
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, Content.times().find(_time))
	var walking := [true]
	rampage.scripted = func(_sim: RampageSim) -> Dictionary:
		return {"move": Vector2(0, -1) if walking[0] else Vector2.ZERO}
	root.add_child(rampage)
	await physics_frame
	var sim := rampage.sim
	sim.time_left = 1.0e9
	while sim.emerge.active:
		sim.hp = sim.max_hp
		await physics_frame
	var walked := 0.0
	while walked < _walk:
		sim.hp = sim.max_hp
		walked += 1.0 / Engine.physics_ticks_per_second
		await physics_frame
	var lead := roundi(LEAD_IN * Engine.max_fps) if Engine.max_fps > 0 else 15
	print("film from frame %d" % maxi(0, Engine.get_frames_drawn() - lead))
	walking[0] = false
	sim.hp = -sim.max_hp
	var t := 0.0
	while t < _seconds:
		t += 1.0 / Engine.physics_ticks_per_second
		await physics_frame
	print(
		(
			"died: nodes %d, blast %.1f, shards %d, chunks shards %d blast %d, over %s (%s)"
			% [
				_nodes,
				sim.death.blast_radius,
				sim.death.shards.size(),
				sim.death.shard_chunks,
				sim.death.blast_chunks,
				sim.over,
				sim.end_reason,
			]
		)
	)
	quit()
