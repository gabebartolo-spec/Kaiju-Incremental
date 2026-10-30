class_name StreetProps
extends RefCounted
## The Tripo street props (D-266, city.street_props): pavement furniture along every playable
## street, Tripo cars among the parked and stopped ones, a traffic light at every lit crossing and
## the lamp model on every streetlight. Each is its baked .kvox (tools/street_props/bake.sh) on
## its own PropField at half the buildings' cube, turned a quarter at a time to face its street,
## and flattens under the kaiju like any prop. Seeded off the decor's own seed, so the decor's
## draws are unchanged. Presentation only.

const DIR := "res://assets/street_props/%s.kvox"

## Parsed models per id (the first pose's cells): every city shares one read.
static var _models: Dictionary = {}

var field: PropField
var placed: Dictionary = {}  # id -> how many stand in this city (tests, the report)
var _cfg: Dictionary
var _rng := RandomNumberGenerator.new()
var _spots: Array[Vector2] = []  # every placed prop's base (spacing)


func _init(city: Dictionary, decor_seed: int) -> void:
	_cfg = city["street_props"]
	field = PropField.new(Num.f(_cfg["voxel"]))
	_rng.seed = hash([decor_seed, "street_props"])


## A prop's cells (prop-local, front to -Z), or null when its .kvox is missing.
static func model(id: String) -> VoxelBuilder:
	if not _models.has(id):
		var read := Kvox.read(DIR % id)
		_models[id] = read.frames[0] if not read.frames.is_empty() else null
	return _models[id]


## Places `id` with its base at `at`, its front (-Z, turned by the model's yaw) toward `face`.
func put(id: String, at: Vector2, face: Vector2) -> bool:
	var cells := model(id)
	if cells == null:
		return false
	var turns := (_quarter(face) + Num.i(_cfg["models"][id]["yaw"])) % 4
	field.add(Vector3(at.x, 0, at.y), func(v: VoxelBuilder) -> void: _turned(cells, turns, v))
	placed[id] = Num.i(placed.get(id, 0)) + 1
	_spots.append(at)
	return true


## A model id drawn from `weights` (id -> weight), or "code" for the decor's own voxel car.
func pick(weights: Dictionary) -> String:
	var total := 0.0
	for id: String in weights:
		total += Num.f(weights[id])
	var roll := _rng.randf() * total
	for id: String in weights:
		roll -= Num.f(weights[id])
		if roll < 0.0:
			return id
	return "code"


## A car at p along its street: a Tripo car by city.street_props.parked (lane: .lane, with the
## big vehicles); false when the draw is the decor's own car.
func vehicle(p: Vector2, dir: Vector2, lane: bool) -> bool:
	var weights: Dictionary = _cfg["lane" if lane else "parked"]
	var id := pick(weights)
	if id == "code":
		return false
	return put(id, p, dir if _rng.randf() < 0.5 else -dir)


## Pavement props along both kerbs of the street a..b, every kerb.gap, inset from the kerb,
## facing the road; none on a building or the water, near a lamp or a street tree (`clear_of`
## answers whether a ground point is free).
func kerb(a: Vector2, b: Vector2, width: float, clear_of: Callable) -> void:
	var cfg: Dictionary = _cfg["kerb"]
	var gap: Array = cfg["gap"]
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var length := a.distance_to(b)
	var clear := Num.f(cfg["clear"])
	for kerb_side: float in [-1.0, 1.0]:
		var t := _rng.randf_range(Num.f(gap[0]), Num.f(gap[1])) * 0.5 + clear
		while t < length - clear:
			var p := a + dir * t + side * kerb_side * (width * 0.5 + Num.f(cfg["inset"]))
			var weights: Dictionary = cfg["weights"]
			var id := pick(weights)
			if clear_of.call(p, clear) and not _crowded(p, clear):
				put(id, p, -side * kerb_side)
			t += _rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))


## Draws the props: one Node3D of culled tiles (PropField.build).
func build(salt: int) -> Node3D:
	return field.build({}, salt, 0.0)


func _crowded(p: Vector2, apart: float) -> bool:
	for q: Vector2 in _spots:
		if p.distance_to(q) < apart:
			return true
	return false


## Which quarter turn (0-3) brings -Z nearest `face` on the ground (x, z).
static func _quarter(face: Vector2) -> int:
	if absf(face.x) > absf(face.y):
		return 1 if face.x < 0.0 else 3
	return 0 if face.y < 0.0 else 2


## `cells` turned `turns` quarters about y (a turn takes -Z to -X) into `v`, colours kept.
static func _turned(cells: VoxelBuilder, turns: int, v: VoxelBuilder) -> void:
	for cell: Vector3i in cells.cells:
		var c := cell
		for _i: int in turns:
			c = Vector3i(c.z, c.y, -c.x)
		var color: Color = cells.colors[cell]
		v.put_color(c, color)
