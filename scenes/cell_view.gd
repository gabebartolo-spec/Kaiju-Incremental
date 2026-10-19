class_name CellView
extends Node3D
## A carved building's look (D-094 WP4): one MeshInstance3D per REGION^3 block of its fine grid
## (CellMesher), so a carve rebuilds only the blocks it touched. Meshing runs on the
## WorkerThreadPool (one task per block, native when the extension is loaded); the finished
## arrays become meshes and are swapped in on the main thread. A carve that lands while a
## batch is still meshing waits for it, then the blocks it touched are meshed again from the
## newest grid, so the view never shows an older grid after a newer one. Presentation only:
## it reads the grid the sim carves and decides nothing.

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

var _cells: PackedByteArray
var _dirty: Dictionary = {}
var _task := -1
var _batch: Array[Vector3i] = []
var _results: Array = []


## cells: the building's grid now (its bytes are copied on write, so the sim may carve on).
func _init(p_mesher: CellMesher, cells: PackedByteArray, p_material: Material) -> void:
	mesher = p_mesher
	material = p_material
	_cells = cells
	for r: Vector3i in mesher.all_regions():
		_dirty[r] = true
	_start()


## The grid changed inside the cell box [lo, hi] (grid cells, inclusive): its touching blocks
## are meshed again from `cells`.
func carved(cells: PackedByteArray, lo: Vector3i, hi: Vector3i) -> void:
	_cells = cells
	for r: Vector3i in mesher.regions_touching(lo, hi):
		_dirty[r] = true
	if _task < 0:
		_start()


## Whether every carve so far is drawn.
func settled() -> bool:
	return _task < 0 and _dirty.is_empty()


## Blocks until every carve so far is drawn (tests, captures, the first build).
func flush() -> void:
	while _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_finish()


## Screen-door share (1 = solid), as BuildingView.set_opacity.
func set_opacity(value: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("opacity", value)


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_group_task_completed(_task):
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_finish()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1


func _start() -> void:
	if _dirty.is_empty():
		return
	_batch.assign(_dirty.keys())
	_dirty.clear()
	_results.clear()
	_results.resize(_batch.size())
	_task = WorkerThreadPool.add_group_task(
		_mesh_one.bind(mesher, _cells, _batch.duplicate(), _results), _batch.size()
	)


## One worker task: block batch[i] of `cells`, its arrays into results[i]. The mesh resource is
## made on the main thread (_finish): a mesh RID made on a worker raced the dummy renderer's
## allocator in the headless bench ("Initializing already initialized RID").
static func _mesh_one(
	i: int, m: CellMesher, cells: PackedByteArray, batch: Array[Vector3i], results: Array
) -> void:
	results[i] = m.mesh_region(cells, batch[i])


func _finish() -> void:
	_task = -1
	for i: int in _batch.size():
		var r := _batch[i]
		var done: Array = _results[i]
		var mesh := CellMesher.to_mesh(done)
		if keep_arrays:
			arrays[r] = done
		var part: MeshInstance3D = parts.get(r, null)
		if mesh == null:
			if part != null:
				remove_child(part)
				part.free()
				parts.erase(r)
			continue
		if part == null:
			part = MeshInstance3D.new()
			part.material_override = material
			parts[r] = part
			add_child(part)
		part.mesh = mesh
	remeshed += _batch.size()
	last_batch = _batch.duplicate()
	_results.clear()
	_start()
