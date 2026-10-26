extends SceneTree
## Records the clumsy military (StrayShell, director comments #18) in a real rampage at the game
## camera: a stage-2 kaiju walks a few steps in from the river (where it rose, the camera sits
## inside a tower and sees black: R 19.4), then stands; the tanks take their posts and fire, and
## the shells that miss fly on into the city behind it and break what they hit. Prints every
## miss (frame, where it landed) and the totals at the end. Pair with --write-movie for the clip.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 --write-movie <out.avi> \
##     --script tools/capture/capture_strays.gd -- --seconds=40 [--seed=0] [--walk=3] [--closer=0.6]

const LEVELS := {"evolve1": 1}  # the stage-2 body: the military suite's tier 2
const TIER := 2

var _seconds := 40.0
var _seed := 0
var _walk := 3.0  # seconds it walks in from the river before it stands
var _closer := 0.6  # the camera's rest offset x this (the game's is 1.0): tanks and impacts read
var _frame := 0
var _walked := 0.0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
		elif arg.begins_with("--walk="):
			_walk = float(arg.substr(7))
		elif arg.begins_with("--closer="):
			_closer = float(arg.substr(9))
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
	rampage.camera_rest = rampage.camera_rest * _closer
	var aim := rampage.get_node_or_null("BreathAim")  # the breath-aim wedge is not part of this shot
	if aim != null:
		aim.queue_free()
	var shots := 0
	var misses := 0
	var frames := roundi(_seconds * Engine.physics_ticks_per_second)
	var hp := INF
	for i: int in frames:
		await physics_frame
		_frame = i
		if rampage.sim == null:
			continue
		if rampage.sim.hp < hp - 0.001 and hp != INF:  # what hurt the kaiju (the HUD readout)
			var kinds: Array[String] = []
			for e: Dictionary in rampage.sim.events:
				kinds.append(str(e["type"]) + (" miss" if e.get("miss", false) else ""))
			print("HP frame %d %.2f -> %.2f events %s" % [i, hp, rampage.sim.hp, kinds])
		hp = rampage.sim.hp
		var cells := 0
		var landed := false
		for e: Dictionary in rampage.sim.events:
			if str(e["type"]) == "chunks_broken":
				var broken: Array = e["cells"]
				cells += broken.size()
			elif str(e["type"]) == "cells_carved":
				var removed: PackedInt32Array = e["index"]
				cells += removed.size()
			elif str(e["type"]) == "stray_landed":
				landed = true
		if cells > 0 or landed:
			print("CHUNKS frame %d stray_landed %s broke %d chunks" % [i, landed, cells])
		for e: Dictionary in rampage.sim.events:
			if str(e["type"]) != "tank_fired" or (e.has("at") and not e.get("miss", false)):
				continue
			shots += 1
			if e.get("miss", false):
				misses += 1
				var at: Vector2 = e["at"]
				var eye := root.get_viewport().get_camera_3d()
				var px := (
					eye.unproject_position(Vector3(at.x, 0.0, at.y))
					if eye != null
					else Vector2.ZERO
				)
				print(
					(
						"MISS frame %d lands at %v (kaiju %v), on screen %v"
						% [i, at, rampage.sim.kaiju_pos, px.round()]
					)
				)
	var killed := 0
	if rampage._city.street != null:
		killed = rampage._city.street.toll.killed
	print("STRAYS %d of %d shots missed; %d civilians killed by the army" % [misses, shots, killed])
	quit()


## Walk in from the river for _walk seconds, then stand: the tanks come to it.
func _input(sim: RampageSim) -> Dictionary:
	if sim.emerge.active or _walked >= _walk:
		return {"move": Vector2.ZERO}
	_walked += 1.0 / Engine.physics_ticks_per_second
	return {"move": Vector2(0.0, -1.0)}
