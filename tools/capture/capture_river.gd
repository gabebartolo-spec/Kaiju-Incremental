extends SceneTree
## The start of a run (D-083): the kaiju rises from the city's river and steps out, on the game
## camera, at a stage (1 young, 2 Behemoth). Prints the frame it emerged on. Pair with
## --write-movie for the clip. Needs a window: CI, or off-screen with the no-focus override.
## The water's proof (D-325 step 1) takes its stills here: the kaiju wading, at a time of day.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/clip.avi --script tools/capture/capture_river.gd -- --stage=1
##   --time=dusk|night|morning|noon   --graphics=potato|low|medium|high|max (default medium)
##   --stills=1.5,3 (seconds after the rise starts) --out=<dir> --label=<name>: PNG stills
##   --mask  with each still, <label>_tNN_mask.png: the water sheets alone, white on black
##   --tune=section.key=value  (a tuning.json number)   --calm  (no camera shake or dip)
## The rise waits for the city to finish streaming in (the sim held, as capture_one_look), and
## prints "river: rise starts at drawn frame N" so a clip can be trimmed from there.

const Kit := preload("res://tools/capture/capture_kit.gd")
const LEVELS: Array[Dictionary] = [{"claws": 2, "hide": 2}, {"claws": 3, "evolve1": 1}]

var _stage := 1
var _seconds := 4.5
var _time := ""
var _graphics := "medium"
var _stills: Array[float] = []
var _out := "user://river"
var _label := "river"
var _mask := false


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = clampi(arg.substr(8).to_int(), 1, LEVELS.size())
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg.begins_with("--graphics="):
			_graphics = arg.substr(11)
		elif arg.begins_with("--stills="):
			for s: String in arg.substr(9).split(","):
				_stills.append(s.to_float())
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--label="):
			_label = arg.substr(8)
		elif arg == "--mask":
			_mask = true
		elif arg == "--calm":
			PlayerSettings.camera_motion = 0.0
		elif arg.begins_with("--tune="):
			var tv := arg.substr(7).split("=")
			var path := tv[0].split(".")
			var table: Dictionary = Content.section(path[0])
			for i: int in range(1, path.size() - 1):
				table = table[path[i]]
			table[path[path.size() - 1]] = float(tv[1])
	if not _stills.is_empty() and not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	PlayerSettings.graphics = _graphics
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS[_stage - 1])
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0)), 0
	)
	if _time != "":
		Content.set_time(_time)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	rampage.set_physics_process(false)  # held until the city has streamed in
	var stream: BuildingStream = (rampage.get("_city") as CityView).get("_stream")
	while not stream.complete():
		await process_frame
	for _i: int in 10:
		await process_frame
	for child: Node in rampage.get_children():  # the aim wedge is a play aid, not the look
		if child is BreathAim:
			child.set_physics_process(false)
			child.set_process(false)
			(child as BreathAim).visible = false
	rampage.set_physics_process(true)
	print(
		(
			"river: stage %d, size tier %d, rises at %s; rise starts at drawn frame %d"
			% [_stage, rampage.sim.size_tier(), rampage.sim.kaiju_pos, Engine.get_frames_drawn()]
		)
	)
	var last := _seconds
	for at: float in _stills:
		last = maxf(last, at)
	var frames := roundi(last * Engine.physics_ticks_per_second)
	var shots := _stills.duplicate()
	shots.sort()
	var emerged := -1
	DirAccess.make_dir_recursive_absolute(_out)
	for frame: int in frames + 1:
		if not shots.is_empty() and frame >= roundi(shots[0] * Engine.physics_ticks_per_second):
			await _still(rampage, shots.pop_front())
		if frame == frames:
			break
		await physics_frame
		if emerged < 0 and not rampage.sim.emerge.active:
			emerged = frame
			print(
				(
					"river: emerged on physics frame %d (%.2f s), at %s"
					% [frame, float(frame) / Engine.physics_ticks_per_second, rampage.sim.kaiju_pos]
				)
			)
	quit()


## One still at `at` s after the rise starts (the sim held while it is taken); with --mask, the
## same frame again with only the water drawn, white, for the measurements.
func _still(rampage: Rampage, at: float) -> void:
	rampage.set_physics_process(false)
	for _i: int in 4:
		await process_frame
	var name := "%s/%s_t%02d" % [_out, _label, roundi(at * 10.0)]
	root.get_viewport().get_texture().get_image().save_png(name + ".png")
	print(
		(
			"river: still %s.png at %.1f s, kaiju at %s, stand_y %.2f"
			% [name, at, rampage.sim.kaiju_pos, rampage.sim.stand_y]
		)
	)
	if _mask:
		await _save_mask(rampage, name + "_mask.png")
	rampage.set_physics_process(true)


## The water sheets alone (WaterSurface.GROUP) in flat white, everything else that can hide
## them flat black, no sky, fog, glow, far blur, particles or full-screen pass, so a measurement
## knows which pixels are water. Restores everything after.
func _save_mask(rampage: Rampage, path: String) -> void:
	var white := _flat(Color.WHITE)
	var black := _flat(Color.BLACK)
	var kept: Dictionary = {}
	for node: Node in rampage.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		kept[geo] = [geo.material_override, geo.visible]
		geo.material_override = white if geo.is_in_group(WaterSurface.GROUP) else black
		geo.visible = geo.visible and not (geo is GPUParticles3D or geo is CPUParticles3D)
		geo.visible = geo.visible and not _full_screen(geo)
	var plain := Environment.new()
	plain.background_mode = Environment.BG_COLOR
	plain.background_color = Color.BLACK
	var worlds: Dictionary = {}
	for node: Node in rampage.find_children("*", "WorldEnvironment", true, false):
		var we := node as WorldEnvironment
		worlds[we] = [we.environment, we.camera_attributes]
		we.environment = plain
		we.camera_attributes = null
	var cam := root.get_viewport().get_camera_3d()
	var attrs: CameraAttributes = cam.attributes if cam else null
	if cam:
		cam.attributes = null
	for _i: int in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	for geo: GeometryInstance3D in kept:
		geo.material_override = kept[geo][0]
		geo.visible = kept[geo][1]
	for we: WorldEnvironment in worlds:
		we.environment = worlds[we][0]
		we.camera_attributes = worlds[we][1]
	if cam:
		cam.attributes = attrs
	for _i: int in 2:
		await process_frame
	print("river: mask %s" % path)


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.disable_fog = true
	return mat


## A full-screen pass (a quad whose shader writes POSITION: the crease and toon passes).
static func _full_screen(geo: GeometryInstance3D) -> bool:
	var mi := geo as MeshInstance3D
	if mi == null or mi.mesh == null:
		return false
	for i: int in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(i) as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.code.contains("POSITION = vec4"):
			return true
	return false
