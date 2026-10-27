extends RefCounted
## Render plan item 9 (tuning render_opt.remesh_high_priority) for tests/run_cell_mesh_tests.gd:
## the flag is ON by default; a CellView reads it when it is made; the blocks come out byte for
## byte the same on either queue (CellMesher.digest of every block after a carve sequence); and
## every batch's swap-in is timed (finish_us: one entry per batch, the last in last_finish_us).
## Seeded by design: a fixed building and a fixed carve sequence, no random numbers.

const CellFaces := preload("res://tests/lib/cell_faces.gd")
## A carve sequence on the fixture (grid cells; [centre, radius]): a punch through the street face,
## a bite out of a corner, a cut across a block boundary, a hole through the roof.
const CARVE_AT: Array[Vector3] = [
	Vector3(1.0, 30.0, 12.0),
	Vector3(0.0, 44.0, 0.0),
	Vector3(16.0, 16.0, 16.0),
	Vector3(12.0, 47.0, 12.0),
]
const CARVE_R: Array[float] = [5.0, 7.0, 6.0, 4.0]

var _check: Callable
var _native: bool


## check: the runner's check; native: whether the KaijuMesher extension is loaded.
func _init(p_check: Callable, p_native: bool) -> void:
	_check = p_check
	_native = p_native


func run() -> void:
	var opt := Content.section("render_opt")
	var was: Variant = opt.get("remesh_high_priority", null)
	_check.call(was == true, "render_opt.remesh_high_priority is ON by default")
	var shown := {}
	for high: bool in [true, false]:
		opt["remesh_high_priority"] = high
		shown["high" if high else "low"] = _carve_all(high)
	opt["remesh_high_priority"] = was
	var high_digests: Dictionary = shown["high"]
	var low_digests: Dictionary = shown["low"]
	_check.call(
		not high_digests.is_empty() and high_digests == low_digests,
		(
			"the high and low queues build the same bytes for every block (%d blocks)"
			% high_digests.size()
		)
	)


## Builds the fixture's view with the flag as set, carves it in sequence (each drawn before the
## next), checks the view and its timers, and returns region -> digest of what it shows.
func _carve_all(high: bool) -> Dictionary:
	var which := "high" if high else "low"
	var b := RampageSim.Building.new()
	b.x = 10.5
	b.z = 4.5
	b.w = 3
	b.d = 3
	b.height = 6
	b.tier = 2
	b.style = 0
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	var grid := BuildingCells.new(b, {})
	var m := CellMesher.new(BuildingVoxels.new(b, Color("8a7f72"), {}), grid, _native)
	var cells := grid.cells
	var view := CellView.new(m, cells, StandardMaterial3D.new())
	view.keep_arrays = true
	view.keep_timings = true
	_check.call(
		view.high_priority == high, "a view made with the flag %s queues %s" % [high, which]
	)
	view.flush()
	for k: int in CARVE_AT.size():
		cells = cells.duplicate()
		var box := CellFaces.carve(cells, m.dims, CARVE_AT[k], CARVE_R[k])
		view.carved(cells, box[0], box[1])
		view.flush()
	var batches := 1 + CARVE_AT.size()
	_check.call(
		view.finish_us.size() == batches,
		"%s: one finish time per batch (%d of %d)" % [which, view.finish_us.size(), batches]
	)
	var timed := 0
	for us: int in view.finish_us:
		timed += 1 if us > 0 else 0
	_check.call(timed == batches, "%s: every finish took measurable time (%d)" % [which, timed])
	_check.call(
		view.last_finish_us == view.finish_us[-1],
		"%s: last_finish_us is the last batch's time" % which
	)
	var digests := {}
	for r: Vector3i in view.arrays:
		var made: Array = view.arrays[r]
		digests[r] = CellMesher.digest(made)
	view.free()
	return digests
