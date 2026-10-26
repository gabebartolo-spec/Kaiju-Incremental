class_name ThreadCheck
extends RefCounted
## Debug-build guard: rendering resources (materials, textures, meshes) are made on the main
## thread only. A ShaderMaterial or ImageTexture made on a WorkerThreadPool task runs the
## renderer's material and texture setup on that thread (Forward+ creates them at once), racing
## the main thread's material update list: the High bench froze with self_list errors forever
## (2026-10-26). Workers return plain data (arrays, images, buffers); the main thread makes the
## resources. Each offending site is reported once; `hits` counts every call (tests read it).

## Site -> calls made off the main thread.
static var hits: Dictionary = {}
static var _lock := Mutex.new()


## Call first in any function that makes a material, texture or mesh resource.
static func main_only(what: String) -> void:
	if not OS.is_debug_build() or OS.get_thread_caller_id() == OS.get_main_thread_id():
		return
	_lock.lock()
	var first := not hits.has(what)
	hits[what] = Num.i(hits.get(what, 0)) + 1
	_lock.unlock()
	if first:
		push_error("ThreadCheck: %s made off the main thread" % what)
		print_stack()


## Every site hit so far, as "site=calls" (benches print it at the end).
static func report() -> String:
	_lock.lock()
	var parts: Array[String] = []
	for what: String in hits:
		parts.append("%s=%d" % [what, Num.i(hits[what])])
	_lock.unlock()
	return "ThreadCheck hits %d: %s" % [parts.size(), ", ".join(parts)]
