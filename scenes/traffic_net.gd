class_name TrafficNet
extends Node3D
## The street network under Traffic (split out to keep files small): the crossings, the lanes out
## of each and the streets they touch, built from the street plan (CityGen.map). Side streets are
## one-way, alternating by street; avenues and the diagonal carry a lane each way; alleys carry no
## cars.

const TWO_WAY_LANE := 1.0  # avenues: each lane's middle this far from the centre line

var _half: float
var _nodes: Array[Vector2] = []
## Per crossing: the lanes out of it, {"to": node, "lane": offset}, and the crossings every
## street it touches leads to (a fleeing car may drive any of them).
var _lanes: Array[Array] = []
var _links: Array[Array] = []
var _ends: Array[Vector2i] = []  # every lane as (from, to), for spawning


## The drivable network inside the playable city: alleys carry no cars.
func _build_lanes(plan: Dictionary) -> void:
	_nodes = plan["nodes"]
	for n: int in _nodes.size():
		_lanes.append([])
		_links.append([])
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		var a := Num.i(street["from"])
		var b := Num.i(street["to"])
		if kind == CityGen.ALLEY or not (_inside(_nodes[a]) and _inside(_nodes[b])):
			continue
		_links[a].append(b)
		_links[b].append(a)
		if kind != CityGen.STREET:
			_add_lane(a, b, TWO_WAY_LANE)
			_add_lane(b, a, TWO_WAY_LANE)
			continue
		# One-way, alternating with the street's index along its axis.
		var d := _nodes[b] - _nodes[a]
		var vertical := absf(d.y) > absf(d.x)
		var index := xs.find(_nodes[a].x) if vertical else zs.find(_nodes[a].y)
		var forward := (d.y if vertical else d.x) > 0.0
		if (posmod(index, 2) == 0) == forward:
			_add_lane(a, b, 0.0)
		else:
			_add_lane(b, a, 0.0)


func _add_lane(a: int, b: int, lane: float) -> void:
	_lanes[a].append({"to": b, "lane": lane})
	_ends.append(Vector2i(a, b))


func _inside(p: Vector2) -> bool:
	return maxf(absf(p.x), absf(p.y)) <= _half + 0.5


func crossing(n: int) -> Vector2:
	return _nodes[n]


## Crossings inside the city that cars can reach (the police pick blockade spots from these).
func crossings() -> Array[int]:
	var out: Array[int] = []
	for n: int in _nodes.size():
		if not _links[n].is_empty():
			out.append(n)
	return out


## Unit directions of the streets leaving crossing n.
func street_dirs(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for other: int in _links[n]:
		out.append((_nodes[other] - _nodes[n]).normalized())
	return out
