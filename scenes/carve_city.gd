class_name CarveCity
extends Node3D
## Carved buildings in the real rampage (D-094: WP4's cell view and WP5's physics, in play).
## A building the kaiju reaches gets its fine grid (BuildingCells) and its cell mesher made on
## a worker thread; from its first blow after that it is drawn by a CellView (only the touched
## 16^3 blocks remeshed) instead of its baked meshes, carved cells fly as WP5 debris, and every
## part the sim drops or topples becomes an IslandBody that follows the sim's fall, then breaks
## and settles into its building's rubble (CarvePhysics: live-body and rubble caps).
##
## Presentation only. The grid here mirrors what the sim decided: until the rampage carves its
## own grid (WP7), a broken chunk empties its cells (BuildingCells.clear_chunk's ranges) and a
## falling part takes its chunks' cells with it; the sim's events, never this node, decide
## what breaks, falls and is crushed. Landmarks keep the chunk path until WP6. Off when
## data/tuning.json "destruction.carving_enabled" is false: CityView draws chunks as before.

signal ignited(at: Vector3, size: float)

## Physics layers: a falling island collides only with the ground (ISLAND_GROUND, which
## CityView's ground also sits on), never with a standing building's colliders, the debris or
## another island. The sim decides what a fall crushes (Collapse's strip, carved on landing);
## an island caught on a neighbour's wall stopped dead at 35 degrees in play (step 691, b44).
const ISLAND_LAYER := 4
const ISLAND_GROUND := 8

var physics: CarvePhysics
## Building index -> its BuildingCells grid (drawn and carved here), once promoted.
var grids: Dictionary = {}
## Building index -> its CarveSite (the physics view's frame of the grid).
var sites: Dictionary = {}
## Promotions finished, carves and falls handed on (tests and benches).
var promoted := 0
var carves := 0
var falls := 0
## Worst main-thread cost per step (microseconds): take, carved, fell, promote, colliders.
var cost_usec: Dictionary = {}

var _sim: RampageSim
var _stream: BuildingStream
var _cfg: Dictionary
## Building index -> worker task id while its grid is being made.
var _tasks: Dictionary = {}
## Building index -> [BuildingCells, CellMesher] made by a worker, not yet taken (under _mutex).
var _made: Dictionary = {}
var _mutex := Mutex.new()
## Building index -> true while its baked meshes still show (its cell view's first batch runs).
var _swapping: Dictionary = {}
var _prefetch_at := 0.0


static func enabled() -> bool:
	return Content.section("destruction").get("carving_enabled", false) == true


func _init(p_sim: RampageSim, stream: BuildingStream, seed_value: int) -> void:
	_sim = p_sim
	_stream = stream
	_cfg = Content.section("destruction")
	physics = CarvePhysics.new(seed_value)
	physics.ignited.connect(func(at: Vector3, size: float) -> void: ignited.emit(at, size))


func _ready() -> void:
	add_child(physics)


## Whether building `index` is drawn and broken on its fine grid now.
func carving(index: int) -> bool:
	return grids.has(index)


## Asks for building `index`'s fine grid (made on a worker; a landmark never gets one here).
func want(index: int) -> void:
	if grids.has(index) or _tasks.has(index) or _sim.buildings[index].landmark != "":
		return
	var view := _stream.view(index)
	var b := _sim.buildings[index]
	var party := _stream.party(index)
	var voxels := view.voxels
	_tasks[index] = WorkerThreadPool.add_task(
		func() -> void:
			var grid := BuildingCells.new(b, party)
			var mesher := CellMesher.new(voxels, grid)
			_mutex.lock()
			_made[index] = [grid, mesher]
			_mutex.unlock()
	)


