class_name BuildingStream
extends Node3D
## The city's buildings (BuildingView), built so a big city loads fast (D-039) and stays inside
## memory: before the rampage starts only the buildings nearest the kaiju are meshed, up to
## city.load_chunks structural chunks; the rest stand as plain facade boxes while worker threads
## mesh them, landmarks first (a stadium never stands as a box: lead 9, 2026-10-21), then nearest
## first, each swapping in as it is ready. A building the rampage touches before its turn is
## built on the spot, so a blow never lands on a stand-in. Meshes cost memory by the chunk, so at
## most city.stream_chunks chunks stay meshed (plus the landmarks the camera can see or that
## stand near, and every building the rampage has touched): as the kaiju walks, the nearest
## unbuilt buildings stream in and the untouched ones far behind him go back to boxes. Presentation
## only. Nearest is judged from the camera as well as the kaiju (StreamRank). A landmark is held
## meshed whenever its wedge, the margin band or city.stream_view.landmark_keep_m reaches it.

## Workers meshing at once (each holds a raw voxel set until baked).
const IN_FLIGHT := 4
## A replan when the kaiju or the camera moved this far, at most every PLAN_EVERY s.
const PLAN_MOVE := 4.0
const PLAN_EVERY := 0.25
## An untouched building goes back to a box only this far past the last one still wanted.
const EVICT_MARGIN := 10.0
const EVICT_PER_FRAME := 6  # buildings freed per frame (a view is a few dozen nodes)
const PLAN_TURN := 4.0  # ...or the camera has turned this far (degrees)
## Key resolution: buildings within 1/KEY_STEP m of each other in rank tie (then by index).
const KEY_STEP := 16.0

## true: _ready starts meshing the nearest buildings on workers and returns at once; the owner
## polls initial_done() and calls finish_initial() (a loading screen keeps drawing meanwhile).
var defer_initial := false
## The slowest _process this stream has had (microseconds): the cost it adds to a frame.
var worst_usec := 0
## Replans after the first, and the microseconds they took in all (probes: the mean cost).
var plans := 0
var plan_usec := 0

var _sim: RampageSim
var _colors: Array[Color]
var _party: Array[Dictionary]
var _views: Array[BuildingView] = []
## Per building: 0 waiting, 1 a worker is on it, 2 built (or claimed by the main thread).
var _state := PackedByteArray()
## Per building: the rampage has touched it (view() was asked for), so it is never freed.
var _pinned := PackedByteArray()
var _chunks := PackedInt32Array()
var _ready_views: Array[BuildingView] = []
var _ready_index: Array[int] = []
var _mutex := Mutex.new()
var _rest: Array[int] = []
var _stand_ins: StreamStandIns
var _now: Array[int] = []
var _pre: Array[BuildingView] = []
var _initial := -1  # the initial group task while it is out, else -1
var _pending := false  # the nearest buildings are meshing or meshed, not yet in the tree
var _budget := 0
var _tasks := {}  # building index -> worker task id, while it is out
var _queue: Array[int] = []  # wanted and not yet built, in the order the workers take them
var _queue_at := 0
var _planned_at := Vector2(INF, INF)
var _since_plan := 0.0
var _evict: Array[int] = []
## What a building ranks by: its distance from the camera and the kaiju, and whether the camera
## can see it (StreamRank).
var _rank: StreamRank
var _cutoff := INF  # the last plan's rank of the first building left out
var _held := 0  # chunks of the buildings the last plan holds meshed
## Set on leaving the tree: workers still queued skip their building (quitting never waits on them).
var _stop := false


func _init(p_sim: RampageSim, colors: Array[Color]) -> void:
	_sim = p_sim
	_colors = colors


func _ready() -> void:
	BuildingBakeCache.begin_city()
	Content.look()  # merged on first use: read here, never raced by the workers
	var count := _sim.buildings.size()
	_views.resize(count)
	_state.resize(count)
	_pinned.resize(count)
	_chunks.resize(count)
	_rank = StreamRank.new(_sim.buildings)
	for n: int in count:
		var b := _sim.buildings[n]
		_chunks[n] = 0 if b.is_rail() else b.w * b.d * b.height  # a viaduct piece is mostly air
	_budget = Num.i(_sim.city.get("stream_chunks", 1 << 30))
	_party = BuildingView.party_walls(_sim.buildings)
	var order: Array[int] = []
	for n: int in count:
		order.append(n)
	var from := _sim.kaiju_pos
	order.sort_custom(
		func(a: int, b: int) -> bool: return _rank.rank(a, from) < _rank.rank(b, from)
	)
	var budget := Num.i(_sim.city.get("load_chunks", 1 << 30))
	var now: Array[int] = []
	var chunks := 0
	for n: int in order:
		if chunks < budget:
			now.append(n)
			chunks += _chunks[n]
		else:
			_rest.append(n)
	StreamRank.landmarks_first(_sim.buildings, _rest)
	_now = now
	_pre.resize(now.size())
	for n: int in now:
		_state[n] = 1  # claimed: view(n) waits for it rather than meshing it a second time
	_mesh_initial()
	_pending = true
	if not defer_initial:
		finish_initial()


