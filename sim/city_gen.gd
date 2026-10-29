class_name CityGen
extends RefCounted
## Seeded city layout, in two steps.
##
## The city grows with each evolution (D-039): cfg.districts = nested district half-extents,
## cfg.half = the one in play. The plan always spans every district, so an evolution only turns
## more of the same city playable; the districts still to come stand past the edge.
##
## map(cfg): the street plan, fixed by the city config alone (its own map_seed), so presentation
## (streets, traffic, the outskirts) can rebuild it without the run's seed. Streets run at
## irregular spacing with a ring avenue on the playable edge, a couple of avenues, alleys that
## split some blocks, and one diagonal avenue cutting across. Blocks between them are built up,
## a park, a plaza or a parking lot. Past the edge, blocks as far as the camera shows are built
## up too (real, destroyable, out of the kaiju's walk); beyond them "outer" (drawn stand-ins).
##
## generate(rng, cfg): the buildings of the playable blocks (CityLots fills each block). Each
## building is its own Structure, so neighbours touch but fall separately. Its tier (from
## height) decides how tough it is.

const AVENUE := "avenue"
const STREET := "street"
const ALLEY := "alley"
const DIAGONAL := "diagonal"
const MIN_LOT_M := 2.0  # CityLots' narrowest lot side: no block is cut thinner


## The buildings of the playable city, one dictionary each: x, z (centre), w, d, h, tier, style.
## Blocks fill district by district, innermost first, so a district's lots draw the same
## numbers whichever stage is in play (only the stage's height caps change them). The river's
## blocks (CityRiver) still draw their lots and drop them, so every other building stays put;
## its quay sheds come last, from their own numbers, in place of the lots by the bank.
static func generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Array[Dictionary]:
	var plan := map(cfg)
	var out: Array[Dictionary] = []
	var quay: Array[Dictionary] = []  # the built blocks by the start bank (CityRiver.on_quay)
	var city_seed := rng.seed  # each block cuts its lots from its own seed (_block_rng)
	for ring: int in districts(cfg).size() + 1:  # + 1: the real blocks past the last district
		for block: Dictionary in plan["blocks"]:
			if str(block.get("was", block["use"])) == "built" and Num.i(block["district"]) == ring:
				var lots := CityLots.fill_block(_block_rng(city_seed, block), plan, block, cfg, 1.0)
				if str(block["use"]) == "built":
					if CityRiver.on_quay(plan, block, cfg):
						quay.append(block)
						lots = CityRiver.off_quay(plan, lots, cfg)
					out.append_array(lots)
		out.append_array(CitySites.entries(plan, ring))
	CityHazards.tag(out, plan, cfg, CityRiver.sheds(plan, quay, out, cfg))  # + red barrels (#19)
	return out


## A block's own lot numbers, from the city's seed and where the block lies: the bay drops
## different streets at each stage (CityHarbour.inside), so a shared draw in block order would
## re-cut every block after the first difference; this way a block of the young city cuts the
## same lots at every stage.
static func _block_rng(city_seed: int, block: Dictionary) -> RandomNumberGenerator:
	var rect: Rect2 = block["rect"]
	var out := RandomNumberGenerator.new()
	out.seed = hash([city_seed, snappedf(rect.position.x, 0.01), snappedf(rect.position.y, 0.01)])
	return out


## Half-extents of the nested districts, smallest first (just [half] for a one-district city).
static func districts(cfg: Dictionary) -> Array[float]:
	var out: Array[float] = []
	var raw: Array = cfg.get("districts", [cfg["half"]])
	for h: Variant in raw:
		out.append(Num.f(h))
	return out


## The district a rect lies in by its furthest edge (0 innermost; past the last: size()).
static func district_of(rect: Rect2, cfg: Dictionary) -> int:
	var edge := maxf(
		maxf(absf(rect.position.x), absf(rect.end.x)), maxf(absf(rect.position.y), absf(rect.end.y))
	)
	var rings := districts(cfg)
	for k: int in rings.size():
		if edge < rings[k]:
			return k
	return rings.size()


static func tier_for_height(height: int, cfg: Dictionary) -> int:
	var step: float = Num.f(cfg["tier_height"])
	return clampi(1 + Num.i(floor(Num.f(height - 1) / step)), 1, 4)


## Half the playable city's side: the centre line of the ring avenue round it.
static func half_extent(cfg: Dictionary) -> float:
	return Num.f(cfg["half"])


