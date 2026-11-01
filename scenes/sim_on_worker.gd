class_name SimOnWorker
extends RefCounted
## A RampageSim (with its city plan) made on a WorkerThreadPool task, so the screen keeps drawing
## meanwhile (Rampage.setup_later, perf 2026-11). Waited for once: by take(), or by drop() when
## its user leaves first.

var _task := -1
var _made: RampageSim


## `make` runs on the worker and returns the sim.
func _init(make: Callable) -> void:
	_task = WorkerWait.add(WorkerThreadPool.add_task(_run.bind(make)))


func done() -> bool:
	return WorkerThreadPool.is_task_completed(_task)


## Waits, a frame at a time (BuildStages.next), until made; false when `node` left the tree first.
func wait(node: Node, stages: BuildStages) -> bool:
	while not done():
		if not await stages.next(node, false):
			return false
	return true


func take() -> RampageSim:
	WorkerWait.wait(_task)
	var made := _made
	_made = null
	return made


## Left before taking it: waits, then lets the sim go (RampageSim.dispose, D-179).
func drop() -> void:
	WorkerWait.wait(_task)
	if _made != null:
		_made.dispose()
		_made = null


func _run(make: Callable) -> void:
	_made = make.call()
