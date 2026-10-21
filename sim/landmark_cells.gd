class_name LandmarkCells
extends CellGrid
## A landmark's fine destruction grid (D-094 WP6): the baked model (data/landmarks.json "kvox",
## tools/landmarks/bake.py) read as cells, on the same grid BuildingCells uses (RES cells per sim
## unit, cells local to the footprint), so LandmarkVoxels' voxels and this grid are the same cells.
## A cell's material is its colour's class: the shape's "ground" colours are landmark_pitch, greys
## landmark_wall, reds landmark_seat, the rest landmark_other (the same tests LandmarkVoxels runs).
## A ring landmark's arcs (Arcs, the stadium) carry over to cells: its sections are the same plan
## columns, and an arc that has lost "arc_shed_cells" cells since it last shed (data/tuning.json
## "destruction") brings down every cell of it above the stub as one toppling section, like
## Structure.settle() does with chunks. shed() reports the section, the caller clears it with
## clear_cell(). Pure sim: no clock, no RNG, no scene.

const GREY := 0.12
const RED := 0.3
## How near (per channel, 0-255) a voxel's colour must be to a ground colour.
const GROUND_MATCH := 24
const MAGIC := "KVOX"

## A parsed model per landmark id: {"cells": PackedInt32Array x, y, z triples, "mats": names}.
static var _cache: Dictionary = {}

var b: RampageSim.Building
## The chunk shape's arcs, or null for a landmark without them.
var arcs: Arcs
var _live := PackedInt32Array()
var _whole := PackedInt32Array()
var _members: Array[PackedInt32Array] = []
var _shed_at := 0


func _init(p_building: RampageSim.Building) -> void:
	b = p_building
	arcs = b.frame.arcs if b.frame != null else null
	res = cell_res()
	_shed_at = Num.i(Content.section("destruction").get("arc_shed_cells", 1))
	var model := _model(b.landmark)
	var xyz: PackedInt32Array = model["xyz"]
	var mats: PackedByteArray = model["mats"]
	var lo := Vector3i.ZERO
	var hi := Vector3i(b.w * res - 1, b.height * res - 1, b.d * res - 1)
	for i: int in mats.size():
		var c := Vector3i(xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2])
		lo = lo.min(c)
		hi = hi.max(c)
	offset = lo
	dims = hi - lo + Vector3i.ONE
	cells = PackedByteArray()
	cells.resize(dims.x * dims.y * dims.z)
	var arc_n := arcs.arc_count() if arcs != null else 0
	_live.resize(arc_n)
	_members.resize(arc_n)
	for i: int in mats.size():
		var c := Vector3i(xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2])
		cells[index(c - offset)] = mats[i]
		var g := arc_of(c)
		if g < 0:
			continue
		_live[g] += 1
		if c.y >= arcs.stub * res:
			_members[g].append(index(c - offset))
	_whole = _live.duplicate()


## The arc a building-local cell belongs to (Arcs.arc_at on its plan column), or -1.
func arc_of(local: Vector3i) -> int:
	if arcs == null or local.x < 0 or local.z < 0:
		return -1
	var x := local.x / res
	var z := local.z / res
	if x >= b.w or z >= b.d:
		return -1
	return arcs.arc_at(x, z)


## Empties a cell; an arc's standing count follows.
func clear_cell(local: Vector3i) -> void:
	if at(local) == 0:
		return
	super(local)
	var g := arc_of(local)
	if g >= 0:
		_live[g] -= 1


## Takes the standing arcs as the baseline: what the chunk Structure already shed (and
## CellPromoter has emptied) is not a new loss.
func rebase() -> void:
	_whole = _live.duplicate()


## The sections to bring down now: for each arc that lost arc_shed_cells cells since it last shed,
## every cell of it still standing above the stub, as {"cells": Array[Vector3i] (building-local),
## "kind": "topple", "pivot": Vector3 (in cells), "dir": Vector2i}. The caller clears them.
func shed() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if arcs == null:
		return out
	var plan := dims.x * dims.z
	for g: int in _live.size():
		if _whole[g] - _live[g] < _shed_at:
			continue
		var section: Array[Vector3i] = []
		for i: int in _members[g]:
			if cells[i] != 0:
				section.append(Vector3i(i % dims.x, i / plan, (i / dims.x) % dims.z) + offset)
		_whole[g] = _live[g] - section.size()
		if not section.is_empty():
			var dir := arcs.dir_of(g)
			out.append(
				{"cells": section, "kind": "topple", "pivot": _pivot(section, dir), "dir": dir}
			)
	return out


## The edge it tips over: the section's far side toward `dir`, at the top of the stub.
func _pivot(section: Array[Vector3i], dir: Vector2i) -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var sum := Vector2.ZERO
	for c: Vector3i in section:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
		hi = Vector2(maxf(hi.x, c.x + 1), maxf(hi.y, c.z + 1))
		sum += Vector2(c.x + 0.5, c.z + 0.5)
	var mid := sum / section.size()
	var px := hi.x if dir.x > 0 else (lo.x if dir.x < 0 else mid.x)
	var pz := hi.y if dir.y > 0 else (lo.y if dir.y < 0 else mid.y)
	return Vector3(px, arcs.stub * res, pz)


## The material of a baked colour, as the id of its landmark_ class.
static func material_of(c: Color, ground: Array) -> String:
	for key: Variant in ground:
		var g := Color(str(key))
		var off := Vector3(absf(c.r - g.r), absf(c.g - g.g), absf(c.b - g.b)) * 255.0
		if maxf(off.x, maxf(off.y, off.z)) <= GROUND_MATCH:
			return "landmark_pitch"
	if maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < GREY:
		return "landmark_wall"
	if c.r > c.g + RED and c.r > c.b + RED:
		return "landmark_seat"
	return "landmark_other"


## The landmark's model as cells, read once: {"xyz": x, y, z per voxel, "mats": material ids}.
## Empty if the shape or file is missing.
static func _model(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var shape: Dictionary = Content.landmarks().get(id, {})
	var out := {"xyz": PackedInt32Array(), "mats": PackedByteArray()}
	var path := str(shape.get("kvox", ""))
	if path != "" and FileAccess.file_exists(path):
		var ground: Array = shape.get("ground", [])
		out = _read(path, ground)
	_cache[id] = out
	return out


## The first pose of a .kvox (Kvox.read's format): version 1 holds one pose, version 2 a count.
static func _read(path: String, ground: Array) -> Dictionary:
	var xyz := PackedInt32Array()
	var mats := PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != MAGIC:
		return {"xyz": xyz, "mats": mats}
	var ids := material_ids()
	var version := f.get_32()
	var first := 0
	if version == 1:
		first = f.get_32()
	else:
		f.get_32()
	f.get_16()  # model height
	var voxels := first if version == 1 else f.get_32()
	var by_class: Dictionary[int, int] = {}
	for _v: int in voxels:
		var x := _signed16(f.get_16())
		var y := _signed16(f.get_16())
		var z := _signed16(f.get_16())
		var color := Color8(f.get_8(), f.get_8(), f.get_8())
		f.get_8()  # face flags: a view look
		var key := color.to_rgba32()
		if not by_class.has(key):
			by_class[key] = Num.i(ids[material_of(color, ground)])
		xyz.append_array(PackedInt32Array([x, y, z]))
		mats.append(by_class[key])
	return {"xyz": xyz, "mats": mats}


static func _signed16(v: int) -> int:
	return v - 65536 if v >= 32768 else v