## The tower districts (a midtown and a downtown): x, z, radius each.
static func cores(cfg: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for at: Array in cfg["cores"]:
		out.append(Vector3(Num.f(at[0]), Num.f(at[1]), Num.f(at[2])))
	return out


## The street plan: nodes (crossings), streets between them, blocks between the streets.
static func map(cfg: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = Num.i(cfg["map_seed"])
	var rings := districts(cfg)
	var full := rings[rings.size() - 1]
	var outer := Num.f(cfg["outer_half"])
	var diag := _diagonal(cfg)
	var lines := CityLines.draw(rng, cfg, diag)
	var xs: Array[float] = lines["xs"]
	var zs: Array[float] = lines["zs"]
	var avenues_x: Dictionary = lines["avenues_x"]
	var avenues_z: Dictionary = lines["avenues_z"]
	var plan := {
		"nodes": [] as Array[Vector2],
		"streets": [] as Array[Dictionary],
		"blocks": [] as Array[Dictionary],
		"sidewalk": Num.f(cfg["sidewalk"]),
		"diagonal": diag,
		"xs": xs,
		"zs": zs,
		"bay": CityHarbour.rect_of(cfg),  # the sea bay, laid first: no street enters it
	}
	plan["sites"] = CitySites.find(plan, rings, [avenues_x, avenues_z], cfg)
	# Which grid edges are alleys (CityAlleys): x-line i between zs[j] and zs[j+1] is
	# alley_x[Vector2i(i, j)].
	var alleys := CityAlleys.lay(rng, plan, [avenues_x, avenues_z], cfg)
	var alley_x: Dictionary = alleys["x"]
	var alley_z: Dictionary = alleys["z"]
	var index := {}
	_lay_streets(plan, index, lines, [alley_x, alley_z], cfg)
	_lay_diagonal(plan, index, diag, xs, zs, outer, cfg)
	_blocks(plan, xs, zs, avenues_x, avenues_z, alley_x, alley_z, rng, cfg)
	return plan


## Every grid street, split at each crossing and where the diagonal crosses: x-lines (running
## along z) first, then z-lines. alleys: [alley_x, alley_z].
static func _lay_streets(
	plan: Dictionary, index: Dictionary, lines: Dictionary, alleys: Array, cfg: Dictionary
) -> void:
	var xs: Array[float] = lines["xs"]
	var zs: Array[float] = lines["zs"]
	var outer := Num.f(cfg["outer_half"])
	var diag: Dictionary = plan["diagonal"]
	var avenues_x: Dictionary = lines["avenues_x"]
	var avenues_z: Dictionary = lines["avenues_z"]
	var alley_x: Dictionary = alleys[0]
	var alley_z: Dictionary = alleys[1]
	for i: int in xs.size():
		var stops: Array[float] = []
		stops.assign(zs)
		var cross := _diag_at_x(diag, xs[i])
		if absf(cross) <= outer:
			stops.append(cross)
		stops.sort()
		for k: int in stops.size() - 1:
			var j := _cell(zs, (stops[k] + stops[k + 1]) * 0.5)
			var kind := AVENUE if avenues_x.has(i) else STREET
			if alley_x.has(Vector2i(i, j)):
				kind = ALLEY
			_street(plan, index, Vector2(xs[i], stops[k]), Vector2(xs[i], stops[k + 1]), kind, cfg)
	for j: int in zs.size():
		var stops: Array[float] = []
		stops.assign(xs)
		var cross := _diag_at_z(diag, zs[j])
		if absf(cross) <= outer:
			stops.append(cross)
		stops.sort()
		for k: int in stops.size() - 1:
			var i := _cell(xs, (stops[k] + stops[k + 1]) * 0.5)
			var kind := AVENUE if avenues_z.has(j) else STREET
			if alley_z.has(Vector2i(j, i)):
				kind = ALLEY
			_street(plan, index, Vector2(stops[k], zs[j]), Vector2(stops[k + 1], zs[j]), kind, cfg)


## The diagonal avenue, crossing to crossing.
static func _lay_diagonal(
	plan: Dictionary,
	index: Dictionary,
	diag: Dictionary,
	xs: Array[float],
	zs: Array[float],
	outer: float,
	cfg: Dictionary
) -> void:
	var along: Array[Vector2] = []
	for x: float in xs:
		var z := _diag_at_x(diag, x)
		if absf(z) <= outer:
			along.append(Vector2(x, z))
	for z: float in zs:
		var x := _diag_at_z(diag, z)
		if absf(x) <= outer:
			along.append(Vector2(x, z))
	along.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for k: int in along.size() - 1:
		_street(plan, index, along[k], along[k + 1], DIAGONAL, cfg)


## The diagonal avenue of cfg: {at, dir} (city.diagonal_through, city.diagonal_deg).
static func diagonal_of(cfg: Dictionary) -> Dictionary:
	return _diagonal(cfg)


## The diagonal avenue: a point it passes and its direction (unit, ground plane).
static func _diagonal(cfg: Dictionary) -> Dictionary:
	var through: Array = cfg["diagonal_through"]
	var angle := deg_to_rad(Num.f(cfg["diagonal_deg"]))
	return {
		"at": Vector2(Num.f(through[0]), Num.f(through[1])),
		"dir": Vector2(cos(angle), sin(angle)),
	}


static func _diag_at_x(diag: Dictionary, x: float) -> float:
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	return at.y + (x - at.x) * dir.y / dir.x


static func _diag_at_z(diag: Dictionary, z: float) -> float:
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	return at.x + (z - at.y) * dir.x / dir.y


## Distance from p to the diagonal's centre line.
static func diagonal_distance(plan: Dictionary, p: Vector2) -> float:
	var diag: Dictionary = plan["diagonal"]
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	return absf((p - at).cross(dir))


## A block's pavement: its rect grown over the sidewalk, except a landmark's plaza, which already
## runs out to the kerb (CitySites._inset), so its pavement never spills into the street.
static func pavement(block: Dictionary, cfg: Dictionary) -> Rect2:
	var rect: Rect2 = block["rect"]
	return rect if block.has("site") else rect.grow(Num.f(cfg["sidewalk"]))


## The non-alley street whose carriageway holds p (between its two crossings), or {}. Alleys
## have no pavement and carry people, so they do not count.
static func road_at(plan: Dictionary, p: Vector2) -> Dictionary:
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) == ALLEY:
			continue
		var from: Vector2 = nodes[Num.i(street["from"])]
		var to: Vector2 = nodes[Num.i(street["to"])]
		var dir := (to - from).normalized()
		var along := (p - from).dot(dir)
		var half := Num.f(street["width"]) * 0.5
		if along > 0.0 and along < from.distance_to(to) and absf((p - from).cross(dir)) < half:
			return street
	return {}


static func width_of(kind: String, cfg: Dictionary) -> float:
	match kind:
		AVENUE, DIAGONAL:
			return Num.f(cfg["avenue_width"])
		ALLEY:
			return Num.f(cfg["alley_width"])
	return Num.f(cfg["street_width"])


## Index of the gap between lines that holds `v`.
static func _cell(lines: Array[float], v: float) -> int:
	for k: int in lines.size() - 1:
		if v >= lines[k] and v <= lines[k + 1]:
			return k
	return 0


static func _node(plan: Dictionary, index: Dictionary, p: Vector2) -> int:
	var key := Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))
	if not index.has(key):
		var nodes: Array[Vector2] = plan["nodes"]
		index[key] = nodes.size()
		nodes.append(p)
	return Num.i(index[key])


