class_name CellPromoter
extends RefCounted
## Lazy promotion to the fine destruction grid (D-094): a building stays on its chunk Structure
## until its first hit; then its BuildingCells grid is made, once, with every chunk the
## Structure has already lost emptied, and kept for every later hit. A whole city of fine grids
## would be ~100 MB (docs/research/DESTRUCTION_SPIKE.md), so only buildings the kaiju touches
## pay for one. A landmark or a pool building (CityPool) gets a LandmarkCells grid (its baked
## model, and the arcs of a ring); a red-barrel site a HazardCells; a building a BuildingCells.
## RampageSim promotes through Carving (WP7).

## Building index -> BuildingCells, LandmarkCells or HazardCells, for the buildings hit so far.
var grids: Dictionary = {}
## Cells made ahead of their first use (prepare), by building; dropped (drop_ready) once they
## could go stale. Not in `grids`, so nothing that asks what is promoted sees them.
var ready: Dictionary = {}


func promoted(n: int) -> bool:
	return grids.has(n)


## The fine grid of building n, or null while it has not been hit.
func grid(n: int) -> CellGrid:
	return grids.get(n, null)


## Makes building n's cells now (the work on_hit would do) and keeps them for its first on_hit.
func prepare(n: int, b: RampageSim.Building, party: Dictionary = {}) -> void:
	if grids.has(n) or ready.has(n):
		return
	ready[n] = on_hit(n, b, party)
	grids.erase(n)


## Forgets every prepared grid not yet used (the buildings may change from here on).
func drop_ready() -> void:
	ready.clear()


## Building n (b) was hit: its fine grid, made now if this is the first hit. party: as
## BuildingCells' (a landmark takes none; the floors a neighbour covers per side).
func on_hit(n: int, b: RampageSim.Building, party: Dictionary = {}) -> CellGrid:
	if grids.has(n):
		return grids[n]
	if ready.has(n):  # made at load (prepare): the same cells, nothing has touched it since
		grids[n] = ready[n]
		ready.erase(n)
		return grids[n]
	var cells: CellGrid
	if b.landmark != "" or b.model != "":  # a landmark or a pool building (D-253)
		cells = LandmarkCells.new(b)
	elif b.hazard != "":
		cells = HazardCells.new(b)  # a red barrel: its own model (HazardShape)
	else:
		cells = BuildingCells.new(b, party)
	if b.frame != null:
		for y: int in b.frame.h:
			for z: int in b.frame.d:
				for x: int in b.frame.w:
					if not b.frame.alive(Vector3i(x, y, z)):
						cells.clear_chunk(Vector3i(x, y, z))
	if cells is LandmarkCells:  # sections the chunks already shed are not new losses
		(cells as LandmarkCells).rebase()
	grids[n] = cells
	return cells
