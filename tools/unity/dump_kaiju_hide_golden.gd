extends SceneTree
## Writes Godot's kaiju hide (scenes/kaiju_hide.gd) and a falling part's break-up against him or
## a neighbour (scenes/city_falls.gd _shatter), so the Unity port
## (unity/Assets/Scripts/GameLogic/KaijuHide.cs) can be checked against it.
##
##   godot --path . --script tools/unity/dump_kaiju_hide_golden.gd
##
## Not headless, like the other view dumps (the building views need their meshes).
##
## A stage-2 run settles; then, with the sim held, the kaiju is posed (size, growth, place,
## stand height) and the city view's own KaijuHide and CityFalls answer.
##
## Output: unity/SimTests/golden/kaiju_hide.txt, read by KaijuHideCheck
## (`dotnet run --project unity/SimTests`). TUNING: fall_contact hide_radius, hide_height,
## fragment_margin; powers body_radius. POSE (size, growth, x, z, stand_y), then CAP (body scale,
## reach height, foot, head, radius), SHAPE (the collision capsule's radius, height and place)
## and OUT lines (a point, the point moved clear of the hide). SHATTER (name, seed, contact), with
## the posed kaiju before it: XF (the part's basis columns and origin), PIVOT, PARTS (count) and
## its PART lines (pos, colour), then the FRAG lines it threw (pos, colour, away).

const OUT := "res://unity/SimTests/golden/kaiju_hide.txt"
const STAGE := 2
const SETTLE := 240
## The poses: [size, growth, x, z, stand_y]: young and grown, ashore, mid-rise and on a roof.
const POSES := [
	[2.0, 0.0, 0.0, 0.0, 0.0],
	[1.0, 0.0, 12.5, -7.25, 0.0],
	[3.0, 2.0, -20.0, 31.0, 0.0],
	[2.0, 1.0, 4.0, 60.0, -3.5],
	[2.0, 0.0, -8.0, -3.0, 6.0],
]
## Each break-up: [name, seed, contact, pose index, floors of the part, turn (deg) about x and z].
const SHATTERS := [
	["kaiju", 101, "kaiju", 0, 2, 0.0],
	["kaiju_tilted", 202, "kaiju", 2, 1, 35.0],
	["building", 303, "building", 1, 2, 60.0],
	["kaiju_one_chunk", 404, "kaiju", 4, 0, 10.0],
]

var _lines: PackedStringArray = []
var _sim: RampageSim
var _view: CityView
var _debris: DebrisField
var _hide: KaijuHide
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
	_sim = rampage.sim
	_view = _find(rampage, "CityView")
	for _i: int in SETTLE:
		await physics_frame
	_debris = _view.get("_debris")
	_debris.set_process(false)
	_hide = _view.kaiju_hide
	var cfg := Content.section("fall_contact")
	(
		_lines
		. append(
			(
				"TUNING %s %s %s %s"
				% [
					_f(Num.f(cfg["hide_radius"])),
					_f(Num.f(cfg["hide_height"])),
					_f(Num.f(cfg["fragment_margin"])),
					_f(Num.f(_sim.powers_cfg["body_radius"])),
				]
			)
		)
	)
	for pose: Array in POSES:
		_pose(pose)
		_outs()
	var index := _pick()
	var b: RampageSim.Building = _sim.buildings[index]
	for spec: Array in SHATTERS:
		var pose: Array = POSES[spec[3]]
		_pose(pose, Vector2(b.x, b.z))
		_shatter(spec, index)
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("kaiju_hide dump: %d lines to %s" % [_lines.size(), OUT])
	rampage.queue_free()
	await process_frame
	quit()


