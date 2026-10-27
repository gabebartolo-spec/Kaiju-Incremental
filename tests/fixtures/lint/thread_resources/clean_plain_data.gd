extends Node
## Clean for tools/lint/thread_resources.py: the worker lays out plain data and hands it to the
## main thread with call_deferred, which makes the material there; a build that may run on either
## thread makes its resources only under the main-thread test; one excused line says why.

var _plans: Array[PackedFloat32Array] = []
var _mat: ShaderMaterial


func start() -> int:
	return WorkerThreadPool.add_task(func() -> void: _hand_over.call_deferred(_lay_out()))


func _lay_out() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(16)
	return buf


func _hand_over(plan: PackedFloat32Array) -> void:
	_plans.append(plan)
	_mat = ShaderMaterial.new()  # the main thread: call_deferred ran this


func build_group() -> int:
	return WorkerThreadPool.add_group_task(_one.bind(), 4)


func _one(_i: int) -> void:
	_lay_out()
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		_dress()


func _dress() -> void:
	_mat = ShaderMaterial.new()
	_mat.set_shader_parameter("x", 1.0)


func _excused() -> void:
	var cache := ShaderMaterial.new()  # thread-ok: only called under a lock the main thread also holds
	cache.set_shader_parameter("x", 2.0)  # thread-ok: same
