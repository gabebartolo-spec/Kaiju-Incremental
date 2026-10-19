extends SceneTree
## A building carved on its fine grid (D-094 WP4), seen from the rampage's own camera framed on
## a kaiju standing beside a tower of the stage-2 city (the kaiju hidden unless --kaiju: at
## this scale its body covers the tower); shots of the baked BuildingView, the same
## building promoted to its grid (CellView, should match), then after each carve of a fixed
## sequence (a claw bite high in the street face, a gouge out of the corner, a stomp
## through the roof, a swipe across the street face). No debris or falls here: that is WP5.
## --bench: also promotes and carves the 20 buildings nearest the kaiju and prints the GPU and
## CPU render time before and after (drawn at 3840x2160 in an off-screen viewport through the
## same camera).
##   godot --path . --resolution 1920x1080 --windowed --script \
##     tools/capture/capture_carve_view.gd -- --out=<dir> [--bench]

const SPECIES := "reptilian"
const GAME_CAMERA := Vector3(0, 27, 19)  # Rampage.CAMERA_OFFSET
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}
const STAGE := 2
const SETTLE_FRAMES := 8
const BENCH_FRAMES := 120
const BENCH_BUILDINGS := 20
const BENCH_SIZE := Vector2i(3840, 2160)

var _out := "user://carve_view"
var _bench := false
var _slab := ""  # --slab=<hex>: try another floor-slab colour (look probe, not the game's)
var _turn := 0.5
var _show_kaiju := false
var _sim: RampageSim
var _city: CityView
var _cam: Camera3D


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--bench":
			_bench = true
		elif arg.begins_with("--slab="):
			_slab = arg.substr(7)
		elif arg == "--kaiju":
			_show_kaiju = true
		elif arg.begins_with("--turn="):
			_turn = arg.substr(7).to_float()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	var species := Content.species_def(SPECIES)
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, SPECIES)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var tuning := CityGrowth.tuning_for(Content.tuning(), STAGE)
	var layout := CityGrowth.layout(Content.tuning(), STAGE, Seeds.make("city", 0))
	_sim = RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	var stage := Node3D.new()
	_city = CityView.new(_sim, Seeds.make("fx", 0))
	stage.add_child(_city)
	var colors: Dictionary = species["colors"]
	var scale := _sim.body_scale()
	var kaiju := KaijuModel.new(SPECIES, colors, KaijuModel.stage_for(_sim.size_tier()))
	kaiju.scale = Vector3.ONE * scale
	stage.add_child(kaiju)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	stage.add_child(_cam)
	root.add_child(stage)
	_cam.current = true
	var n := _pick()
	var b := _sim.buildings[n]
	print(
		(
			"building %d: %dx%dx%d style %d at (%.1f, %.1f)"
			% [n, b.w, b.d, b.height, b.style, b.x, b.z]
		)
	)
	# The kaiju stands east of the tower, facing it; the camera follows it as in a rampage.
	var at := Vector3(b.x + b.w * 0.5 + 1.6 * scale, 0, b.z + b.d * 0.25)
	kaiju.position = at
	kaiju.rotation.y = PI * _turn
	kaiju.animate(0.0, 0.0)
	kaiju.visible = _show_kaiju  # off by default: at this scale its body covers the tower
	_cam.position = at + GAME_CAMERA * (0.75 + 0.4 * scale)
	_cam.look_at(at + Vector3(0, 3.5 * scale, 0))
	var stream: BuildingStream = _city._stream
	var view := stream.view(n)
	await _shot("a_baked")
	var party := BuildingView.party_walls(_sim.buildings)
	var grid := BuildingCells.new(b, party[n])
	if _slab != "":
		view.voxels.palette["slab"] = Color(_slab)
	var cv := view.promote(grid)
	cv.flush()
	await _shot("b_promoted_uncarved")
	var cells := grid.cells
	var k := 0
	for carve: Array in _carves(grid):
		k += 1
		cells = cells.duplicate()
		var box := _carve(cells, grid.dims, carve)
		cv.carved(cells, box[0], box[1])
		cv.flush()
		await _shot("c_carve%d" % k)
	if _bench:
		await _bench_city(n, party)
	quit()


