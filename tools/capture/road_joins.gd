extends RefCounted
## Where two roads join, for capture_road_seams.gd (roads suite R6, director 2026-10-26: "some
## weird spots where two roads met, like a seam between them rather than a seamless join"),
## worked out from the street plan alone (CityGen.map), never from how CityGround draws it, so the
## check judges the drawing. Pure: plan and config in.
##   A square junction (an x street meets a z street; alleys carry no asphalt) is a box reaching
##   the widest crossing road's half width each way; each arm joins it along the box's edge.
##   The diagonal joins each street it crosses along that street's kerb line.
## A join: {node, p (the join line's centre), e (along the line), n (its normal, out into the
## arm), along (the arm's direction), half (half the line's sampled length), free (how far the
## arm runs on clear of the next join), what}.

const MARGIN := 0.8  # kept clear of each kerb's gutter at the join line's ends (m)
const AXIS := 0.999  # |cos| of a street that runs along x or z

var plan: Dictionary
var cfg: Dictionary
var joins: Array[Dictionary] = []
## node -> [box half along x, box half along z] for every square junction.
var boxes := {}
var _arms := {}  # node -> Array of {dir, half, kind, far}


func _init(p_plan: Dictionary, p_cfg: Dictionary) -> void:
	plan = p_plan
	cfg = p_cfg
	_index()
	_square_joins()
	_diagonal_joins()


func _index() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		if kind == CityGen.ALLEY:
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		for i: int in 2:
			var here := nodes[ends[i]]
			var far := nodes[ends[1 - i]]
			if not _arms.has(ends[i]):
				_arms[ends[i]] = []
			var list: Array = _arms[ends[i]]
			list.append(
				{
					"dir": (far - here).normalized(),
					"half": Num.f(street["width"]) * 0.5,
					"kind": kind,
					"far": ends[1 - i],
					"length": here.distance_to(far)
				}
			)
	for n: int in _arms:
		var hx := 0.0
		var hz := 0.0
		for arm: Dictionary in _arms[n]:
			var d: Vector2 = arm["dir"]
			if absf(d.y) > AXIS:
				hx = maxf(hx, Num.f(arm["half"]))
			elif absf(d.x) > AXIS:
				hz = maxf(hz, Num.f(arm["half"]))
		if hx > 0.0 and hz > 0.0:
			boxes[n] = Vector2(hx, hz)


## How far an arm reaches into the node it starts from (its box, or the crossed street's kerb).
func _reach(n: int, dir: Vector2) -> float:
	if boxes.has(n):
		var box: Vector2 = boxes[n]
		return box.x if absf(dir.x) > AXIS else box.y
	var out := 0.0
	for arm: Dictionary in _arms.get(n, []):
		var d: Vector2 = arm["dir"]
		var s := absf(d.cross(dir))
		if s > 0.05 and str(arm["kind"]) != CityGen.DIAGONAL:
			out = maxf(out, Num.f(arm["half"]) / s)
	return out


func _square_joins() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	for n: int in boxes:
		for arm: Dictionary in _arms[n]:
			var d: Vector2 = arm["dir"]
			if absf(d.x) < AXIS and absf(d.y) < AXIS:
				continue  # the diagonal: _diagonal_joins
			var at := _reach(n, d)
			var free := Num.f(arm["length"]) - at - _reach(Num.i(arm["far"]), -d)
			joins.append(
				{
					"node": n,
					"p": nodes[n] + d * at,
					"e": Vector2(-d.y, d.x),
					"n": d,
					"along": d,
					"half": Num.f(arm["half"]) - MARGIN,
					"free": free,
					"what": "%s meets a junction" % arm["kind"]
				}
			)


func _diagonal_joins() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	for n: int in _arms:
		var crossed := false
		for arm: Dictionary in _arms[n]:
			if str(arm["kind"]) != CityGen.DIAGONAL:
				continue
			if not crossed:
				_street_joins(n, arm)
				crossed = true
			var d: Vector2 = arm["dir"]
			for cross: Dictionary in _arms[n]:
				var c: Vector2 = cross["dir"]
				var s := absf(c.cross(d))
				if str(cross["kind"]) == CityGen.DIAGONAL or s < 0.05:
					continue
				var normal := Vector2(-c.y, c.x)
				if normal.dot(d) < 0.0:
					normal = -normal
				var at := Num.f(cross["half"]) / s
				var free := Num.f(arm["length"]) - at - _reach(Num.i(arm["far"]), -d)
				joins.append(
					{
						"node": n,
						"p": nodes[n] + d * at,
						"e": c,
						"n": normal,
						"along": d,
						"half": (Num.f(arm["half"]) - MARGIN) / s,
						"free": free,
						"what": "the diagonal meets a %s" % cross["kind"]
					}
				)
				break  # one join per arm: the street it leaves


## The streets running on through the diagonal's crossing at node n: each arm joins the crossing
## along the diagonal's kerb line.
func _street_joins(n: int, diagonal: Dictionary) -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	var d: Vector2 = diagonal["dir"]
	var line := Vector2(-d.y, d.x)
	for arm: Dictionary in _arms[n]:
		var c: Vector2 = arm["dir"]
		var s := absf(c.cross(d))
		if str(arm["kind"]) == CityGen.DIAGONAL or s < 0.05 or boxes.has(n):
			continue
		var normal := line if line.dot(c) > 0.0 else -line
		var at := Num.f(diagonal["half"]) / s
		joins.append(
			{
				"node": n,
				"p": nodes[n] + c * at,
				"e": d,
				"n": normal,
				"along": c,
				"half": (Num.f(arm["half"]) - MARGIN) / s,
				"free": Num.f(arm["length"]) - at - _reach(Num.i(arm["far"]), -c),
				"what": "a %s meets the diagonal's crossing" % arm["kind"]
			}
		)
