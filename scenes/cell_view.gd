class_name CellView
extends Node3D
## A carved building's look (D-094 WP4): one MeshInstance3D per REGION^3 block of its fine grid
## (CellMesher), so a carve rebuilds only the blocks it touched. Meshing runs on the
## WorkerThreadPool (one task per block, native when the extension is loaded); the finished
## arrays become meshes on the main thread. A carve that lands while a batch is still meshing
## waits for it, then the blocks it touched are meshed again from the newest grid, so the view
## never shows an older grid after a newer one. A batch goes on screen at once (every block of
## it the same frame, never half old and half new): its meshes are made first, under a per-frame
## time budget every CellView shares (upload_usec, 0 in tests and captures), then swapped in
## together, when `gate` allows (CityCarve holds a batch until the falling pieces it frees are
## drawn, so a section never blinks out before its piece shows). It draws CellMesher.drawn() of
## the grid (a balcony floor stays undrawn, as in the baked view). Presentation only: it reads
## the grid the sim carves and decides nothing.

## The first build is on screen (once).
signal drawn
## A batch is on screen: every carve up to ticket `upto` (carved()'s return) is drawn.
signal batch_done(upto: int)

## The frame the shared upload clock counts, and what was spent in it (spend()).
static var _clock_frame := -1
static var _clock_usec := 0
## The most main-thread time one frame spent on fine-grid views (meshes, swaps, CityCarve).
static var worst_usec := 0

## Meshes in their own world space (CellMesher.origin is world), as BuildingView's are.
var mesher: CellMesher
var material: Material
## Region -> its MeshInstance3D (absent: no visible face there).
var parts: Dictionary = {}
## Regions meshed since this view was made, and those of the last finished batch (tests).
var remeshed := 0
var last_batch: Array[Vector3i] = []
## When on (tests), region -> the arrays its mesh was built from (CellMesher.mesh_region).
var keep_arrays := false
var arrays: Dictionary = {}
## Main-thread microseconds a frame that every CellView together may spend making meshes of
## finished arrays (0: no limit); a batch past it is finished on later frames, then swapped in.
var upload_usec := 0
## Whether the first build is on screen (`drawn` has fired).
var is_drawn := false
## Carves asked so far (each carved() call's ticket) and the last one wholly on screen.
var carves := 0
var drawn_carves := 0
## gate.call(upto) -> bool: whether a finished batch that draws carves up to `upto` may go on
## screen now (unset: always). flush() ignores it.
var gate: Callable

## Whether the grids handed in are CellMesher.drawn already (CityCarve's).
var _fed := false
var _cells: PackedByteArray
var _dirty: Dictionary = {}
var _task := -1
var _batch: Array[Vector3i] = []
var _batch_carves := 0
var _results: Array = []
## Per block of the finished batch: its new mesh (null: no face) and, for a block with no part
## yet, the part made for it, hidden until the swap.
var _made: Array = []
var _fresh: Array = []
## The next finished block to make a mesh of (-1: no finished batch on hand).
var _next := -1


## cells: the building's grid now (its bytes are copied on write, so the sim may carve on).
## regions empty: every block, and `cells` is the sim's grid (tests, captures, promote()); else
## only these blocks, and `cells` and every later carve's are CellMesher.drawn already (CityCarve:
## the building, or a falling piece's own grid and the blocks round it).
func _init(
	p_mesher: CellMesher, cells: PackedByteArray, p_material: Material, regions := []
) -> void:
	mesher = p_mesher
	material = p_material
	_fed = not regions.is_empty()
	_cells = cells if _fed else mesher.drawn(cells)
	if not _fed:
		regions = mesher.all_regions()
	for r: Vector3i in regions:
		_dirty[r] = true
	_start()


## The grid changed inside the cell box [lo, hi] (grid cells, inclusive): its touching blocks
## are meshed again from `cells`. Returns this carve's ticket (drawn once drawn_carves reaches it).
func carved(cells: PackedByteArray, lo: Vector3i, hi: Vector3i) -> int:
	_cells = cells if _fed else mesher.drawn(cells)
	for r: Vector3i in mesher.regions_touching(lo, hi):
		_dirty[r] = true
	carves += 1
	if _idle():
		_start()
	return carves


