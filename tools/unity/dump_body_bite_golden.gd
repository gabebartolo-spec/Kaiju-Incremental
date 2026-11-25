extends SceneTree
## Writes how Godot's body bite tears a piece off a building (scenes/body_bite.gd,
## BuildingView.chip),
## so the Unity port (unity/Assets/Scripts/GameLogic/BodyBite.cs) can be checked against it.
##
##   godot --path . --script tools/unity/dump_body_bite_golden.gd
##
## Not headless, like the other view dumps (the building views need their meshes).
##
## A stage-2 run settles, then BodyBite.tear (its rng seeded per case) bites chunks of real
## building views: the city's debris queue is read, and the piece's tween is stepped by hand.
##
## Output: unity/SimTests/golden/body_bite.txt, read by BodyBiteCheck
## (`dotnet run --project unity/SimTests`). TUNING: fall_gravity. Per CASE (name, seed): SITE
## (index, x, z, base, w, d, height, landmark 0/1), STATE per chunk of the floors next to the
## bite (x y z state), PARTS per such chunk (x y z count) and its PART lines (pos, colour); BITE
## (kaiju at, cell count, cells), then the chipped FRAG lines (pos, colour, away); PIECE (sample
## count) and its PART lines; POSE per 1/60 s step of the piece's fall (seconds, position,
## rotation); LAND, then the landing's FRAG lines; END then the chunks' states after (STATE).

const OUT := "res://unity/SimTests/golden/body_bite.txt"
const STAGE := 2
const SETTLE := 240
const STEP := 1.0 / 60.0
const MAX_STEPS := 600
## Each case's rng seed (the CASE line carries it for BodyBiteCheck).
const SEEDS := {"wall": 101, "low": 202, "landmark": 303}

var _lines: PackedStringArray = []
var _sim: RampageSim
var _view: CityView
var _debris: DebrisField
var _seen := 0


func _initialize() -> void:
	QuitGame.release_sims_at_exit(self)
	SaveFile.pinned_seed = 0
	_run.call_deferred()


func _run() -> void:
	await process_frame
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
	_sim = sim
	_view = _find(rampage, "CityView")
	for _i: int in SETTLE:
		await physics_frame
	_lines.append("TUNING fall_gravity %s" % _f(Num.f(sim.city["fall_gravity"])))
	_debris = _view.get("_debris")
	_debris.set_process(false)
	var plain := _pick(sim, false)
	var mark := _pick(sim, true)
	print("body_bite dump: plain %d landmark %d" % [plain, mark])
	var b: RampageSim.Building = sim.buildings[plain]
	var y := b.height - 2
	var side: Array[Vector3i] = [Vector3i(0, y, 0), Vector3i(0, y, 1)]
	_case(plain, "wall", side, Vector3(b.x - b.w * 0.5 - 3.0, 0.0, b.z + 0.25))
	var low: Array[Vector3i] = [Vector3i(1, 0, 0)]
	_case(plain, "low", low, Vector3(b.x + 0.5, 0.0, b.z - b.d * 0.5 - 2.5))
	var m: RampageSim.Building = sim.buildings[mark]
	var pair: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(1, 1, 0)]
	_case(mark, "landmark", pair, Vector3(m.x - 9.0, 0.0, m.z - 7.0))
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("body_bite dump: %d lines to %s" % [_lines.size(), OUT])
	rampage.queue_free()
	await process_frame
	quit()


## The building of the kind nearest the middle of the map with two chunks a side: a plain one
## whole and at least three floors high, a landmark as it stands.
func _pick(sim: RampageSim, landmark: bool) -> int:
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b: RampageSim.Building = sim.buildings[i]
		if (b.landmark != "") != landmark or b.w < 2 or b.d < 2:
			continue
		if not landmark and b.height < 3:
			continue
		if not landmark and b.frame.alive_count < b.w * b.d * b.height:
			continue
		var dist := Vector2(b.x, b.z).length()
		if dist < best_d:
			best_d = dist
			best = i
	return best


func _case(index: int, name: String, cells: Array[Vector3i], kaiju_at: Vector3) -> void:
	var b: RampageSim.Building = _sim.buildings[index]
	var view := _bv(index)
	var rng_seed: int = SEEDS[name]
	_lines.append("CASE %s %d" % [name, rng_seed])
	_lines.append(
		(
			"SITE %d %s %s %d %d %d %d %d"
			% [index, _f(b.x), _f(b.z), b.base, b.w, b.d, b.height, int(b.landmark != "")]
		)
	)
	var floors := _floors(b, cells)
	_states(b, view, floors)
	for y: int in floors:
		for z: int in b.d:
			for x: int in b.w:
				var c := Vector3i(x, y, z)
				var parts: Array[Dictionary] = view.call("_parts", [c] as Array[Vector3i])
				_lines.append("PARTS %d %d %d %d" % [x, y, z, parts.size()])
				for part: Dictionary in parts:
					_part(part)
	var ids := PackedStringArray()
	for c: Vector3i in cells:
		ids.append("%d %d %d" % [c.x, c.y, c.z])
	_lines.append("BITE %s %d %s" % [_v(kaiju_at), cells.size(), " ".join(ids)])
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var before := get_processed_tweens()
	_mark()
	var kids := _view.get_child_count()
	BodyBite.tear(_view, view, cells, kaiju_at, rng)
	_flush()  # the chipped edges fly at once
	var piece: Node3D = _view.get_child(kids)
	var tween := _new_tween(before)
	var parts: Array = PieceParts.of(piece)
	_lines.append("PIECE %d" % parts.size())
	for part: Dictionary in parts:
		_part(part)
	var t := 0.0
	for _k: int in MAX_STEPS:
		tween.custom_step(STEP)
		t += STEP
		if not tween.is_running():
			break
		_lines.append("POSE %s %s %s" % [_f(t), _v(piece.position), _v(piece.rotation)])
	_lines.append("LAND %s" % _f(t))
	_flush()
	_lines.append("END")
	_states(b, view, floors)


## The tween the bite made (the one not running before it).
func _new_tween(before: Array[Tween]) -> Tween:
	for tw: Tween in get_processed_tweens():
		if not before.has(tw):
			return tw
	push_error("body_bite dump: the bite made no tween")
	return null


## The bite's floors and the one either side of each (the chip reaches no further).
func _floors(b: RampageSim.Building, cells: Array[Vector3i]) -> Array[int]:
	var out: Array[int] = []
	for y: int in b.height:
		for c: Vector3i in cells:
			if absi(c.y - y) <= 1 and not out.has(y):
				out.append(y)
	return out


func _states(b: RampageSim.Building, view: BuildingView, floors: Array[int]) -> void:
	for y: int in floors:
		for z: int in b.d:
			for x: int in b.w:
				var s: float = view.call("_get_state", Vector3i(x, y, z))
				_lines.append("STATE %d %d %d %s" % [x, y, z, _f(s)])


## Forget what the debris queue holds so far.
func _mark() -> void:
	var queue: Array = _debris.get("_queue")
	_seen = queue.size()


## The debris made since the last mark.
func _flush() -> void:
	var queue: Array = _debris.get("_queue")
	for k: int in range(_seen, queue.size()):
		var q: Array = queue[k]
		var qp: Vector3 = q[0]
		var qc: Color = q[1]
		var qa: Vector3 = q[2]
		_lines.append("FRAG %s %s %s" % [_v(qp), _c(qc), _v(qa)])
	_mark()


func _part(part: Dictionary) -> void:
	var pos: Vector3 = part["pos"]
	var col: Color = part["color"]
	_lines.append("PART %s %s" % [_v(pos), _c(col)])


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
