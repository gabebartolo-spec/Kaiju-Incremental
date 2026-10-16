extends SceneTree
## Captures every look in data/looks.json on one fixed stage for the art-direction review:
## a mid-rampage city shot (the evolved reptilian, three buildings breaking, debris in the air)
## and a line-up of the three species. Needs a window (no --headless) and the untracked
## no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_looks.gd -- --out=<dir>

const SETTLE := 12
const DEBRIS_FRAMES := 9
const STAGE_AT := Vector2(13.5, 31.5)
const CAMERA_OFFSET := Vector3(0, 27, 19)
const LINEUP_SPACING := 13.0

var _out := "user://looks"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for look: Dictionary in Content.looks():
		Content.set_look(str(look["id"]))
		await _city_shot(str(look["id"]))
		await _lineup_shot(str(look["id"]))
	quit()


func _city_shot(id: String) -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(
		Content.upgrades(), {"claws": 1, "hide": 1, "rage": 1, "evolve1": 1}
	)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.kaiju_pos = STAGE_AT
	var stage := Node3D.new()
	var city := CityView.new(sim, Seeds.make("fx", 0))
	stage.add_child(city)
	var colors: Dictionary = species["colors"]
	var kaiju := KaijuModel.new("reptilian", colors)
	var at := Vector3(STAGE_AT.x, 0, STAGE_AT.y)
	kaiju.position = at
	kaiju.scale = Vector3.ONE * sim.body_scale()
	kaiju.rotation.y = 0.5
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 55.0
	stage.add_child(cam)
	cam.position = at + CAMERA_OFFSET * (0.75 + 0.4 * sim.body_scale())
	root.add_child(stage)
	cam.look_at(at + Vector3(0, 3.5 * sim.body_scale(), 0))
	cam.current = true
	await _frames(SETTLE)
	for index: int in _nearest(sim, 4):
		var lost := sim.damage_building(index, sim.buildings[index].layer_hp * 6.0)
		if lost > 0:
			city.layers_destroyed(index, lost, at)
	city.ring(at, sim.stomp_radius(), Color(1, 0.85, 0.6, 0.7), 0.35)
	await _frames(DEBRIS_FRAMES)
	_shot("%s_city" % id)
	stage.queue_free()
	await process_frame


func _lineup_shot(id: String) -> void:
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new({}, Content.tuning(), empty, Seeds.make("army", 0))
	var stage := Node3D.new()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0)))
	var x := -LINEUP_SPACING
	for def: Dictionary in Content.species():
		var colors: Dictionary = def["colors"]
		var kaiju := KaijuModel.new(str(def["id"]), colors)
		kaiju.position = Vector3(x, 0, 0)
		kaiju.rotation.y = PI - 0.55
		stage.add_child(kaiju)
		x += LINEUP_SPACING
	var cam := Camera3D.new()
	cam.fov = 50.0
	stage.add_child(cam)
	cam.position = Vector3(0, 11, 30)
	root.add_child(stage)
	cam.look_at(Vector3(0, 5, 0))
	cam.current = true
	await _frames(SETTLE)
	_shot("%s_lineup" % id)
	stage.queue_free()
	await process_frame


func _nearest(sim: RampageSim, count: int) -> Array[int]:
	var order: Array[int] = []
	for i: int in sim.buildings.size():
		if sim.buildings[i].tier <= sim.size_tier():
			order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var pa := Vector2(sim.buildings[a].x, sim.buildings[a].z)
			var pb := Vector2(sim.buildings[b].x, sim.buildings[b].z)
			return pa.distance_to(sim.kaiju_pos) < pb.distance_to(sim.kaiju_pos)
	)
	return order.slice(0, count)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
