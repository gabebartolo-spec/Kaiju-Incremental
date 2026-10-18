class_name PropField
extends RefCounted
## Many small static props (cars, trees, streetlights) in one MultiMesh, each prop a group of
## instances that can be crushed (flattened) when the kaiju stomps on it, or for a tree felled:
## a short stump left standing and the rest laid flat along the way it was pushed (critic on
## #55: squashed trees read as bushes). Presentation only: the sim never knows props exist.

const BUCKET := 8.0  # props are filed by ground cell of this size, so a crush looks nearby only
const STUMP := 2  # a felled tree leaves its lowest cells this many high standing

var vox := VoxelBuilder.new()
var voxel: float
var fall_seconds := 0.4  # how long a felled tree takes to come down
var fell_lighten := 0.0  # a felled tree's cells go this much toward white, to read on the grass
var felled: Array[Vector3] = []  # stumps whose tree landed since the owner last drained this
var _groups: Array[Dictionary] = []
var _buckets: Dictionary = {}  # Vector2i cell -> Array of group indices
var _mmi: MultiMeshInstance3D
var _heading := Vector2.ZERO  # the way the current crush pushes, or zero for away from it
var _falling: Array[Dictionary] = []  # trees still coming down (tick)


func _init(p_voxel: float) -> void:
	voxel = p_voxel


## Adds a prop: `shape` fills a VoxelBuilder in prop-local cells; `at` is its world base.
## Each prop is built into the shared builder offset by its own cell origin. fells: a tree,
## felled rather than flattened.
func add(at: Vector3, shape: Callable, fells := false) -> void:
	var local := VoxelBuilder.new()
	shape.call(local)
	var offset := Vector3i((at / voxel).round())
	offset.y = 0
	var before := vox.cells.size()
	for cell: Vector3i in local.cells:
		vox.put(cell + offset, local.key_at(cell))
	_groups.append(
		{
			"at": at,
			"cells": vox.cells.size() - before,
			"offset": offset,
			"local": local,
			"fells": fells
		}
	)
	var key := Vector2i(floori(at.x / BUCKET), floori(at.z / BUCKET))
	if not _buckets.has(key):
		_buckets[key] = []
	var bucket: Array = _buckets[key]
	bucket.append(_groups.size() - 1)


## glow: strength for palette colours with alpha 0 (lamps).
## glow: strength for palette colours with alpha 0 (lamps).
func build(palette: Dictionary, salt: int, glow: float) -> MultiMeshInstance3D:
	vox.salt = salt
	_mmi = vox.build(palette, voxel, glow, Vector3.ZERO)
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Each prop remembers which instances are its voxels, so crushing touches only those.
	var index_of := {}
	for i: int in vox.built_cells.size():
		index_of[vox.built_cells[i]] = i
	for group: Dictionary in _groups:
		var local: VoxelBuilder = group["local"]
		var offset: Vector3i = group["offset"]
		var ids := PackedInt32Array()
		var heights := PackedInt32Array()  # each instance's prop-local cell height
		for cell: Vector3i in local.cells:
			if index_of.has(cell + offset):
				var idx: int = index_of[cell + offset]
				ids.append(idx)
				heights.append(cell.y)
		group["ids"] = ids
		group["heights"] = heights
		group.erase("local")
	return _mmi


## Flattens every prop whose base is within `radius` of `at` (ground plane); trees fall along
## `heading`, or away from `at` when it is zero.
func crush(at: Vector3, radius: float, heading := Vector2.ZERO) -> void:
	if _mmi == null:
		return
	_heading = heading
	var mm := _mmi.multimesh
	var lo := Vector2i(floori((at.x - radius) / BUCKET), floori((at.z - radius) / BUCKET))
	var hi := Vector2i(floori((at.x + radius) / BUCKET), floori((at.z + radius) / BUCKET))
	for bx: int in range(lo.x, hi.x + 1):
		for bz: int in range(lo.y, hi.y + 1):
			var bucket: Array = _buckets.get(Vector2i(bx, bz), [])
			for index: int in bucket:
				var group: Dictionary = _groups[index]
				var base: Vector3 = group["at"]
				if Vector2(base.x - at.x, base.z - at.z).length() <= radius:
					_crush_group(mm, group, at)


