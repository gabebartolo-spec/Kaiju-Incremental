class_name RoadJunctions
extends RefCounted
## Where CityGround lays each street's asphalt, so two roads that meet make one surface
## (director 2026-10-26: "some weird spots where two roads met, like a seam between them rather
## than a seamless join"; roads suite R6, tools/capture/capture_road_seams.gd). Each street's
## slab carries its own lanes, tracks and kerb gutters (ground_slab.gdshader); where two used to
## overlap in a junction, one street's gutters ran across the other's mouth. Now:
##   - a square junction (an x street meets a z street) is one box (GroundKit.K_JUNCTION: both
##     streets' lanes, faded into each other, no gutter), as wide as the widest road crossing it
##     each way, and every street stops at its edge;
##   - a street running on through a node abuts the next piece there (no overlap);
##   - where the diagonal crosses a street, the patch both cover is the street's asphalt with no
##     gutter, laid over both.
## Alleys get no slab: the pavements either side meet across them. Presentation only.


## node -> Vector2(the box's half extent along x, along z), for every square junction.
static func boxes(plan: Dictionary, coast: float) -> Dictionary:
	var nodes: Array[Vector2] = plan["nodes"]
	var half := {}  # node -> Vector2(widest z street's half, widest x street's half)
	for street: Dictionary in plan["streets"]:
		if not _laid(street):
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var along_x := is_equal_approx(nodes[ends[0]].y, nodes[ends[1]].y)
		for n: int in ends:
			var h: Vector2 = half.get(n, Vector2.ZERO)
			var w := Num.f(street["width"]) * 0.5
			half[n] = Vector2(h.x, maxf(h.y, w)) if along_x else Vector2(maxf(h.x, w), h.y)
	var out := {}
	for n: int in half:
		var h: Vector2 = half[n]
		if h.x > 0.0 and h.y > 0.0 and nodes[n].y >= coast:
			out[n] = h
	return out


## The box at node n as a rect (x, z).
static func box_rect(plan: Dictionary, n: int, half: Vector2) -> Rect2:
	var nodes: Array[Vector2] = plan["nodes"]
	return Rect2(nodes[n] - half, half * 2.0)


## Every street's slab: {rect, axis (GroundKit.ALONG_*), centre, half}, from box edge to box edge,
## abutting at a node where the street runs on, reaching half its width past a node where it
## ends (the plan's edge, a bridge).
static func streets(plan: Dictionary, coast: float, junctions: Dictionary) -> Array[Dictionary]:
	var nodes: Array[Vector2] = plan["nodes"]
	var runs_on := _runs_on(plan)
	var out: Array[Dictionary] = []
	for street: Dictionary in plan["streets"]:
		if not _laid(street):
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var a := nodes[ends[0]]
		var b := nodes[ends[1]]
		if minf(a.y, b.y) < coast:
			continue
		var half := Num.f(street["width"]) * 0.5
		var along_x := is_equal_approx(a.y, b.y)
		var axis := 0 if along_x else 1
		var ta := a.x if along_x else a.y
		var tb := b.x if along_x else b.y
		var lo_n := ends[0] if ta <= tb else ends[1]
		var hi_n := ends[1] if ta <= tb else ends[0]
		var lo := minf(ta, tb) - _reach(junctions, runs_on, lo_n, axis, half)
		var hi := maxf(ta, tb) + _reach(junctions, runs_on, hi_n, axis, half)
		if hi - lo <= 0.0:
			continue  # two junction boxes meet: nothing between them
		var centre := a.y if along_x else a.x
		var rect := (
			Rect2(lo, centre - half, hi - lo, half * 2.0)
			if along_x
			else Rect2(centre - half, lo, half * 2.0, hi - lo)
		)
		out.append({"rect": rect, "axis": axis, "centre": centre, "half": half})
	return out


## The patches where the diagonal (its pieces as drawn, `diagonal`: polygons) crosses the street
## pieces `pieces` ({rect, data}): {poly (x, z), data: the street's kind data, its gutter off}, so
## the street's lanes run on through the crossing with no kerb gutter across the diagonal's mouth.
static func crossings(
	diagonal: Array[PackedVector2Array], pieces: Array[Dictionary]
) -> Array[Dictionary]:
	var merged: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in diagonal:
		var left: Array[PackedVector2Array] = [poly]
		if not merged.is_empty():
			var last: PackedVector2Array = merged.pop_back()
			var joined := Geometry2D.merge_polygons(last, poly)
			left.assign(joined)
		merged.append_array(left)
	var out: Array[Dictionary] = []
	for street: Dictionary in pieces:
		var piece: Rect2 = street["rect"]
		var d: Color = street["data"]
		var rect := PackedVector2Array(
			[
				piece.position,
				Vector2(piece.end.x, piece.position.y),
				piece.end,
				Vector2(piece.position.x, piece.end.y)
			]
		)
		for band: PackedVector2Array in merged:
			for common: PackedVector2Array in Geometry2D.intersect_polygons(rect, band):
				out.append({"poly": common, "data": Color(d.r, d.g, d.b, -absf(d.a))})
	return out


## How far a street's slab reaches past node n along its axis (negative: stops short of it).
static func _reach(
	junctions: Dictionary, runs_on: Dictionary, n: int, axis: int, half: float
) -> float:
	if junctions.has(n):
		var box: Vector2 = junctions[n]
		return -(box.x if axis == 0 else box.y)
	if runs_on.has(Vector2i(n, axis)):
		return 0.0
	return half


## Vector2i(node, axis) -> true where two laid streets of that axis meet (the street runs on).
static func _runs_on(plan: Dictionary) -> Dictionary:
	var nodes: Array[Vector2] = plan["nodes"]
	var count := {}
	for street: Dictionary in plan["streets"]:
		if not _laid(street):
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var axis := 0 if is_equal_approx(nodes[ends[0]].y, nodes[ends[1]].y) else 1
		for n: int in ends:
			var key := Vector2i(n, axis)
			count[key] = Num.i(count.get(key, 0)) + 1
	var out := {}
	for key: Vector2i in count:
		if Num.i(count[key]) > 1:
			out[key] = true
	return out


## True for a street CityGround lays as a slab of its own (not the diagonal, not an alley).
static func _laid(street: Dictionary) -> bool:
	return not str(street["kind"]) in [CityGen.DIAGONAL, CityGen.ALLEY]
