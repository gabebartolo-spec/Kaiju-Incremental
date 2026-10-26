extends SceneTree
## D-065 evidence: stills of the greenery at the game camera's angle (a park, its playground,
## a stretch of avenue trees) and, with --trample, a real rampage clip of the kaiju walking
## north across a park on player input ("move_up"), so the game's own body contact and stomps
## bring it down; it starts just inside the park, so no tower south of it hides the contact
## from the game camera, and the crushed trail lies between the camera and the kaiju.
## Needs a window: run it on CI (tools/capture/ci_capture.sh [--movie] capture_green.gd).
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_green.gd -- --out=<dir> [--stage=N]
##   ... --write-movie <clip> --fixed-fps 60 ... -- --trample [--seconds=5]
##   ... -- --trample --park-stills  (no movie: stills of the park from the east, before and after)
##   ... -- --trample --still-at=2.0 [--no-trample]  (a game-camera still at 2 s; with
##   --no-trample the same deterministic walk leaves the decor standing: the before frame)
## Every trample prints how many of the park's props the walk crushed or flattened.

const PropLog := preload("res://tools/capture/prop_log.gd")
const SETTLE := 12
const SPECIES := "reptilian"
const PARK_ZOOM := 0.6
const PLAYGROUND_ZOOM := 0.25
const AVENUE_ZOOM := 0.45
const ROW_REACH := 15.0  # street trees this far either way along a pavement count as a row
const START_INSIDE := 2.0  # the clip starts this far inside the park's south edge
const OFF_PATH := 0.25  # ...and this share of its width east of the middle path, in the trees
## The park stills look west across the park from here (off its centre), so the walk's
## north-south strip of flattened props crosses the frame; straight down, a flattened tree
## looks like a standing one.
const PARK_VIEW := Vector3(20, 13, 0)
const AVENUE_MIN := 18.0  # the avenue close-up looks down the first block at least this long

var _out := "user://green"
var _stage := 1
var _trample := false
var _park_stills := false
var _seconds := 5.0
var _still_at := -1.0  # --still-at: a game-camera still this many seconds into the walk
var _no_trample := false  # --no-trample: the same walk with the decor left standing
var _log_props := false  # --log-props: per-prop table (PropLog) after the walk


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg == "--trample":
			_trample = true
		elif arg == "--park-stills":
			_park_stills = true
		elif arg.begins_with("--still-at="):
			_still_at = arg.substr(11).to_float()
		elif arg == "--no-trample":
			_no_trample = true
		elif arg == "--log-props":
			_log_props = true
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _trample:
		await _trample_clip()
	else:
		await _stills()
	quit()


## The first park inside the playable city.
func _park(cfg: Dictionary) -> Rect2:
	var half := CityGen.half_extent(cfg)
	for block: Dictionary in CityGen.map(cfg)["blocks"]:
		var rect: Rect2 = block["rect"]
		var c := rect.get_center()
		if str(block["use"]) == "park" and maxf(absf(c.x), absf(c.y)) < half:
			return rect
	return Rect2()


## The middle of the first long avenue block in the playable city that runs north-south, so
## the camera (from the south, like the game's) looks down it rather than over a roof.
func _avenue_spot(cfg: Dictionary) -> Vector2:
	var plan := CityGen.map(cfg)
	var nodes: Array[Vector2] = plan["nodes"]
	var half := CityGen.half_extent(cfg)
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var inside := maxf(maxf(absf(a.x), absf(a.y)), maxf(absf(b.x), absf(b.y))) <= half
		var north_south := absf(a.x - b.x) < 0.01
		if str(street["kind"]) == CityGen.AVENUE and inside and north_south:
			if a.distance_to(b) >= AVENUE_MIN:
				return (a + b) * 0.5
	return Vector2.ZERO


## The middle of the longest run of street trees down one north-south pavement (D-065), so the
## avenue close-up shows a row of them rather than a corner.
func _tree_row(trees: Array) -> Vector2:
	var best := Vector2.ZERO
	var most := 0
	for t: Vector2 in trees:
		var row: Array[float] = []
		for u: Vector2 in trees:
			if absf(u.x - t.x) < 0.1 and absf(u.y - t.y) <= ROW_REACH:
				row.append(u.y)
		if row.size() > most:
			most = row.size()
			row.sort()
			best = Vector2(t.x, row[row.size() >> 1])
	return best


func _stats() -> Dictionary:
	return UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def(SPECIES), UpgradeTree.new(Content.upgrades())
	)


func _stills() -> void:
	var sim := RampageSim.new(
		_stats(),
		CityGrowth.tuning_for(Content.tuning(), _stage),
		CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	var stage := Node3D.new()
	var city := CityView.new(sim, Seeds.make("fx", 0))
	stage.add_child(city)
	var cam := Camera3D.new()
	cam.fov = CameraTuning.fov()
	cam.far = 4000.0
	stage.add_child(cam)
	root.add_child(stage)
	cam.current = true
	var park := _park(sim.city)
	var at := Vector3(park.get_center().x, 0, park.get_center().y)
	await _shot(cam, at, PARK_ZOOM, "green_park_s%d" % _stage)
	var pad := CityGreenery.playground_pad(park, sim.city).get_center()
	await _shot(cam, Vector3(pad.x, 0, pad.y), PLAYGROUND_ZOOM, "green_playground_s%d" % _stage)
	var kerb := _avenue_spot(sim.city)
	var decor: CityDecor = city._decor
	var planted: Variant = decor.get("green")
	if planted is Dictionary:
		var green: Dictionary = planted
		var trees: Array = green.get("street_trees", [])
		if not trees.is_empty():
			kerb = _tree_row(trees)
	await _shot(cam, Vector3(kerb.x, 0, kerb.y), AVENUE_ZOOM, "green_avenue_s%d" % _stage)
	stage.queue_free()
	await process_frame


func _shot(cam: Camera3D, at: Vector3, zoom: float, shot_name: String) -> void:
	cam.position = at + CameraTuning.offset() * zoom  # the game camera's direction, closer for the close-ups
	cam.look_at(at)
	for _i: int in SETTLE:
		await process_frame
	var path := _out.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path, " looking at ", at)


