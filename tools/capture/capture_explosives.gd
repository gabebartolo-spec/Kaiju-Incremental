extends SceneTree
## The red barrels going off (director comments #19, #20): a seeded day rampage (city seed 0, the
## reptilian standing still once it has risen from the river) with a short chain of hazard sites
## tagged on the low buildings in front of the game camera and off to one side of the kaiju, so
## its body never covers them (fuel silo, fireworks factory, chem lab, fuel silo, each within the
## last one's blast), the first armed as a shell would arm it. It prints "film from frame N": the
## movie's frames before N are the rise from the river (the camera inside a facade); cut there.
## --view=game films from the game camera, --view=close from a camera near the chain,
## --view=models takes stills of the three models before anything blows. Stills (--stills=a,b,..
## seconds after the arming) go to --out; record a clip with Godot's --write-movie. --perf prints
## the worst frame time while the chain plays and BlastFx's own cost per event.
##
##   godot --path . --resolution 1920x1080 --fixed-fps 30 --write-movie <dir>/f.png \
##     --script tools/capture/capture_explosives.gd -- --view=game --seconds=9 --out=<dir>
##   godot --path . --resolution 1920x1080 --script tools/capture/capture_explosives.gd -- --perf

const KINDS: Array[String] = ["fuel_silo", "fireworks_factory", "chem_lab", "fuel_silo"]
const STEP := 1.0 / 30.0
const SIDE := 9.0  # the first site sits at least this far to the kaiju's side (units)
const SMALL_HALF := 60.0  # --city=small keeps only the buildings this close to the centre

var _view := "game"
var _out := "user://explosives"
var _seconds := 9.0
var _perf := false
var _stills: Array[float] = []
var _time := "day"
var _arm := true
var _small := false  # --city=small: a cropped city, so a CI software render finishes in time
var _side := Vector2.ZERO  # the side of the kaiju the chain is on (unit, ground plane)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			_view = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg == "--no-arm":  # the same run with nothing set off: the frame-time baseline
			_arm = false
		elif arg == "--city=small":
			_small = true
		elif arg == "--perf":
			_perf = true
		elif arg.begins_with("--stills="):
			for s: String in arg.substr(9).split(","):
				_stills.append(s.to_float())
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	Content.set_time(_time)
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	if _small:
		var near := layout.filter(
			func(e: Dictionary) -> bool:
				return absf(Num.f(e["x"])) <= SMALL_HALF and absf(Num.f(e["z"])) <= SMALL_HALF
		)
		layout.assign(near)
		print("small city: %d buildings" % layout.size())
	var chain := _pick_chain(stats, layout)
	for k: int in chain.size():
		layout[chain[k]]["hazard"] = KINDS[k]
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, Content.times().find(_time))
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await physics_frame
	while rampage.sim.emerge.active:
		await physics_frame
	for _i: int in 20:  # the camera settles
		await physics_frame
	var centre := Vector3.ZERO
	for i: int in chain:
		var b := rampage.sim.buildings[i]
		centre += Vector3(b.x, 0.0, b.z) / chain.size()
	print("chain: ", chain.map(func(i: int) -> String: return _describe(rampage.sim, i)))
	if _view != "game":
		_close_camera(rampage, centre)
	if _view == "models":
		for i: int in chain.slice(0, 3):
			await _model_still(rampage, i)
		quit()
		return
	if _arm:
		rampage.sim.explosives.damaged(chain[0])
	rampage.cost_usec.clear()
	await _film(rampage)
	quit()


