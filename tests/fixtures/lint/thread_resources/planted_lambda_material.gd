extends Node
## Planted defect for tools/lint/thread_resources.py: a worker task makes a ShaderMaterial itself.


func start() -> int:
	return WorkerThreadPool.add_task(
		func() -> void:
			var mat := ShaderMaterial.new()
			mat.set_shader_parameter("x", 1.0)
	)
