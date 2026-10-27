class_name KerbTrees
extends RefCounted
## Where the street trees stand (CityGreenery plants them): one every city.street_tree_gap
## metres down both kerbs of every avenue and street (city.street_tree_kinds) out to the edge of
## the view (D-062), the trunk on the kerb line (city.street_tree_kerb in from the road's edge),
## clear of the crossings (city.street_tree_clear), the buildings and the diagonal, and
## city.tree_min_apart from every spot kept before it (a crossing's two streets would stand
## 1.2 m apart). Draws nothing from the RNG.

## Every spot kept: {"p", "lean", "playable", "row"}; `lean` is the way the crown leans (over the
## road), `row` the index into `rows` (-1 outside the playable city).
var spots: Array[Dictionary] = []
## The playable city's kerb rows, each an Array of the trunks planted along it (CityGreenery
## fills them).
var rows: Array = []
## The length of avenue and street the playable city's trees line.
var avenue_m := 0.0
var _sim: RampageSim
var _plan: Dictionary
var _on_building: Callable  # Callable(p: Vector2) -> bool
var _half: float
var _beyond: float
var _taken := TreeSpots.new()  # the spots kept so far
var _gap: float
var _clear: float
var _apart: float
var _diagonal: float
# The street being walked: its start, direction, left-hand normal, length and whether it is inside
# the playable city (only those count in the green tally).
var _a: Vector2
var _dir: Vector2
var _side: Vector2
var _length: float
var _playable: bool


## beyond: how far past the playable city's edge the camera sees.
func _init(sim: RampageSim, plan: Dictionary, on_building: Callable, beyond: float) -> void:
	_sim = sim
	_plan = plan
	_on_building = on_building
	_half = CityGen.half_extent(sim.city)
	_beyond = beyond
	_gap = Num.f(sim.city["street_tree_gap"])
	_clear = Num.f(sim.city["street_tree_clear"])
	_apart = Num.f(sim.city["tree_min_apart"])
	var walk := Num.f(sim.city["sidewalk"])
	_diagonal = CityGen.width_of(CityGen.DIAGONAL, sim.city) * 0.5 + walk


## Works the spots out and returns their positions (the same ones, in order, as `spots`).
func positions() -> Array[Vector2]:
	var nodes: Array[Vector2] = _plan["nodes"]
	var kinds: Array = _sim.city["street_tree_kinds"]
	for street: Dictionary in _plan["streets"]:
		if not str(street["kind"]) in kinds:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if _inside(a, _beyond) or _inside(b, _beyond):
			_street(street, a, b)
	var out: Array[Vector2] = []
	for spot: Dictionary in spots:
		out.append(spot["p"])
	return out


func _inside(p: Vector2, margin: float) -> bool:
	return maxf(absf(p.x), absf(p.y)) <= _half + margin


## Both kerbs of one street from node a to node b.
func _street(street: Dictionary, a: Vector2, b: Vector2) -> void:
	_a = a
	_dir = (b - a).normalized()
	_side = Vector2(-_dir.y, _dir.x)
	_length = a.distance_to(b)
	_playable = _inside(a, 0.5) and _inside(b, 0.5)
	var kerb := Num.f(street["width"]) * 0.5 + Num.f(_sim.city["street_tree_kerb"])
	if _playable:
		avenue_m += _length
	for s: float in [-1.0, 1.0]:
		_kerb(s, kerb)


## The trees down the kerb on side `s` (1 or -1) of the street, `kerb` metres out from its middle.
func _kerb(s: float, kerb: float) -> void:
	var lean := Vector2i(roundi(-_side.x * s), roundi(-_side.y * s))  # over the road
	# One city-wide spacing (trunks where along-street position is a whole number of gaps), so
	# the rows carry on across the crossings instead of restarting at each block.
	var t := ceilf((_a.dot(_dir) + _clear) / _gap) * _gap - _a.dot(_dir)
	var row := -1  # a new row starts after anything but a lamp breaks the line
	while t < _length - _clear:
		var p := _a + _dir * t + _side * s * kerb
		# Too close to a tree already kept (a crossing's other street): slide along the kerb to
		# the nearest free spot, and start a row of its own there.
		var slid := _fits(p) and _taken.crowded(p, _apart)
		if slid:
			var along: Array[Vector2] = [_dir, -_dir]
			p = TreeSpots.nearest(p, along, _sim.city, _free)
		if p.is_finite() and _fits(p):
			row = _keep(p, lean, -1 if slid else row)
			if slid:
				row = -1
		else:
			row = -1
		t += _gap


## Keeps the spot p (on `row`, or on a new one when row < 0 inside the playable city); returns
## the row it is on.
func _keep(p: Vector2, lean: Vector2i, row: int) -> int:
	if row < 0 and _playable:
		rows.append([] as Array[Vector2])
		row = rows.size() - 1
	spots.append({"p": p, "lean": lean, "playable": _playable, "row": row})
	_taken.add(p)
	return row


## Whether a tree may stand at q: in view, off the buildings, clear of the diagonal.
func _fits(q: Vector2) -> bool:
	return (
		_inside(q, _beyond)
		and not _on_building.call(q)
		and CityGen.diagonal_distance(_plan, q) > _diagonal
	)


## Whether q is a free spot on the street being walked: clear of its crossings and the trees kept.
func _free(q: Vector2) -> bool:
	var at := (q - _a).dot(_dir)
	return at >= _clear and at <= _length - _clear and _fits(q) and not _taken.crowded(q, _apart)
