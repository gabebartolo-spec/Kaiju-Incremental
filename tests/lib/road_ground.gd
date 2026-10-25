extends RefCounted
## The ground of one street plan (CityGen.map) as CityGround draws it, for the roads suite: what
## a point (x, z, metres) is, how high its top stands, and which road's carriageway holds it.
## It follows CityGround's drawing order: a bridge deck over the river's open water; the
## diagonal avenue laid over the blocks; each block's raised pavement (CityGen.pavement) with a
## park's lawn, a plaza or landmark's paving and a car park's asphalt on it; then the asphalt
## land, which is a road where a street's carriageway (crossing to crossing, reaching half its
## width into each junction) holds the point, and bare asphalt anywhere else. Alleys carry no
## asphalt: the pavements either side meet across them. Pure: plan and config in.

const ROAD := "road"
const DECK := "deck"
const WATER := "water"
const BARE := "bare asphalt"
const PAVE := "pavement"
const LAWN := "lawn"
const PLAZA := "plaza"
const LOT := "car park"
const BAY := "bay"
const BUCKET := 16.0  # spatial hash cell (m)
const PARK_LAWN_INSET := 0.5  # CityGround: a park's lawn, in from its pavement
const LOT_INSET := 0.6  # CityGround: a car park's asphalt, in from its pavement
const LAWN_RISE := 0.02  # CityGround: the lawn over the pavement
const LOT_RISE := 0.01  # CityGround: the car park over the pavement
const DECK_TOP := 0.001  # CityGround: a deck's top, level with the land
const LAND_TOP := 0.001  # CityGround: the asphalt land's top

var plan: Dictionary
var cfg: Dictionary
## How far from the centre (measured square) the real city is drawn at this stage (CityBand).
var reach: float
## Every street but the alleys: {a, b, dir, length, half, kind, index}.
var roads: Array[Dictionary] = []
var decks: Array[Rect2] = []
var water: Array[Rect2] = []
var _blocks: Array[Dictionary] = []  # {walk, rect, use}
var _block_hash := {}  # Vector2i -> Array[int]
var _road_hash := {}  # Vector2i -> Array[int]
var _coast: float
var _diag_deck: Dictionary


func _init(p_plan: Dictionary, p_cfg: Dictionary) -> void:
	plan = p_plan
	cfg = p_cfg
	reach = CityBand.extent(cfg)
	_coast = Num.f(cfg["coast_z"])
	water = CityRiver.channels(plan, cfg)
	decks = CityRiver.bridges(plan, cfg)
	_diag_deck = CityRiver.diagonal_deck(plan, cfg)
	_index_roads()
	_index_blocks()


## {kind, top, road (index into roads, -1 if none)} at p.
func at(p: Vector2) -> Dictionary:
	if p.y < _coast:
		return _is(BAY, -1.0)
	for r: int in _near(_road_hash, p):
		if str(roads[r]["kind"]) == CityGen.DIAGONAL and holds(r, p, Num.f(roads[r]["half"])):
			return _is(DECK if _over_water(p) else ROAD, CityGround.DIAG_TOP, r)
	for deck: Rect2 in decks:
		if deck.has_point(p):
			return _is(DECK, DECK_TOP, _road_holding(p, true))
	for w: Rect2 in water:
		if w.has_point(p):
			return _is(WATER, -Num.f(cfg.get("river_depth", 0.0)))
	var block := _block_at(p)
	if block >= 0:
		return _paving(_blocks[block], p)
	var road := _road_holding(p, false)
	return _is(ROAD if road >= 0 else BARE, LAND_TOP, road)


## True when road r's carriageway, reaching `into` past each crossing, holds p.
func holds(r: int, p: Vector2, into: float) -> bool:
	var road := roads[r]
	var a: Vector2 = road["a"]
	var dir: Vector2 = road["dir"]
	var along := (p - a).dot(dir)
	var across := absf((p - a).cross(dir))
	return (
		along >= -into
		and along <= Num.f(road["length"]) + into
		and across < Num.f(road["half"])
	)


## Every road whose carriageway (reaching `into` into its crossings; below 0, half its own width)
## holds p.
func roads_at(p: Vector2, into: float) -> Array[int]:
	var out: Array[int] = []
	for r: int in _near(_road_hash, p):
		if holds(r, p, into if into >= 0.0 else Num.f(roads[r]["half"])):
			out.append(r)
	return out


## True when p lies in the real city drawn at this stage, south of the coast.
func in_view(p: Vector2) -> bool:
	return maxf(absf(p.x), absf(p.y)) <= reach and p.y >= _coast