## Whether every carve so far is drawn.
func settled() -> bool:
	return _idle() and _dirty.is_empty()


## Blocks until every carve so far is drawn (tests, captures).
func flush() -> void:
	while not settled():
		if _idle():
			_start()
		_take_batch(true)
		_upload(0, true)


## Screen-door share (1 = solid), as BuildingView.set_opacity.
func set_opacity(value: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("opacity", value)


## Adds `usec` of main-thread fine-grid work to this frame's shared clock (CityCarve's own work
## counts too) and keeps worst_usec, the costliest frame so far.
static func spend(usec: int) -> void:
	var frame := Engine.get_process_frames()
	if frame != _clock_frame:
		_clock_frame = frame
		_clock_usec = 0
	_clock_usec += usec
	worst_usec = maxi(worst_usec, _clock_usec)


func _process(_delta: float) -> void:
	_take_batch(false)
	_upload(upload_usec, false)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1


func _idle() -> bool:
	return _task < 0 and _next < 0


func _start() -> void:
	if _dirty.is_empty():
		return
	_batch.assign(_dirty.keys())
	_dirty.clear()
	_batch_carves = carves
	_results.clear()
	_results.resize(_batch.size())
	_task = WorkerThreadPool.add_group_task(
		_mesh_one.bind(mesher, _cells, _batch.duplicate(), _results), _batch.size()
	)


## One worker task: block batch[i] of `cells`, its arrays into results[i]. The mesh resource is
## made on the main thread (_upload): a mesh RID made on a worker raced the dummy renderer's
## allocator in the headless bench ("Initializing already initialized RID").
static func _mesh_one(
	i: int, m: CellMesher, cells: PackedByteArray, batch: Array[Vector3i], results: Array
) -> void:
	results[i] = m.mesh_region(cells, batch[i])


## The running batch's arrays, once the workers are done (wait: block until they are).
func _take_batch(wait: bool) -> void:
	if _task < 0 or not (wait or WorkerThreadPool.is_group_task_completed(_task)):
		return
	WorkerThreadPool.wait_for_group_task_completion(_task)
	_task = -1
	_next = 0
	_made.clear()
	_made.resize(_batch.size())
	_fresh.clear()
	_fresh.resize(_batch.size())


## Makes meshes of the finished batch's blocks in order until this frame's shared clock passes
## `budget` microseconds (0: all of them); all made, the batch goes on screen at once (force:
## whatever the gate says), then the next one starts.
func _upload(budget: int, force: bool) -> void:
	if _next < 0:
		return
	spend(0)
	while _next < _batch.size():
		if budget > 0 and _clock_usec >= budget:
			return
		var t0 := Time.get_ticks_usec()
		_make(_next)
		_next += 1
		spend(Time.get_ticks_usec() - t0)
	if not force and gate.is_valid() and not gate.call(_batch_carves):
		return
	var t1 := Time.get_ticks_usec()
	_swap()
	spend(Time.get_ticks_usec() - t1)
	if not is_drawn:
		is_drawn = true
		drawn.emit()
	batch_done.emit(drawn_carves)
	_start()


## Block k's mesh, and a hidden part for it when it has none yet (made now so the swap is cheap).
func _make(k: int) -> void:
	var mesh := CellMesher.to_mesh(_results[k])
	_made[k] = mesh
	if mesh != null and not parts.has(_batch[k]):
		var part := MeshInstance3D.new()
		part.material_override = material
		part.visible = false
		add_child(part)
		_fresh[k] = part


## Every block of the batch shows its new mesh, the same frame.
func _swap() -> void:
	for k: int in _batch.size():
		var r := _batch[k]
		var mesh: ArrayMesh = _made[k]
		var part: MeshInstance3D = parts.get(r, null)
		if keep_arrays:
			arrays[r] = _results[k]
		if mesh == null:
			if part != null:
				remove_child(part)
				part.free()
				parts.erase(r)
			continue
		if part == null:
			part = _fresh[k]
			parts[r] = part
		part.mesh = mesh
		part.visible = true
	remeshed += _batch.size()
	last_batch = _batch.duplicate()
	drawn_carves = _batch_carves
	_results.clear()
	_made.clear()
	_fresh.clear()
	_next = -1
