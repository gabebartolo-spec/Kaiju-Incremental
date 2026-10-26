extends SceneTree
## Does a carve change the look of the building's UNTOUCHED upper half (the director, 2026-10-27:
## "when a building gets carved anywhere, its whole facade changes texture, so even if you carve
## the bottom of a tower, the top of the tower is changing appearance too", D-289)?
## One tower per facade archetype of the stage-2 city, seen from the rampage's own camera framed
## on a kaiju standing `--gap` m east of it (kaiju hidden; the city is frozen so only the
## building's own look can change). Per building it saves 4K PNGs: a0 and a1 (the same scene twice,
## the noise floor), `hidden` (the building switched off: its pixel mask), then one shot per step
## in `--steps` (each starts from the standing building), and <tag>.json (its screen rectangle
## and the screen row of its mid-height). tools/capture/facade_diff.py measures them: per-channel
## mean and 99th percentile of the step on the building's pixels above that row.
##   slabs   : only the hidden floor-slab mesh made visible (hide_chunks does that first)
##   hit     : the game's own blow path, CityView.chunks_broken on the street-side base chunk
##   promote : BuildingView.promote (the fine-grid CellView); not part of the live game today
## A step that changes the building for good (hit, promote) goes last. Needs a window and the
## no-focus override.cfg (Kit.window_ok).
##   godot --path . --resolution 1280x720 --windowed \
##     --script tools/capture/capture_facade_carve.gd -- --out=<dir> --steps=slabs,hit \
##     [--style=-1] [--floors=8] [--gap=5]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const SIZE := Vector2i(3840, 2160)
const SETTLE_FRAMES := 8
const MARGIN := 60  # a tower must sit this far inside the frame

var _opt := {}
var _out := ""
var _sim: RampageSim
var _city: CityView
var _cam: Camera3D
var _kaiju: KaijuModel
var _port: SubViewport
var _eye: Camera3D
var _at := Vector3.ZERO  # where the kaiju stands for the building in hand


