extends SceneTree
## Writes how Godot's landmark sections burst (scenes/landmark_burst.gd, CarveJob.samples) so the
## Unity port (unity/Assets/Scripts/GameLogic/LandmarkBurst.cs) can be checked against it.
##
##   godot --path . --script tools/unity/dump_landmark_burst_golden.gd
##
## Not headless: a headless MultiMesh keeps no instance transforms or colours.
##
## The stage-2 city's stadium is poked once (its fine view comes up), then its west side is
## smashed the way tests/lib/flow_stadium.gd's run does, so its sections fall from the fine view:
## the path Unity always takes. The first SECTIONS of them with cells, and two made-up big ones,
## are burst again here, each from Godot's own code, and written down.
##
## Output: unity/SimTests/golden/landmark_burst.txt, read by LandmarkBurstCheck
## (`dotnet run --project unity/SimTests`). TUNING: the landmark_burst section. Per section:
## SECTION (event id, building middle x z, cell count), GRID (w, d, origin, voxel), INDEX
## (every cell, in the event's order; RUN start count for a made-up one), SAMPLE per sample
## (cell, pos, colour), CHUNK per thrown chunk (from, velocity, colour, size), CLOUD per puff
## (position) and CLOUDSIZE, FRAG per fragment (pos, colour, away), DUST (centre, size); then per
## sampled frame of a 60 Hz clock STEP (frame, t, spray alive, clouds alive), SPRAY per
## SPRAY_EVERY-th chunk (number, basis x, y, z, origin) and PUFF per cloud (scale, colour alpha).

const OUT := "res://unity/SimTests/golden/landmark_burst.txt"
const STAGE := 2  # the first stage whose city holds the stadium (D-271)
const SETTLE := 240  # flow_stadium's PLAY_FRAMES: the emerge is over
## Most frames after the poke for the fine view to come up (its job is threaded).
const FINE_WAIT := 1200
const SMASH_EVERY := 30  # frames between blows down the west side
const SMASH_FRAMES := 360
const FLOORS := 3  # each blow takes this many floors of one column
const SECTIONS := 4  # sections written down
const BIG: Array[int] = [6000, 40000]  # made-up sections' cell counts
const BIG_START := 20000
const BIG_ID := 9000
const SPRAY_EVERY := 25  # chunks whose pose is written each step (and the last)
const DT := 1.0 / 60.0
const FRAMES := 30  # frames a burst is stepped (its cloud is gone by 27)
const SAMPLED: Array[int] = [0, 1, 6, 12, 17, 18, 19, 26, 27]


class DustLog:
	extends Fx
	var calls: Array[Array] = []

	func dust(at: Vector3, size: float, _tint := Color(0, 0, 0, 0)) -> void:
		calls.append([at, size])


var _lines: PackedStringArray = []


