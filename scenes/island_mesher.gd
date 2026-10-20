class_name IslandMesher
extends RefCounted
## Meshes an IslandBody's bricks on worker threads, one brick per job, so a falling tower costs
## the main thread no meshing (carve-play bench: a tower's island took 103 ms to mesh in GDScript
## at once) and shows within a frame or two, as the building's own remesh (CellView) does.
## The workers only fill surface arrays (CarveMesh.arrays_at); take() makes the meshes.
## scan() is the island's one main-thread pass over its cells.

var _task := -1
var _keys: Array[Vector3i] = []
var _out: Array = []  # per key, its surface arrays; sized up front, each job writes its own slot


## `src`: the island's [cells, mats, solid] (copied: a break may change them meanwhile);
## `bricks`: brick -> positions in cells; vertices relative to `com` (world).
func _init(site: CarveSite, src: Array, bricks: Dictionary, com: Vector3) -> void:
	var cells: PackedInt32Array = src[0]
	var mats: PackedByteArray = src[1]
	var solid: PackedByteArray = src[2]
	var snap := solid.duplicate()
	for key: Vector3i in bricks:
		_keys.append(key)
	_out.resize(_keys.size())
	var keys := _keys
	var out := _out
	_task = WorkerThreadPool.add_group_task(
		func(n: int) -> void:
			var ks: PackedInt32Array = bricks[keys[n]]
			var work := job(cells, mats, ks)
			var own: PackedInt32Array = work[0]
			out[n] = CarveMesh.arrays_at(site, own, [work[1], snap], com),
		_keys.size()
	)


## A brick's job: [its cells' positions, their mats], from the island's `cells`/`mats` and the
## brick's `ks` (positions in `cells`).
static func job(cells: PackedInt32Array, mats: PackedByteArray, ks: PackedInt32Array) -> Array:
	var own := PackedInt32Array()
	var own_mats := PackedByteArray()
	for k: int in ks:
		own.append(cells[k])
		own_mats.append(mats[k])
	return [own, own_mats]


## One pass over an island's `cells` (grid indices of `site`): "solid" (site-sized, 1 per cell),
## "bricks" (brick -> positions in cells, as CarveMesh.bricks), "spans" (brick -> world AABB, as
## CarveMesh.span) and "com" (the cells' mean world centre). Three GDScript passes took ~22 ms
## on a 10k-cell tower; a fall's cells come in index order, so a brick's run is kept local.
static func scan(site: CarveSite, cells: PackedInt32Array) -> Dictionary:
	var solid := PackedByteArray()
	solid.resize(site.count())
	var sx := site.size.x
	var sz := site.size.z
	var plan := sx * sz
	var bricks := {}
	var lows := {}
	var highs := {}
	var sum := Vector3i.ZERO
	var last := -Vector3i.ONE
	var list := PackedInt32Array()
	var lo := Vector3i.ZERO
	var hi := Vector3i.ZERO
	for k: int in cells.size():
		var i := cells[k]
		solid[i] = 1
		@warning_ignore("integer_division")
		var c := Vector3i(i % sx, i / plan, (i / sx) % sz)
		sum += c
		var key := c / site.res
		if key != last:
			if last.x >= 0:
				bricks[last] = list
				lows[last] = lo
				highs[last] = hi
			last = key
			list = bricks.get(key, PackedInt32Array())
			bricks[key] = PackedInt32Array()  # keeps first-seen order; drops the shared copy
			lo = lows.get(key, c)
			hi = highs.get(key, c)
		list.append(k)
		lo = lo.min(c)
		hi = hi.max(c)
	if last.x >= 0:
		bricks[last] = list
		lows[last] = lo
		highs[last] = hi
	var step := 1.0 / site.res
	var spans := {}
	for key: Vector3i in bricks:
		var low: Vector3i = lows[key]
		var high: Vector3i = highs[key]
		spans[key] = AABB(
			site.origin + Vector3(low) * step, Vector3(high - low + Vector3i.ONE) * step
		)
	var com := Vector3.ZERO
	if not cells.is_empty():
		com = site.origin + (Vector3(sum) / cells.size() + Vector3.ONE * 0.5) * step
	return {"solid": solid, "bricks": bricks, "spans": spans, "com": com}


func done() -> bool:
	return _task < 0 or WorkerThreadPool.is_group_task_completed(_task)


func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1


## brick -> ArrayMesh (null where no face shows); waits for the workers if they still run.
func take() -> Dictionary:
	wait()
	var meshes := {}
	for n: int in _keys.size():
		var arrays: Array = _out[n]
		meshes[_keys[n]] = CarveMesh.from_arrays(arrays)
	_out.clear()
	return meshes
