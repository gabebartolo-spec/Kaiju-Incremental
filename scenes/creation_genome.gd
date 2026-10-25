class_name CreationGenome
extends Node3D
## What happens in the dish of Kaiju Creation (D-207): the picked reptile genome, a double helix
## of blocks lying on the agar, and its takeover. On the strike, white-hot forked lightning crawls
## out from the needle across the dish like a growing colony (seeded branching paths of glowing
## blocks, flickering); each genome block it reaches flashes white, then turns dark with burning
## veins: the kaiju genome. At the overload the whole dish burns white. One block size with the
## props; every number in tuning "creation" "lab". The croc breath's bolt shader is not on main yet,
## so the lightning is drawn with the game's glow blocks (the voxel material's glow flag).

const SALT := 207

## The genome's cells (dish space, cells), nearest the centre first, when each turns, and which
## burn on as veins (those the lightning's path runs over).
var _helix: Array[Vector3i] = []
var _turn_at: PackedFloat32Array = PackedFloat32Array()
var _vein: PackedByteArray = PackedByteArray()
var _helix_mm: MultiMesh
var _genome := Color.WHITE
var _scales := Color.BLACK
## The lightning's cells, in the order the bolt reaches them, and the step each is reached on.
var _bolt: Array[Vector3i] = []
var _bolt_step: PackedInt32Array = PackedInt32Array()
var _bolt_mm: MultiMesh
var _max_step := 1
var _light: OmniLight3D
var _rng: RandomNumberGenerator
var _tick := 0


func _ready() -> void:
	var cfg := CreationSet.cfg()
	var dish: Dictionary = cfg["dish"]
	_rng = Seeds.make("creation_bolt", 0)
	_build_helix(Num.i(dish["surface_y"]))
	var glass: Dictionary = dish["glass"]
	_build_bolt(Num.i(dish["surface_y"]), floori(Num.f(glass["inner"])) - 1)
	_time_takeover()
	_light = OmniLight3D.new()
	_light.light_color = CreationSet.color("bolt")
	_light.light_energy = 0.0
	_light.omni_range = 1.6
	_light.position = Vector3(0.0, 0.45, 0.0)
	add_child(_light)


## The picked titan's genome colour and its body colour (the takeover's dark scales).
func set_titan(genome: Color, body: Color) -> void:
	_genome = genome
	_scales = body.darkened(Num.f(CreationSet.cfg()["bolt"]["char"]))
	for i: int in _helix.size():
		_helix_mm.set_instance_color(i, Color(_genome, 0.0))


func _blocks(cells: Array[Vector3i], col: Color, glow: float) -> MultiMesh:
	var voxel := Num.f(CreationSet.cfg()["voxel"])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Look.voxel_mesh(voxel, glow)
	mm.instance_count = cells.size()
	for i: int in cells.size():
		var at := (Vector3(cells[i]) + Vector3(0.5, 0.5, 0.5)) * voxel
		mm.set_instance_transform(
			i, Transform3D(Basis().scaled(Vector3.ONE * CreationSet.gapless()), at)
		)
		mm.set_instance_color(i, col)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mm


## Two strands winding round a line across the dish, low over the agar, with rungs between them.
func _build_helix(surface: int) -> void:
	var h: Dictionary = CreationSet.cfg()["helix"]
	var length := Num.i(h["length"])
	var radius := Num.f(h["radius"])
	var turns := Num.f(h["turns"])
	var every := Num.i(h["rung_every"])
	var seen := {}
	for i: int in length:
		var x := i - floori(length * 0.5)
		var phase := TAU * turns * i / length
		for side: float in [0.0, PI]:
			var z := roundi(cos(phase + side) * radius)
			var y := surface + roundi((1.0 + sin(phase + side)) * radius * 0.25)
			for dy: int in 2:
				seen[Vector3i(x, y + dy, z)] = true
		if i % every == 0:
			var reach := roundi(absf(cos(phase)) * radius)
			for z: int in range(-reach, reach + 1):
				seen[Vector3i(x, surface + 1, z)] = true
	for cell: Vector3i in seen:
		_helix.append(cell)
	_helix.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return _r2(a) < _r2(b))
	_helix_mm = _blocks(_helix, _genome, Num.f(CreationSet.cfg()["glow"]))
	_helix_mm.visible_instance_count = 0


static func _r2(c: Vector3i) -> int:
	return c.x * c.x + c.z * c.z


