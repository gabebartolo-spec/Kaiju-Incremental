extends SceneTree
## Captures every look in data/looks.json on one fixed stage for the art-direction review:
## a mid-rampage city shot (the evolved reptilian, three buildings breaking, debris in the
## air), the same at the city's north edge (what lies past the playable area), a wide view
## over the bay to the far skyline, and a line-up of the three species. Needs a window
## (no --headless) and the untracked no-focus override.cfg. --street: only the default look's
## young shot plus street close-ups (civilians walking, civilians fleeing, a police blockade)
## for the anatomy check. --pan: only the evolved city shot, then the camera slides sideways for
## PAN_FRAMES; --pan=N slides N times as fast (a shimmer check for screen-space passes; record
## with --write-movie --fixed-fps 60).
## --resize: the evolved city shot, then the same view after a window resize, at 150% UI scale,
## and under the evolution reveal (screen-space passes must not stretch or go stale).
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_looks.gd -- --out=<dir> [--street]

const SETTLE := 12
const DEBRIS_FRAMES := 9
const FALL_FRAMES := 240
const STAGE_AT := Vector2(5.0, -8.0)  # a crossing at the edge of the midtown towers
const CAMERA_OFFSET := Vector3(0, 27, 19)
const LINEUP_SPACING := 13.0
const EDGE_AT := Vector2(5.0, -40.0)  # on the north ring avenue, looking out over the edge
const SKYLINE_CAMERA := Vector3(-30, 34, 30)
const SKYLINE_LOOK := Vector3(10, 12, -140)
const EAST_CAMERA := Vector3(30, 34, 10)  # out over the east edge, where the streets fade
const EAST_LOOK := Vector3(180, 0, 40)
const EVOLVED := {"claws": 3, "hide": 3, "rage": 3, "stride": 2, "quake": 2, "evolve1": 1}
const STREET_FRAMES := 3000  # most frames to wait for a police blockade to open fire
const CLOSE := Vector3(1.6, 1.3, 1.6)  # close-up camera offset from its subject
const PAN_FRAMES := 180  # 3 s at 60 fps
const PAN_STEP := Vector3(0.04, 0, 0)  # camera slide per frame (world units)
const RESIZED := Vector2i(1280, 720)
const UI_SCALE := 1.5

var _out := "user://looks"
var _street := false
var _pan := false
var _pan_speed := 1.0
var _resize := false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--street":
			_street = true
		elif arg.begins_with("--pan"):  # --pan or --pan=<speed multiplier>
			_pan = true
			_pan_speed = float(arg.substr(6)) if arg.begins_with("--pan=") else 1.0
		elif arg == "--resize":
			_resize = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _pan or _resize:
		await _city_shot(str(Content.look()["id"]) + "_evolved", EVOLVED)
		quit()
		return
	if _street:
		await _city_shot(str(Content.look()["id"]) + "_young", {})
		await _street_shots()
		quit()
		return
	for look: Dictionary in Content.looks():
		Content.set_look(str(look["id"]))
		await _city_shot(str(look["id"]) + "_young", {})
		await _city_shot(str(look["id"]) + "_evolved", EVOLVED)
		await _city_shot(str(look["id"]) + "_edge", EVOLVED, EDGE_AT)
		await _skyline_shot(str(look["id"]) + "_skyline", SKYLINE_CAMERA, SKYLINE_LOOK)
		await _skyline_shot(str(look["id"]) + "_east", EAST_CAMERA, EAST_LOOK)
		await _lineup_shot(str(look["id"]))
	quit()


func _city_shot(id: String, levels: Dictionary, stage_at: Vector2 = STAGE_AT) -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.kaiju_pos = stage_at
	var stage := Node3D.new()
	var city := CityView.new(sim, Seeds.make("fx", 0))
	stage.add_child(city)
	var colors: Dictionary = species["colors"]
	var kaiju := KaijuModel.new("reptilian", colors)
	var at := Vector3(stage_at.x, 0, stage_at.y)
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
		city.crush(tank.position, 1.6)
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
	if _pan:
		for _f: int in PAN_FRAMES:
			cam.position += PAN_STEP * _pan_speed
			await process_frame
	if _resize:
		await _resize_shots(id)
	stage.queue_free()
	await process_frame


