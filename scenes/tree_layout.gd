class_name TreeLayout
extends RefCounted
## Where each node of the evolution tree sits (D-275, layout A: "A but we need to be able to zoom
## out and pan easily"): polar rings, the baby's ring round the centre and each growth stage's
## ring further out (R 16.5). Pure maths over the tree's data, in canvas units at the default zoom
## (text 24 px at 1080p), so the tree suite checks it headless. Sizes and spacing: tuning "tree"
## "layout". Each ring's radius clears the ring inside it and leaves every node in it room on
## the circle; nodes are spread evenly round their ring, ordered so each sits near the nodes it
## needs (ring 1 in the order its links run, outer rings by the mean angle of their parents).

## id -> the node's centre (canvas units, the tree's centre at 0, 0).
var centres: Dictionary = {}
## id -> the node's box size.
var sizes: Dictionary = {}
## id -> the node's angle round the centre (radians).
var angles: Dictionary = {}
## Ring radius by ring (index 0 = ring 1).
var radii: Array[float] = []
## Half the radial depth each ring's band takes (index 0 = ring 1): a node's box stays inside
## radius +/- this.
var half_depth: Array[float] = []
## The box round every node.
var bounds := Rect2()


## Lays out `tree` (every node, shown or not, so a node never moves as rings open).
## ultimate_ids: nodes drawn as their branch's capstone (a taller box).
static func build(tree: UpgradeTree, ultimate_ids: Array[String]) -> TreeLayout:
	var out := TreeLayout.new()
	var cfg: Dictionary = Content.section("tree")["layout"]
	var by_ring := _by_ring(tree)
	for id: String in tree.order:
		out.sizes[id] = _size(cfg, tree.kind(id), ultimate_ids.has(id))
	var gap := Num.f(cfg["node_gap"])
	var inner := Num.f(cfg["centre_radius"])
	var last_half := 0.0
	for r: int in range(1, by_ring.size() + 1):
		var ids: Array[String] = by_ring[r - 1]
		var widest := 0.0
		for id: String in ids:
			var size: Vector2 = out.sizes[id]
			widest = maxf(widest, _extent(size))
		var around := ids.size() * (widest + gap) / TAU
		var outward := inner + last_half + widest * 0.5 + Num.f(cfg["ring_gap"])
		if r == 1:
			outward = inner
		var radius := maxf(around, outward)
		out.radii.append(radius)
		out.half_depth.append(widest * 0.5)
		out._place_ring(tree, ids, radius, r == 1)
		inner = radius
		last_half = widest * 0.5
	out._measure()
	return out


## The nodes of each ring, ring 1 first (a ring with no nodes is an empty list).
static func _by_ring(tree: UpgradeTree) -> Array:
	var top := 1
	for id: String in tree.order:
		top = maxi(top, tree.ring(id))
	var out: Array = []
	for r: int in top:
		var ids: Array[String] = []
		out.append(ids)
	for id: String in tree.order:
		var ids: Array[String] = out[tree.ring(id) - 1]
		ids.append(id)
	return out


static func _size(cfg: Dictionary, kind: String, ultimate: bool) -> Vector2:
	var nodes: Dictionary = cfg["node"]
	var box: Array = nodes.get(kind, nodes["stat"])
	var size := Vector2(Num.f(box[0]), Num.f(box[1]))
	if ultimate:
		size.y += Num.f(cfg["ultimate_extra"])
	return size


## The most room a box can take in any direction: its diagonal (two nodes whose centres are
## at least the mean of their diagonals apart never touch, whatever their angle).
static func _extent(size: Vector2) -> float:
	return size.length()


func _place_ring(tree: UpgradeTree, ids: Array[String], radius: float, centre: bool) -> void:
	if ids.is_empty():
		return
	var ordered := _link_order(tree, ids) if centre else _by_parents(tree, ids)
	var step := TAU / ordered.size()
	var start := -PI / 2.0 if centre else _best_turn(tree, ordered, step)
	for k: int in ordered.size():
		var id: String = ordered[k]
		var a := start + step * k
		angles[id] = a
		centres[id] = Vector2(cos(a), sin(a)) * radius


## Ring 1: each root, then what it opens, depth first, so linked nodes sit side by side.
func _link_order(tree: UpgradeTree, ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids:
		if _inner_parents(tree, id, ids).is_empty():
			_visit(tree, id, ids, out)
	for id: String in ids:
		if not out.has(id):
			out.append(id)
	return out


func _visit(tree: UpgradeTree, id: String, ids: Array[String], out: Array[String]) -> void:
	if out.has(id):
		return
	out.append(id)
	for child: String in ids:
		var parents := _inner_parents(tree, child, ids)
		if parents.has(id) and parents.all(func(p: String) -> bool: return out.has(p)):
			_visit(tree, child, ids, out)


static func _inner_parents(tree: UpgradeTree, id: String, ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var def: Dictionary = tree.defs[id]
	var requires: Array = def.get("requires", [])
	for req: String in requires:
		if ids.has(req):
			out.append(req)
	return out


## The mean angle of the placed nodes `id` needs (NAN when none is placed yet).
func _parent_angle(tree: UpgradeTree, id: String) -> float:
	var def: Dictionary = tree.defs[id]
	var requires: Array = def.get("requires", [])
	var sum := Vector2.ZERO
	for req: String in requires:
		if angles.has(req):
			var a := Num.f(angles[req])
			sum += Vector2(cos(a), sin(a))
	return NAN if sum.length() < 0.0001 else sum.angle()


## Outer rings: by the mean angle of their parents (no placed parent: data order, last).
func _by_parents(tree: UpgradeTree, ids: Array[String]) -> Array[String]:
	var keyed: Array = []
	for k: int in ids.size():
		var a := _parent_angle(tree, ids[k])
		keyed.append([TAU * 2.0 + k if is_nan(a) else fposmod(a, TAU), ids[k]])
	keyed.sort_custom(func(x: Array, y: Array) -> bool: return Num.f(x[0]) < Num.f(y[0]))
	var out: Array[String] = []
	for pair: Array in keyed:
		out.append(str(pair[1]))
	return out


## The turn of the ring that puts its nodes nearest their parents on average.
func _best_turn(tree: UpgradeTree, ordered: Array[String], step: float) -> float:
	var sum := Vector2.ZERO
	for k: int in ordered.size():
		var a := _parent_angle(tree, ordered[k])
		if not is_nan(a):
			var off := a - step * k
			sum += Vector2(cos(off), sin(off))
	return -PI / 2.0 if sum.length() < 0.0001 else sum.angle()


## The box of node `id` (canvas units, centred on its centre).
func rect(id: String) -> Rect2:
	var size: Vector2 = sizes[id]
	var at: Vector2 = centres[id]
	return Rect2(at - size * 0.5, size)


func _measure() -> void:
	var first := true
	for id: String in centres:
		bounds = rect(id) if first else bounds.merge(rect(id))
		first = false
