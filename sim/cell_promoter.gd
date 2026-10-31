class_name CellPromoter
extends RefCounted
## Lazy promotion to the fine destruction grid (D-094): a building stays on its chunk Structure
## until its first hit; then its BuildingCells grid is made, once, with every chunk the
## Structure has already lost emptied, and kept for every later hit. A whole city of fine grids
## would be ~100 MB (docs/research/DESTRUCTION_SPIKE.md), so only buildings the kaiju touches
## pay for one. A landmark or a pool building (CityPool) gets a LandmarkCells grid (its baked
## model, and the arcs of a ring); a red-barrel site a HazardCells; a building a BuildingCells.
## RampageSim promotes through Carving (WP7).

## How many buildings past the one warming have their cells made ahead on workers (tuning
## warm_ahead; WarmOrder.ahead).
var ahead := 0
## Building index -> BuildingCells, LandmarkCells or HazardCells, for the buildings hit so far.
var grids: Dictionary = {}
## Cells made ahead of their first use (prepare), by building; dropped (drop_ready) once they
## could go stale. Not in `grids`, so nothing that asks what is promoted sees them.
var ready: Dictionary = {}
## Building index -> [WorkerThreadPool task, [its BuildingCells]], for cells started ahead (start).
var _jobs: Dictionary = {}


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


## Starts building n's cells on a worker thread (Carving.warm's look-ahead); its first on_hit
## waits for them. Only a plain building's: their making reads nothing the run changes (its
## shape, style and party walls; the native generator holds no state), and the chunks it has
## lost are cleared on the main thread when they are taken, so they come out the same as made
## then. A landmark or hazard (its arcs, its own models) is made on the main thread as before.
func start(n: int, b: RampageSim.Building, party: Dictionary) -> void:
	if grids.has(n) or ready.has(n) or _jobs.has(n):
		return
	if b.landmark != "" or b.model != "" or b.hazard != "":
		return
	VoxelSupport.native()  # the shared generator is made here, on the main thread
	var out: Array = [null]
	var job := func() -> void: out[0] = BuildingCells.new(b, party)
	var task := WorkerWait.add(WorkerThreadPool.add_task(job, true))
	_jobs[n] = [task, out]


## Building n changed under its cells (Endless regrows it): waits out and drops what was made.
func forget(n: int) -> void:
	if _jobs.has(n):
		_take(n)
	grids.erase(n)
	ready.erase(n)


func _take(n: int) -> BuildingCells:
	var job: Array = _jobs[n]
	_jobs.erase(n)
	WorkerWait.wait(Num.i(job[0]))
	var out: Array = job[1]
	return out[0]


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
	var cells := _make(n, b, party)
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


## Building n's fresh grid: its own kind's cells, or the ones started ahead on a worker.
func _make(n: int, b: RampageSim.Building, party: Dictionary) -> CellGrid:
	if b.landmark != "" or b.model != "":  # a landmark or a pool building (D-253)
		return LandmarkCells.new(b)
	if b.hazard != "":
		return HazardCells.new(b)  # a red barrel: its own model (HazardShape)
	if _jobs.has(n):  # started ahead on a worker (start)
		return _take(n)
	return BuildingCells.new(b, party)
