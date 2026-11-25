extends SceneTree
## Writes how Godot draws a downed helicopter's numbers (HeliWreck _fall, _break_up, _jump, _canopy,
## _process; HeliDebris shards, throw, _step), so the Unity port
## (unity/Assets/Scripts/GameLogic/HeliWreck.cs) can be checked against it.
##
##   godot --path . --script tools/unity/dump_heli_wreck_golden.gd
##
## Run it with a window for the canopy: a headless MultiMesh keeps no instance transforms, so a
## headless run (while a game is running, say) leaves the CANOPY section out.
##
## The wreck is made with no city or sim (only its effects need them), and the effects are left
## out: only the code that draws from the heli_wreck stream or moves something runs. A fall is set
## up as HeliWreck._spin sets it (from, drift, seconds, side) and a crew member jumps from where
## _spin jumps them; both are copied here because _spin also lights the city's effects.
##
## Output: unity/SimTests/golden/heli_wreck.txt, read by HeliWreckCheck
## (`dotnet run --project unity/SimTests`). RATE: steps a second. FALL: from, drift, seconds,
## then FPOSE per sampled step (time, position, basis x, y, z). BURST / CRASH: where, then one
## PIECE per piece thrown, in the order Godot threw them (part number or -1 for a chunk,
## position, rotation, scale, velocity, spin, half, lie, flat, fire seed or -1, chunk colour
## or -, a part's start position, rotation and scale as float bits or -), then per sampled
## step one STEP per piece still there (piece, position, basis x, y, z, burning) and GONE when
## it faded. CREW: where the hit was and the drift, then for each of two jumpers CHUTE: from,
## to, seconds, then CPOSE per sampled step (time, position, swing) and LANDED.
## CANOPY: one CELL per dome cube (cell, dark panel) and one LINE per shroud line (middle,
## length).

const OUT := "res://unity/SimTests/golden/heli_wreck.txt"
const RATE := 30  # steps a second
const DT := 1.0 / RATE
const STEPS := 360  # 12 s: flight from 40 m, a bounce, rest_seconds lying, fade_seconds shrinking
const EVERY := 6
const FALLS: Array[Array] = [  # from, drift, seconds
	[Vector3(12.0, 30.0, -8.0), Vector3(3.0, 0.0, -1.5), 3.2],
	[Vector3(-20.0, 26.5, 14.0), Vector3(0.0, 0.0, 0.0), 2.6],
	[Vector3(4.0, 41.0, 9.0), Vector3(-2.2, 0.0, 4.1), 4.0],
]
const BURSTS: Array[Vector3] = [Vector3(6.0, 32.0, -4.0), Vector3(-15.0, 28.0, 21.0)]
const CRASHES: Array[Vector3] = [Vector3(10.0, 0.0, 3.0), Vector3(-7.0, 18.0, -12.0)]
const YAWS: Array[float] = [0.4, -2.3]  # the models' headings before they break up
const CREW: Array[Array] = [  # where the hit was, the fall's drift
	[Vector3(12.0, 30.0, -8.0), Vector3(3.0, 0.0, -1.5)],
	[Vector3(-20.0, 26.5, 14.0), Vector3(0.0, 0.0, 0.0)],
]

var _lines: PackedStringArray = []
var _wreck: HeliWreck
var _cfg: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wreck = HeliWreck.new(null, null)
	root.add_child(_wreck)
	_wreck.set_process(false)
	_wreck._debris.set_process(false)
	_cfg = Content.section("heli_wreck")
	_lines.append("RATE %d" % RATE)
	_falls()
	var paint := HelicopterModel.GUNSHIP_PAINT
	for k: int in BURSTS.size():
		_lines.append("BURST %s %s %s" % [_v(BURSTS[k]), _c(paint[0]), _c(paint[1])])
		var start := _wreck._debris._pieces.size()
		_wreck._break_up(_model(BURSTS[k], YAWS[k]), 1.0, true)
		_wreck._debris.shards(
			BURSTS[k], Vector2i(Num.i(_cfg["burst_shards"]), Num.i(_cfg["burst_burning"])), paint
		)
		_pieces(start)
	for k: int in CRASHES.size():
		var ground := CRASHES[k]
		_lines.append("CRASH %s %s %s" % [_v(ground), _c(paint[0]), _c(paint[1])])
		var start := _wreck._debris._pieces.size()
		_wreck._break_up(_model(ground + Vector3(0, 1.2, 0), YAWS[k]), 0.6, false)
		_wreck._debris.shards(
			ground + Vector3(0, 0.8, 0), Vector2i(Num.i(_cfg["crash_shards"]), 2), paint, 0.7
		)
		_pieces(start)
	_chutes()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("heli wreck golden: %d lines -> %s" % [_lines.size(), OUT])
	quit(0)


## A gunship at `at` heading `yaw`, its rotors turned a little so their parts start askew.
func _model(at: Vector3, yaw: float) -> HelicopterModel:
	var heli := HelicopterModel.added_to(_wreck)
	heli.position = at
	heli.rotation.y = yaw
	heli._main_rotor.rotation.y = 0.9
	heli._tail_rotor.rotation.x = 1.7
	return heli


