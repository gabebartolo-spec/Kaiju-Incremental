class_name BuildingStream
extends Node3D
## The city's buildings (BuildingView), built so a big city loads fast (D-039): before the
## rampage starts only the buildings nearest the kaiju are meshed, up to city.load_chunks
## structural chunks; the rest stand as plain facade boxes while worker threads mesh them,
## nearest first, and each swaps in as it is ready. A building the rampage touches before its
## turn is built on the spot, so a blow never lands on a stand-in. Small cities fit the budget
## and load exactly as before. Presentation only.

var _sim: RampageSim
var _colors: Array[Color]
var _party: Array[Dictionary]
var _views: Array[BuildingView] = []
## Per building: 0 waiting, 1 a worker is on it, 2 built (or claimed by the main thread).
var _state := PackedByteArray()
var _ready_views: Array[BuildingView] = []
var _ready_index: Array[int] = []
var _mutex := Mutex.new()
var _rest: Array[int] = []
var _task := -1
var _stand_ins: MultiMesh
var _slot := {}  # building index -> stand-in instance


func _init(p_sim: RampageSim, colors: Array[Color]) -> void:
	_sim = p_sim
	_colors = colors


func _ready() -> void:
	var count := _sim.buildings.size()
	_views.resize(count)
	_state.resize(count)
	_party = BuildingView.party_walls(_sim.buildings)
	var order: Array[int] = []
	for n: int in count:
		order.append(n)
	var from := _sim.kaiju_pos
	order.sort_custom(func(a: int, b: int) -> bool: return _dist(a, from) < _dist(b, from))
	var budget := Num.i(_sim.city.get("load_chunks", 1 << 30))
	var now: Array[int] = []
	var chunks := 0
	for n: int in order:
		var b := _sim.buildings[n]
		if chunks < budget:
			now.append(n)
			chunks += b.w * b.d * b.height
		else:
			_rest.append(n)
	var task := WorkerThreadPool.add_group_task(
		func(k: int) -> void: _views[now[k]] = _make(now[k]), now.size()
	)
	WorkerThreadPool.wait_for_group_task_completion(task)
	for n: int in now:
		_state[n] = 2
		add_child(_views[n])
	if not _rest.is_empty():
		_build_stand_ins()
		_task = WorkerThreadPool.add_group_task(_stream_one, _rest.size())


func _make(n: int) -> BuildingView:
	return BuildingView.new(_sim.buildings[n], _colors[n], _party[n])


func _dist(n: int, from: Vector2) -> float:
	var b := _sim.buildings[n]
	return from.distance_squared_to(Vector2(b.x, b.z))


## Worker thread: mesh the k-th building of the rest, unless the main thread took it first.
func _stream_one(k: int) -> void:
	var n := _rest[k]
	_mutex.lock()
	var mine := _state[n] == 0
	if mine:
		_state[n] = 1
	_mutex.unlock()
	if not mine:
		return
	var built := _make(n)
	_mutex.lock()
	_ready_views.append(built)
	_ready_index.append(n)
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _task < 0:
		return
	var finished := WorkerThreadPool.is_group_task_completed(_task)
	if finished:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
	for pair: Array in _take_ready():
		var done: BuildingView = pair[1]
		_place(Num.i(pair[0]), done)


## The views the workers finished since the last call, as [index, view] pairs.
func _take_ready() -> Array[Array]:
	_mutex.lock()
	var out: Array[Array] = []
	for k: int in _ready_views.size():
		out.append([_ready_index[k], _ready_views[k]])
	_ready_views = []
	_ready_index = []
	_mutex.unlock()
	return out


## Building n's view, built now if it is still waiting, or taken the moment a worker is done.
func view(n: int) -> BuildingView:
	if _views[n] != null:
		return _views[n]
	_mutex.lock()
	var waiting := _state[n] == 0
	if waiting:
		_state[n] = 2
	_mutex.unlock()
	if waiting:
		_place(n, _make(n))
	while _views[n] == null:
		_mutex.lock()
		var at := _ready_index.find(n)
		var done: BuildingView = null
		if at >= 0:
			done = _ready_views[at]
			_ready_views.remove_at(at)
			_ready_index.remove_at(at)
		_mutex.unlock()
		if done != null:
			_place(n, done)
		else:
			OS.delay_usec(200)
	return _views[n]


## Building n's view if it is built yet, else null (never builds it).
func built(n: int) -> BuildingView:
	return _views[n]


## Whether every building's mesh is in (captures wait on it).
func complete() -> bool:
	return _task < 0


## How many buildings were meshed before the rampage started.
func built_at_load() -> int:
	return _sim.buildings.size() - _rest.size()


func _place(n: int, built: BuildingView) -> void:
	_mutex.lock()
	_state[n] = 2
	_mutex.unlock()
	_views[n] = built
	add_child(built)
	if _slot.has(n):
		var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		_stand_ins.set_instance_transform(Num.i(_slot[n]), hidden)


## One facade box per building still to come (the skyline's stand-in look).
func _build_stand_ins() -> void:
	_stand_ins = MultiMesh.new()
	_stand_ins.transform_format = MultiMesh.TRANSFORM_3D
	_stand_ins.use_colors = true
	_stand_ins.use_custom_data = true
	var mesh := BoxMesh.new()
	mesh.material = CitySkyline.facade_material(0.0)
	_stand_ins.mesh = mesh
	_stand_ins.instance_count = _rest.size()
	for k: int in _rest.size():
		var n := _rest[k]
		var b := _sim.buildings[n]
		var size := Vector3(b.w, b.height, b.d)
		var at := Vector3(b.x, b.height * 0.5, b.z)
		_stand_ins.set_instance_transform(k, Transform3D(Basis.from_scale(size), at))
		_stand_ins.set_instance_color(k, _colors[n])
		var tall := 1.0 if b.height > 18 else 0.0
		var custom := Color(b.style % 4, 0.35, tall, fposmod(b.x * 0.37 + b.z * 0.11, 1.0))
		_stand_ins.set_instance_custom_data(k, custom)
		_slot[n] = k
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _stand_ins
	add_child(mmi)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
	for pair: Array in _take_ready():  # finished after the last frame: never entered the tree
		var orphan: BuildingView = pair[1]
		orphan.free()