## Chunks of building `index` broke (sim event): their cells go, some fly as debris thrown
## away from `kaiju_at`. False when the building is not carving yet (the chunk path draws it).
func chunks_broken(index: int, cells: Array[Vector3i], kaiju_at: Vector3) -> bool:
	want(index)
	if not grids.has(index):
		return false
	var t0 := Time.get_ticks_usec()
	var taken := _take_chunks(index, cells)
	t0 = _note("take", t0)
	var removed: PackedInt32Array = taken[0]
	if removed.is_empty():
		return true
	var b := _sim.buildings[index]
	var away := Vector3(b.x - kaiju_at.x, 0.0, b.z - kaiju_at.z).normalized()
	var push := (away + Vector3.UP * Num.f(_cfg["carve_lift"])).normalized()
	var grid: BuildingCells = grids[index]
	physics.carved(index, grid.cells, {
		"cells": removed, "mats": taken[1], "push": push
	})
	_note("carved", t0)
	carves += 1
	return true


## A part of building `index` starts to fall (sim "fall_start"): it leaves the grid as an
## IslandBody that follows the sim's drop or topple. False when the building is not carving.
func fall_start(event: Dictionary) -> bool:
	var index := Num.i(event["building"])
	if not grids.has(index):
		return false
	var cells: Array[Vector3i] = event["cells"]
	var t0 := Time.get_ticks_usec()
	var taken := _take_chunks(index, cells)
	t0 = _note("take", t0)
	var removed: PackedInt32Array = taken[0]
	if removed.is_empty():
		return true
	var b := _sim.buildings[index]
	var pivot: Vector3 = event["pivot"]
	var fall := {
		"index": removed,
		"mats": taken[1],
		"kind": str(event["kind"]),
		"pivot": pivot - b.local_to_world(Vector3.ZERO),  # building-local sim units
		"dir": event["dir"],
		"duration": Num.f(event["duration"]),
	}
	var grid: BuildingCells = grids[index]
	var island := physics.fell(index, grid.cells, fall)
	island.collision_layer = ISLAND_LAYER
	island.collision_mask = ISLAND_GROUND
	var mat := _stream.view(index).cells_material()  # the building's own look, not a flat one
	for child: Node in island.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat
	_note("fell", t0)
	falls += 1
	return true


## Every promotion and first remesh done (captures wait on it).
func settled() -> bool:
	if not _tasks.is_empty() or not _swapping.is_empty():
		return false
	for index: int in grids:
		var view := _stream.view(index)
		if view.cells_view != null and not view.cells_view.settled():
			return false
	return true


func _process(delta: float) -> void:
	_take_made()
	for index: int in _swapping.keys():
		var view := _stream.view(index)
		if view.cells_view.settled():
			view.show_cells()
			_swapping.erase(index)
	_prefetch_at -= delta
	if _prefetch_at <= 0.0:
		_prefetch_at = Num.f(_cfg["prefetch_seconds"])
		_prefetch()


func _exit_tree() -> void:
	for index: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(Num.i(_tasks[index]))
	_tasks.clear()


## Grids the workers finished: the chunks the sim has already lost are emptied, the view
## switches to cells (its baked meshes stay up until the first batch is drawn) and the
## physics view gets the building's colliders.
func _take_made() -> void:
	_mutex.lock()
	var ready := _made.duplicate()
	_made.clear()
	_mutex.unlock()
	for index: int in ready:
		WorkerThreadPool.wait_for_task_completion(Num.i(_tasks[index]))
		_tasks.erase(index)
		var pair: Array = ready[index]
		var grid: BuildingCells = pair[0]
		var mesher: CellMesher = pair[1]
		var t0 := Time.get_ticks_usec()
		var b := _sim.buildings[index]
		for y: int in b.frame.h:
			for z: int in b.frame.d:
				for x: int in b.frame.w:
					if not b.frame.alive(Vector3i(x, y, z)):
						grid.clear_chunk(Vector3i(x, y, z))
		var view := _stream.view(index)
		view.promote(grid, mesher, true)
		_swapping[index] = true
		var site := CarveSite.new(
			index, mesher.origin - Vector3.ONE * mesher.voxel * 0.5, grid.dims, grid.res
		)
		site.offset = grid.offset
		t0 = _note("promote", t0)
		physics.add_site(site, grid.cells)
		_note("colliders", t0)
		_palette(site, view.voxels)
		grids[index] = grid
		sites[index] = site
		promoted += 1


