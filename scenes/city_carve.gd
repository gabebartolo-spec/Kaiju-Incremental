class_name CityCarve
extends Node
## The fine grid in play (destruction plan stage 1, D-327, D-094 option A): a building the sim
## promotes (cells_promoted) is drawn from its own fine cells, fed in order with every cell the
## sim takes (cells_carved, fall_start), so a blow bites out exactly what the sim removed and a
## falling section is exactly its cells, in the building's own facade. Each building's work runs
## as CarveJobs on the WorkerThreadPool, one at a time in order; the main thread only makes the
## meshes (CellView, under its shared per-frame budget) and swaps them in. The baked shell stays
## until the fine view is drawn and up to date (then they switch the same frame, no blink); until
## then a fall lifts its chunks as before (CityFalls). A falling piece shows the same frame its
## cells leave the standing view (CellView.gate): no gap, no ghost. Presentation only: it reads
## the sim's grid and events and decides nothing (hard rule 3). Off: tuning destruction.carve_view.

var on := false
## Tests: every fine view keeps the arrays its meshes were made of (CellView.keep_arrays).
var keep_arrays := false
## Pieces shown so far, the most frames one waited for its cells to leave the standing view, and
## the pieces that landed before they could show (probes and the bench).
var shown := 0
var worst_wait := 0
var unseen := 0

var _sim: RampageSim
var _stream: BuildingStream
var _upload_usec := 0
var _sites: Dictionary = {}  # building index -> Site
var _by_view: Dictionary = {}  # BuildingView instance id -> building index
var _orphans: Array[int] = []  # tasks of forgotten sites (regrow), waited for before they go


func _init(sim: RampageSim, stream: BuildingStream) -> void:
	_sim = sim
	_stream = stream
	var cfg := Content.section("destruction")
	on = cfg.get("carve_view", true) == true and sim.carving.on
	_upload_usec = Num.i(cfg.get("view_upload_usec", 0))


## cells_promoted or cells_carved: the building's fine view is built, or loses these cells.
func on_event(event: Dictionary) -> void:
	var site := _site(Num.i(event["building"]))
	if site != null and str(event["type"]) == "cells_carved":
		site.ops.append({"index": event["index"], "mats": event["mats"], "cut": true})


## A carved part starts to fall (fall_start with "index"): the node CityFalls moves, drawn from
## exactly the part's cells once they leave the standing view (hidden until then), or null when
## the fine view is not on screen yet (CityFalls lifts its chunks; the fine view still loses them).
func piece(event: Dictionary) -> Node3D:
	if not event.has("index"):
		return null
	var site := _site(Num.i(event["building"]))
	if site == null:
		return null
	var index: PackedInt32Array = event["index"]
	var op := {"index": index, "mats": event["mats"]}
	site.ops.append(op)
	if site.foreign or not site.view.fine or index.is_empty():
		return null
	var pivot: Vector3 = event["pivot"]
	var node := _hidden_piece(pivot)
	op["node"] = node
	return node


## The body tears off what this frame's blow carved from `view` (BodyBite): a node pivoting at
## `mid`, drawn from exactly those cells, or null (not on its fine view: BodyBite lifts chunks).
func bite(view: BuildingView, mid: Vector3) -> Node3D:
	var site: Site = _sites.get(_by_view.get(view.get_instance_id(), -1), null)
	if site == null or site.foreign or not view.fine or site.ops.is_empty():
		return null
	var op: Dictionary = site.ops[-1]
	if not op.has("cut") or op.has("node"):
		return null
	var node := _hidden_piece(mid)
	op["node"] = node
	return node


## Building n regrew (Endless): its fine view goes with its old view; a new promotion starts over.
func forget(n: int) -> void:
	var site: Site = _sites.get(n, null)
	if site == null:
		return
	if site.task >= 0:
		_orphans.append(site.task)
	for h: Dictionary in site.held:
		_show(h)
	_by_view.erase(site.view.get_instance_id())
	_sites.erase(n)


## Building n's fine view as this node feeds it (null: none yet, or not carved here).
func view_of(n: int) -> CellView:
	var site: Site = _sites.get(n, null)
	return site.cv if site != null and not site.foreign else null


