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


## The buildings of the playable city, one dictionary each: x, z (centre), w, d, h, tier, style.
## Blocks fill district by district, innermost first, so a district's lots draw the same
## numbers whichever stage is in play (only the stage's height caps change them). The river's
## blocks (CityRiver) still draw their lots and drop them, so every other building stays put;
## its quay sheds come last, from their own numbers.
static func generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Array[Dictionary]:
	var plan := map(cfg)
	var out: Array[Dictionary] = []
	var bare: Array[Dictionary] = []  # the first district's built blocks too thin for a lot
	for ring: int in districts(cfg).size() + 1:  # + 1: the real blocks past the last district
		for block: Dictionary in plan["blocks"]:
			if str(block.get("was", block["use"])) == "built" and Num.i(block["district"]) == ring:
				var lots := CityLots.fill_block(rng, plan, block, cfg, 1.0)
				if str(block["use"]) == "built":
					out.append_array(lots)
					if lots.is_empty() and ring == 0:
						bare.append(block)
		out.append_array(CitySites.entries(plan, ring))
	out.append_array(CityRiver.sheds(plan, bare, cfg))
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
	var lines := _grid_lines(rng, rings, cfg)
	var xs: Array[float] = lines[0]
	var zs: Array[float] = lines[1]
	var avenues_x := _avenues(rng, xs, rings, cfg)
	var avenues_z := _avenues(rng, zs, rings, cfg)
	# Which grid edges are alleys: x-line i between zs[j] and zs[j+1] is ax[Vector2i(i, j)].
	var alley_x := _alleys(rng, xs, zs, avenues_x, full, cfg)
	var alley_z := _alleys(rng, zs, xs, avenues_z, full, cfg)
	var plan := {
		"nodes": [] as Array[Vector2],
		"streets": [] as Array[Dictionary],
		"blocks": [] as Array[Dictionary],
		"sidewalk": Num.f(cfg["sidewalk"]),
		"diagonal": _diagonal(cfg),
		"xs": xs,
		"zs": zs,
	}
	plan["sites"] = CitySites.find(plan, rings, [avenues_x, avenues_z], cfg)
	var grid := {
		"xs": xs,
		"zs": zs,
		"avenues_x": avenues_x,
		"avenues_z": avenues_z,
		"alley_x": alley_x,
		"alley_z": alley_z,
	}
	_streets(plan, grid, cfg)
	CityBlocks.add(plan, grid, rng, cfg)
	return plan


## The x-lines and z-lines: Manhattan blocks (long one way, short the other) in the first
## district, each later district's out to its own ring avenue, then the outskirts. [xs, zs].
static func _grid_lines(
	rng: RandomNumberGenerator, rings: Array[float], cfg: Dictionary
) -> Array[Array]:
	var outer := Num.f(cfg["outer_half"])
	# Long blocks one way, short the other (Manhattan): x-lines far apart, z-lines close.
	var long: Array = cfg["block_long"]
	var short: Array = cfg["block_short"]
	var xs := CityLines.across(rng, rings[0], Num.i(long[0]), Num.i(long[1]))
	var zs := CityLines.across(rng, rings[0], Num.i(short[0]), Num.i(short[1]))
	# Each later district's streets, out to its own ring avenue, draw from their own stream.
	var grow := RandomNumberGenerator.new()
	grow.seed = Num.i(cfg["map_seed"]) + 2
	for k: int in range(1, rings.size()):
		CityLines.ring(grow, xs, rings[k - 1], rings[k], Num.i(long[0]), Num.i(long[1]))
		CityLines.ring(grow, zs, rings[k - 1], rings[k], Num.i(short[0]), Num.i(short[1]))
	# The outskirts draw from their own stream, so tuning them never reshuffles the city.
	var far := RandomNumberGenerator.new()
	far.seed = Num.i(cfg["map_seed"]) + 1
	# ...and their blocks vary far more than the city's, so the outskirts are no even grid.
	CityLines.extend(far, xs, outer, Num.i(long[0]) - 6, Num.i(long[1]) + 14)
	CityLines.extend(far, zs, outer, Num.i(short[0]) - 2, Num.i(short[1]) + 12)
	var out: Array[Array] = [xs, zs]
	return out


