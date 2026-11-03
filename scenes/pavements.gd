class_name Pavements
extends RefCounted
## The pavement graph StreetLife's people walk (split out of StreetLife for gdlint's 400-line
## file cap): corner nodes and the links between them.

const CORNERS: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
const PAVEMENT := 0.45  # pavement line, out from the block's edge (its buildings' walls)
const CROSSWALK := 9.5  # longest crossing to the corner of the block across the street
const CROSS_CHANCE := 0.3  # a walker at a corner crosses the street rather than turns

var nodes := PackedVector2Array()
var links: Array[Array] = []
var in_road := PackedByteArray()  # per node: 1 when the corner lies in a carriageway
## The walkers' stream (StreetLife's), for next_corner.
var rng: RandomNumberGenerator
var wary := 0.0  # m: within this of the kaiju no walker turns toward it (StreetSteps sets it)


## Pavement corners round every block of the playable city (4 per block), linked round the
## block and across the streets to the nearest corner of the block opposite. The diagonal avenue
## runs through the blocks it crosses: a corner of theirs in its carriageway has no links, and
## neither has a pavement line that would cross it, so people never walk in the road.
func _init(sim: RampageSim) -> void:
	var half := CityGen.half_extent(sim.city)
	var plan := CityGen.map(sim.city)
	var diagonal := _diagonal_only(plan)  # only the diagonal runs through a block
	var reach := CityGen.width_of(CityGen.DIAGONAL, sim.city) * 0.5
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		var use := str(block["use"])
		if (
			use in ["outer", "river", "harbour", "shore"]
			or maxf(absf(rect.end.x), absf(rect.end.y)) > half
		):
			continue  # past the edge, the river, the sea bay or the fjord: no one walks on the water
		# The pavement line, the same distance in from the kerb as round every other block.
		var ring := CityGen.pavement(block, sim.city).grow(PAVEMENT - Num.f(sim.city["sidewalk"]))
		var size := ring.size * 0.5
		var cut := CityGen.diagonal_distance(plan, ring.get_center()) < size.length() + reach
		var first := nodes.size()
		for c: Vector2 in CORNERS:
			nodes.append(ring.get_center() + c * size)
			links.append([])
			in_road.append(1 if cut and not _road_at(diagonal, nodes[-1]).is_empty() else 0)
		for c: int in 4:
			var a := first + c
			var b := first + (c + 1) % 4
			if in_road[a] == 0 and in_road[b] == 0:
				_link(a, b)
	_cross_streets()


## The plan with only its diagonal avenue among the streets (_road_at's input).
static func _diagonal_only(plan: Dictionary) -> Dictionary:
	var avenue: Array[Dictionary] = []
	for road: Dictionary in plan["streets"]:
		if str(road["kind"]) == CityGen.DIAGONAL:
			avenue.append(road)
	return {"nodes": plan["nodes"], "streets": avenue}


## The non-alley street whose carriageway holds p (between its two crossings), or {}. Alleys
## have no pavement and carry people, so they do not count.
static func _road_at(plan: Dictionary, p: Vector2) -> Dictionary:
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) == CityGen.ALLEY:
			continue
		var from: Vector2 = nodes[Num.i(street["from"])]
		var to: Vector2 = nodes[Num.i(street["to"])]
		var dir := (to - from).normalized()
		var along := (p - from).dot(dir)
		var half := Num.f(street["width"]) * 0.5
		if along > 0.0 and along < from.distance_to(to) and absf((p - from).cross(dir)) < half:
			return street
	return {}


## Crossings: a corner links to the nearest corner of another block straight across a street.
func _cross_streets() -> void:
	for a: int in nodes.size():
		if in_road[a] == 1:
			continue
		for axis: int in 2:
			var best := _nearest_across(a, axis)
			if best >= 0 and not links[a].has(best):
				_link(a, best)


## The nearest corner of another block across a street from corner a along `axis` (0: x), or -1.
func _nearest_across(a: int, axis: int) -> int:
	var best := -1
	for b: int in nodes.size():
		if a >> 2 == b >> 2 or in_road[b] == 1:
			continue
		var d := nodes[b] - nodes[a]
		var along := absf(d.x) if axis == 0 else absf(d.y)
		var off := absf(d.y) if axis == 0 else absf(d.x)
		if off > 1.0 or along > CROSSWALK:
			continue
		if best < 0 or along < nodes[best].distance_to(nodes[a]):
			best = b
	return best


## The corners people can walk between (4 per block, minus the ones in the road).
func ring_nodes() -> PackedVector2Array:
	var out := PackedVector2Array()
	for n: int in nodes.size():
		if not links[n].is_empty():
			out.append(nodes[n])
	return out


## Where a walker placed at block `lot`'s `corner` starts: the first corner from there on
## (round the block, then the next block) with a pavement line round its block (StreetLife).
func line_start(lot: int, corner: int) -> int:
	var blocks := nodes.size() >> 2
	for _try: int in blocks * 4:
		var from := (lot % blocks) * 4 + corner
		if links[from].has((from & ~3) + ((from + 1) & 3)):
			break
		corner = (corner + 1) % 4
		lot += 1 if corner == 0 else 0
	return (lot % blocks) * 4 + corner


## A fleeing walker's next corner from `here`: of the linked corners whose pavement leads away
## from the kaiju from its first step (a straight line that starts away only gets further), the
## furthest; the corner it came from counts too (a dead end turns it round). None leads away (the
## kaiju is past every one): `here`, it stands until one does. Never a corner toward the kaiju.
func flee_corner(here: int, kaiju: Vector2) -> int:
	var at := nodes[here]
	var away := at - kaiju
	var best := here
	var far := -1.0
	for n: int in links[here]:
		if (nodes[n] - at).dot(away) <= 0.0:
			continue
		var d := nodes[n].distance_squared_to(kaiju)
		if d > far:
			far = d
			best = n
	return best


## The corner a walker at `here` (come from `from`) heads for next: never straight back unless
## it must; fleeing, flee_corner; else round its block or, by CROSS_CHANCE,
## across the street (StreetLife's walkers; draws from rng in that order). Within `wary` of the
## kaiju a walker (one just calmed) takes no corner toward it while another is left (D-453).
func next_corner(here: int, from: int, kaiju: Vector2, fleeing: bool) -> int:
	if fleeing:
		return flee_corner(here, kaiju)
	var at := nodes[here]
	var near := at.distance_squared_to(kaiju) < wary * wary
	var options: Array[int] = []
	for n: int in links[here]:
		if n != from and not (near and (nodes[n] - at).dot(at - kaiju) < 0.0):
			options.append(n)
	if options.is_empty():
		var back := not near or (nodes[from] - at).dot(at - kaiju) >= 0.0
		return from if back else here
	var lot := here >> 2
	var crossings: Array[int] = []
	var round_lot: Array[int] = []
	for n: int in options:
		if n >> 2 == lot:
			round_lot.append(n)
		else:
			crossings.append(n)
	var pick := round_lot
	if round_lot.is_empty() or (not crossings.is_empty() and rng.randf() < CROSS_CHANCE):
		pick = crossings
	return pick[rng.randi_range(0, pick.size() - 1)]


func _link(a: int, b: int) -> void:
	links[a].append(b)
	links[b].append(a)