static func _street(
	plan: Dictionary, index: Dictionary, a: Vector2, b: Vector2, kind: String, cfg: Dictionary
) -> void:
	if a.distance_to(b) < 0.01 or CitySites.cuts(plan, a, b) or CityHarbour.inside(plan, a, b):
		return
	var streets: Array[Dictionary] = plan["streets"]
	(
		streets
		. append(
			{
				"from": _node(plan, index, a),
				"to": _node(plan, index, b),
				"width": width_of(kind, cfg),
				"kind": kind,
			}
		)
	)


## Blocks between the lines, inset by each side's street half-width and sidewalk (alleys have
## no sidewalk), with what each is used for.
static func _blocks(
	plan: Dictionary,
	xs: Array[float],
	zs: Array[float],
	avenues_x: Dictionary,
	avenues_z: Dictionary,
	alley_x: Dictionary,
	alley_z: Dictionary,
	rng: RandomNumberGenerator,
	cfg: Dictionary
) -> void:
	var full := districts(cfg)[-1]
	var walk := Num.f(cfg["sidewalk"])
	var blocks: Array[Dictionary] = plan["blocks"]
	var inner: Array[int] = []
	for i: int in xs.size() - 1:
		for j: int in zs.size() - 1:
			var inset := func(avenue: bool, alley: bool) -> float:
				if alley:
					return Num.f(cfg["alley_width"]) * 0.5
				return width_of(AVENUE if avenue else STREET, cfg) * 0.5 + walk
			var x0: float = xs[i] + inset.call(avenues_x.has(i), alley_x.has(Vector2i(i, j)))
			var x1: float = (
				xs[i + 1] - inset.call(avenues_x.has(i + 1), alley_x.has(Vector2i(i + 1, j)))
			)
			var z0: float = zs[j] + inset.call(avenues_z.has(j), alley_z.has(Vector2i(j, i)))
			var z1: float = (
				zs[j + 1] - inset.call(avenues_z.has(j + 1), alley_z.has(Vector2i(j + 1, i)))
			)
			var rect := Rect2(x0, z0, x1 - x0, z1 - z0)
			# Inside the last district a block takes the use it has once that district is in
			# play, whatever the stage, so its lots never change (CityBand holds it back).
			var city := maxf(maxf(absf(x0), absf(x1)), maxf(absf(z0), absf(z1))) < full
			var use := "built" if city or CityBand.real(rect, cfg) else "outer"
			var roll := rng.randf()
			if CitySites.covers(plan, i, j):
				continue  # one of a landmark's merged cells
			if city and CityLots.town_share(rect.get_center(), cfg) < 0.2:
				if roll < Num.f(cfg["parking_chance"]):
					use = "parking"
			blocks.append(
				{
					"rect": rect,
					"use": use,
					"district": district_of(rect, cfg),
					"cell": Vector2i(i, j)
				}
			)
			if city:
				inner.append(blocks.size() - 1)
	CitySites.add_blocks(plan, cfg)
	CityRiver.mark(plan, zs, cfg)
	CityHarbour.mark(plan, avenues_x, avenues_z, cfg)  # the sea bay's blocks
	CityParks.pick(plan, inner, cfg)
	CityBand.hold_back(plan, inner, cfg)