## Low buildings in front of the game camera, each within reach of the one before.
func _pick_chain(stats: Dictionary, layout: Array[Dictionary]) -> Array[int]:
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.emerge.start(sim)
	var guard := 0
	while sim.emerge.active and guard < 2000:
		sim.step(STEP, Vector2.ZERO, false)
		guard += 1
	var rest := CameraTuning.offset()
	var ahead := -Vector2(rest.x, rest.z).normalized()
	var at := sim.kaiju_pos
	var chain: Array[int] = []
	var side := Vector2(-ahead.y, ahead.x)
	var last := at + ahead * 14.0 + side * 12.0
	for _k: int in KINDS.size():
		var best := -1
		var best_d := INF
		for i: int in sim.buildings.size():
			var b := sim.buildings[i]
			var p := Vector2(b.x, b.z)
			var reach := 3.0 if chain.is_empty() else 7.0
			if b.landmark != "" or b.height > 10 or chain.has(i) or b.w * b.d < 4:
				continue
			if (p - at).dot(ahead) < 4.0 or p.distance_to(at) > 40.0:
				continue
			if (p - at).dot(side) < (SIDE if chain.is_empty() else SIDE * 0.6):
				continue
			var d := p.distance_to(last)
			if d < best_d and d >= reach:
				best = i
				best_d = d
		if best < 0:
			break
		chain.append(best)
		last = Vector2(sim.buildings[best].x, sim.buildings[best].z)
	_side = side
	return chain


func _describe(sim: RampageSim, i: int) -> String:
	var b := sim.buildings[i]
	return "%d %s at (%.1f, %.1f) %dx%dx%d" % [i, b.hazard, b.x, b.z, b.w, b.d, b.height]


func _close_camera(rampage: Rampage, centre: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 50.0
	rampage.add_child(cam)
	var back := CameraTuning.offset()
	back.y = 0.0
	var side := Vector3(_side.x, 0.0, _side.y)  # further out on the chain's side: the kaiju is off it
	cam.position = centre + back.normalized() * 24.0 + side * 12.0 + Vector3(0.0, 12.0, 0.0)
	cam.look_at(centre + Vector3(0, 2.5, 0))
	cam.current = true


## A still of one site from a camera 3/4 above it, close enough to judge the model.
func _model_still(rampage: Rampage, i: int) -> void:
	var b := rampage.sim.buildings[i]
	var cam := get_root().get_viewport().get_camera_3d()
	var span := maxf(maxf(b.w, b.d), b.height)
	var at := Vector3(b.x, b.height * 0.5, b.z)
	var away := (
		Vector3(b.x - rampage.sim.kaiju_pos.x, 0.0, b.z - rampage.sim.kaiju_pos.y).normalized()
	)
	# From the side, so the line to the kaiju never crosses the site (BuildingFade would thin it).
	cam.position = at + (away.cross(Vector3.UP) * 1.5 + away * 0.3 + Vector3(0, 1.9, 0)) * span
	for node: Node in rampage.get_children():
		if node is KaijuModel or node is BreathAim:
			(node as Node3D).visible = false
	cam.look_at(at)
	for _f: int in 6:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/model_%s.png" % [_out, b.hazard]
	image.save_png(path)
	print("saved ", path)


func _film(rampage: Rampage) -> void:
	var fx := rampage.get_children().filter(func(n: Node) -> bool: return n is BlastFx)
	var start := Time.get_ticks_usec()
	var last := start
	var worst := 0.0
	var worst_at := 0.0
	var frames := 0
	var t := 0.0
	var next_still := 0
	print("film from frame ", Engine.get_frames_drawn())
	while t < _seconds:
		await process_frame
		frames += 1
		t += STEP if not _perf else 0.0
		var now := Time.get_ticks_usec()
		if _perf:
			t = (now - start) / 1e6
			var ms := (now - last) / 1000.0
			if ms > worst:
				worst = ms
				worst_at = t
		last = now
		if next_still < _stills.size() and t >= _stills[next_still]:
			var path := "%s/%s_t%04.1f.png" % [_out, _view, _stills[next_still]]
			root.get_viewport().get_texture().get_image().save_png(path)
			print("saved ", path)
			next_still += 1
	if _perf:
		print("frames %d over %.1f s, worst frame %.1f ms at %.2f s" % [frames, t, worst, worst_at])
		var costs := {}
		for kind: String in rampage.cost_usec:
			costs[kind] = "%.2f ms" % (Num.f(rampage.cost_usec.get(kind, 0)) / 1000.0)
		print("worst cost per sim step / event kind: ", costs)
	if not fx.is_empty():
		var blasts: BlastFx = fx[0]
		print("drawn: ", blasts.drawn, " kick frames: ", blasts.kicked, " peak: ", blasts.kick_peak)
