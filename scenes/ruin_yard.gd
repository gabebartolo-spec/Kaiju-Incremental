class_name RuinYard
extends Node3D
## The ruins of a rampage, split out of CityView: a gone building's heap (Ruin.build) and a
## toppled tower's rubble strip (Ruin.strip) and thrown chunks (Ruin.chunk), each laid out on a
## worker thread (thousands of voxels), then made and added on the main thread. A gone building's
## ruin rises only once the kaiju's body is off its footprint: raised round the body, its heap
## would read as walls it stands inside (playtest note 2). A ruin never burns: rubble, not a
## burning shell (#111, R 26.1).

var sim: RampageSim
var _view: Callable  # building index -> BuildingView
var _tasks: Array[int] = []
var _due: Array[int] = []


func _init(p_sim: RampageSim, view: Callable) -> void:
	sim = p_sim
	_view = view


## Call after a building's chunks break: once none stand, its ruin is due.
func mark(index: int) -> void:
	var view: BuildingView = _view.call(index)
	if sim.buildings[index].frame.alive_count == 0 and not view.has_meta("ruined"):
		view.set_meta("ruined", true)
		_due.append(index)


## Runs make() -> a ruin plan (Ruin.build_plan, strip_plan, chunk_plan: plain data) on a worker
## thread; the main thread makes its heap (Ruin.make) and adds it. ready(mmi), if given, runs
## once it is in the tree (a toppled tower's heap settles).
func build(make: Callable, ready := Callable()) -> void:
	_tasks.append(
		WorkerThreadPool.add_task(func() -> void: _attach.call_deferred(make.call(), ready))
	)


func _process(_delta: float) -> void:
	for index: int in _due.filter(func(i: int) -> bool: return not sim.body.over(i)):
		_due.erase(index)
		var view: BuildingView = _view.call(index)
		var voxels := view.voxels
		var rng := Seeds.make("ruin", index)
		build(func() -> Dictionary: return Ruin.build_plan(voxels, rng))


## Main thread: a finished plan becomes its heap, unless the yard has left the tree.
func _attach(plan: Dictionary, ready := Callable()) -> void:
	if is_inside_tree():
		_add(Ruin.make(plan), ready)


func _add(mmi: MultiMeshInstance3D, ready := Callable()) -> void:
	if Num.i(Content.section("destruction").get("ruin_shadows", 1)) == 0:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	if ready.is_valid():
		ready.call(mmi)


## A foot came down at `at` (world): every rubble voxel within radius of it (flat, in xz) is
## pressed toward the ground to keep only the share `keep` of its height and thickness, for good
## (DESIGN: his feet crunch rubble flatter, D-245). Heaps, strips and chunks alike.
func press(at: Vector3, radius: float, keep: float) -> void:
	for child: Node in get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var mm := mmi.multimesh
		var local := mmi.to_local(at)
		var reach := radius / maxf(mmi.global_basis.get_scale().x, 0.001)
		var box := mm.get_aabb().grow(reach)
		if not box.has_point(Vector3(local.x, box.position.y, local.z)):
			continue
		var stride := VoxelBuilder.DETAIL_STRIDE if mm.use_custom_data else VoxelBuilder.STRIDE
		var buf := mm.buffer
		var pressed := false
		for o in range(0, buf.size(), stride):
			var dx := buf[o + 3] - local.x
			var dz := buf[o + 11] - local.z
			if dx * dx + dz * dz > reach * reach or buf[o + 7] <= local.y:
				continue
			buf[o + 7] = local.y + (buf[o + 7] - local.y) * keep
			buf[o + 5] *= keep
			pressed = true
		if pressed:
			mm.buffer = buf


## Never leave the scene while a ruin is still being built on another thread.
func _exit_tree() -> void:
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()
