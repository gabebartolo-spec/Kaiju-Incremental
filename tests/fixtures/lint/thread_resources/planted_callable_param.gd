extends Node
## Planted defect for tools/lint/thread_resources.py: the worker runs a Callable parameter
## (RuinYard.build's shape), and one caller passes a lambda that makes an ArrayMesh.

var _tasks: Array[int] = []


func run(make: Callable) -> void:
	_tasks.append(WorkerThreadPool.add_task(func() -> void: _attach.call_deferred(make.call())))


func _attach(_plan: Variant) -> void:
	pass


func caller() -> void:
	run(func() -> ArrayMesh: return ArrayMesh.new())