static func where(p: Vector2) -> String:
	return "(%.1f, %.1f)" % [p.x, p.y]


## True when p is on a bridge deck: a street's (CityRiver.bridges) or the diagonal's
## (CityRiver.diagonal_deck).
func on_deck(p: Vector2) -> bool:
	for deck: Rect2 in decks:
		if deck.has_point(p):
			return true
	if _diag_deck.is_empty():
		return false
	var a: Vector2 = _diag_deck["from"]
	var b: Vector2 = _diag_deck["to"]
	var dir := (b - a).normalized()
	var along := (p - a).dot(dir)
	var across := absf((p - a).cross(dir))
	return along >= 0.0 and along <= a.distance_to(b) and across <= Num.f(_diag_deck["width"]) * 0.5


func _over_water(p: Vector2) -> bool:
	for w: Rect2 in water:
		if w.has_point(p):
			return true
	return false


func _is(kind: String, top: float, road: int = -1) -> Dictionary:
	return {"kind": kind, "top": top, "road": road}


## The grid street (not the diagonal) whose carriageway holds p, half a width into each crossing;
## on a deck, any street.
func _road_holding(p: Vector2, any: bool) -> int:
	for r: int in _near(_road_hash, p):
		if (any or str(roads[r]["kind"]) != CityGen.DIAGONAL) and holds(r, p, Num.f(roads[r]["half"])):
			return r
	return -1


func _paving(block: Dictionary, p: Vector2) -> Dictionary:
	var top := CityGround.PAVE_TOP
	var rect: Rect2 = block["rect"]
	match str(block["use"]):
		"park":
			if rect.grow(-PARK_LAWN_INSET).has_point(p) and _off_diagonal(p):
				return _is(LAWN, top + LAWN_RISE)
		"plaza", "landmark":
			var walk: Rect2 = block["walk"]
			if CityGround.plaza(walk, cfg).has_point(p):
				return _is(PLAZA, top + CityGround.PLAZA_RISE)
		"parking":
			if rect.grow(-LOT_INSET).has_point(p) and _off_diagonal(p):
				return _is(LOT, top + LOT_RISE)
	return _is(PAVE, top)


## True when p lies a pavement's width or more from the diagonal's kerbs (DiagonalPaving keeps a
## lawn or car park that far back).
func _off_diagonal(p: Vector2) -> bool:
	var keep := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + Num.f(cfg["sidewalk"])
	return CityGen.diagonal_distance(plan, p) >= keep


func _block_at(p: Vector2) -> int:
	for n: int in _near(_block_hash, p):
		var walk: Rect2 = _blocks[n]["walk"]
		if walk.has_point(p):
			return n
	return -1


func _index_roads() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	var streets: Array[Dictionary] = plan["streets"]
	for s: int in streets.size():
		var street := streets[s]
		if str(street["kind"]) == CityGen.ALLEY:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var half := Num.f(street["width"]) * 0.5
		var road := {
			"a": a,
			"b": b,
			"dir": (b - a).normalized(),
			"length": a.distance_to(b),
			"half": half,
			"kind": str(street["kind"]),
			"index": s,
			"from": Num.i(street["from"]),
			"to": Num.i(street["to"]),
		}
		roads.append(road)
		var box := Rect2(a, Vector2.ZERO).expand(b).grow(half * 2.0)
		_add(_road_hash, box, roads.size() - 1)


## The blocks CityGround paves (not the river's, not the bay's).
func _index_blocks() -> void:
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		var use := str(block["use"])
		if use == "river" or rect.position.y < _coast:
			continue
		var entry := {"walk": CityGen.pavement(block, cfg), "rect": rect, "use": use}
		_blocks.append(entry)
		var walk: Rect2 = entry["walk"]
		_add(_block_hash, walk, _blocks.size() - 1)


static func _add(hash: Dictionary, box: Rect2, n: int) -> void:
	var lo := Vector2i(floori(box.position.x / BUCKET), floori(box.position.y / BUCKET))
	var hi := Vector2i(floori(box.end.x / BUCKET), floori(box.end.y / BUCKET))
	for i: int in range(lo.x, hi.x + 1):
		for j: int in range(lo.y, hi.y + 1):
			var key := Vector2i(i, j)
			if not hash.has(key):
				hash[key] = []
			var list: Array = hash[key]
			list.append(n)


static func _near(hash: Dictionary, p: Vector2) -> Array:
	return hash.get(Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET)), [])
