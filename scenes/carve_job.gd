class_name CarveJob
extends RefCounted
## One worker task of CityCarve for one building (destruction plan stage 1, D-327): plain data,
## no render resource (D-295). A building's first job builds its view voxels (when the view has
## none), the CellMesher looks from its grid (the cells this frame's events took put back, so a
## piece that falls now keeps its colours) and the drawn grid. Every job then takes its events'
## cells out of the drawn grid in order (the sim's own removals: cells_carved, fall_start), boxes
## them, and lays out each falling piece's own grid: exactly the part's cells, nothing else, with
## debris samples and its box at rest. CityCarve hands the results to CellViews on the main thread.

## Debris samples per structural chunk's worth of cells, as the baked view keeps (BuildingMesher).
const SAMPLES := BuildingMesher.SAMPLES_PER_CHUNK
const CHUNK_CELLS := BuildingVoxels.RES * BuildingVoxels.RES * BuildingVoxels.RES

## First job: what builds the view voxels (BuildingView.voxel_maker) unless `voxels` is set, and
## the sim's grid now (its bytes shared copy-on-write; read here, never written).
var maker: Callable
var voxels: BuildingVoxels
var snapshot: CellGrid
## Later jobs: the building's mesher and its drawn grid before this job.
var mesher: CellMesher
var cells: PackedByteArray
## The removals in order: {"index": PackedInt32Array, "mats": PackedByteArray, "piece": bool}.
var ops: Array[Dictionary] = []
## Main thread only: the nodes of the ops that lay out a piece, in order (CityCarve's).
var nodes: Array[Node3D] = []
## Out: the grid box of every removal (lo > hi when none), and per piece op in order
## {"cells": its drawn grid, "lo", "hi": its box, "parts": debris samples, "box": AABB at rest}.
var lo := Vector3i.MAX
var hi := Vector3i.MIN
var pieces: Array[Dictionary] = []


## The worker task.
func run() -> void:
	if mesher == null:
		_first()
	else:
		cells = cells.duplicate()
	for op: Dictionary in ops:
		var index: PackedInt32Array = op["index"]
		var box := _take(index)
		if op["piece"]:
			pieces.append(_piece(index, op["mats"], box))


func _first() -> void:
	if voxels == null:
		voxels = maker.call()
	var whole := CellGrid.new()
	whole.res = snapshot.res
	whole.dims = snapshot.dims
	whole.offset = snapshot.offset
	whole.cells = snapshot.cells.duplicate()
	for op: Dictionary in ops:
		var index: PackedInt32Array = op["index"]
		var mats: PackedByteArray = op["mats"]
		for k: int in index.size():
			whole.cells[index[k]] = mats[k]
	mesher = CellMesher.new(voxels, whole)
	cells = mesher.drawn(whole.cells)


## Empties these cells of the drawn grid; returns their box [lo, hi] and widens the job's.
func _take(index: PackedInt32Array) -> Array[Vector3i]:
	var w := mesher.dims.x
	var d := mesher.dims.z
	var plan := w * d
	var a := Vector3i.MAX
	var b := Vector3i.MIN
	for i: int in index:
		cells[i] = 0
		var c := Vector3i(i % w, i / plan, (i / w) % d)
		a = a.min(c)
		b = b.max(c)
	lo = lo.min(a)
	hi = hi.max(b)
	return [a, b]


## A falling piece: a grid holding exactly these cells (drawn as the building is), its samples.
func _piece(index: PackedInt32Array, mats: PackedByteArray, box: Array[Vector3i]) -> Dictionary:
	var own := PackedByteArray()
	own.resize(cells.size())
	own.fill(0)
	for k: int in index.size():
		own[index[k]] = mats[k]
	var w := mesher.dims.x
	var d := mesher.dims.z
	var plan := w * d
	var count := clampi(ceili(float(index.size()) * SAMPLES / CHUNK_CELLS), 1, index.size())
	var parts: Array[Dictionary] = []
	for j: int in count:
		var i := index[j * index.size() / count]
		var c := Vector3i(i % w, i / plan, (i / w) % d)
		var pos := mesher.origin + Vector3(c) * mesher.voxel
		parts.append({"pos": pos, "color": mesher.palette[mesher.looks[i]]})
	var half := Vector3.ONE * mesher.voxel * 0.5
	var at := mesher.origin + Vector3(box[0]) * mesher.voxel - half
	var size := Vector3(box[1] - box[0] + Vector3i.ONE) * mesher.voxel
	return {
		"cells": mesher.drawn(own),
		"lo": box[0],
		"hi": box[1],
		"parts": parts,
		"box": AABB(at, size),
	}