func _initialize() -> void:
	QuitGame.release_sims_at_exit(self)
	SaveFile.pinned_seed = 0
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var cfg := Content.section("landmark_burst")
	_lines.append(
		(
			"TUNING chunks %d voxels %s %s speed %s %s life %s shade %s dark %s share %s"
			% [
				Num.i(cfg["chunks"]),
				_f(cfg["chunk_voxels"][0]),
				_f(cfg["chunk_voxels"][1]),
				_f(cfg["chunk_speed"][0]),
				_f(cfg["chunk_speed"][1]),
				_f(cfg["chunk_life"]),
				_f(cfg["chunk_shade"]),
				_f(cfg["chunk_dark"]),
				_f(cfg["chunk_dark_share"]),
			]
		)
	)
	_lines.append(
		(
			"TUNING fragments %d clouds %d alpha %s cloud_life %s cloud_max %s"
			% [
				Num.i(cfg["fragments"]),
				Num.i(cfg["clouds"]),
				_f(cfg["cloud_alpha"]),
				_f(cfg["cloud_life"]),
				_f(cfg["cloud_max"]),
			]
		)
	)
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	stats["size"] = float(STAGE)
	var layout := CityGrowth.layout(Content.tuning(), STAGE, Seeds.make("city", 0))
	rampage.setup(species, stats, layout, 0)
	root.add_child(rampage)
	await process_frame
	var sim := rampage.sim
	var si := -1
	for i: int in sim.buildings.size():
		if sim.buildings[i].landmark == str(Content.sports()["pitch"]["landmark"]):
			si = i
	var stadium: RampageSim.Building = sim.buildings[si]
	var view: CityView = _find_view(rampage)
	for _i: int in SETTLE:
		await physics_frame
	var poke: Array[Vector3i] = [Vector3i(0, 0, stadium.d / 2)]
	sim.damage_chunks(si, poke, 1e6)
	for _i: int in FINE_WAIT:
		if view.carve.view_of(si) != null:
			break
		await physics_frame
	for _i: int in SMASH_EVERY:
		await physics_frame
	var events: Array[Dictionary] = []
	var last: Array[Dictionary] = []
	for f: int in SMASH_FRAMES:
		if f % SMASH_EVERY == 0:
			var cells: Array[Vector3i] = []
			for z: int in stadium.d:
				for y: int in FLOORS:
					cells.append(Vector3i(f / SMASH_EVERY, y, z))
			sim.damage_chunks(si, cells, 1e6)
		await physics_frame
		if is_same(sim.events, last):
			continue
		last = sim.events
		for e: Dictionary in sim.events:
			if str(e["type"]) != "fall_start" or Num.i(e["building"]) != si:
				continue
			if not e.has("index"):
				continue
			var idx: PackedInt32Array = e["index"]
			if idx.is_empty():
				continue
			if view.carve.view_of(si) == null:
				continue
			events.append(e)
	print("landmark_burst dump: %d fine-view sections" % events.size())
	var picked := _pick(events)
	# The real sections here are small (one sample each), so two made-up ones of the same grid,
	# big enough that the throw and the fragments skip samples, walk every branch: an id and a
	# run of cells, as a fall_start has.
	for n: int in BIG:
		var index := PackedInt32Array()
		for i: int in n:
			index.append(BIG_START + i)
		picked.append({"id": BIG_ID + n, "building": si, "index": index, "kind": "made-up"})
	for e: Dictionary in picked:
		_section(view, stadium, e)
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("landmark_burst dump: %d lines to %s" % [_lines.size(), OUT])
	rampage.queue_free()
	await process_frame
	quit()


## Up to SECTIONS events: the biggest topple, the biggest drop, then the next biggest.
func _pick(events: Array[Dictionary]) -> Array[Dictionary]:
	var by_size := events.duplicate()
	by_size.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var ia: PackedInt32Array = a["index"]
			var ib: PackedInt32Array = b["index"]
			return ia.size() > ib.size()
	)
	var out: Array[Dictionary] = []
	for kind: String in ["topple", "drop"]:
		for e: Dictionary in by_size:
			if str(e["kind"]) == kind:
				out.append(e)
				break
	for e: Dictionary in by_size:
		if out.size() >= SECTIONS:
			break
		if not out.has(e):
			out.append(e)
	return out