## Starts meshing the nearest buildings (_now) into _pre: on workers, or at once here under the
## headless dummy renderer, whose resource ids are unsafe across threads (the real one is safe).
func _mesh_initial() -> void:
	if DisplayServer.get_name() == "headless":
		for k: int in _now.size():
			_pre[k] = _make(_now[k])
		return
	_initial = WorkerThreadPool.add_group_task(
		func(k: int) -> void: _pre[k] = null if _stop else _make(_now[k]), _now.size()
	)


## Whether the nearest buildings are meshed (finish_initial won't wait).
func initial_done() -> bool:
	return _initial < 0 or WorkerThreadPool.is_group_task_completed(_initial)


## Takes the nearest buildings into the tree, then starts streaming the rest. Waits for the
## workers if they are not done; a no-op once it has run.
func finish_initial() -> void:
	if not _pending:
		return
	if _initial >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_initial)
		_initial = -1
	_pending = false
	_stand_ins = StreamStandIns.new(_sim.buildings)
	add_child(_stand_ins.build(_colors))
	for k: int in _now.size():
		var n := _now[k]
		_state[n] = 2
		_views[n] = _pre[k]
		add_child(_pre[k])
		_stand_ins.hide(n)
	_pre.clear()
	_plan()
	_feed()


## The buildings still to stream after load, in the order the workers take them.
func queued() -> Array[int]:
	return _rest.duplicate()


func _make(n: int) -> BuildingView:
	return BuildingView.new(_sim.buildings[n], _colors[n], _party[n])


## Decides which buildings should be meshed now: the held ones, then the best ranked until the
## chunk budget is spent. Queues the wanted ones not built (landmarks first) and lists the
## untouched built ones well past the last wanted building to go back to boxes.
func _plan() -> void:
	var from := _sim.kaiju_pos
	_rank.set_view(_look(), _sim.city)
	_planned_at = from
	_since_plan = 0.0
	var marks: Array[int] = []
	var keys := _rank_keys(from, marks)
	var used := _held
	_queue.clear()
	for n: int in marks:
		if _state[n] == 0:
			_queue.append(n)
	var cutoff := INF
	for key: float in keys:
		var n := int(fmod(key, 65536.0))
		if used + _chunks[n] > _budget:
			cutoff = floorf(key / 65536.0) / KEY_STEP
			break
		used += _chunks[n]
		if _state[n] == 0:
			_queue.append(n)
	_queue_at = 0
	_cutoff = cutoff
	_evict.clear()
	if cutoff < INF:
		for key: float in keys:
			var n := int(fmod(key, 65536.0))
			if floorf(key / 65536.0) / KEY_STEP > cutoff + EVICT_MARGIN and _views[n] != null:
				_evict.append(n)


## The buildings not held, as sorted keys (rank, then index). The held ones (landmarks that stay
## meshed, listed in `marks`, and touched buildings) add their chunks to _held.
func _rank_keys(from: Vector2, marks: Array[int]) -> PackedFloat64Array:
	var keys := PackedFloat64Array()
	var limit := _cutoff + _rank.outside + EVICT_MARGIN + PLAN_MOVE * 4.0  # INF while all fit
	_held = 0
	for n: int in _sim.buildings.size():
		if _sim.buildings[n].is_held() and _rank.keeps_landmark(n, from):
			marks.append(n)
			_held += _chunks[n]
		elif _pinned[n] == 1:
			_held += _chunks[n]
		else:
			keys.append(floorf(_rank.rank(n, from, limit) * KEY_STEP) * 65536.0 + n)
	keys.sort()
	return keys


## The camera the stream ranks by (StreamRank.look), or [] when there is none.
func _look() -> Array:
	return StreamRank.look(get_viewport() if is_inside_tree() else null, _sim.city)