## A wide establishing view from `from` toward `look_at`: north over the towers to the bay
## and the far skyline, or east to where the streets fade into the fog.
func _skyline_shot(id: String, from: Vector3, look_at: Vector3) -> void:
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := RampageSim.new({}, Content.tuning(), layout, Seeds.make("army", 0))
	var stage := Node3D.new()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0)))
	var cam := Camera3D.new()
	cam.fov = 55.0
	stage.add_child(cam)
	cam.position = from
	root.add_child(stage)
	cam.look_at(look_at)
	cam.current = true
	await _frames(SETTLE)
	_shot(id)
	print("perf ", id, " ", await _measure(), " voxels ", _count_voxels(stage))
	stage.queue_free()
	await process_frame


## Close-ups of street life: a calm walker, a fleeing civilian and a police blockade.
func _street_shots() -> void:
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.kaiju_pos = STAGE_AT
	var stage := Node3D.new()
	var city := CityView.new(sim, Seeds.make("fx", 0))
	stage.add_child(city)
	var colors: Dictionary = species["colors"]
	var kaiju := KaijuModel.new("reptilian", colors)
	kaiju.position = Vector3(STAGE_AT.x, 0, STAGE_AT.y)
	kaiju.scale = Vector3.ONE * sim.body_scale()
	stage.add_child(kaiju)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	root.add_child(stage)
	cam.current = true
	var street := city.street
	var waited := 0
	while street.police.shots < 4 and waited < STREET_FRAMES:  # officers at posts, firing
		await process_frame
		waited += 1
	var calm := Vector2(INF, INF)
	var fleeing := Vector2(INF, INF)
	for i: int in street.pos.size():
		if street.cop[i] == 1:
			continue
		var at := street.pos[i]
		if street.fleeing[i] == 1 and fleeing.x == INF:
			fleeing = at
		elif street.fleeing[i] == 0 and calm.x == INF and at.distance_to(sim.kaiju_pos) > 40.0:
			calm = at
	var cruisers := Vector2.ZERO
	var count := 0
	for car: Traffic.Car in street.traffic.cars:
		if car.police and not car.crushed:
			cruisers += car.pos
			count += 1
	var subjects := {"street_walkers": calm, "street_fleeing": fleeing}
	if count > 0:
		subjects["street_blockade"] = cruisers / count
	for shot_name: String in subjects:
		var at: Vector2 = subjects[shot_name]
		if at.x == INF:
			print("no subject for ", shot_name)
			continue
		var target := Vector3(at.x, 0.35, at.y)
		var offset := CLOSE * (2.2 if shot_name == "street_blockade" else 1.0)
		cam.position = target + offset
		cam.look_at(target)
		await _frames(3)
		_shot(shot_name)
	print(
		(
			"street: civilians %d cars %d fled %d blockades %d shots %d"
			% [
				street.civilians(),
				street.traffic.cars.size(),
				street.fled,
				street.police.blockades_made,
				street.police.shots
			]
		)
	)
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


## The same view after a window resize, at a larger UI scale, and under the evolution reveal.
func _resize_shots(id: String) -> void:
	var full := root.size
	root.size = RESIZED
	await _frames(SETTLE)
	_shot("%s_resized" % id)
	root.size = full
	root.content_scale_factor = UI_SCALE
	await _frames(SETTLE)
	_shot("%s_uiscale" % id)
	root.content_scale_factor = 1.0
	var species := Content.species_def("reptilian")
	var kaiju := Content.section("kaiju")
	var before := UpgradeTree.run_stats(kaiju, species, UpgradeTree.new(Content.upgrades(), {}))
	var after := UpgradeTree.run_stats(kaiju, species, UpgradeTree.new(Content.upgrades(), EVOLVED))
	var reveal := EvolutionReveal.new()
	var city: Dictionary = CityGrowth.for_stats(after)["city"]
	reveal.setup(species, before, after, city)
	root.add_child(reveal)
	await _frames(EvolutionReveal.SWAP_FRAME + SETTLE)
	_shot("%s_reveal" % id)
	reveal.queue_free()


func _shot(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
