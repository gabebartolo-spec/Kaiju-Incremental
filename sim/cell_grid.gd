class_name CellGrid
extends RefCounted
## The fine destruction grid of one building or landmark (D-094): RES cells per sim unit
## (data/tuning.json "destruction"), one byte per cell (0 empty, else a data/materials.json id),
## x fastest, then z, then y. BuildingCells makes one from a generated facade, LandmarkCells from a
## baked landmark model; both are read the same way. Pure sim.

## Cells per sim unit.
var res: int
## Grid size in cells.
var dims: Vector3i
## The building-local cell (BuildingVoxels' coordinates) of grid cell (0, 0, 0): the grid also
## holds what stands proud of the footprint (sills, awnings, signs) and the roof gear.
var offset: Vector3i
## One byte per cell, index x + z * dims.x + y * dims.x * dims.z.
var cells: PackedByteArray


## Cells per sim unit, from data/tuning.json.
static func cell_res() -> int:
	return Num.i(Content.section("destruction").get("res", 0))


## Material name -> id (data/materials.json).
static func material_ids() -> Dictionary:
	var out := {}
	for m: Dictionary in Content.materials():
		out[str(m["name"])] = Num.i(m["id"])
	return out


func index(c: Vector3i) -> int:
	return c.x + c.z * dims.x + c.y * dims.x * dims.z


## The material at a building-local cell (BuildingVoxels' coordinates); 0 outside the grid.
func at(local: Vector3i) -> int:
	var c := local - offset
	if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= dims.x or c.y >= dims.y or c.z >= dims.z:
		return 0
	return cells[index(c)]


## Cells that are not empty.
func count() -> int:
	return cells.size() - cells.count(0)


## Empties every cell of a structural chunk (one sim unit, one floor) that is gone.
func clear_chunk(chunk: Vector3i) -> void:
	_clear_rows(chunk)


## Empties a chunk's cells and returns how many were standing. Row by row on the flat index: a
## landmark's promote clears thousands of chunks in one step (the wheel took 1.75 s through
## clear_cell, docs/research/2026-10-31-cpu-profile.md).
func _clear_rows(chunk: Vector3i) -> int:
	var lost := 0
	var lo := chunk * res - offset
	var x0 := maxi(lo.x, 0)
	var x1 := mini(lo.x + res, dims.x)
	for y: int in range(maxi(lo.y, 0), mini(lo.y + res, dims.y)):
		for z: int in range(maxi(lo.z, 0), mini(lo.z + res, dims.z)):
			var row := z * dims.x + y * dims.x * dims.z
			for x: int in range(x0, x1):
				if cells[row + x] != 0:
					cells[row + x] = 0
					lost += 1
	return lost


## Empties one building-local cell (a no-op outside the grid or on an empty cell).
func clear_cell(local: Vector3i) -> void:
	var c := local - offset
	if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= dims.x or c.y >= dims.y or c.z >= dims.z:
		return
	cells[index(c)] = 0
