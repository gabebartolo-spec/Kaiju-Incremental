extends SceneTree
## D-065 evidence: stills of the greenery at the game camera's angle (a park, its playground,
## a stretch of avenue trees) and, with --trample, a real rampage clip of the kaiju walking
## north across a park on player input ("move_up"), so the game's own stomps flatten it.
## Needs a window: run it on CI (tools/capture/ci_capture.sh [--movie] capture_green.gd).
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_green.gd -- --out=<dir> [--stage=N]
##   ... --write-movie <clip> --fixed-fps 60 ... -- --trample [--seconds=5]
##   ... -- --trample --park-stills  (no movie: top-down stills of the park before and after)
## Every trample prints how many of the park's props the walk flattened.

const SETTLE := 12
const SPECIES := "reptilian"
## Rampage.CAMERA_OFFSET: the game camera's direction, scaled down for the close-ups.
const GAME_CAMERA := Vector3(0, 27, 19)
const PARK_ZOOM := 0.6
const PLAYGROUND_ZOOM := 0.25
const AVENUE_ZOOM := 0.45
const ROW_REACH := 15.0  # street trees this far either way along a pavement count as a row
const START_OUTSIDE := 3.0  # the clip starts this far south of the park
const OFF_PATH := 0.25  # ...and this share of its width east of the middle path, in the trees
const TOP_DOWN := 26.0  # the park stills look straight down from this height
const AVENUE_MIN := 18.0  # the avenue close-up looks down the first block at least this long

var _out := "user://green"
var _stage := 1
var _trample := false
var _park_stills := false
var _seconds := 5.0


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
	cam.fov = 55.0
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
	cam.position = at + GAME_CAMERA * zoom
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
	rampage.sim.kaiju_pos = Vector2(x, park.end.y + START_OUTSIDE)
	root.add_child(rampage)
	if _park_stills:
		await _top_down(rampage, park, "trample_park_before")
	Input.action_press("move_up")
	var frames := 0
	while frames < roundi(_seconds * Engine.physics_ticks_per_second) and not rampage.sim.over:
		await physics_frame
		frames += 1
	Input.action_release("move_up")
	print("trample: kaiju from ", park.end.y + START_OUTSIDE, " to ", rampage.sim.kaiju_pos)
	var flat := 0
	var standing := 0
	var decor: CityDecor = rampage._city._decor
	for group: Dictionary in decor._props._groups:
		var at: Vector3 = group["at"]
		if park.has_point(Vector2(at.x, at.z)):
			if group.get("crushed", false):
				flat += 1
			else:
				standing += 1
	print("trample: %d of %d park props flattened" % [flat, flat + standing])
	if _park_stills:
		await _top_down(rampage, park, "trample_park_after")


## A still of the park from straight above (the rampage's own camera is put back after).
func _top_down(rampage: Rampage, park: Rect2, shot_name: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 55.0
	rampage.add_child(cam)
	var c := park.get_center()
	cam.position = Vector3(c.x, TOP_DOWN, c.y + 0.01)
	cam.look_at(Vector3(c.x, 0, c.y))
	cam.current = true
	for _i: int in SETTLE:
		await process_frame
	var path := _out.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	rampage._camera.current = true
	cam.queue_free()
