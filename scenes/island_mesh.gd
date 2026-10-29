class_name IslandMesh
extends Node3D
## Render plan item 11 (D-311, tuning render_opt.island_merged): an IslandBody's cells drawn as
## one merged mesh and one patch, not a MeshInstance3D per brick (a 300-brick island drew 300).
## It sits at the body's origin; vertices are placed relative to the body's spawn centre of mass.
##  - A dropped brick vanishes at once: its vertex range in the merged mesh is zeroed on the
##    renderer (its triangles collapse to a point); no other brick's vertices change.
##  - The faces a drop laid bare on the cells left go into the patch, made on the main thread
##    from the dropped cells alone, their corners' AO as the cells now stand.
##  - Once a staged break is over (remesh()), the whole island is meshed again on a worker
##    (WorkerThreadPool) from a copy of its cells; the old mesh and patch stay drawn until the new
##    mesh is ready, then it swaps in within one frame, the bricks dropped meanwhile hidden again
##    and the patch keeping only the faces laid bare after the copy was taken.
## The worker lays out plain arrays (build()); only the main thread makes a mesh
## (CarveMesh.to_mesh). A task still running when its island leaves is waited on later (reap(),
## by CarvePhysics), so a freed island never blocks a frame.

const NO_TASK := -1

## Tasks of islands that left the tree before their remesh ended (main thread only).
static var _orphans: Array[int] = []

## The look of the cells (the building's material; null: vertex colours).
var material: Material:
	set(m):
		material = m
		_main.material_override = m
		_patch_view.material_override = m
## How long the last swap took on the main thread (the new mesh made, dropped bricks hidden).
var last_swap_us := 0
var _site: CarveSite
var _strength: float
var _main := MeshInstance3D.new()
var _patch_view := MeshInstance3D.new()
var _ranges: Dictionary = {}  # brick -> Vector2i(first vertex, vertex count) in _main's mesh
var _stride := 0  # bytes per vertex position in _main's mesh (the renderer's layout)
var _patch: Dictionary = {}  # Vector4i(brick, drop) -> CarveMesh.Faces laid bare on it then
var _where: Dictionary = {}  # brick -> {cell index: position in cells}, made when a drop needs it
var _gone: Dictionary = {}  # brick -> true, every brick dropped
var _drops := 0
var _job: Job
var _task := NO_TASK
var _ask: Array = []  # the latest remesh() asked for while one ran: [src, bricks, offset, drops]


## A remesh on a worker: its inputs copied on the main thread, its result read back once done.
class Job:
	extends RefCounted
	var site: CarveSite
	var src: Array  # [cells, mats, solid (a copy)]
	var bricks: Dictionary  # a copy: brick -> positions in cells
	var frame: Array  # [offset, AO strength]
	var drops := 0  # the drops already in the copy
	var built: Array = []


func _init(p_site: CarveSite, p_strength: float) -> void:
	_site = p_site
	_strength = p_strength
	add_child(_main)
	add_child(_patch_view)
	set_process(false)


## The merged faces of `bricks` (brick -> positions in `src`'s cells, as IslandBody keeps them)
## and each brick's vertex range in them: [CarveMesh.Faces, brick -> Vector2i(first, count)].
## `src` is [cells, mats (parallel), solid], `frame` [offset (world), AO strength]. Plain data
## only: it runs on a worker.
static func build(site: CarveSite, src: Array, bricks: Dictionary, frame: Array) -> Array:
	var cells: PackedInt32Array = src[0]
	var mats: PackedByteArray = src[1]
	var solid: PackedByteArray = src[2]
	var offset: Vector3 = frame[0]
	var strength: float = frame[1]
	var out := CarveMesh.Faces.new(site, solid, strength)
	var ranges := {}
	for key: Vector3i in bricks:
		var ks: PackedInt32Array = bricks[key]
		var own := PackedInt32Array()
		var own_mats := PackedByteArray()
		for k: int in ks:
			own.append(cells[k])
			own_mats.append(mats[k])
		var first := out.verts.size()
		CarveMesh.add_cells(out, own, own_mats, offset)
		ranges[key] = Vector2i(first, out.verts.size() - first)
	return [out, ranges]


## Waits on the tasks of islands gone before their remesh ended: the finished ones, or every one
## (`all`, blocking). Main thread: CarvePhysics calls it each tick and on leaving the tree.
static func reap(all: bool) -> void:
	var left: Array[int] = []
	for task: int in _orphans:
		if all or WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
		else:
			left.append(task)
	_orphans = left


## Meshes the island on this thread (its spawn); arguments as build()'s.
func build_now(src: Array, bricks: Dictionary, offset: Vector3) -> void:
	_install(build(_site, src, bricks, [offset, _strength]))


## The bricks of `lists` (brick -> positions in cells) dropped, their cells already cleared from
## `src`'s solid ([cells, mats, solid]); `bricks` are the ones left. Hides them at once and
## patches the faces their drop laid bare.
func dropped(lists: Dictionary, src: Array, bricks: Dictionary, offset: Vector3) -> void:
	_drops += 1
	for key: Vector3i in lists:
		_gone[key] = true
		_where.erase(key)
		_hide(key)
		for tag: Vector4i in _patch.keys():
			if Vector3i(tag.x, tag.y, tag.z) == key:
				_patch.erase(tag)
	var bare := _laid_bare(lists, src, bricks, offset)
	for key: Vector3i in bare:
		_patch[Vector4i(key.x, key.y, key.z, _drops)] = bare[key]
	_draw_patch()


