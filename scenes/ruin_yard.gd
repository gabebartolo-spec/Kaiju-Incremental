class_name RuinYard
extends Node3D
## The ruins of a rampage, split out of CityView: a gone building's heap (Ruin.build) and a
## toppled tower's rubble strip (Ruin.strip), each built on a worker thread (thousands of voxels)
## and added when ready. A gone building's ruin rises only once the kaiju's body is off its
## footprint: raised round the body, its heap would read as walls it stands inside
## (playtest note 2).

var sim: RampageSim
var _view: Callable  # building index -> BuildingView
var _fire: Callable  # (at: Vector3, size: float), CityView.fire
var _tasks: Array[int] = []
var _due: Array[int] = []


func _init(p_sim: RampageSim, view: Callable, fire: Callable) -> void:
	sim = p_sim
	_view = view
	_fire = fire


## Call after a building's chunks break: once none stand, its ruin is due.
func mark(index: int) -> void:
	var view: BuildingView = _view.call(index)
	if sim.buildings[index].frame.alive_count == 0 and not view.has_meta("ruined"):
		view.set_meta("ruined", true)
		_due.append(index)


## Builds make() -> MultiMeshInstance3D on a worker thread and adds it when ready; ready(mmi), if
## given, runs once it is in the tree (a toppled tower's heap settles).
func build(make: Callable, ready := Callable()) -> void:
	_tasks.append(
		WorkerThreadPool.add_task(func() -> void: _attach.call_deferred(make.call(), ready))
	)


func _process(_delta: float) -> void:
	for index: int in _due.filter(func(i: int) -> bool: return not sim.body.over(i)):
		_due.erase(index)
		var b := sim.buildings[index]
		var size := clampf(b.w * b.d / 9.0, 0.6, 2.5)
		var heap_top := 2.4 + 0.9 * b.tier  # flames sit on top of the rubble heap
		_fire.call(Vector3(b.x, heap_top, b.z), size)
		_fire.call(Vector3(b.x + b.w * 0.3, heap_top * 0.6, b.z - b.d * 0.25), size * 0.6)
		var view: BuildingView = _view.call(index)
		var voxels := view.voxels
		var rng := Seeds.make("ruin", index)
		build(func() -> MultiMeshInstance3D: return Ruin.build(voxels, rng))


## Adds a chunk built on this thread (ready(mmi) as build()).
func put(mmi: MultiMeshInstance3D, ready := Callable()) -> void:
	_attach(mmi, ready)


func _attach(mmi: MultiMeshInstance3D, ready := Callable()) -> void:
	if is_inside_tree():
		add_child(mmi)
		if ready.is_valid():
			ready.call(mmi)
	else:
		mmi.free()


## Never leave the scene while a ruin is still being built on another thread.
func _exit_tree() -> void:
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()
