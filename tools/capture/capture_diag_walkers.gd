extends SceneTree
## A game-camera still of the kaiju standing on the diagonal avenue: the walkers on the pavement
## (never in its carriageway) and the diagonal's parked row (DiagonalParking). Needs a window:
##   tools/capture/ci_capture.sh --resolution=1920x1080 capture_diag_walkers.gd -- --out=<dir>
##     [--t=<m along the diagonal from its anchor>] [--stage=N]

var _out := "user://diag"
var _t := 20.0
var _stage := 1


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--t="):
			_t = arg.substr(4).to_float()
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage := Rampage.new()
	rampage.setup(
		Content.species_def("reptilian"),
		UpgradeTree.run_stats(
			Content.section("kaiju"),
			Content.species_def("reptilian"),
			UpgradeTree.new(Content.upgrades())
		),
		CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0)),
		0
	)
	var plan := CityGen.map(rampage.sim.city)
	var diag: Dictionary = plan["diagonal"]
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	rampage.sim.kaiju_pos = at + dir * _t
	root.add_child(rampage)
	await rampage.wait_loaded()
	for i: int in 90:
		await process_frame
	var street: StreetLife = rampage._city.street
	var parked := 0
	for car: Traffic.Car in street.traffic.cars:
		if car.parked and not car.police:
			parked += 1
	var shot := _out.path_join("diag_walkers_s%d_t%d.png" % [_stage, roundi(_t)])
	root.get_texture().get_image().save_png(shot)
	print("saved ", shot, " kaiju ", rampage.sim.kaiju_pos, " parked on diagonal ", parked)
	quit()