func _section(view: CityView, b: RampageSim.Building, e: Dictionary) -> void:
	var index: PackedInt32Array = e["index"]
	var sites: Dictionary = view.carve.get("_sites")
	var mesher: CellMesher = sites[Num.i(e["building"])].mesher
	_lines.append(
		(
			"SECTION %d %s %s %d %s"
			% [Num.i(e["id"]), _f(b.x), _f(b.z), index.size(), str(e["kind"])]
		)
	)
	_lines.append(
		"GRID %d %d %s %s" % [mesher.dims.x, mesher.dims.z, _v(mesher.origin), _f(mesher.voxel)]
	)
	if str(e["kind"]) == "made-up":
		_lines.append("RUN %d %d" % [index[0], index.size()])
	else:
		var ids := PackedStringArray()
		for i: int in index:
			ids.append(str(i))
		_lines.append("INDEX " + " ".join(ids))
	var parts := view.carve.samples(e)
	var w := mesher.dims.x
	var d := mesher.dims.z
	var plan := w * d
	for part: Dictionary in parts:
		var pos: Vector3 = part["pos"]
		var col: Color = part["color"]
		var c := Vector3i(roundi((pos - mesher.origin).x / mesher.voxel), 0, 0)
		c.y = roundi((pos - mesher.origin).y / mesher.voxel)
		c.z = roundi((pos - mesher.origin).z / mesher.voxel)
		_lines.append(
			"SAMPLE %d %s %s" % [c.x + c.z * w + c.y * plan, _v(pos), _c(col)]
		)
	# The burst itself, from an empty piece: LandmarkBurst takes the samples from the cells.
	var piece := Node3D.new()
	piece.set_meta("parts", [])
	var real_fx := view.fx
	var log := DustLog.new()
	view.fx = log
	var debris: DebrisField = view.get("_debris")
	var queue: Array = debris.get("_queue")
	var before := queue.size()
	var burst := LandmarkBurst.new(piece, view, e)
	view.fx = real_fx
	root.add_child(burst)
	burst.set_process(false)
	var from: PackedVector3Array = burst.get("_from")
	var vel: PackedVector3Array = burst.get("_vel")
	var size: PackedFloat32Array = burst.get("_size")
	var spray: MultiMeshInstance3D = burst.get("_spray")
	for i: int in from.size():
		_lines.append(
			(
				"CHUNK %s %s %s %s"
				% [_v(from[i]), _v(vel[i]), _c(spray.multimesh.get_instance_color(i)), _f(size[i])]
			)
		)
	var clouds: PackedVector3Array = burst.get("_cloud_at")
	for at: Vector3 in clouds:
		_lines.append("CLOUD %s" % _v(at))
	_lines.append("CLOUDSIZE %s" % _f(burst.get("_cloud_size")))
	queue = debris.get("_queue")
	for k: int in range(before, queue.size()):
		var q: Array = queue[k]
		var qp: Vector3 = q[0]
		var qc: Color = q[1]
		var qa: Vector3 = q[2]
		_lines.append("FRAG %s %s %s" % [_v(qp), _c(qc), _v(qa)])
	for call: Array in log.calls:
		var at: Vector3 = call[0]
		_lines.append("DUST %s %s" % [_v(at), _f(call[1])])
	log.free()
	var mm_spray := spray.multimesh if spray != null else null
	var cloud_node: MultiMeshInstance3D = burst.get("_clouds")
	var mm_cloud := cloud_node.multimesh if cloud_node != null else null
	for frame: int in FRAMES:
		if frame > 0:
			burst._process(DT)
		if not SAMPLED.has(frame):
			continue
		var live_spray: bool = burst.get("_spray") != null
		var live_cloud: bool = burst.get("_clouds") != null
		_lines.append(
			(
				"STEP %d %s %d %d"
				% [frame, _f(burst.get("_t")), int(live_spray), int(live_cloud)]
			)
		)
		if live_spray:
			for i: int in mm_spray.instance_count:
				if i % SPRAY_EVERY != 0 and i != mm_spray.instance_count - 1:
					continue
				var t := mm_spray.get_instance_transform(i)
				_lines.append(
					(
						"SPRAY %d %s %s %s %s"
						% [i, _v(t.basis.x), _v(t.basis.y), _v(t.basis.z), _v(t.origin)]
					)
				)
		if live_cloud:
			for n: int in mm_cloud.instance_count:
				var t := mm_cloud.get_instance_transform(n)
				_lines.append(
					"PUFF %s %s" % [_f(t.basis.x.x), _f(mm_cloud.get_instance_color(n).a)]
				)
	burst.queue_free()


func _find_view(node: Node) -> CityView:
	if node is CityView:
		return node
	for child: Node in node.get_children():
		var found := _find_view(child)
		if found != null:
			return found
	return null


func _f(x: Variant) -> String:
	return "%.9f" % [x]


func _v(v: Vector3) -> String:
	return "%s %s %s" % [_f(v.x), _f(v.y), _f(v.z)]


func _c(c: Color) -> String:
	return "%s %s %s %s" % [_f(c.r), _f(c.g), _f(c.b), _f(c.a)]