func _falls() -> void:
	for spec: Array in FALLS:
		var node := Node3D.new()
		_wreck.add_child(node)
		var fall := HeliWreck.Fall.new()
		fall.node = node
		var drift: Vector3 = spec[1]
		fall.from = spec[0]
		fall.drift = Vector3(drift.x, 0.0, drift.z)
		fall.seconds = spec[2]
		fall.side = Vector3(-fall.drift.z, 0.0, fall.drift.x).normalized()
		if fall.side.length() < 0.5:
			fall.side = Vector3.RIGHT
		fall.trail = GPUParticles3D.new()
		_wreck.add_child(fall.trail)
		_lines.append("FALL %s %s %s" % [_v(fall.from), _v(fall.drift), _f(fall.seconds)])
		var steps := ceili(fall.seconds / DT)
		for s: int in steps:
			_wreck._fall(fall, DT)
			if s % EVERY == 0 or s == steps - 1:
				var b := node.basis
				_lines.append(
					(
						"FPOSE %s %s %s %s %s"
						% [_f(fall.t), _v(node.position), _v(b.x), _v(b.y), _v(b.z)]
					)
				)
		fall.trail.free()
		node.free()


## Every piece thrown since `start`, then their flight until each has faded.
func _pieces(start: int) -> void:
	var pieces: Array = _wreck._debris._pieces.slice(start)
	for n: int in pieces.size():
		var p: HeliDebris.Piece = pieces[n]
		var node := p.node
		var part := -1
		var colour := "-"
		if node is MeshInstance3D:
			colour = _c(
				((node as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
			)
		else:
			part = n
		(
			_lines
			. append(
				(
					"PIECE %d %s %s %s %s %s %s %s %d %s %s %s"
					% [
						part,
						_v(node.global_position),
						_v(node.rotation),
						_v(node.scale),
						_v(p.vel),
						_v(p.spin),
						_f(p.half),
						_f(p.lie),
						1 if p.flat else 0,
						_f(p.fire._seed) if p.fire != null else "-1",
						colour,
						(
							_bits([node.global_position, node.rotation, node.scale])
							if part >= 0
							else "-"
						),
					]
				)
			)
		)
	var live: Array[bool] = []
	live.resize(pieces.size())
	live.fill(true)
	var gravity := Num.f(_cfg["gravity"])
	for s: int in STEPS:
		for n: int in pieces.size():
			if not live[n]:
				continue
			var p: HeliDebris.Piece = pieces[n]
			if not _wreck._debris._step(p, DT, gravity):
				live[n] = false
				_lines.append("GONE %d %d" % [n, s])
				continue
			if s % EVERY == 0:
				var b := p.node.global_transform.basis
				_lines.append(
					(
						"STEP %d %d %s %s %s %s %d"
						% [
							n,
							s,
							_v(p.node.global_position),
							_v(b.x),
							_v(b.y),
							_v(b.z),
							1 if p.fire != null else 0
						]
					)
				)
	for n: int in pieces.size():
		var p: HeliDebris.Piece = pieces[n]
		if is_instance_valid(p.node) and not p.node.is_queued_for_deletion():
			p.node.free()
	_wreck._debris._pieces.clear()


func _chutes() -> void:
	for spec: Array in CREW:
		var at: Vector3 = spec[0]
		var drift: Vector3 = spec[1]
		_lines.append("CREW %s %s" % [_v(at), _v(drift)])
		for n: int in 2:
			_wreck._crew.clear()
			_wreck._jump(at + Vector3((n - 0.5) * 7.0, -0.5, 1.5), drift)
			var chute: HeliWreck.Chute = _wreck._crew[0]
			_lines.append("CHUTE %s %s %s" % [_v(chute.from), _v(chute.to), _f(chute.seconds)])
			var node := chute.node
			if n == 0 and spec == CREW[0] and DisplayServer.get_name() != "headless":
				_canopy(node.get_child(0) as Node3D)
			var s := 0
			while not _wreck._crew.is_empty():
				_wreck._process(DT)
				if _wreck._crew.is_empty():
					_lines.append("LANDED %d" % s)
				elif s % EVERY == 0:
					_lines.append(
						"CPOSE %s %s %s" % [_f(chute.t), _v(node.position), _f(node.rotation.z)]
					)
				s += 1
			if is_instance_valid(node):
				node.free()


## The canopy's dome cubes and shroud lines as _canopy built them.
func _canopy(canopy: Node3D) -> void:
	var voxel := Num.f(_cfg["canopy_voxel"])
	var dome := canopy.get_child(0) as MultiMeshInstance3D
	var mm := dome.multimesh
	_lines.append("CANOPY %d %s" % [mm.instance_count, _v(dome.position)])
	for n: int in mm.instance_count:
		var cell := mm.get_instance_transform(n).origin / voxel
		var dark := 0 if mm.get_instance_color(n).is_equal_approx(HeliWreck.CANOPY) else 1
		_lines.append("CELL %d %d %d %d" % [roundi(cell.x), roundi(cell.y), roundi(cell.z), dark])
	for k: int in range(1, canopy.get_child_count()):
		var line := canopy.get_child(k) as MeshInstance3D
		_lines.append("LINE %s %s" % [_v(line.position), _f((line.mesh as BoxMesh).size.z)])


static func _f(x: float) -> String:
	return "%.7f" % x


static func _v(v: Vector3) -> String:
	return "%s %s %s" % [_f(v.x), _f(v.y), _f(v.z)]


## A part's start exactly (position, rotation, scale as the float bits Godot holds), so the
## port starts each part's tumble from the same angles: near a quarter turn of pitch the
## reading back of the angles magnifies the last digit.
static func _bits(vs: Array[Vector3]) -> String:
	var out := PackedFloat32Array()
	for v: Vector3 in vs:
		out.append_array([v.x, v.y, v.z])
	return out.to_byte_array().hex_encode()


static func _c(c: Color) -> String:
	return c.to_html(false)