## Flattens every prop whose base lies under a body: `foot` is its ground box (x across, y
## along) in the frame `body` (scale included), so the box turns and grows with it; trees fall
## along `heading`.
func crush_box(body: Transform3D, foot: Rect2, heading: Vector2) -> void:
	if _mmi == null:
		return
	_heading = heading
	var mm := _mmi.multimesh
	var reach := maxf(foot.position.length(), foot.end.length()) * body.basis.get_scale().x
	var at := body.origin
	var into := body.affine_inverse()
	var lo := Vector2i(floori((at.x - reach) / BUCKET), floori((at.z - reach) / BUCKET))
	var hi := Vector2i(floori((at.x + reach) / BUCKET), floori((at.z + reach) / BUCKET))
	for bx: int in range(lo.x, hi.x + 1):
		for bz: int in range(lo.y, hi.y + 1):
			var bucket: Array = _buckets.get(Vector2i(bx, bz), [])
			for index: int in bucket:
				var group: Dictionary = _groups[index]
				var base: Vector3 = group["at"]
				var local := into * Vector3(base.x, at.y, base.z)
				if foot.has_point(Vector2(local.x, local.z)):
					_crush_group(mm, group, at)


## Brings the felling trees down a step: each turns its quarter over fall_seconds, slow at
## first and fast at the end, the way a trunk goes over.
func tick(delta: float) -> void:
	if _mmi == null:
		return
	var mm := _mmi.multimesh
	for fall: Dictionary in _falling.duplicate():
		var done := minf(1.0, Num.f(fall["t"]) + delta / maxf(0.01, fall_seconds))
		fall["t"] = done
		var axis: Vector3 = fall["axis"]
		var turn := Basis(axis, PI * 0.5 * done * done)
		var pivot: Vector3 = fall["pivot"]
		var ids: PackedInt32Array = fall["ids"]
		var starts: PackedVector3Array = fall["starts"]
		for k: int in ids.size():
			var t := mm.get_instance_transform(ids[k])
			t.origin = pivot + turn * (starts[k] - pivot)
			mm.set_instance_transform(ids[k], t)
		if done >= 1.0:
			felled.append(fall["stump"])
			_falling.erase(fall)


func _crush_group(mm: MultiMesh, group: Dictionary, at: Vector3) -> void:
	if group.get("crushed", false):
		return
	group["crushed"] = true
	if group.get("fells", false):
		_fell(mm, group, at)
		return
	var ids: PackedInt32Array = group["ids"]
	for i: int in ids:
		var t := mm.get_instance_transform(i)
		t.origin.y = t.origin.y * 0.2 + voxel * 0.1
		t.basis = Basis.from_scale(Vector3(1.15, 0.25, 1.15))
		mm.set_instance_transform(i, t)


## A tree falls: its cells above STUMP turn a quarter about the top of the stump, toward
## _heading (or away from the blow), over fall_seconds (tick), and lie along the ground.
func _fell(mm: MultiMesh, group: Dictionary, at: Vector3) -> void:
	var base: Vector3 = group["at"]
	var away := _heading
	if away.length() < 0.01:
		away = Vector2(base.x - at.x, base.z - at.z)
	if away.length() < 0.01:
		away = Vector2.RIGHT
	away = away.normalized()
	var axis := Vector3.UP.cross(Vector3(away.x, 0, away.y)).normalized()
	var ids: PackedInt32Array = group["ids"]
	var heights: PackedInt32Array = group["heights"]
	var pivot := Vector3.INF
	for k: int in ids.size():
		if heights[k] == 0:
			pivot = mm.get_instance_transform(ids[k]).origin
			break
	if pivot == Vector3.INF:
		return
	var stump := pivot
	pivot.y += STUMP * voxel
	var falls := PackedInt32Array()
	var starts := PackedVector3Array()
	for k: int in ids.size():
		mm.set_instance_color(ids[k], mm.get_instance_color(ids[k]).lightened(fell_lighten))
		if heights[k] >= STUMP:
			falls.append(ids[k])
			starts.append(mm.get_instance_transform(ids[k]).origin)
	_falling.append(
		{"ids": falls, "starts": starts, "pivot": pivot, "axis": axis, "t": 0.0, "stump": stump}
	)