func _initialize() -> void:
	_opt = Kit.args(
		{
			"out": "user://facade_carve",
			"steps": "slabs,hit",
			"style": -1,
			"floors": 8,
			"gap": 5.0,
			"stage": 2
		}
	)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_out = str(_opt["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	var stage_n := Num.i(_opt["stage"])
	var stats := Kit.stats(SPECIES, Kit.STAGE_LEVELS[1], SPECIES)
	_sim = Kit.stage_sim(stats, stage_n, CityGrowth.tuning_for(Content.tuning(), stage_n))
	var stage := Node3D.new()
	_city = CityView.new(_sim, Seeds.make("fx", 0))
	stage.add_child(_city)
	var species := Content.species_def(SPECIES)
	var colors: Dictionary = species["colors"]
	var scale := _sim.body_scale()
	_kaiju = KaijuModel.new(SPECIES, colors, KaijuModel.stage_for(_sim.size_tier()))
	_kaiju.scale = Vector3.ONE * scale
	stage.add_child(_kaiju)
	_cam = Camera3D.new()
	stage.add_child(_cam)
	root.add_child(stage)
	_cam.current = true
	_make_port()
	_kaiju.visible = false
	for _i: int in 40:
		await process_frame
	_city.process_mode = Node.PROCESS_MODE_DISABLED
	for n: int in _pick(scale):
		await _building(n, scale)
	quit()


## A 4K off-screen viewport on the same world, with the game's graphics row, through _cam.
func _make_port() -> void:
	_port = SubViewport.new()
	_port.size = SIZE
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	PlayerSettings.apply_graphics(_port)
	_eye = Camera3D.new()
	_port.add_child(_eye)
	root.add_child(_port)
	_eye.current = true


## One tower per facade archetype: tall enough (--floors), the nearest to the city's middle whose
## whole box is on screen from the game camera with the kaiju beside it.
func _pick(scale: float) -> Array[int]:
	var out: Array[int] = []
	var want := Num.i(_opt["style"])
	for style: int in 4:
		if want >= 0 and style != want:
			continue
		var found: Array[Array] = []
		for i: int in _sim.buildings.size():
			var b := _sim.buildings[i]
			if b.landmark != "" or b.hazard != "" or b.is_rail() or b.style % 4 != style:
				continue
			if b.height >= Num.i(_opt["floors"]) and b.w >= 3 and b.d >= 3:
				found.append([Vector2(b.x, b.z).length(), i])
		found.sort()
		var frame := Rect2i(Vector2i(MARGIN, MARGIN), SIZE - Vector2i(MARGIN, MARGIN) * 2)
		for pair: Array in found:
			var n: int = pair[1]
			_place(_sim.buildings[n], scale)
			if frame.encloses(_rect(_sim.buildings[n])):
				out.append(n)
				break
	return out


## The kaiju beside building b (east of it) and the game camera on it; returns where it stands.
func _place(b: RampageSim.Building, scale: float) -> Vector3:
	var at := Vector3(b.x + b.w * 0.5 + Num.f(_opt["gap"]), 0, b.z)
	_kaiju.position = at
	_kaiju.rotation.y = PI * 0.5
	_kaiju.animate(0.0, 0.0)
	Kit.place_game_camera(_cam, _kaiju, scale)
	_eye.fov = _cam.fov
	_eye.global_transform = _cam.global_transform
	return at


func _building(n: int, scale: float) -> void:
	var b := _sim.buildings[n]
	var tag := "b%d_a%d" % [n, b.style % 4]
	print("building %d: %dx%dx%d style %d, files %s_*" % [n, b.w, b.d, b.height, b.style, tag])
	_at = _place(b, scale)
	var view := (_city._stream as BuildingStream).view(n)
	(await _shot()).save_png(_out.path_join(tag + "_a0.png"))
	(await _shot()).save_png(_out.path_join(tag + "_a1.png"))
	view.visible = false
	(await _shot()).save_png(_out.path_join(tag + "_hidden.png"))
	view.visible = true
	var rect := _rect(b)
	var mid := _eye.unproject_position(Vector3(b.x, b.height * 0.5, b.z))
	var meta := {
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "mid_row": int(mid.y)
	}
	var file := FileAccess.open(_out.path_join(tag + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta))
	file.close()
	for step: String in str(_opt["steps"]).split(","):
		await _step(step, n, view, tag)


func _step(step: String, n: int, view: BuildingView, tag: String) -> void:
	var b := view.b
	match step:
		"slabs":
			view._slabs.visible = true
			(await _shot()).save_png(_out.path_join(tag + "_slabs.png"))
			view._slabs.visible = false
		"hit":
			var cells: Array[Vector3i] = [Vector3i(b.w - 1, 0, b.d / 2)]
			_city.chunks_broken(n, cells, _at)
			(await _shot()).save_png(_out.path_join(tag + "_hit.png"))
		"promote":
			var party := BuildingView.party_walls(_sim.buildings)
			var cv := view.promote(BuildingCells.new(b, party[n]))
			cv.flush()
			(await _shot()).save_png(_out.path_join(tag + "_promote.png"))


func _shot() -> Image:
	for _i: int in SETTLE_FRAMES:
		await process_frame
	return _port.get_texture().get_image()


## The building's screen rectangle in the 4K shot (its standing box through the eye camera).
func _rect(b: RampageSim.Building) -> Rect2i:
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for i: int in 8:
		var corner := Vector3(
			b.x + b.w * 0.5 * (1 if (i & 1) != 0 else -1),
			float(b.height) * float((i >> 1) & 1),
			b.z + b.d * 0.5 * (1 if ((i >> 2) & 1) != 0 else -1)
		)
		if _eye.is_position_behind(corner):
			continue
		var p := _eye.unproject_position(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2i(Vector2i(lo.floor()), Vector2i((hi - lo).ceil()))