## Seeded branching paths from the needle's touch outwards across the agar: each branch steps one
## cell at a time, wandering, and sometimes forks, until the dish's edge or the cell budget.
func _build_bolt(surface: int, radius: int) -> void:
	var b: Dictionary = CreationSet.cfg()["bolt"]
	var fork := Num.f(b["fork_chance"])
	var budget := Num.i(b["max_cells"])
	var tips: Array[Array] = []
	for k: int in Num.i(b["branches"]):
		var angle := TAU * k / Num.f(b["branches"]) + _rng.randf_range(-0.3, 0.3)
		tips.append([Vector2.ZERO, angle, 0])
	var seen := {}
	while not tips.is_empty() and _bolt.size() < budget:
		var tip: Array = tips.pop_front()
		var at: Vector2 = tip[0]
		var angle := Num.f(tip[1]) + _rng.randf_range(-0.3, 0.3)
		var step := Num.i(tip[2]) + 1
		var next := at + Vector2.from_angle(angle)
		if next.length() > radius:
			continue
		var cell := Vector3i(roundi(next.x), surface + 2, roundi(next.y))
		if not seen.has(cell):
			seen[cell] = true
			_bolt.append(cell)
			_bolt_step.append(step)
			_max_step = maxi(_max_step, step)
		tips.append([next, angle, step])
		if _rng.randf() < fork:
			tips.append(
				[next, angle + _rng.randf_range(0.6, 1.1) * signf(_rng.randf() - 0.5), step]
			)
	_bolt_mm = _blocks(_bolt, Color(CreationSet.color("bolt"), 0.0), Num.f(b["glow"]))
	_bolt_mm.visible_instance_count = 0


## Each genome cell turns when the nearest bolt cell within reach is struck (its step), else at
## the overload (a step past the last).
func _time_takeover() -> void:
	var b: Dictionary = CreationSet.cfg()["bolt"]
	var reach := Num.i(b["convert_reach"])
	var vein_reach := Num.i(b["vein_reach"])
	var grid := {}
	for i: int in _bolt.size():
		var key := Vector2i(_bolt[i].x, _bolt[i].z)
		grid[key] = mini(Num.i(grid.get(key, _bolt_step[i])), _bolt_step[i])
	_turn_at.resize(_helix.size())
	_vein.resize(_helix.size())
	for i: int in _helix.size():
		var best := _max_step + 1
		for dx: int in range(-reach, reach + 1):
			for dz: int in range(-reach, reach + 1):
				var key := Vector2i(_helix[i].x + dx, _helix[i].z + dz)
				if grid.has(key):
					best = mini(best, Num.i(grid[key]))
					if absi(dx) <= vein_reach and absi(dz) <= vein_reach:
						_vein[i] = 1
		_turn_at[i] = float(best) / (_max_step + 1)


## The genome settles into the agar from the centre out (t 0..1).
func settle(t: float) -> void:
	_helix_mm.visible_instance_count = roundi(_helix.size() * clampf(t, 0.0, 1.0))


## The takeover (p 0..1): the bolt reaches out step by step, flickering; each genome cell it has
## reached flashes white, then darkens to the kaiju's scales; those under its path burn on as veins.
func takeover(p: float) -> void:
	var b: Dictionary = CreationSet.cfg()["bolt"]
	_tick += 1
	var now := p * (_max_step + 1)
	var shown := 0
	while shown < _bolt.size() and _bolt_step[shown] <= now:
		shown += 1
	_bolt_mm.visible_instance_count = shown
	if _tick % Num.i(b["flicker_ticks"]) == 0:
		_flicker(shown, Num.f(b["flicker_share"]))
	var hot := Color(CreationSet.color("bolt"), 0.0)
	var lag := 0.03
	for i: int in _helix.size():
		if p < _turn_at[i]:
			continue
		var vein := _vein[i] == 1
		var cooled := p >= _turn_at[i] + lag
		_helix_mm.set_instance_color(i, (hot if vein else _scales) if cooled else hot)
	_light.light_energy = (
		CreationSet.energy("bolt") * (0.6 + 0.4 * _rng.randf()) * minf(p * 4.0, 1.0)
	)


func _flicker(shown: int, share: float) -> void:
	var hot := Color(CreationSet.color("bolt"), 0.0)
	var dim := Color(CreationSet.color("bolt_flicker"), 0.0)
	for i: int in shown:
		_bolt_mm.set_instance_color(i, dim if _rng.randf() < share else hot)


## The overload (o 0..1): every genome and bolt cell burns white and the dish floods the lab.
func overload(o: float) -> void:
	var hot := Color(CreationSet.color("bolt"), 0.0)
	_bolt_mm.visible_instance_count = _bolt.size()
	var upto := roundi(_helix.size() * clampf(o * 1.5, 0.0, 1.0))
	for i: int in upto:
		_helix_mm.set_instance_color(i, hot)
	for i: int in _bolt.size():
		_bolt_mm.set_instance_color(i, hot)
	_light.light_energy = CreationSet.energy("bolt") * (1.0 + 2.0 * o)