func _process(_delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	for site: Site in _sites.values():
		_tick(site)
	for k: int in range(_orphans.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_orphans[k]):
			WorkerThreadPool.wait_for_task_completion(_orphans[k])
			_orphans.remove_at(k)
	CellView.spend(Time.get_ticks_usec() - t0)


func _exit_tree() -> void:
	for site: Site in _sites.values():
		if site.task >= 0:
			_orphans.append(site.task)
			site.task = -1
	for task: int in _orphans:
		WorkerThreadPool.wait_for_task_completion(task)
	_orphans.clear()


## Building n's site, made on its first event; null when it is not carved here.
func _site(n: int) -> Site:
	if not on or _sim.buildings[n].landmark != "":
		return null
	if _sites.has(n):
		return _sites[n]
	var site := Site.new()
	site.n = n
	site.view = _stream.view(n)  # the rampage touches it: built now if waiting, never freed
	site.foreign = site.view.cells_view != null
	_by_view[site.view.get_instance_id()] = n
	_sites[n] = site
	return site


func _hidden_piece(pivot: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pivot
	node.visible = false
	node.set_meta("pivot", pivot)
	node.set_meta("parts", [])
	node.set_meta("since", Engine.get_process_frames())
	return node


## One frame of a building: a finished job goes on hand, the next one goes out, the shell
## switches to the fine view once that is drawn and up to date.
func _tick(site: Site) -> void:
	if site.foreign:
		site.ops.clear()
		return
	if site.task >= 0 and WorkerThreadPool.is_task_completed(site.task):
		WorkerThreadPool.wait_for_task_completion(site.task)
		site.task = -1
		_take(site, site.job)
		site.job = null
	if site.task < 0 and (site.mesher == null or not site.ops.is_empty()):
		_send(site)
	var cv := site.cv
	if cv != null and not site.view.fine and site.task < 0 and cv.is_drawn and cv.settled():
		site.view.show_cells()


func _send(site: Site) -> void:
	var job := CarveJob.new()
	for op: Dictionary in site.ops:
		job.ops.append({"index": op["index"], "mats": op["mats"], "piece": op.has("node")})
		if op.has("node"):  # a piece that landed already holds a null place (shown as unseen)
			var node: Node3D = null
			if is_instance_valid(op["node"]):
				node = op["node"]
			job.nodes.append(node)
	if site.mesher == null:
		var f := _sim.carving.frame(site.n)
		if f == null:
			return
		job.snapshot = CellGrid.new()
		job.snapshot.res = f.res
		job.snapshot.dims = Vector3i(f.w, f.h, f.d)
		job.snapshot.offset = f.offset
		job.snapshot.cells = f.cells
		if site.view.has_voxels():
			job.voxels = site.view.voxels
		else:
			job.maker = site.view.voxel_maker()
	else:
		job.mesher = site.mesher
		job.cells = site.grid
	site.ops = []
	site.job = job
	site.task = WorkerThreadPool.add_task(job.run)


## A finished job: the first builds the standing view (hidden until drawn); a later one makes its
## pieces' views and hands the standing view its grid, held until those pieces are drawn.
func _take(site: Site, job: CarveJob) -> void:
	site.grid = job.cells
	if site.mesher == null:
		site.mesher = job.mesher
		site.view.adopt_voxels(job.voxels)
		if site.view.cells_view != null:
			site.foreign = true  # a tool promoted it meanwhile
			return
		var all := site.mesher.all_regions()
		var cv := CellView.new(site.mesher, site.grid, site.view.cells_material(), all)
		cv.upload_usec = _upload_usec
		cv.keep_arrays = keep_arrays
		cv.gate = _may_draw.bind(site)
		cv.batch_done.connect(_on_batch.bind(site))
		site.view.attach_cells(cv)
		site.cv = cv
		return
	var views: Array[CellView] = []
	for k: int in job.pieces.size():
		var view: CellView = null
		if is_instance_valid(job.nodes[k]):  # not landed while the job ran
			view = _dress_piece(site, job.nodes[k], job.pieces[k])
		views.append(view)
	if job.lo.x > job.hi.x:
		return
	var upto := site.cv.carved(site.grid, job.lo, job.hi)
	for k: int in views.size():
		site.held.append({"upto": upto, "node": job.nodes[k], "view": views[k]})


## A piece's own view under its node (meshes in world space, the node at the pivot), its debris
## samples and its box at rest (tests read it).
func _dress_piece(site: Site, node: Node3D, made: Dictionary) -> CellView:
	var parts: Array = node.get_meta("parts")
	var samples: Array = made["parts"]
	parts.append_array(samples)
	node.set_meta("box", made["box"])
	var lo: Vector3i = made["lo"]
	var hi: Vector3i = made["hi"]
	var cells: PackedByteArray = made["cells"]
	var regions := site.mesher.regions_touching(lo, hi)
	var view := CellView.new(site.mesher, cells, site.view.cells_material(), regions)
	view.upload_usec = _upload_usec
	view.keep_arrays = keep_arrays
	view.process_priority = -1  # first at the shared budget: a fall waits on it
	var pivot: Vector3 = node.get_meta("pivot")
	view.position = -pivot
	node.add_child(view)
	return view


## Whether the standing view may draw carves up to `upto`: every piece those carves free is drawn
## (or gone: a piece that landed unseen holds nothing back).
func _may_draw(upto: int, site: Site) -> bool:
	for h: Dictionary in site.held:
		if Num.i(h["upto"]) > upto or not is_instance_valid(h["view"]):
			continue
		var view: CellView = h["view"]
		if not view.is_drawn:
			return false
	return true


## The standing view drew carves up to `upto`: the pieces they freed show this same frame.
func _on_batch(upto: int, site: Site) -> void:
	for k: int in range(site.held.size() - 1, -1, -1):
		if Num.i(site.held[k]["upto"]) <= upto:
			_show(site.held[k])
			site.held.remove_at(k)


func _show(h: Dictionary) -> void:
	if not is_instance_valid(h["node"]):
		unseen += 1
		return
	var piece_node: Node3D = h["node"]
	piece_node.visible = true
	shown += 1
	worst_wait = maxi(worst_wait, Engine.get_process_frames() - Num.i(piece_node.get_meta("since")))


## One carved building's fine view as it is built and fed.
class Site:
	var n: int
	var view: BuildingView
	## The standing view (null until the first job is on hand) and its mesher.
	var cv: CellView
	var mesher: CellMesher
	## The drawn grid after the last finished job.
	var grid: PackedByteArray
	## This frame's removals, not sent yet: {"index", "mats", "cut" (a blow's), "node" (a piece's)}.
	var ops: Array[Dictionary] = []
	var job: CarveJob
	var task := -1
	## Pieces waiting on the standing view: {"upto": its ticket, "node", "view"}.
	var held: Array[Dictionary] = []
	## Another tool promoted this view itself (BuildingView.promote): left alone.
	var foreign := false