## Keeps the worst cost of `what` since `since` (usec); returns now.
func _note(what: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	cost_usec[what] = maxi(Num.i(cost_usec.get(what, 0)), now - since)
	return now


## Debris and islands in the building's own colours (its view palette by material name).
static func _palette(site: CarveSite, voxels: BuildingVoxels) -> void:
	for m: Dictionary in Content.materials():
		var name := str(m["name"])
		if voxels.palette.has(name):
			site.palette[Num.i(m["id"])] = voxels.palette[name]


## Empties the cells of these chunks in building `index`'s grid and redraws the blocks they
## were in. Returns [removed indices, their materials].
func _take_chunks(index: int, chunks: Array[Vector3i]) -> Array:
	var grid: BuildingCells = grids[index]
	var removed := PackedInt32Array()
	var mats := PackedByteArray()
	var lo := grid.dims
	var hi := -Vector3i.ONE
	for chunk: Vector3i in chunks:
		var box := _chunk_box(grid, chunk)
		var a: Vector3i = box[0]
		var c: Vector3i = box[1]
		for y: int in range(a.y, c.y):
			for z: int in range(a.z, c.z):
				for x: int in range(a.x, c.x):
					var i := grid.index(Vector3i(x, y, z))
					var m := grid.cells[i]
					if m != 0:
						removed.append(i)
						mats.append(m)
						grid.cells[i] = 0
						lo = lo.min(Vector3i(x, y, z))
						hi = hi.max(Vector3i(x, y, z))
	var view := _stream.view(index)
	view.hide_chunks(chunks)  # the baked meshes agree while they still show
	if not removed.is_empty() and view.cells_view != null:
		view.cells_view.carved(grid.cells, lo, hi)
	return [removed, mats]


## A chunk's cell range in the grid, [lo, hi) clamped, as BuildingCells.clear_chunk takes it
## (a boundary chunk owns what stands proud of its face, a top chunk its roof gear).
static func _chunk_box(grid: BuildingCells, chunk: Vector3i) -> Array:
	var lo := chunk * grid.res - grid.offset
	var hi := lo + Vector3i.ONE * grid.res
	var last := Vector3i(grid.b.w, grid.b.height, grid.b.d) - Vector3i.ONE
	for axis: int in 3:
		if chunk[axis] == 0:
			lo[axis] = 0
		if chunk[axis] == last[axis]:
			hi[axis] = grid.dims[axis]
	return [lo.max(Vector3i.ZERO), hi.min(grid.dims)]


## Starts the grids of the standing buildings nearest the kaiju, a few at a time, so its next
## blow already carves.
func _prefetch() -> void:
	var reach := Num.f(_cfg["prefetch_reach"]) * maxf(1.0, _sim.body_scale())
	var room := Num.i(_cfg["prefetch_tasks"]) - _tasks.size()
	if room <= 0:
		return
	var near: Array[Vector2] = []  # (distance, index)
	for n: int in _sim.buildings.size():
		var b := _sim.buildings[n]
		if grids.has(n) or _tasks.has(n) or b.landmark != "" or b.frame.alive_count == 0:
			continue
		if _stream.built(n) == null:  # a stand-in: the stream meshes it first
			continue
		var gap := Vector2(b.x, b.z).distance_to(_sim.kaiju_pos) - Vector2(b.w, b.d).length() * 0.5
		if gap <= reach:
			near.append(Vector2(gap, n))
	near.sort()
	for k: int in mini(room, near.size()):
		want(int(near[k].y))