## Meshes the whole island again on a worker (a staged break is over); arguments as dropped()'s
## but `bricks` only. While one runs, the latest call waits for it to end.
func remesh(src: Array, bricks: Dictionary, offset: Vector3) -> void:
	var solid: PackedByteArray = src[2]
	_ask = [[src[0], src[1], solid.duplicate()], bricks.duplicate(), offset, _drops]
	if _task == NO_TASK:
		_launch()


func pending() -> bool:
	return _task != NO_TASK


## Blocks until a running remesh ends and swaps it in (tests; a capture's last frame).
func finish() -> void:
	while _task != NO_TASK:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = NO_TASK
		_swap()


## The faces in the patch now, as one set (tests).
func patch_faces() -> CarveMesh.Faces:
	var all := CarveMesh.Faces.new(_site, PackedByteArray(), _strength)
	for tag: Vector4i in _patch:
		var part: CarveMesh.Faces = _patch[tag]
		all.verts.append_array(part.verts)
		all.normals.append_array(part.normals)
		all.colors.append_array(part.colors)
	return all


## The vertex ranges still drawn in the merged mesh: brick -> Vector2i(first, count) (tests).
func ranges() -> Dictionary:
	return _ranges.duplicate()


func _process(_delta: float) -> void:
	if _task == NO_TASK or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = NO_TASK
	_swap()


func _exit_tree() -> void:
	if _task != NO_TASK:
		_orphans.append(_task)
		_task = NO_TASK
	_ask = []


## The worker's part of a remesh.
static func _work(job: Job) -> void:
	job.built = build(job.site, job.src, job.bricks, job.frame)


func _launch() -> void:
	var job := Job.new()
	job.site = _site
	job.src = _ask[0]
	job.bricks = _ask[1]
	job.frame = [_ask[2], _strength]
	job.drops = _ask[3]
	_ask = []
	_job = job
	_task = WorkerThreadPool.add_task(_work.bind(job), false, "IslandMesh remesh")
	set_process(true)


## The finished remesh in place, then the next one asked for meanwhile, if any.
func _swap() -> void:
	var t0 := Time.get_ticks_usec()
	_install(_job.built)
	for tag: Vector4i in _patch.keys():
		if tag.w <= _job.drops:
			_patch.erase(tag)
	_draw_patch()
	_job = null
	last_swap_us = Time.get_ticks_usec() - t0
	set_process(false)
	if not _ask.is_empty():
		_launch()


## A build in place as the merged mesh, every brick dropped since its copy hidden again.
func _install(built: Array) -> void:
	var faces: CarveMesh.Faces = built[0]
	var mesh := CarveMesh.to_mesh(faces)
	_main.mesh = mesh
	_ranges = built[1]
	_stride = 0
	if mesh != null:
		var format := mesh.surface_get_format(0)
		_stride = RenderingServer.mesh_surface_get_format_vertex_stride(format, faces.verts.size())
	for key: Vector3i in _ranges.keys():
		if _gone.has(key):
			_hide(key)


## Zeroes brick `key`'s vertex positions in the merged mesh: its triangles collapse to a point.
func _hide(key: Vector3i) -> void:
	if not _ranges.has(key):
		return
	var span: Vector2i = _ranges[key]
	_ranges.erase(key)
	var mesh := _main.mesh
	if mesh == null or span.y == 0:
		return
	var zero := PackedByteArray()
	zero.resize(span.y * _stride)
	zero.fill(0)
	RenderingServer.mesh_surface_update_vertex_region(mesh.get_rid(), 0, span.x * _stride, zero)


func _draw_patch() -> void:
	_patch_view.mesh = CarveMesh.to_mesh(patch_faces())


## The faces the drop of `lists` laid bare, per receiving brick (brick -> CarveMesh.Faces): the
## face of each solid neighbour that looks into a dropped cell. Only a dropped cell on its
## brick's side can have one (the rest of its brick went with it).
func _laid_bare(lists: Dictionary, src: Array, bricks: Dictionary, offset: Vector3) -> Dictionary:
	var cells: PackedInt32Array = src[0]
	var mats: PackedByteArray = src[1]
	var solid: PackedByteArray = src[2]
	var base := _site.origin - offset
	var size := 1.0 / _site.res
	var out := {}
	for key: Vector3i in lists:
		var ks: PackedInt32Array = lists[key]
		for k: int in ks:
			var c := _site.cell(cells[k])
			var local := c - key * _site.res
			for f: int in 6:
				var q := c + CarveMesh.STEPS[f]
				if not _on_side(local, f) or not _site.inside(q) or solid[_site.index(q)] == 0:
					continue
				var brick := q / _site.res
				if not out.has(brick):
					out[brick] = CarveMesh.Faces.new(_site, solid, _strength)
				var faces: CarveMesh.Faces = out[brick]
				var col := CarveMesh.shaded(_site, q, mats[_position(brick, q, cells, bricks)])
				faces.add(q, f ^ 1, base + Vector3(q) * size, col)
	for brick: Vector3i in out:  # a held reference would make the body's next write copy its grid
		var faces: CarveMesh.Faces = out[brick]
		faces.solid = PackedByteArray()
	return out


## Whether a cell at `local` in its brick lies on the brick's side that face `f` looks out of.
func _on_side(local: Vector3i, f: int) -> bool:
	return local[f >> 1] == (0 if f & 1 == 0 else _site.res - 1)


## The position in `cells` of cell `q` of brick `brick` (its lookup made on first use).
func _position(brick: Vector3i, q: Vector3i, cells: PackedInt32Array, bricks: Dictionary) -> int:
	if not _where.has(brick):
		var made := {}
		var ks: PackedInt32Array = bricks[brick]
		for k: int in ks:
			made[cells[k]] = k
		_where[brick] = made
	var lookup: Dictionary = _where[brick]
	var at: int = lookup[_site.index(q)]
	return at
