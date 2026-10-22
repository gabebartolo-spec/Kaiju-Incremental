class_name CityBlocks
extends RefCounted
## The blocks of the street plan (CityGen.map): the rect between the lines, inset by each side's
## street half-width and sidewalk (alleys have no sidewalk), what each is used for, the parks and
## the plaza. Part of CityGen.map, split out to keep files small. grid: {xs, zs, avenues_x,
## avenues_z, alley_x, alley_z} as CityGen.map builds them; rng is the map's own stream.


static func add(
	plan: Dictionary, grid: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary
) -> void:
	var inner := _cells(plan, grid, rng, cfg)
	CitySites.add_blocks(plan, cfg)
	var zs: Array[float] = grid["zs"]
	CityRiver.mark(plan, zs, cfg)
	_parks_and_plaza(plan, inner, cfg)
	CityBand.hold_back(plan, inner, cfg)


## Appends a block for every cell of the grid (one roll each, drawn before anything else is
## decided); returns the indices of those inside the last district.
static func _cells(
	plan: Dictionary, grid: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary
) -> Array[int]:
	var xs: Array[float] = grid["xs"]
	var zs: Array[float] = grid["zs"]
	var blocks: Array[Dictionary] = plan["blocks"]
	var inner: Array[int] = []
	for i: int in xs.size() - 1:
		for j: int in zs.size() - 1:
			if _append(plan, grid, Vector2i(i, j), rng, cfg):
				inner.append(blocks.size() - 1)
	return inner


## The block of cell `at` onto plan["blocks"]; true when it lies inside the last district (and
## so counts to `inner`). A landmark's merged cell adds none.
static func _append(
	plan: Dictionary, grid: Dictionary, at: Vector2i, rng: RandomNumberGenerator, cfg: Dictionary
) -> bool:
	var edges := _edges(grid, at, cfg)  # x0, z0, x1, z1
	var rect := Rect2(edges[0], edges[1], edges[2] - edges[0], edges[3] - edges[1])
	# Inside the last district a block takes the use it has once that district is in
	# play, whatever the stage, so its lots never change (CityBand holds it back).
	var full := CityGen.districts(cfg)[-1]
	var city := maxf(maxf(absf(edges[0]), absf(edges[2])), maxf(absf(edges[1]), absf(edges[3])))
	var inside := city < full
	var use := "built" if inside or CityBand.real(rect, cfg) else "outer"
	var roll := rng.randf()
	if CitySites.covers(plan, at.x, at.y):
		return false  # one of a landmark's merged cells
	if inside and CityLots.town_share(rect.get_center(), cfg) < 0.2:
		if roll < Num.f(cfg["parking_chance"]):
			use = "parking"
	var blocks: Array[Dictionary] = plan["blocks"]
	blocks.append(
		{"rect": rect, "use": use, "district": CityGen.district_of(rect, cfg), "cell": at}
	)
	return inside


## Cell `at`'s edges as [x0, z0, x1, z1]: each line moved in by its street's half-width and
## sidewalk (an alley's half-width alone).
static func _edges(grid: Dictionary, at: Vector2i, cfg: Dictionary) -> Array[float]:
	var xs: Array[float] = grid["xs"]
	var zs: Array[float] = grid["zs"]
	var ax: Dictionary = grid["avenues_x"]
	var az: Dictionary = grid["avenues_z"]
	var lx: Dictionary = grid["alley_x"]
	var lz: Dictionary = grid["alley_z"]
	var i := at.x
	var j := at.y
	var x0: float = xs[i] + _inset(ax.has(i), lx.has(Vector2i(i, j)), cfg)
	var x1: float = xs[i + 1] - _inset(ax.has(i + 1), lx.has(Vector2i(i + 1, j)), cfg)
	var z0: float = zs[j] + _inset(az.has(j), lz.has(Vector2i(j, i)), cfg)
	var z1: float = zs[j + 1] - _inset(az.has(j + 1), lz.has(Vector2i(j + 1, i)), cfg)
	var out: Array[float] = [x0, z0, x1, z1]
	return out


static func _inset(avenue: bool, alley: bool, cfg: Dictionary) -> float:
	if alley:
		return Num.f(cfg["alley_width"]) * 0.5
	var kind := CityGen.AVENUE if avenue else CityGen.STREET
	return CityGen.width_of(kind, cfg) * 0.5 + Num.f(cfg["sidewalk"])


## One park per district: its biggest block between the towers and its ring. One plaza: the
## block at the heart of the first tower district.
static func _parks_and_plaza(plan: Dictionary, inner: Array[int], cfg: Dictionary) -> void:
	var blocks: Array[Dictionary] = plan["blocks"]
	var parks := _parks(blocks, inner, cfg)
	var plaza := _plaza(blocks, inner, cfg)
	for n: int in parks:
		if n >= 0:
			blocks[n]["use"] = "park"
	if plaza >= 0 and not plaza in parks and Num.f(cfg["plaza_blocks"]) > 0.0:
		blocks[plaza]["use"] = "plaza"


## Each district's park block (-1: none): the biggest built block thin of towers and not on the
## outer edge of a first district (a later district is one ring of blocks deep).
static func _parks(blocks: Array[Dictionary], inner: Array[int], cfg: Dictionary) -> Array[int]:
	var rings := CityGen.districts(cfg)
	var parks: Array[int] = []
	var park_area: Array[float] = []
	for k: int in rings.size():
		parks.append(-1)
		park_area.append(0.0)
	for n: int in inner:
		if str(blocks[n]["use"]) != "built":
			continue  # the river (CityRiver)
		var rect: Rect2 = blocks[n]["rect"]
		var ring := Num.i(blocks[n]["district"])
		var town := CityLots.town_share(rect.get_center(), cfg)
		var edge := maxf(absf(rect.get_center().x), absf(rect.get_center().y)) / rings[ring]
		var inside := edge < 0.75 or ring > 0
		if town < 0.1 and inside and rect.get_area() > park_area[ring]:
			parks[ring] = n
			park_area[ring] = rect.get_area()
	return parks


## The built block nearest the heart of the first tower district (-1: none).
static func _plaza(blocks: Array[Dictionary], inner: Array[int], cfg: Dictionary) -> int:
	var heart := CityGen.cores(cfg)[0]
	var best := -1
	var best_away := INF
	for n: int in inner:
		if str(blocks[n]["use"]) != "built":
			continue  # the river (CityRiver)
		var rect: Rect2 = blocks[n]["rect"]
		var away := rect.get_center().distance_to(Vector2(heart.x, heart.y))
		if away < best_away:
			best = n
			best_away = away
	return best