## The kaiju posed (`at`: his place instead of the pose's own) and his hide followed, as the
## view's physics step does.
func _pose(pose: Array, at := Vector2.INF) -> void:
	_sim.stats["size"] = pose[0]
	_sim.stats["growth"] = pose[1]
	var x: float = pose[2]
	var z: float = pose[3]
	var stand: float = pose[4]
	_sim.kaiju_pos = Vector2(x, z) if at == Vector2.INF else at
	_sim.stand_y = stand
	_lines.append(
		(
			"POSE %s %s %s %s %s"
			% [_f(pose[0]), _f(pose[1]), _f(_sim.kaiju_pos.x), _f(_sim.kaiju_pos.y), _f(pose[4])]
		)
	)
	var cap := _hide.capsule()
	var foot: Vector3 = cap[0]
	var head: Vector3 = cap[1]
	_lines.append(
		(
			"CAP %s %s %s %s %s"
			% [_f(_sim.body_scale()), _f(_sim.reach_height()), _v(foot), _v(head), _f(cap[2])]
		)
	)
	_hide.call("_follow")
	var shape: CapsuleShape3D = _hide.get("_shape")
	_lines.append("SHAPE %s %s %s" % [_f(shape.radius), _f(shape.height), _v(_hide.position)])


## Points round the hide, each moved clear of it: on the axis, inside, on the skin, inside the
## margin, past it, under the foot and over the head.
func _outs() -> void:
	var cap := _hide.capsule()
	var a: Vector3 = cap[0]
	var b: Vector3 = cap[1]
	var r: float = cap[2]
	var mid := (a + b) * 0.5
	var side := Vector3(0.6, 0.0, 0.8)
	var points: Array[Vector3] = [
		mid,
		a,
		mid + side * r * 0.5,
		mid + side * r,
		mid + side * (r + 0.1),
		mid + side * (r + 0.29),
		mid + side * (r + 0.31),
		mid + side * (r + 2.0),
		a + Vector3(0.2, -r * 0.7, -0.1),
		a + Vector3(0.0, -r - 0.1, 0.0),
		b + Vector3(-0.3, r * 0.6, 0.4),
		b + Vector3(0.0, r + 5.0, 0.0),
		b + Vector3(r * 0.4, r * 0.4, r * 0.4),
	]
	for p: Vector3 in points:
		_lines.append("OUT %s %s" % [_v(p), _v(_hide.outside(p))])


## A part of building `index` (its top floors' samples, or one chunk's) posed over the kaiju
## and broken up by CityFalls, on its own seed.
func _shatter(spec: Array, index: int) -> void:
	_lines.append("SHATTER %s %d %s" % [spec[0], spec[1], spec[2]])
	var b: RampageSim.Building = _sim.buildings[index]
	var view := _bv(index)
	var cells: Array[Vector3i] = []
	var floors: int = spec[4]
	if floors == 0:
		cells.append(Vector3i(0, b.height - 1, 0))
	else:
		for y: int in range(b.height - floors, b.height):
			for z: int in b.d:
				for x: int in b.w:
					cells.append(Vector3i(x, y, z))
	var parts: Array = view.call("_parts", cells)
	var node := Node3D.new()
	_view.add_child(node)
	var degrees: float = spec[5]
	var turn := deg_to_rad(degrees)
	var basis := Basis(Vector3(1, 0, 1).normalized(), turn)
	var pivot := Vector3(b.x, b.base + b.height - floors, b.z)
	node.global_transform = Transform3D(basis, pivot + Vector3(0.4, -1.5, -0.25))
	node.set_meta("parts", parts)
	node.set_meta("pivot", pivot)
	var xf := node.global_transform
	_lines.append(
		"XF %s %s %s %s" % [_v(xf.basis.x), _v(xf.basis.y), _v(xf.basis.z), _v(xf.origin)]
	)
	_lines.append("PIVOT %s" % _v(pivot))
	_lines.append("PARTS %d" % parts.size())
	for part: Dictionary in parts:
		_part(part)
	var falls: CityFalls = _view.get("_falls")
	var rng: RandomNumberGenerator = falls.get("_rng")
	var rng_seed: int = spec[1]
	rng.seed = rng_seed
	_mark()
	falls.call("_shatter", node, parts, {"contact": spec[2]})
	_flush()


## The plain building nearest the middle of the map, whole, at least three floors high and two
## chunks a side.
func _pick() -> int:
	var best := -1
	var best_d := INF
	for i: int in _sim.buildings.size():
		var b: RampageSim.Building = _sim.buildings[i]
		if b.landmark != "" or b.w < 2 or b.d < 2 or b.height < 3:
			continue
		if b.frame.alive_count < b.w * b.d * b.height:
			continue
		var dist := Vector2(b.x, b.z).length()
		if dist < best_d:
			best_d = dist
			best = i
	return best


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
