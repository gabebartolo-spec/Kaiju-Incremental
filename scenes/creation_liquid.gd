class_name CreationLiquid
extends RefCounted
## A liquid of the Kaiju Creation lab drawn on its own (D-207): the croc's vial, the Special K
## canister and the injector's glass barrel. Its cells glow in the liquid's colour up to a level
## (0..1, filled from the bottom) and show their empty look above it, so a vial drains and the
## barrel fills as the injector draws, then empties as it dispenses.

## The liquid's blocks (add it under the prop's node).
var node: MultiMeshInstance3D
var _mm: MultiMesh
var _cells: Array[Vector3i] = []
var _empty: Array[Color] = []
var _full := Color.WHITE
var _y0 := 0
var _y1 := 0
var _level := -1.0


## empties: cell -> the colour it shows empty; full: the liquid's colour (alpha 0 glows).
func _init(empties: Dictionary, full: Color, level: float) -> void:
	_full = full
	var vox := VoxelBuilder.new()
	for cell: Vector3i in empties:
		var col: Color = empties[cell]
		vox.put_color(cell, col)
	vox.inset = CreationSet.gapless()
	var voxel := Num.f(CreationSet.cfg()["voxel"])
	node = vox.build({}, voxel, Num.f(CreationSet.cfg()["glow"]), Vector3.ZERO)
	_mm = node.multimesh
	_cells = vox.built_cells
	for cell: Vector3i in _cells:
		var col: Color = empties[cell]
		_empty.append(col)
	if not _cells.is_empty():
		_y0 = _cells[0].y
		_y1 = _cells[_cells.size() - 1].y
	set_level(level)


## Fills the liquid to `level` (0 empty, 1 full) from the bottom up.
func set_level(level: float) -> void:
	var f := clampf(level, 0.0, 1.0)
	if is_equal_approx(f, _level):
		return
	_level = f
	var top := _y0 + f * (_y1 - _y0 + 1)
	for i: int in _cells.size():
		var col := _full if _cells[i].y < top else _empty[i]
		_mm.set_instance_color(i, Look.jitter(col, _cells[i], 0))


## The liquid's colour from now on (alpha 0 glows).
func set_color(full: Color) -> void:
	if full == _full:
		return
	_full = full
	var keep := _level
	_level = -1.0
	set_level(keep)


func level() -> float:
	return _level
