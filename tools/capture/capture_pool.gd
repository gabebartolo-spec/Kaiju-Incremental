extends SceneTree
## Evidence for the Tripo city pool (D-256): the adult croc (Colossus) in a real rampage at night
## (run 1) in the stage 3 city, at the game camera.
## --district=<name>: a board still of that district's pool buildings: the croc stands BOARD_SIDE
## body lengths east of the spot where the district's models stand tallest together, facing
## north, so they stand beside him in the game camera's frame; the frame is saved as
## <out>/<district>.png with <district>.json (each pool building within LABEL_M: model id and
## image point, for labels).
## --clip: the croc walks north into the tallest pool hero and smashes it; pair with
## --write-movie. Prints the frame the shot starts (cut the clip from there).
## Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_pool.gd -- --out=<dir> --district=neon [--seed=0]
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_pool.gd -- --out=<dir> --clip --seconds=8

const Kit := preload("res://tools/capture/capture_kit.gd")
const ADULT_LEVELS := 2  ## Kit.STAGE_LEVELS: the Colossus
const STAGE := 3
const NIGHT_RUN := 1  ## Content.time_for_run: dusk, night, morning, noon
const GROUP_M := 30.0  ## a board's spot: the most district models within this many metres
const SETTLE := 90  ## frames after he is moved into place before the shot (the camera follows)
const BACK := 1.4  ## clip: body lengths south of the tower the croc starts
## board: body lengths east of the district's group the croc stands, so the group is beside him
## at the middle of the game camera's frame
const BOARD_SIDE := 0.9
const LABEL_M := 45.0  ## board: pool buildings this near the group are labelled

var _out := "user://pool"
var _district := ""
var _clip := false
var _seconds := 8.0
var _seed := 0


func _initialize() -> void:
	var a := Kit.args(
		{"out": _out, "district": "", "clip": false, "seconds": _seconds, "seed": _seed}
	)
	_out = str(a["out"])
	_district = str(a["district"])
	_clip = a["clip"] == true
	_seconds = Num.f(a["seconds"])
	_seed = Num.i(a["seed"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[ADULT_LEVELS]
	var layout := CityGrowth.layout(Content.tuning(), STAGE, Seeds.make("city", _seed))
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), NIGHT_RUN, layout)
	var sim := rampage.sim
	var target := _clip_target(sim) if _clip else _board_target(sim)
	if target < 0:
		push_error("capture_pool: no pool building to frame")
		quit(1)
		return
	var t := sim.buildings[target]
	var walk := [false]
	rampage.scripted = func(_s: RampageSim) -> Dictionary:
		return {"move": Vector2(0, -1)} if walk[0] else {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	while rampage.sim.emerge.active:  # the rise from the river places him; then he is moved
		await process_frame
	var back := Num.f(t.d) * 0.5 + sim.body.length() * BACK
	sim.kaiju_pos = Vector2(t.x, t.z + back)
	if not _clip:
		sim.kaiju_pos = Vector2(t.x + Num.f(t.w) * 0.5 + sim.body.length() * BOARD_SIDE, t.z)
	sim.facing = Vector2(0, -1)
	sim.body.heading = sim.facing
	await Kit.frames(self, SETTLE)  # the camera follows him there
	print(
		(
			"capture_pool: target %s (%d floors), shot starts at frame %d"
			% [t.model, t.height, Engine.get_process_frames()]
		)
	)
	walk[0] = _clip
	if _clip:
		await Kit.frames(self, int(_seconds * 60.0))
		print(
			(
				"capture_pool: %d chunks broken, %d toppled"
				% [sim.chunks_destroyed, sim.collapse.toppled]
			)
		)
	else:
		_board(rampage, Vector2(t.x, t.z))
	quit()


## The pool building of `_district` with the most floors of its district's models within GROUP_M.
func _board_target(sim: RampageSim) -> int:
	var pool: Dictionary = Content.city_buildings()["pool"]
	var mine: Array[int] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.model == "":
			continue
		var row: Dictionary = pool[b.model]
		if str(row["district"]) == _district:
			mine.append(i)
	var best := -1
	var most := 0
	for i: int in mine:
		var at := Vector2(sim.buildings[i].x, sim.buildings[i].z)
		var near := 0
		for j: int in mine:
			var by := at.distance_to(Vector2(sim.buildings[j].x, sim.buildings[j].z)) < GROUP_M
			near += sim.buildings[j].height if by else 0  # floors: tall models stand out
		if near > most:
			most = near
			best = i
	return best


## The tallest pool hero.
func _clip_target(sim: RampageSim) -> int:
	var best := -1
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.model.begins_with("H") and (best < 0 or b.height > sim.buildings[best].height):
			best = i
	return best


## Saves the still and, beside it, each on-screen pool building's id and roof-centre image point.
func _board(rampage: Rampage, group: Vector2) -> void:
	var img := root.get_texture().get_image()
	var size := Vector2(img.get_size())
	img.save_png(_out.path_join(_district + ".png"))
	var cam := rampage._camera
	var marks: Array[Dictionary] = []
	for b: RampageSim.Building in rampage.sim.buildings:
		if b.model == "" or Vector2(b.x, b.z).distance_to(group) > LABEL_M:
			continue
		var top := Vector3(b.x, b.height, b.z)
		if cam.is_position_behind(top):
			continue
		var p := Kit.image_point(self, cam, top, size)
		if Rect2(Vector2.ZERO, size).has_point(p):
			marks.append({"id": b.model, "x": p.x, "y": p.y, "palette": b.palette})
	var f := FileAccess.open(_out.path_join(_district + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(marks))
	print("capture_pool: %s board, %d pool buildings in frame" % [_district, marks.size()])