## The kaiju starts just south of a park and walks north across it on player input.
func _trample_clip() -> void:
	var rampage := Rampage.new()
	rampage.setup(
		Content.species_def(SPECIES),
		_stats(),
		CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0)),
		0
	)
	var park := _park(rampage.sim.city)
	var x := park.get_center().x + park.size.x * OFF_PATH
	rampage.sim.kaiju_pos = Vector2(x, park.end.y - START_INSIDE)
	root.add_child(rampage)
	var decor: CityDecor = rampage._city._decor
	decor.trampling = not _no_trample
	if _park_stills:
		await _park_view(rampage, park, "trample_park_before")
	Input.action_press("move_up")
	var log: PropLog = null
	if _log_props:
		log = PropLog.new(decor, park.grow(4.0), root.get_visible_rect().size.y)
	var frames := 0
	var still := roundi(_still_at * Engine.physics_ticks_per_second)
	while frames < roundi(_seconds * Engine.physics_ticks_per_second) and not rampage.sim.over:
		await physics_frame
		frames += 1
		if log != null:
			log.sample(decor, rampage._camera)
			_print_puffs(decor)
		if frames == still:
			var shot := (
				"trample_game_%.1fs%s.png" % [_still_at, "_untouched" if _no_trample else ""]
			)
			root.get_texture().get_image().save_png(_out.path_join(shot))
			print("saved %s: %s" % [shot, _park_count(decor, park)])
	Input.action_release("move_up")
	print("trample: kaiju from ", park.end.y - START_INSIDE, " to ", rampage.sim.kaiju_pos)
	print("trample: ", _park_count(decor, park))
	if log != null:
		print(log.report())
		_print_leaf_flight(decor, rampage._camera, rampage._kaiju.global_position)
	if _park_stills:
		await _park_view(rampage, park, "trample_park_after")


## With --log-props, each crushed-tree dust puff's alpha this frame (lead, #55 r14: the
## printout that shows it peaks by frame 3 and is gone by frame 30).
func _print_puffs(decor: CityDecor) -> void:
	var alphas := PackedStringArray()
	for node: Node in decor._fx.get_children():
		var quad := node as MeshInstance3D
		if quad != null and quad.mesh is QuadMesh:
			var mat := quad.mesh.surface_get_material(0) as StandardMaterial3D
			alphas.append("%.3f" % mat.albedo_color.a)
	if not alphas.is_empty():
		print("puff frame %d alpha %s" % [Engine.get_frames_drawn(), " ".join(alphas)])


## With --log-props, how far crushed trees' leaves landed from their stumps (lead, #55 r14:
## they landed 300+ px away; about 150 asked): metres on the ground, each leaf from its nearest
## stump, and pixels at the game camera's scale where the walk ended.
func _print_leaf_flight(decor: CityDecor, camera: Camera3D, at: Vector3) -> void:
	var stumps: Array[Vector2] = []
	for group: Dictionary in decor._props._groups:
		if group.get("fells", false) and group.get("crushed", false):
			var base: Vector3 = group["at"]
			stumps.append(Vector2(base.x, base.z))
	var metres: Array[float] = []
	for body: RigidBody3D in decor._props.leaf_field._bodies:
		var near := INF
		for base: Vector2 in stumps:
			near = minf(near, base.distance_to(Vector2(body.position.x, body.position.z)))
		metres.append(near)
	metres.sort()
	if metres.is_empty():
		return
	var scale := camera.unproject_position(at).distance_to(
		camera.unproject_position(at + Vector3.RIGHT)
	)
	var median := metres[floori(metres.size() * 0.5)]
	var most := metres[floori(metres.size() * 0.9)]
	print(
		(
			"leaf flight m: median %.1f, 90%% %.1f, max %.1f of %d; %.0f px/m: median %.0f px, 90%% %.0f px"
			% [median, most, metres[-1], metres.size(), scale, median * scale, most * scale]
		)
	)


## How many of the park's props are down so far.
func _park_count(decor: CityDecor, park: Rect2) -> String:
	var down := 0
	var all := 0
	for group: Dictionary in decor._props._groups:
		var at: Vector3 = group["at"]
		if park.has_point(Vector2(at.x, at.z)):
			all += 1
			down += 1 if group.get("crushed", false) else 0
	return "%d of %d park props crushed or flattened" % [down, all]


## A still of the park from PARK_VIEW (the rampage's own camera is put back after).
func _park_view(rampage: Rampage, park: Rect2, shot_name: String) -> void:
	var cam := Camera3D.new()
	cam.fov = CameraTuning.fov()
	rampage.add_child(cam)
	var c := park.get_center()
	cam.position = Vector3(c.x, 0, c.y) + PARK_VIEW
	cam.look_at(Vector3(c.x, 0, c.y))
	cam.current = true
	for _i: int in SETTLE:
		await process_frame
	var path := _out.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	rampage._camera.current = true
	cam.queue_free()
