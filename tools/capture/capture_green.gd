extends SceneTree
## D-065 evidence: stills of the greenery at the game camera's angle (a park, its playground,
## a stretch of avenue trees) and, with --trample, a real rampage clip of the kaiju walking
## north across a park on player input ("move_up"), so the game's own stomps flatten it.
## Needs a window: run it on CI (tools/capture/ci_capture.sh [--movie] capture_green.gd).
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_green.gd -- --out=<dir> [--stage=N]
##   ... --write-movie <clip> --fixed-fps 60 ... -- --trample [--seconds=5]

const SETTLE := 12
const SPECIES := "reptilian"
## Rampage.CAMERA_OFFSET: the game camera's direction, scaled down for the close-ups.
const GAME_CAMERA := Vector3(0, 27, 19)
const PARK_ZOOM := 0.6
const PLAYGROUND_ZOOM := 0.25
const AVENUE_ZOOM := 0.3
const START_OUTSIDE := 3.0  # the clip starts this far south of the park

var _out := "user://green"
var _stage := 1
var _trample := false
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
	var decor: CityDecor = city._decor
	var trees: Array = decor.green["street_trees"]
	var tree: Vector2 = trees[trees.size() >> 1]
	await _shot(cam, Vector3(tree.x, 0, tree.y), AVENUE_ZOOM, "green_avenue_s%d" % _stage)
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
	rampage.sim.kaiju_pos = Vector2(park.get_center().x, park.end.y + START_OUTSIDE)
	root.add_child(rampage)
	Input.action_press("move_up")
	var frames := 0
	while frames < roundi(_seconds * Engine.physics_ticks_per_second) and not rampage.sim.over:
		await physics_frame
		frames += 1
	Input.action_release("move_up")
	print("trample: kaiju from ", park.end.y + START_OUTSIDE, " to ", rampage.sim.kaiju_pos)