## Which edges of `lines` are alleys: line i between cross[j] and cross[j+1] is Vector2i(i, j).
## One roll per edge, in order.
static func _alleys(
	rng: RandomNumberGenerator,
	lines: Array[float],
	cross: Array[float],
	avenues: Dictionary,
	half: float,
	cfg: Dictionary
) -> Dictionary:
	var out := {}
	for i: int in lines.size():
		for j: int in cross.size() - 1:
			if _alley_ok(lines[i], cross[j], cross[j + 1], half, avenues.has(i), rng, cfg):
				out[Vector2i(i, j)] = true
	return out


## Every street of the plan: the x-lines (running along z), the z-lines, then the diagonal.
static func _streets(plan: Dictionary, grid: Dictionary, cfg: Dictionary) -> void:
	var index := {}
	var x_axis := {
		"lines": grid["xs"],
		"cross": grid["zs"],
		"avenues": grid["avenues_x"],
		"alleys": grid["alley_x"],
	}
	var z_axis := {
		"lines": grid["zs"],
		"cross": grid["xs"],
		"avenues": grid["avenues_z"],
		"alleys": grid["alley_z"],
	}
	_axis_streets(plan, index, x_axis, true, cfg)
	_axis_streets(plan, index, z_axis, false, cfg)
	_diagonal_streets(plan, index, grid, cfg)


## One axis's lines as streets, each split at every crossing and where the diagonal crosses.
## x_lines: they run along z (a point on line v at c is (v, c)), else along x ((c, v)).
static func _axis_streets(
	plan: Dictionary, index: Dictionary, axis: Dictionary, x_lines: bool, cfg: Dictionary
) -> void:
	var lines: Array[float] = axis["lines"]
	var cross: Array[float] = axis["cross"]
	var diag: Dictionary = plan["diagonal"]
	var outer := Num.f(cfg["outer_half"])
	for i: int in lines.size():
		var stops: Array[float] = []
		stops.assign(cross)
		var hit := _diag_at_x(diag, lines[i]) if x_lines else _diag_at_z(diag, lines[i])
		if absf(hit) <= outer:
			stops.append(hit)
		stops.sort()
		for k: int in stops.size() - 1:
			var j := _cell(cross, (stops[k] + stops[k + 1]) * 0.5)
			var kind := _kind(axis, i, j)
			var from := _point(x_lines, lines[i], stops[k])
			var to := _point(x_lines, lines[i], stops[k + 1])
			_street(plan, index, from, to, kind, cfg)


## The kind of street line i of an axis is between cross lines j and j + 1.
static func _kind(axis: Dictionary, i: int, j: int) -> String:
	var alleys: Dictionary = axis["alleys"]
	var avenues: Dictionary = axis["avenues"]
	if alleys.has(Vector2i(i, j)):
		return ALLEY
	return AVENUE if avenues.has(i) else STREET


## The point at c along line v: (v, c) for an x-line, (c, v) for a z-line.
static func _point(x_lines: bool, v: float, c: float) -> Vector2:
	return Vector2(v, c) if x_lines else Vector2(c, v)


## The diagonal avenue, crossing to crossing.
static func _diagonal_streets(
	plan: Dictionary, index: Dictionary, grid: Dictionary, cfg: Dictionary
) -> void:
	var diag: Dictionary = plan["diagonal"]
	var outer := Num.f(cfg["outer_half"])
	var xs: Array[float] = grid["xs"]
	var zs: Array[float] = grid["zs"]
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


## Every district's ring lines and one or two lines through the first district are avenues.
static func _avenues(
	rng: RandomNumberGenerator, lines: Array[float], rings: Array[float], cfg: Dictionary
) -> Dictionary:
	var out := {}
	var inner: Array[int] = []
	for i: int in lines.size():
		var ring := false
		for h: float in rings:
			ring = ring or is_equal_approx(absf(lines[i]), h)
		if ring:
			out[i] = true
		elif absf(lines[i]) < rings[0]:
			inner.append(i)
	for n: int in mini(Num.i(cfg["avenues"]), inner.size()):
		var pick := inner[rng.randi_range(0, inner.size() - 1)]
		inner.erase(pick)
		out[pick] = true
	return out


static func _alley_ok(
	line: float,
	a: float,
	b: float,
	half: float,
	avenue: bool,
	rng: RandomNumberGenerator,
	cfg: Dictionary
) -> bool:
	var roll := rng.randf()  # always drawn, so the plan does not shift when a rule changes
	if avenue or absf(line) >= half - 0.01 or maxf(absf(a), absf(b)) > half + 0.01:
		return false
	return roll < Num.f(cfg["alley_chance"])


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
	if a.distance_to(b) < 0.01 or CitySites.cuts(plan, a, b):
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
