extends RefCounted
## ROADS audit, graph half (D-265: "audit that the road layouts are natural and realistic in all
## seeds"). Reads one stage's street plan (CityGen.map) as a graph of crossings and street pieces
## and returns every violation of the hard rules plus the metrics real street-network studies
## report. Only what the stage builds as the real city counts: a piece whose middle lies inside
## CityBand.extent (the arena plus the band the camera shows past it); the drawn outskirts are
## stand-ins. Pure and seeded by the plan alone.
##
## Rules (each violation: {rule, at: Vector2 (x, z m), note}):
##   stub      a dead end (one street at a crossing) short of the plan's edge, shorter than one
##             block (city.block_short[0]), unless the street is marked "cul_de_sac"
##   arms      a crossing with more than MAX_ARMS streets, unless plan["authored_junctions"]
##             lists it (the authored big intersection)
##   close     two junctions (3+ streets) nearer than one block (city.block_short[0])
##   zero      a street piece shorter than ZERO_M, or two pieces over the same ground (same
##             ends, or collinear and overlapping)
##   split     a road piece cut off from the rest (more than one connected component)
##   angle     two neighbouring arms of a junction closer than MIN_ANGLE_DEG
##   aspect    more than ASPECT_SHARE of the blocks longer than MAX_ASPECT times their width
## Metrics (Boeing's OSMnx city metrics): streets per node (mean, histogram), dead-end share,
## junction arm angles (10 degree histogram), block short and long sides and aspect ratios.
##
## Bars and their sources:
## - MAX_ARMS 5: real junctions are 3-way (T) and 4-way (X); 5+ arms are rare one-offs (Boeing
##   2020, "A multi-scale analysis of 27,000 urban street networks", Environment and Planning B
##   47(4): 590-608, streets-per-node distributions; Boeing 2017, OSMnx, CEUS 65: 126-139).
## - MIN_ANGLE_DEG 20: highway design wants 60-90 degrees (AASHTO "A Policy on Geometric Design
##   of Highways and Streets", ch. 9, intersection angle); grids cut by one diagonal avenue keep
##   their sharpest corners near 20-30 degrees (Broadway at Fifth Avenue, the Flatiron).
## - MAX_ASPECT 4, ASPECT_SHARE 0.05: Manhattan's 1811 grid blocks run about 80 x 270 m (3.4:1),
##   the long end of real grids; Barcelona's Eixample 113 x 113 m, Portland 61 x 61 m (1:1).
## - stub / close at one block (the plan's shortest block side): a dead end or a junction gap
##   shorter than a block does not occur in a planned grid (Boeing 2019, "Urban spatial order",
##   Applied Network Science 4: 67: grid cities have few dead ends and near-uniform spacing).
## Sources are cited from the published papers' figures as known on 2026-10-26 (no live web tool
## in the audit session); every bar is a constant here, so the lead can retune one with its source.

const MAX_ARMS := 5
const MIN_ANGLE_DEG := 20.0
const MAX_ASPECT := 4.0
const ASPECT_SHARE := 0.05
const ZERO_M := 0.05
const ANGLE_BIN := 10.0


## The real city's piece of a plan, typed: every street piece whose middle lies inside the
## extent, and per crossing the pieces that meet there.
class Net:
	var plan: Dictionary
	var cfg: Dictionary
	var nodes: Array[Vector2] = []
	var streets: Array[Dictionary] = []
	var pieces: Array[int] = []
	var adj: Dictionary = {}  # node index -> Array of piece indices
	var extent: float

	func _init(p_plan: Dictionary, p_cfg: Dictionary) -> void:
		plan = p_plan
		cfg = p_cfg
		nodes = plan["nodes"]
		streets = plan["streets"]
		extent = CityBand.extent(cfg)
		for k: int in streets.size():
			var mid := (end_a(k) + end_b(k)) * 0.5
			if maxf(absf(mid.x), absf(mid.y)) >= extent:
				continue
			pieces.append(k)
			for n: int in [from_of(k), to_of(k)]:
				if not adj.has(n):
					adj[n] = []
				var list: Array = adj[n]
				list.append(k)

	func from_of(k: int) -> int:
		return Num.i(streets[k]["from"])

	func to_of(k: int) -> int:
		return Num.i(streets[k]["to"])

	func end_a(k: int) -> Vector2:
		return nodes[from_of(k)]

	func end_b(k: int) -> Vector2:
		return nodes[to_of(k)]

	func length(k: int) -> float:
		return end_a(k).distance_to(end_b(k))

	func kind(k: int) -> String:
		return str(streets[k]["kind"])

	func arms(n: int) -> Array:
		var list: Array = adj.get(n, [])
		return list