## Starts workers on the queue, up to IN_FLIGHT at once.
func _feed() -> void:
	while _tasks.size() < IN_FLIGHT and _queue_at < _queue.size():
		var n := _queue[_queue_at]
		_queue_at += 1
		_mutex.lock()
		var mine := _state[n] == 0
		if mine:
			_state[n] = 1
		_mutex.unlock()
		if mine:
			_tasks[n] = WorkerThreadPool.add_task(_stream_one.bind(n))


## Worker thread: mesh building n, unless the main thread took it first.
func _stream_one(n: int) -> void:
	if _stop:
		return
	var built := _make(n)
	_mutex.lock()
	_ready_views.append(built)
	_ready_index.append(n)
	_mutex.unlock()


func _process(delta: float) -> void:
	if _pending:
		return
	var t0 := Time.get_ticks_usec()
	step(delta)
	worst_usec = maxi(worst_usec, Time.get_ticks_usec() - t0)


## One frame's work. A test that owns the clock turns _process off; settle: wait for workers first.
func step(delta: float, settle := false) -> void:
	for n: int in _tasks.keys():
		if settle or WorkerThreadPool.is_task_completed(Num.i(_tasks[n])):
			WorkerThreadPool.wait_for_task_completion(Num.i(_tasks[n]))
			_tasks.erase(n)
	for pair: Array in _take_ready():
		var done: BuildingView = pair[1]
		_place(Num.i(pair[0]), done)
	_since_plan += delta
	if _since_plan >= PLAN_EVERY and _replan_wanted():
		var t0 := Time.get_ticks_usec()
		_plan()
		plans += 1
		plan_usec += Time.get_ticks_usec() - t0
	var freed := 0
	while freed < EVICT_PER_FRAME and not _evict.is_empty():
		_free_view(Num.i(_evict.pop_back()))
		freed += 1
	_feed()


## Whether the kaiju or the camera has moved, or the camera turned, enough since the last plan
## (or the camera has appeared or gone).
func _replan_wanted() -> bool:
	if _sim.kaiju_pos.distance_to(_planned_at) >= PLAN_MOVE:
		return true
	return _rank.moved(_look(), PLAN_MOVE, PLAN_TURN)


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
## Asking for a view means the rampage touches the building, so it is never freed again.
func view(n: int) -> BuildingView:
	_pinned[n] = 1
	if _views[n] != null:
		return _views[n]
	finish_initial()  # n may be one of the nearest buildings, still on its worker
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


## Whether every building the stream wants meshed is in (captures wait on it).
func complete() -> bool:
	if _pending or not _tasks.is_empty() or _queue_at < _queue.size() or not _evict.is_empty():
		return false
	_mutex.lock()
	var idle := _ready_views.is_empty()
	_mutex.unlock()
	return idle


## How many buildings were meshed before the rampage started.
func built_at_load() -> int:
	return _sim.buildings.size() - _rest.size()


## How many structural chunks are meshed now (tests and probes).
func resident_chunks() -> int:
	var sum := 0
	for n: int in _views.size():
		sum += _chunks[n] if _views[n] != null else 0
	return sum


func _place(n: int, built: BuildingView) -> void:
	_mutex.lock()
	_state[n] = 2
	_mutex.unlock()
	_views[n] = built
	add_child(built)
	_stand_ins.hide(n)


## Building n regrew (Endless mode): its view goes, pinned or not, and is rebuilt.
func regrow(n: int) -> void:
	_free_view(n, true)


## An untouched, far building goes back to its box (or a regrown one); its meshes are dropped.
func _free_view(n: int, force := false) -> void:
	var gone := _views[n]
	if gone == null or (_pinned[n] == 1 and not force):
		return
	_pinned[n] = 0
	_views[n] = null
	_state[n] = 0
	remove_child(gone)
	BuildingBakeCache.forget(gone.bake_key())
	gone.free()
	_stand_ins.show(n)


func _exit_tree() -> void:
	_stop = true
	if _initial >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_initial)
		_initial = -1
	if _pending:
		for pending: BuildingView in _pre:
			if pending != null:
				pending.free()  # meshed, never entered the tree
		_pre.clear()
	for id: Variant in _tasks.values():
		WorkerThreadPool.wait_for_task_completion(Num.i(id))
	_tasks.clear()
	for pair: Array in _take_ready():  # finished after the last frame: never entered the tree
		var orphan: BuildingView = pair[1]
		orphan.free()
	BuildingBakeCache.end_city()  # streaming is done: keep only this city's buildings
