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
const FALL_FRAMES := 240
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
		await _city_shot(str(look["id"]) + "_young", {})
		await _city_shot(
			str(look["id"]) + "_evolved",
			{"claws": 3, "hide": 3, "rage": 3, "stride": 2, "quake": 2, "evolve1": 1}
		)
		await _lineup_shot(str(look["id"]))
	quit()


func _city_shot(id: String, levels: Dictionary) -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels)
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
	var nearest := _nearest(sim, 4)
	for n: int in nearest.size():  # two flattened, two with holes bitten into the near wall
		var index := nearest[n]
		var b := sim.buildings[index]
		var cells: Array[Vector3i] = []
		if n < 2:
			for y: int in b.height:
				for x: int in b.w:
					for z: int in b.d:
						cells.append(Vector3i(x, y, z))
		else:
			for y: int in range(maxi(1, b.height - 5), b.height):
				var step := b.height - y  # a stepped notch: wider the higher it goes
				for x: int in range(0, mini(b.w, 1 + (5 - step))):
					for z: int in range(maxi(0, b.d - 1 - (5 - step) / 2), b.d):
						cells.append(Vector3i(x, y, z))
		sim.damage_chunks(index, cells, 9999.0)
	_route(sim, city, at)
	for t: int in 2:  # tanks closing in, one firing
		var tank := TankModel.new()
		tank.position = at + Vector3(-7.0 + t * 12.0, 0, 9.0 - t * 3.0)
		stage.add_child(tank)
		tank.look_at_from_position(tank.position, at, Vector3.UP, true)
	city.flash(at + Vector3(-7.0, 1.0, 9.0), Color("ffc070"), 4.0, 0.4)
	for _f: int in FALL_FRAMES:  # let the undermined towers topple and land
		_send(sim.step(1.0 / 60.0, Vector2.ZERO, false), city, at)
		await process_frame
	city.ring(at, sim.stomp_radius(), Color(1, 0.85, 0.6, 0.7), 0.35)
	await _frames(DEBRIS_FRAMES)
	_shot("%s_city" % id)
	var floating := 0
	var lifted := 0
	for node: Node in stage.find_children("*", "RigidBody3D", true, false):
		var body: RigidBody3D = node
		if body.global_position.y > 2.0:
			floating += 1
	for node: Node in city.get_children():
		if node.has_meta("parts"):
			lifted += 1
	print("debris above 2u: ", floating, " pieces still lifted: ", lifted)
	print("perf ", id, " ", await _measure(), " voxels ", _count_voxels(stage))
	stage.queue_free()
	await process_frame


func _lineup_shot(id: String) -> void:
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new({}, Content.tuning(), empty, Seeds.make("army", 0))
	var stage := Node3D.new()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0), false))
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
	print("perf lineup ", await _measure())
	stage.queue_free()
	await process_frame


## Sends the sim's pending events to the city view (what Rampage does each frame).
func _route(sim: RampageSim, city: CityView, at: Vector3) -> void:
	_send(sim.events.duplicate(), city, at)


func _send(events: Array[Dictionary], city: CityView, at: Vector3) -> void:
	for event: Dictionary in events:
		match str(event["type"]):
			"chunks_broken":
				var cells: Array[Vector3i] = event["cells"]
				city.chunks_broken(Num.i(event["building"]), cells, at)
			"fall_start":
				city.fall_start(event)
			"fall_land":
				city.fall_land(event)


func _nearest(sim: RampageSim, count: int) -> Array[int]:
	var order: Array[int] = []
	for i: int in sim.buildings.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var pa := Vector2(sim.buildings[a].x, sim.buildings[a].z)
			var pb := Vector2(sim.buildings[b].x, sim.buildings[b].z)
			return pa.distance_to(sim.kaiju_pos) < pb.distance_to(sim.kaiju_pos)
	)
	return order.slice(0, count)


## Average GPU and CPU frame time (ms) over 60 frames, from the engine's own timers, plus the
## triangles drawn: independent of window focus or vsync.
func _measure() -> String:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _frames(20)
	var gpu := 0.0
	var cpu := 0.0
	for _i: int in 60:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var tris := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
	)
	return "gpu %.1fms cpu %.1fms tris %dk" % [gpu / 60.0, cpu / 60.0, tris / 1000]


func _count_voxels(stage: Node) -> int:
	var instances := 0
	for node: Node in stage.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi: MultiMeshInstance3D = node
		instances += mmi.multimesh.instance_count
	return instances


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
