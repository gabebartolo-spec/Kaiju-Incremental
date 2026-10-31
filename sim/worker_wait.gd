class_name WorkerWait
extends RefCounted
## The worker tasks started ahead of their use (CellPromoter.start, PieceParts.start), so each is
## waited for exactly once: by its user, or at exit (QuitGame.release_sims_at_exit) when a run
## drops it first. A task still running script code as the process quits crashes the exit.

static var _open: Array[int] = []


static func add(task: int) -> int:
	_open.append(task)
	return task


## Waits for this task (once only; WorkerThreadPool forgets a task once waited for).
static func wait(task: int) -> void:
	if _open.has(task):
		_open.erase(task)
		WorkerThreadPool.wait_for_task_completion(task)


static func wait_all() -> void:
	for task: int in _open:
		WorkerThreadPool.wait_for_task_completion(task)
	_open.clear()
