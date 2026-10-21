class_name RuinYard
extends Node3D
## The ruins of a rampage, split out of CityView: a gone building's heap (Ruin.build) and a
## toppled tower's rubble strip (Ruin.strip), each built on a worker thread (thousands of voxels)
## and added when ready. A gone building's ruin rises only once the kaiju's body is off its
## footprint: raised round the body, its heap would read as walls it stands inside
## (playtest note 2). A ruin never burns: rubble, not a burning shell (#111, R 26.1).

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


## Builds make() -> MultiMeshInstance3D on a worker thread and adds it when ready; ready(mmi), if
## given, runs once it is in the tree (a toppled tower's heap settles).
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
		build(func() -> MultiMeshInstance3D: return Ruin.build(voxels, rng))


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
