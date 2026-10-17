extends SceneTree
## Captures the rooftop defenders (D-063) at the game camera: a Behemoth croc stands in the
## Behemoth city within rifle range of the roofs most squads hold, and they fire on it. Stills
## after volleys, plus rooftops.json with each still's squad screen spots (for the 2x crop).
## Pair with --write-movie (ci_capture.sh --movie) for the clip. Needs a window and the
## no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_rooftops.gd -- --out=<dir> [--seed=0]

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FRAMES := 60 * 4
const SETTLE := 45  # frames for the camera to settle before stills count
const MAX_STILLS := 4
const LEVELS := {"claws": 3, "hide": 5, "rage": 3, "evolve1": 1}
## Where the kaiju stands from the chosen squad (south-east, so the squad is up-left of it on
## screen and not behind its body), as a share of the rifle range.
const STAND := Vector2(0.45, 0.4)

var _out := "user://rooftops"
var _seed := 0
var _stills: Array[Dictionary] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(
		Content.tuning(), Num.i(stats["size"]), Seeds.make("city", _seed)
	)
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, _seed)
	var sim := rampage.sim
	var squad := _busiest(sim)
	var reach := Num.f(sim.army["rooftop"]["range"])
	sim.kaiju_pos = sim.clamp_to_arena(squad.pos + STAND * reach)
	sim.facing = (squad.pos - sim.kaiju_pos).normalized()
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	root.add_child(rampage)
	var roofs: RooftopView = GuiInput.find_script(rampage, RooftopView)
	var camera := root.get_viewport().get_camera_3d()
	var shots := 0
	for i: int in FRAMES:
		await physics_frame
		if i < SETTLE or _stills.size() >= MAX_STILLS:
			continue
		if roofs.shots > shots:
			shots = roofs.shots
			await process_frame  # the flash and tracer drawn
			_still(rampage, roofs, camera, i)
	var file := FileAccess.open(_out.path_join("rooftops.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"stills": _stills, "squad": squad.id}, "  "))
	file.close()
	print(
		(
			"rooftops: %d squads, %d volleys drawn, %d stills"
			% [sim.army_units.squads.size(), roofs.shots, _stills.size()]
		)
	)
	quit()


## The squad with the most others within rifle range of it.
func _busiest(sim: RampageSim) -> Army.Squad:
	var reach := Num.f(sim.army["rooftop"]["range"])
	var best: Army.Squad = sim.army_units.squads[0]
	var best_n := -1
	for a: Army.Squad in sim.army_units.squads:
		var n := 0
		for b: Army.Squad in sim.army_units.squads:
			n += 1 if a.pos.distance_to(b.pos) < reach * 0.8 else 0
		if n > best_n:
			best_n = n
			best = a
	return best


func _still(rampage: Rampage, roofs: RooftopView, camera: Camera3D, frame: int) -> void:
	var name := "rooftops_%04d.png" % frame
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(name))
	var spots: Array[Dictionary] = []
	for squad: Army.Squad in rampage.sim.army_units.squads:
		var feet := roofs.stance(squad, 1).origin
		if camera.is_position_behind(feet):
			continue
		var at := camera.unproject_position(feet + Vector3(0, 0.4, 0))
		spots.append({"squad": squad.id, "x": roundi(at.x), "y": roundi(at.y)})
	_stills.append({"file": name, "frame": frame, "spots": spots})
