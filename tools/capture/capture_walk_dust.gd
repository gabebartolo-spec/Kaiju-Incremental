extends SceneTree
## Stills of an autoplayed croc walk at the game camera, for the footfall dust (greenery review,
## 2026-10-18): saves walk_<seconds>s.png at each --at time and prints how many dust particles
## are in the air there. "--before" replays the old look on the same seed: every footfall threw
## the collapse cloud (Fx.dust) instead of the footfall puff. "--behemoth" walks the evolved
## croc (bigger feet, bigger dust). Each still also saves a crop around the kaiju. Needs a window.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_walk_dust.gd -- --out=<dir> [--before] [--behemoth] [--at=6,9]

var _out := "user://walk_dust"
var _before := false
var _levels := {}
var _at: Array[float] = [6.0, 9.0, 12.0]


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--before":
			_before = true
		elif arg == "--behemoth":
			_levels = {"claws": 3, "hide": 1, "evolve1": 1}
		elif arg.begins_with("--at="):
			_at.clear()
			for t: String in arg.substr(5).split(","):
				_at.append(float(t))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), _levels)
	)
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await process_frame
	var fx: Fx = rampage._city.fx
	if _before:
		fx._step_cfg = fx._step_cfg.duplicate()
		fx._step_cfg["max_live"] = 0  # no footfall puffs: the old cloud below instead
		rampage._kaiju.foot_planted.connect(
			func(_side: String, strength: float, at: Vector3) -> void:
				var size := rampage.sim.body_scale() * (0.2 + strength)
				fx.dust(at + Vector3(0, 0.2, 0), Rampage.FOOTFALL_DUST * size)
		)
	var frame := 0
	for t: float in _at:
		while frame < roundi(t * 60.0):
			await process_frame
			frame += 1
		await RenderingServer.frame_post_draw
		var name := "walk_%02ds%s.png" % [roundi(t), "_before" if _before else ""]
		var shot := root.get_viewport().get_texture().get_image()
		shot.save_png(_out.path_join(name))
		var cam := root.get_viewport().get_camera_3d()
		var at := cam.unproject_position(rampage._kaiju.global_position)
		var box := Rect2i(Vector2i(at) - Vector2i(400, 225), Vector2i(800, 450))
		box.position = box.position.clamp(Vector2i.ZERO, shot.get_size() - box.size)
		shot.get_region(box).save_png(_out.path_join(name.replace(".png", "_crop.png")))
		print("%s: %d effect particles in the air" % [name, _particles(fx)])
	quit()


func _particles(fx: Fx) -> int:
	var total := 0
	for child: Node in fx.get_children():
		if child is GPUParticles3D:
			total += (child as GPUParticles3D).amount
	return total
