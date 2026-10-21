extends SceneTree
## Records the clumsy military (StrayShell, director comments #18) in a real rampage at the game
## camera: a stage-2 kaiju walks a few steps in from the river (where it rose, the camera sits
## inside a tower and sees black: R 19.4), then stands; the tanks take their posts and fire, and
## the shells that miss fly on into the city behind it and break what they hit. Prints every
## miss (frame, where it landed) and the totals at the end. Pair with --write-movie for the clip.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 --write-movie <out.avi> \
##     --script tools/capture/capture_strays.gd -- --seconds=40 [--seed=0] [--walk=3]

const LEVELS := {"evolve1": 1}  # the stage-2 body: the military suite's tier 2
const TIER := 2

var _seconds := 40.0
var _seed := 0
var _walk := 3.0  # seconds it walks in from the river before it stands
var _frame := 0
var _walked := 0.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
		elif arg.begins_with("--walk="):
			_walk = float(arg.substr(7))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(Content.tuning(), TIER, Seeds.make("city", _seed))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, _seed)
	rampage.scripted = _input
	root.add_child(rampage)
	await physics_frame
	var shots := 0
	var misses := 0
	var frames := roundi(_seconds * Engine.physics_ticks_per_second)
	for i: int in frames:
		await physics_frame
		_frame = i
		if rampage.sim == null:
			continue
		for e: Dictionary in rampage.sim.events:
			if str(e["type"]) != "tank_fired" or (e.has("at") and not e.get("miss", false)):
				continue
			shots += 1
			if e.get("miss", false):
				misses += 1
				print("MISS frame %d lands at %v" % [i, e["at"]])
	var killed := 0
	if rampage._city.street != null:
		killed = rampage._city.street.army_killed
	print("STRAYS %d of %d shots missed; %d civilians killed by the army" % [misses, shots, killed])
	quit()


## Walk in from the river for _walk seconds, then stand: the tanks come to it.
func _input(sim: RampageSim) -> Dictionary:
	if sim.emerge.active or _walked >= _walk:
		return {"move": Vector2.ZERO}
	_walked += 1.0 / Engine.physics_ticks_per_second
	return {"move": Vector2(0.0, -1.0)}
