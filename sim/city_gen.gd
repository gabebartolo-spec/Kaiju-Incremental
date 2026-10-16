class_name CityGen
extends RefCounted
## Seeded city layout, in two steps.
##
## map(cfg): the street plan, fixed by the city config alone (its own map_seed), so presentation
## (streets, traffic, the outskirts) can rebuild it without the run's seed. Streets run at
## irregular spacing with a ring avenue on the playable edge, a couple of avenues, alleys that
## split some blocks, and one diagonal avenue cutting across. Blocks between them are built up,
## a park, a plaza or a parking lot; blocks past the edge are "outer" (drawn, never destroyed).
##
## generate(rng, cfg): the buildings of the playable blocks (CityLots fills each block). Each
## building is its own Structure, so neighbours touch but fall separately. Its tier (from
## height) decides how tough it is.

const AVENUE := "avenue"
const STREET := "street"
const ALLEY := "alley"
const DIAGONAL := "diagonal"


## The buildings of the playable city, one dictionary each: x, z (centre), w, d, h, tier, style.
static func generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Array[Dictionary]:
	var plan := map(cfg)
	var out: Array[Dictionary] = []
	for block: Dictionary in plan["blocks"]:
		if str(block["use"]) == "built":
			out.append_array(CityLots.fill_block(rng, plan, block, cfg, 1.0))
	return out


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
	var half := half_extent(cfg)
	var outer := Num.f(cfg["outer_half"])
	# Long blocks one way, short the other (Manhattan): x-lines far apart, z-lines close.
	var long: Array = cfg["block_long"]
	var short: Array = cfg["block_short"]
	var xs := _lines(rng, half, outer, Num.i(long[0]), Num.i(long[1]))
	var zs := _lines(rng, half, outer, Num.i(short[0]), Num.i(short[1]))
	var avenues_x := _avenues(rng, xs, half, cfg)
	var avenues_z := _avenues(rng, zs, half, cfg)
	# Which grid edges are alleys: x-line i between zs[j] and zs[j+1] is ax[Vector2i(i, j)].
	var alley_x := {}
	var alley_z := {}
	for i: int in xs.size():
		for j: int in zs.size() - 1:
			if _alley_ok(xs[i], zs[j], zs[j + 1], half, avenues_x.has(i), rng, cfg):
				alley_x[Vector2i(i, j)] = true
	for j: int in zs.size():
		for i: int in xs.size() - 1:
			if _alley_ok(zs[j], xs[i], xs[i + 1], half, avenues_z.has(j), rng, cfg):
				alley_z[Vector2i(j, i)] = true
	var diag := _diagonal(cfg)
	var plan := {
		"nodes": [] as Array[Vector2],
		"streets": [] as Array[Dictionary],
		"blocks": [] as Array[Dictionary],
		"sidewalk": Num.f(cfg["sidewalk"]),
		"diagonal": diag,
		"xs": xs,
		"zs": zs,
	}
	var index := {}
	# x-lines (streets running along z), split at every crossing and where the diagonal crosses.
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
	# The diagonal avenue, crossing to crossing.
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
	_blocks(plan, xs, zs, avenues_x, avenues_z, alley_x, alley_z, rng, cfg)
	return plan


## Street centre lines on one axis: random gaps, with lines exactly on the ring (+-half).
static func _lines(
	rng: RandomNumberGenerator, half: float, outer: float, lo: int, hi: int
) -> Array[float]:
	var out: Array[float] = [-half]
	var p := -half
	while half - p > hi + lo:
		p += rng.randi_range(lo, hi)
		out.append(p)
	if half - p > hi:  # split a long last gap in two
		out.append(p + roundi((half - p) * 0.5))
	out.append(half)
	p = half
	while p < outer:
		p += rng.randi_range(lo, hi + 4)
		out.append(p)
	p = -half
	while p > -outer:
		p -= rng.randi_range(lo, hi + 4)
		out.push_front(p)
	return out


## The ring lines and one or two lines through the playable city are avenues.
static func _avenues(
	rng: RandomNumberGenerator, lines: Array[float], half: float, cfg: Dictionary
) -> Dictionary:
	var out := {}
	var inner: Array[int] = []
	for i: int in lines.size():
		if is_equal_approx(absf(lines[i]), half):
			out[i] = true
		elif absf(lines[i]) < half:
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
	if a.distance_to(b) < 0.01:
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
	var half := half_extent(cfg)
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
			var playable := maxf(maxf(absf(x0), absf(x1)), maxf(absf(z0), absf(z1))) < half
			var use := "built" if playable else "outer"
			var roll := rng.randf()
			if playable and CityLots.town_share(rect.get_center(), cfg) < 0.2:
				if roll < Num.f(cfg["parking_chance"]):
					use = "parking"
			blocks.append({"rect": rect, "use": use})
			if playable:
				inner.append(blocks.size() - 1)
	# One park: the biggest block between the towers and the edge. One plaza: the block at the
	# heart of the first tower district.
	var heart := cores(cfg)[0]
	var best_park := -1
	var park_area := 0.0
	var best_plaza := -1
	var plaza_away := INF
	for n: int in inner:
		var rect: Rect2 = blocks[n]["rect"]
		var town := CityLots.town_share(rect.get_center(), cfg)
		var edge := maxf(absf(rect.get_center().x), absf(rect.get_center().y)) / half
		if town < 0.1 and edge < 0.75 and rect.get_area() > park_area:
			best_park = n
			park_area = rect.get_area()
		var away := rect.get_center().distance_to(Vector2(heart.x, heart.y))
		if away < plaza_away:
			best_plaza = n
			plaza_away = away
	if best_park >= 0:
		blocks[best_park]["use"] = "park"
	if best_plaza >= 0 and best_plaza != best_park:
		blocks[best_plaza]["use"] = "plaza"
