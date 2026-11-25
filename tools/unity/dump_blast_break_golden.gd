extends SceneTree
## Writes how Godot's blast break lets a building go (scenes/blast_break.gd, BuildingView.chip)
## and how a blast throws its site's skin (scenes/blast_fx.gd _throw), so the Unity port
## (unity/Assets/Scripts/GameLogic/BlastBreak.cs) can be checked against it.
##
##   godot --path . --script tools/unity/dump_blast_break_golden.gd
##
## Not headless, like the other view dumps (the building views need their meshes).
##
## A stage-2 run settles, then a BlastBreak of the dump's own (its rng seeded per case) breaks
## chunks of real building views: the city's dust goes to a log and its debris queue is read.
##
## Output: unity/SimTests/golden/blast_break.txt, read by BlastBreakCheck
## (`dotnet run --project unity/SimTests`). TUNING: the blast_fx break section and debris
## count. Per CASE (name, seed): SITE (index, x, z, base, w, d, height, landmark 0/1), STATE per
## chunk of the floors the case can touch (x y z state), PARTS per such chunk (x y z count) and
## its PART lines (pos, colour); then the calls in order: BLEW (origin, reach), TAKES (x z, cell
## count, cells; then its result), PROCESS; each followed by the FRAG (pos, colour, away) and DUST
## (at, size) lines
## it made; END then the chunks' states after (STATE). THROW (kind, seed, centre, half, colour
## count) with COLOUR and FRAG lines.

const OUT := "res://unity/SimTests/golden/blast_break.txt"
const STAGE := 2
const SETTLE := 240
const FLOORS := 3  # the blast case breaks this many top floors
const KEEP_LOW := 2  # floors 0..this are written down too (the two case's low chunks and above)
const LANDMARK_FLOORS := 1  # a landmark is wide: one top floor is plenty
const THROW_KINDS: Array[String] = ["fuel_silo", "fireworks_factory", "chem_lab"]


class DustLog:
	extends Fx
	var calls: Array[Array] = []

	func dust(at: Vector3, size: float, _tint := Color(0, 0, 0, 0)) -> void:
		calls.append([at, size])


var _lines: PackedStringArray = []
var _view: CityView
var _log: DustLog
var _debris: DebrisField
var _seen := 0