## Everything the graph rules find in `plan` (CityGen.map(cfg)): {violations, metrics}.
static func audit(plan: Dictionary, cfg: Dictionary) -> Dictionary:
	var g := Net.new(plan, cfg)
	var out: Array[Dictionary] = []
	out.append_array(_stubs(g))
	out.append_array(_arms(g))
	out.append_array(_close(g))
	out.append_array(_zero(g))
	out.append_array(_split(g))
	var hist := {}
	out.append_array(_angles(g, hist))
	var metrics := _degrees(g)
	metrics["angle_hist"] = hist
	out.append_array(_blocks(plan, cfg, metrics))
	return {"violations": out, "metrics": metrics}


static func violation(rule: String, at: Vector2, note: String) -> Dictionary:
	return {"rule": rule, "at": at, "note": note}


static func _block_m(cfg: Dictionary) -> float:
	var short: Array = cfg["block_short"]
	return Num.f(short[0])


static func _stubs(g: Net) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var edge := minf(Num.f(g.cfg["outer_half"]) - 0.01, g.extent)
	for n: int in g.adj:
		var list := g.arms(n)
		var p := g.nodes[n]
		if list.size() != 1 or maxf(absf(p.x), absf(p.y)) >= edge:
			continue
		var k: int = list[0]
		if g.streets[k].get("cul_de_sac", false) or g.length(k) >= _block_m(g.cfg):
			continue
		out.append(violation("stub", p, "%s %.1f m dead end" % [g.kind(k), g.length(k)]))
	return out


static func _arms(g: Net) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var authored: Array = g.plan.get("authored_junctions", [])
	for n: int in g.adj:
		var count := g.arms(n).size()
		if count > MAX_ARMS and not n in authored:
			out.append(violation("arms", g.nodes[n], "%d streets meet" % count))
	return out


static func _close(g: Net) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gap := _block_m(g.cfg)
	var cells := {}
	var junctions: Array[int] = []
	for n: int in g.adj:
		if g.arms(n).size() >= 3:
			junctions.append(n)
			var key := Vector2i((g.nodes[n] / gap).floor())
			if not cells.has(key):
				cells[key] = []
			var list: Array = cells[key]
			list.append(n)
	for n: int in junctions:
		var key := Vector2i((g.nodes[n] / gap).floor())
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var near: Array = cells.get(key + Vector2i(dx, dz), [])
				for m: int in near:
					var d := g.nodes[n].distance_to(g.nodes[m])
					if m > n and d < gap:
						var at := (g.nodes[n] + g.nodes[m]) * 0.5
						var boxes := _widest(g, n) + _widest(g, m)
						var how := "boxes overlap" if d < boxes else "short block"
						var note := "junctions %.1f m apart (%s)" % [d, how]
						out.append(violation("close", at, note))
	return out


## Half the width of the widest street at crossing n: how far its junction box reaches.
static func _widest(g: Net, n: int) -> float:
	var out := 0.0
	for k: int in g.arms(n):
		out = maxf(out, Num.f(g.streets[k]["width"]) * 0.5)
	return out


static func _zero(g: Net) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var lines := {}  # axis-aligned pieces by their line: "x:<cm>" or "z:<cm>" -> [[lo, hi]]
	for k: int in g.pieces:
		var a := g.end_a(k)
		var b := g.end_b(k)
		if a.distance_to(b) < ZERO_M:
			out.append(violation("zero", a, "%s piece of zero length" % g.kind(k)))
		var pair := Vector2i(mini(g.from_of(k), g.to_of(k)), maxi(g.from_of(k), g.to_of(k)))
		if seen.has(pair):
			out.append(violation("zero", (a + b) * 0.5, "two pieces share both ends"))
		seen[pair] = true
		if absf(a.x - b.x) < 0.001:
			var key := "x:%d" % roundi(a.x * 100.0)
			_overlap(out, lines, key, [minf(a.y, b.y), maxf(a.y, b.y), Vector2(a.x, 0.0)])
		elif absf(a.y - b.y) < 0.001:
			var key := "z:%d" % roundi(a.y * 100.0)
			_overlap(out, lines, key, [minf(a.x, b.x), maxf(a.x, b.x), Vector2(0.0, a.y)])
	return out