## A tower near the city's middle with a real wall colour: 5-9 floors, 3+ units a side, no
## landmark, the most open ground to its east (where the kaiju stands).
func _pick() -> int:
	var best := -1
	var best_d := 1.0e9
	for i: int in _sim.buildings.size():
		var b := _sim.buildings[i]
		if b.landmark != "" or b.height < 5 or b.height > 9 or b.w < 3 or b.d < 3:
			continue
		if b.style % 4 == BuildingVoxels.GLASS:
			continue  # a curtain wall hides the floors behind it; a punched facade shows them
		var d := Vector2(b.x, b.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


## The carve sequence in grid cells as [centre, radius] spheres (some are strings of spheres:
## a swipe).
func _carves(g: BuildingCells) -> Array:
	var w := g.b.w * g.res
	var d := g.b.d * g.res
	var h := g.b.height * g.res
	var o := Vector3(-g.offset)  # building-local -> grid
	var bite := [[o + Vector3(w * 0.3, h * 0.62, d - 1), 9.0]]
	var gouge := [[o + Vector3(w - 2, h * 0.38, d - 2), 13.0]]
	var stomp := [[o + Vector3(w * 0.55, h, d * 0.5), 15.0]]
	var swipe := []
	for i: int in 6:
		swipe.append([o + Vector3(w * (0.15 + i * 0.12), h * 0.22 + i * 1.5, d - 1), 6.0])
	return [bite, gouge, stomp, swipe]


## Carves a string of spheres; returns the cell box it touched as [lo, hi].
func _carve(cells: PackedByteArray, dims: Vector3i, spheres: Array) -> Array[Vector3i]:
	var lo := dims
	var hi := Vector3i(-1, -1, -1)
	for s: Array in spheres:
		var c: Vector3 = s[0]
		var r: float = s[1]
		var a := Vector3i((c - Vector3.ONE * r).floor()).max(Vector3i.ZERO)
		var z := Vector3i((c + Vector3.ONE * r).ceil()).min(dims - Vector3i.ONE)
		lo = lo.min(a)
		hi = hi.max(z)
		for y: int in range(a.y, z.y + 1):
			for zz: int in range(a.z, z.z + 1):
				for x: int in range(a.x, z.x + 1):
					if (Vector3(x + 0.5, y + 0.5, zz + 0.5) - c).length_squared() <= r * r:
						cells[x + zz * dims.x + y * dims.x * dims.z] = 0
	return [lo, hi] as Array[Vector3i]


func _shot(name: String) -> void:
	for _i: int in SETTLE_FRAMES:
		await process_frame
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved %s" % path)


## GPU and CPU render ms over BENCH_FRAMES, then the same after the BENCH_BUILDINGS nearest the
## kaiju are promoted and carved by the sequence.
func _bench_city(skip: int, party: Array[Dictionary]) -> void:
	# A 4K off-screen view through the same camera (a window cannot outgrow the monitor).
	var view := SubViewport.new()
	view.size = BENCH_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var eye := Camera3D.new()
	eye.fov = _cam.fov
	view.add_child(eye)
	root.add_child(view)
	eye.global_transform = _cam.global_transform
	eye.current = true
	var vp := view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var before := await _measure(vp)
	var near: Array = []
	for i: int in _sim.buildings.size():
		var b := _sim.buildings[i]
		if i != skip and b.landmark == "":
			near.append(
				[Vector2(b.x, b.z).distance_to(Vector2(_cam.position.x, _cam.position.z)), i]
			)
	near.sort()
	var stream: BuildingStream = _city._stream
	var tris := 0
	for k: int in mini(BENCH_BUILDINGS, near.size()):
		var i: int = near[k][1]
		var grid := BuildingCells.new(_sim.buildings[i], party[i])
		var cv := stream.view(i).promote(grid)
		cv.flush()
		var cells := grid.cells
		for carve: Array in _carves(grid):
			cells = cells.duplicate()
			var box := _carve(cells, grid.dims, carve)
			cv.carved(cells, box[0], box[1])
		cv.flush()
		for r: Vector3i in cv.parts:
			var mi: MeshInstance3D = cv.parts[r]
			var mesh: ArrayMesh = mi.mesh
			tris += mesh.surface_get_array_index_len(0) / 3
	var after := await _measure(vp)
	var size := view.size
	print(
		(
			(
				"bench %dx%d: baked city GPU %.2f ms CPU %.2f ms; with %d buildings promoted and carved"
				+ " (%d triangles) GPU %.2f ms CPU %.2f ms"
			)
			% [size.x, size.y, before[0], before[1], BENCH_BUILDINGS + 1, tris, after[0], after[1]]
		)
	)


func _measure(vp: RID) -> Array[float]:
	for _i: int in 20:
		await process_frame
	var gpu := 0.0
	var cpu := 0.0
	for _i: int in BENCH_FRAMES:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	return [gpu / BENCH_FRAMES, cpu / BENCH_FRAMES] as Array[float]