func _initialize() -> void:
	QuitGame.release_sims_at_exit(self)
	SaveFile.pinned_seed = 0
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var blast_cfg := Content.section("blast_fx")
	var cfg: Dictionary = blast_cfg["break"]
	(
		_lines
		. append(
			(
				"TUNING slices %d window %d per_chunk %d push %s up %s debris %d"
				% [
					Num.i(cfg["slices"]),
					Num.i(cfg["window_frames"]),
					Num.i(cfg["per_chunk"]),
					_f(cfg["push"]),
					_f(cfg["up"]),
					Num.i(blast_cfg["debris"]),
				]
			)
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
	_view = _find(rampage, "CityView")
	for _i: int in SETTLE:
		await physics_frame
	var real_fx := _view.fx
	_log = DustLog.new()
	_view.fx = _log
	_debris = _view.get("_debris")
	_debris.set_process(false)
	var plain := _pick(sim, false)
	var mark := _pick(sim, true)
	print("blast_break dump: plain %d landmark %d" % [plain, mark])
	_case_blast(sim, plain, "blast", 101)
	_case_two(sim, plain, "two", 202)
	_case_expired(sim, plain, "expired", 303)
	_case_blast(sim, mark, "landmark", 404)
	_throws(rampage)
	_view.fx = real_fx
	_log.free()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("blast_break dump: %d lines to %s" % [_lines.size(), OUT])
	rampage.queue_free()
	await process_frame
	quit()


## The building of the kind nearest the middle of the map with two chunks a side: a plain one
## whole and at least FLOORS + 1 floors high, a landmark as it stands.
func _pick(sim: RampageSim, landmark: bool) -> int:
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b: RampageSim.Building = sim.buildings[i]
		if (b.landmark != "") != landmark or b.w < 2 or b.d < 2:
			continue
		if not landmark and b.height < FLOORS + 1:
			continue
		if not landmark and b.frame.alive_count < b.w * b.d * b.height:
			continue
		var dist := Vector2(b.x, b.z).length()
		if dist < best_d:
			best_d = dist
			best = i
	return best


func _site(sim: RampageSim, index: int, name: String, rng_seed: int) -> BlastBreak:
	var b: RampageSim.Building = sim.buildings[index]
	var view := _bv(index)
	_lines.append("CASE %s %d" % [name, rng_seed])
	_lines.append(
		(
			"SITE %d %s %s %d %d %d %d %d"
			% [index, _f(b.x), _f(b.z), b.base, b.w, b.d, b.height, int(b.landmark != "")]
		)
	)
	_states(b, view)
	for y: int in b.height:
		if not _kept(b, y):
			continue
		for z: int in b.d:
			for x: int in b.w:
				var c := Vector3i(x, y, z)
				var parts: Array[Dictionary] = view.call("_parts", [c] as Array[Vector3i])
				_lines.append("PARTS %d %d %d %d" % [x, y, z, parts.size()])
				for part: Dictionary in parts:
					var pos: Vector3 = part["pos"]
					var col: Color = part["color"]
					_lines.append("PART %s %s" % [_v(pos), _c(col)])
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var cfg: Dictionary = Content.section("blast_fx")["break"]
	var bb := BlastBreak.new(_view, rng, cfg)
	bb.set_process(false)
	_mark()
	return bb


func _states(b: RampageSim.Building, view: BuildingView) -> void:
	for y: int in b.height:
		if not _kept(b, y):
			continue
		for z: int in b.d:
			for x: int in b.w:
				var s: float = view.call("_get_state", Vector3i(x, y, z))
				_lines.append("STATE %d %d %d %s" % [x, y, z, _f(s)])


func _end(sim: RampageSim, index: int, bb: BlastBreak) -> void:
	_lines.append("END")
	_states(sim.buildings[index], _bv(index))
	bb.free()


## The floors a case can touch (the low ones, the top ones and the floor under them): the only
## ones written down, so a landmark stays small.
func _kept(b: RampageSim.Building, y: int) -> bool:
	return y <= KEEP_LOW or y >= b.height - FLOORS - 1


## The building's top FLOORS floors, in the sim's order (x, then z, then y).
func _top(b: RampageSim.Building, floors: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for y: int in range(maxi(0, b.height - floors), b.height):
		for z: int in b.d:
			for x: int in b.w:
				cells.append(Vector3i(x, y, z))
	return cells


func _case_blast(sim: RampageSim, index: int, name: String, rng_seed: int) -> void:
	var b: RampageSim.Building = sim.buildings[index]
	var bb := _site(sim, index, name, rng_seed)
	_blew(bb, Vector3(b.x + 3.5, 0.0, b.z - 1.25), b.w + 6.0)
	_takes(sim, bb, index, _top(b, LANDMARK_FLOORS if b.landmark != "" else FLOORS))
	for _f: int in 5:
		_step(bb)
	_end(sim, index, bb)


## A far blast first (its reach misses), then a near one: the near one takes the chunks; a second
## break of other chunks rides along while the first is still running.
func _case_two(sim: RampageSim, index: int, name: String, rng_seed: int) -> void:
	var b: RampageSim.Building = sim.buildings[index]
	var bb := _site(sim, index, name, rng_seed)
	_blew(bb, Vector3(b.x + 60.0, 0.0, b.z), 5.0)
	_blew(bb, Vector3(b.x - 2.0, 0.0, b.z + 2.5), 9.0)
	var low: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0)]
	_takes(sim, bb, index, _top(b, 1))
	_step(bb)
	_takes(sim, bb, index, low)
	for _f: int in 4:
		_step(bb)
	_end(sim, index, bb)


## The window shuts after window_frames frames: a later break is not the blast's.
func _case_expired(sim: RampageSim, index: int, name: String, rng_seed: int) -> void:
	var b: RampageSim.Building = sim.buildings[index]
	var bb := _site(sim, index, name, rng_seed)
	_blew(bb, Vector3(b.x, 0.0, b.z), 20.0)
	for _f: int in 3:
		_step(bb)
	var one: Array[Vector3i] = [Vector3i(0, b.height - 1, 0)]
	_takes(sim, bb, index, one)
	_end(sim, index, bb)


func _blew(bb: BlastBreak, at: Vector3, reach: float) -> void:
	bb.blew(at, reach)
	_lines.append("BLEW %s %s" % [_v(at), _f(reach)])


func _takes(sim: RampageSim, bb: BlastBreak, index: int, cells: Array[Vector3i]) -> void:
	var b: RampageSim.Building = sim.buildings[index]
	var ids := PackedStringArray()
	for c: Vector3i in cells:
		ids.append("%d %d %d" % [c.x, c.y, c.z])
	_lines.append("TAKES %s %s %d %s" % [_f(b.x), _f(b.z), cells.size(), " ".join(ids)])
	var took := bb.takes(index, cells, _bv(index))
	_lines.append("TOOK %d" % int(took))
	_flush()


func _step(bb: BlastBreak) -> void:
	_lines.append("PROCESS")
	bb._process(1.0 / 60.0)
	_flush()


## Forget what the debris queue and the dust log hold so far.
func _mark() -> void:
	var queue: Array = _debris.get("_queue")
	_seen = queue.size()
	_log.calls.clear()


## The debris and dust made since the last mark.
func _flush() -> void:
	var queue: Array = _debris.get("_queue")
	for k: int in range(_seen, queue.size()):
		var q: Array = queue[k]
		var qp: Vector3 = q[0]
		var qc: Color = q[1]
		var qa: Vector3 = q[2]
		_lines.append("FRAG %s %s %s" % [_v(qp), _c(qc), _v(qa)])
	for call: Array in _log.calls:
		var at: Vector3 = call[0]
		_lines.append("DUST %s %s" % [_v(at), _f(call[1])])
	_mark()


func _throws(rampage: Node) -> void:
	var fx: BlastFx = _find(rampage, "BlastFx")
	var colours_of: Dictionary = Content.section("blast_fx")["debris_colors"]
	var n := 0
	for kind: String in THROW_KINDS:
		n += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + n
		fx.set("_rng", rng)
		var centre := Vector3(4.25 * n, 1.5 + n, -3.75 * n)
		var half := Vector3(1.5 + n * 0.25, 2.0 + n, 1.25)
		var colours: Array = colours_of[kind]
		_lines.append(
			"THROW %s %d %s %s %d" % [kind, 500 + n, _v(centre), _v(half), colours.size()]
		)
		for hex: Variant in colours:
			_lines.append("COLOUR %s" % _c(Color(str(hex))))
		_mark()
		fx.call("_throw", kind, centre, half)
		_flush()


func _bv(index: int) -> BuildingView:
	var stream: BuildingStream = _view.get("_stream")
	return stream.view(index)


func _find(node: Node, type: String) -> Node:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() == type:
		return node
	for child: Node in node.get_children():
		var found := _find(child, type)
		if found != null:
			return found
	return null


func _f(x: Variant) -> String:
	return "%.9f" % [x]


func _v(v: Vector3) -> String:
	return "%s %s %s" % [_f(v.x), _f(v.y), _f(v.z)]


func _c(c: Color) -> String:
	return "%s %s %s %s" % [_f(c.r), _f(c.g), _f(c.b), _f(c.a)]