## Records span [lo, hi, base point] on line `key`; a violation where it overlaps one there.
static func _overlap(out: Array[Dictionary], lines: Dictionary, key: String, span: Array) -> void:
	var base: Vector2 = span[2]
	var lo: float = span[0]
	var hi: float = span[1]
	if not lines.has(key):
		lines[key] = []
	var known: Array = lines[key]
	for other: Array in known:
		var o_lo: float = other[0]
		var o_hi: float = other[1]
		var over := minf(hi, o_hi) - maxf(lo, o_lo)
		if over > ZERO_M:
			var mid := (maxf(lo, o_lo) + minf(hi, o_hi)) * 0.5
			var at := Vector2(base.x, mid) if key.begins_with("x") else Vector2(mid, base.y)
			out.append(violation("zero", at, "pieces overlap for %.1f m" % over))
	known.append([lo, hi])


static func _split(g: Net) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var root := {}
	for k: int in g.pieces:
		var a := _find(root, g.from_of(k))
		var b := _find(root, g.to_of(k))
		if a != b:
			root[a] = b
	var sizes := {}
	for n: int in g.adj:
		var r := _find(root, n)
		sizes[r] = Num.i(sizes.get(r, 0)) + 1
	if sizes.size() <= 1:
		return out
	var biggest := -1
	for r: int in sizes:
		if biggest < 0 or Num.i(sizes[r]) > Num.i(sizes[biggest]):
			biggest = r
	for r: int in sizes:
		if r != biggest:
			var note := "%d crossings cut off" % Num.i(sizes[r])
			out.append(violation("split", g.nodes[r], note))
	return out


static func _find(root: Dictionary, n: int) -> int:
	while root.has(n) and Num.i(root[n]) != n:
		n = Num.i(root[n])
	return n


static func _degrees(g: Net) -> Dictionary:
	var hist := {}
	var total := 0
	var dead := 0
	for n: int in g.adj:
		var c := g.arms(n).size()
		hist[c] = Num.i(hist.get(c, 0)) + 1
		total += c
		if c == 1:
			dead += 1
	var count := maxi(1, g.adj.size())
	return {
		"nodes": g.adj.size(),
		"streets_per_node": float(total) / count,
		"degree_hist": hist,
		"dead_end_share": float(dead) / count,
	}


## Angles between neighbouring arms (sorted round each junction) into `hist`; the too-sharp out.
static func _angles(g: Net, hist: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: int in g.adj:
		var list := g.arms(n)
		if list.size() < 3:
			continue
		var dirs: Array[float] = []
		for k: int in list:
			var other := g.to_of(k) if g.from_of(k) == n else g.from_of(k)
			var d := g.nodes[other] - g.nodes[n]
			if d.length() > ZERO_M:
				dirs.append(atan2(d.y, d.x))
		dirs.sort()
		for i: int in dirs.size():
			var next := dirs[(i + 1) % dirs.size()] + (TAU if i == dirs.size() - 1 else 0.0)
			var deg := rad_to_deg(next - dirs[i])
			var bin := floori(deg / ANGLE_BIN) * roundi(ANGLE_BIN)
			hist[bin] = Num.i(hist.get(bin, 0)) + 1
			if deg < MIN_ANGLE_DEG:
				out.append(violation("angle", g.nodes[n], "arms %.0f deg apart" % deg))
	return out


## Block sides inside the real city into `metrics` (histograms in whole metres, aspect ratios);
## the stretched blocks out when more than ASPECT_SHARE of them are.
static func _blocks(plan: Dictionary, cfg: Dictionary, metrics: Dictionary) -> Array[Dictionary]:
	var extent := CityBand.extent(cfg)
	var short_hist := {}
	var long_hist := {}
	var aspect_hist := {}
	var count := 0
	var stretched: Array[Dictionary] = []
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if CityBand.near_edge(rect) >= extent or str(block["use"]) == "river":
			continue
		count += 1
		var lo := minf(rect.size.x, rect.size.y)
		var hi := maxf(rect.size.x, rect.size.y)
		short_hist[floori(lo)] = Num.i(short_hist.get(floori(lo), 0)) + 1
		long_hist[floori(hi)] = Num.i(long_hist.get(floori(hi), 0)) + 1
		var aspect := hi / maxf(lo, 0.01)
		aspect_hist[floori(aspect)] = Num.i(aspect_hist.get(floori(aspect), 0)) + 1
		if aspect > MAX_ASPECT:
			var note := "block %.1f x %.1f m" % [lo, hi]
			stretched.append(violation("aspect", rect.get_center(), note))
	metrics["blocks"] = count
	metrics["stretched_blocks"] = stretched.size()
	metrics["block_short_hist"] = short_hist
	metrics["block_long_hist"] = long_hist
	metrics["block_aspect_hist"] = aspect_hist
	var out: Array[Dictionary] = []
	if float(stretched.size()) > ASPECT_SHARE * count:
		out = stretched
	return out
