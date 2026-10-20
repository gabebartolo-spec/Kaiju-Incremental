class_name CellPromoter
extends RefCounted
## Lazy promotion to the fine destruction grid (D-094): a building stays on its chunk Structure
## until its first hit; then its BuildingCells grid is made, once, with every chunk the
## Structure has already lost emptied, and kept for every later hit. A whole city of fine grids
## would be ~100 MB (docs/research/DESTRUCTION_SPIKE.md), so only buildings the kaiju touches
## pay for one. RampageSim promotes through Carving (WP7). Landmarks keep their baked chunk shape
## until the landmark port (WP6): on_hit() gives them null.

## Building index -> BuildingCells, for the buildings hit so far.
var grids: Dictionary = {}


func promoted(n: int) -> bool:
	return grids.has(n)


## The fine grid of building n, or null while it has not been hit.
func grid(n: int) -> BuildingCells:
	return grids.get(n, null)


## Building n (b) was hit: its fine grid, made now if this is the first hit. party: as
## BuildingCells' (the floors a neighbour covers per side).
func on_hit(n: int, b: RampageSim.Building, party: Dictionary = {}) -> BuildingCells:
	if grids.has(n):
		return grids[n]
	if b.landmark != "":
		return null
	var cells := BuildingCells.new(b, party)
	if b.frame != null:
		for y: int in b.frame.h:
			for z: int in b.frame.d:
				for x: int in b.frame.w:
					if not b.frame.alive(Vector3i(x, y, z)):
						cells.clear_chunk(Vector3i(x, y, z))
	grids[n] = cells
	return cells
