extends Node
## Planted defect for tools/lint/thread_resources.py: a Thread's function calls the RenderingServer's
## create call, and another reaches a function that is main-thread only by its own guard.


func start() -> void:
	var worker := Thread.new()
	worker.start(_work)
	worker.wait_to_finish()


func _work() -> void:
	var rid := RenderingServer.material_create()
	RenderingServer.free_rid(rid)
	_only_main()


func _only_main() -> void:
	ThreadCheck.main_only("planted")
