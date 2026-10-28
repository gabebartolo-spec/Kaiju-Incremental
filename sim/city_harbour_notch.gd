class_name CityHarbourNotch
extends RefCounted
## The quay steps the sea bay (CityHarbour) leaves round a junction its curve only clips, so no
## street there dead-ends short of its cross street (lead ruling 2026-10-28, "the junction wins"),
## and the rect subtraction the bay's bands use to leave those steps dry. Pure.

const NOTCH_PASSES := 4  # rounds of notching: a notch can bring the water off another junction


## The junctions the bay's curve only clips (lead 2026-10-28, "the junction wins"): where the
## water would stop a north-south or east-west street no more than its own width short of a dry
## junction, the bay's water is notched round that junction's asphalt and pavement and the
## street's own from there to the water (a small quay step in the shore), so the street runs on
## to its cross street. Recorded as plan["harbour"]["notches"]; bands and holds leave them dry.
static func junctions(plan: Dictionary, cfg: Dictionary) -> void:
	var notches: Array[Rect2] = []
	plan["harbour"]["notches"] = notches
	for _pass: int in NOTCH_PASSES:
		var water := CityHarbour.bands(plan, cfg)
		var added := false
		for street: Dictionary in plan["streets"]:
			for r: Rect2 in _notch(plan, street, water, cfg):
				if not notches.has(r):
					notches.append(r)
					added = true
		if not added:
			return


## The notches `street` needs (its junction's square and its own corridor to the water, see
## _notch_junctions); [] when the water leaves it whole, cuts it through, or stops it further
## from its junction.
static func _notch(
	plan: Dictionary, street: Dictionary, water: Array[Rect2], cfg: Dictionary
) -> Array[Rect2]:
	var nodes: Array[Vector2] = plan["nodes"]
	var a := nodes[Num.i(street["from"])]
	var b := nodes[Num.i(street["to"])]
	var width := Num.f(street["width"])
	var axis := CityHarbour.axis_of(a, b)
	var wet := CityHarbour.wet(CityHarbour.carriageway(a, b, width * 0.5, axis), water)
	if wet.is_empty() or axis < 0:
		return []
	for end: Vector2 in [a, b]:
		var other := b if end == a else a
		var reach := _wet_reach(end, other, axis, wet)
		if reach > CityHarbour.CUT_MIN and reach <= width and _dry(end, water) and _dry(other, water):
			var side := width * 0.5 + Num.f(cfg["sidewalk"])
			var tip := end.lerp(other, reach / end.distance_to(other))
			var lane := Rect2(end, Vector2.ZERO).expand(tip).grow(side)
			return [_junction(plan, end, cfg), lane]
	return []


## How far from `end` toward `other` (along axis) the water over the street reaches, when it
## lies on `end`'s half of the street; 0 when it lies only on the far half.
static func _wet_reach(end: Vector2, other: Vector2, axis: int, wet: Array[Rect2]) -> float:
	var out := 0.0
	var dir := signf(other[axis] - end[axis])
	var length := absf(other[axis] - end[axis])
	for w: Rect2 in wet:
		var near := w.position[axis] if dir > 0.0 else w.end[axis]
		var far := w.end[axis] if dir > 0.0 else w.position[axis]
		if (near - end[axis]) * dir <= length * 0.5:
			out = maxf(out, minf((far - end[axis]) * dir, length))
	return out


## Whether p lies outside every band of `water`.
static func _dry(p: Vector2, water: Array[Rect2]) -> bool:
	for w: Rect2 in water:
		if w.has_point(p):
			return false
	return true


## The asphalt and pavement square of the junction at p: half its widest street of each axis,
## plus the pavement, each way.
static func _junction(plan: Dictionary, p: Vector2, cfg: Dictionary) -> Rect2:
	var nodes: Array[Vector2] = plan["nodes"]
	var half := Vector2.ZERO
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if a.distance_to(p) < 0.001 or b.distance_to(p) < 0.001:
			var axis := CityHarbour.axis_of(a, b)
			if axis >= 0:
				half[1 - axis] = maxf(half[1 - axis], Num.f(street["width"]) * 0.5)
	return Rect2(p - half, half * 2.0).grow(Num.f(cfg["sidewalk"]))


## Each of `rects` less every rect of `holes`.
static func minus(rects: Array[Rect2], holes: Array) -> Array[Rect2]:
	var out := rects
	for hole: Rect2 in holes:
		var next: Array[Rect2] = []
		for r: Rect2 in out:
			next.append_array(_cut_rect(r, hole))
		out = next
	return out


## r less hole: up to four rects (the strips above, below, left and right of the hole).
static func _cut_rect(r: Rect2, hole: Rect2) -> Array[Rect2]:
	if not r.intersects(hole):
		return [r]
	var cut := r.intersection(hole)
	var pieces: Array[Rect2] = [
		Rect2(r.position.x, r.position.y, r.size.x, cut.position.y - r.position.y),
		Rect2(r.position.x, cut.end.y, r.size.x, r.end.y - cut.end.y),
		Rect2(r.position.x, cut.position.y, cut.position.x - r.position.x, cut.size.y),
		Rect2(cut.end.x, cut.position.y, r.end.x - cut.end.x, cut.size.y),
	]
	var out: Array[Rect2] = []
	for piece: Rect2 in pieces:
		if piece.size.x > CityHarbour.CUT_MIN and piece.size.y > CityHarbour.CUT_MIN:
			out.append(piece)
	return out


## The quay steps of the bay's curve (stored as plan["harbour"]["quays"], which
## CityHarbour.bands adds to its water): each band's curved end run on across the street the bay
## cuts there and to the next block's pavement (no wider than the widest street and its
## pavements), so the curve leaves no sliver of bare asphalt between its water and the blocks
## (R4), the streets there ending at a quay instead. Never over a street the bay leaves whole or
## its junctions; a band end inside a block stays as it is. Run once by CityHarbour.mark,
## before it cuts streets.
static func quays(plan: Dictionary, cfg: Dictionary) -> void:
	var strips := CityHarbour.bands(plan, cfg)
	var reach := _widest(plan) + 2.0 * Num.f(cfg["sidewalk"])
	var dry := _dry_roads(plan, strips)
	var cut := _cut_lanes(plan, strips)
	var out: Array[Rect2] = []
	for s: Rect2 in strips:
		var lo := _next_block(plan, cfg, s, _across(cut, s, s.position.x, -1.0), -1.0, reach)
		var hi := _next_block(plan, cfg, s, _across(cut, s, s.end.x, 1.0), 1.0, reach)
		var west := Rect2(lo, s.position.y, s.position.x - lo, s.size.y)
		var east := Rect2(s.end.x, s.position.y, hi - s.end.x, s.size.y)
		for gap: Rect2 in [west, east]:
			if gap.size.x > CityHarbour.CUT_MIN:
				var step: Array[Rect2] = [gap]
				out.append_array(minus(step, dry))
	plan["harbour"]["quays"] = out


## The x of the nearest dry block's pavement (CityGen.pavement) edge from x outward (dir)
## across strip s's z-span,
## when it is no further than `reach`; else x (and x when a dry block straddles x).
static func _next_block(
	plan: Dictionary, cfg: Dictionary, s: Rect2, x: float, dir: float, reach: float
) -> float:
	var best := x + dir * reach
	var found := false
	for block: Dictionary in plan["blocks"]:
		var r := CityGen.pavement(block, cfg)
		if r.end.y <= s.position.y or r.position.y >= s.end.y or str(block["use"]) == "harbour":
			continue
		if r.position.x < x and r.end.x > x:
			return x
		var edge := r.position.x if dir > 0.0 else r.end.x
		if (edge - x) * dir >= 0.0 and (edge - best) * dir <= 0.0:
			best = edge
			found = true
	return best if found else x


## The widest street of the plan (m).
static func _widest(plan: Dictionary) -> float:
	var out := 0.0
	for street: Dictionary in plan["streets"]:
		out = maxf(out, Num.f(street["width"]))
	return out


## The carriageways of the north-south streets the bands of `strips` reach (the bay cuts them).
static func _cut_lanes(plan: Dictionary, strips: Array[Rect2]) -> Array[Rect2]:
	var nodes: Array[Vector2] = plan["nodes"]
	var out: Array[Rect2] = []
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if CityHarbour.axis_of(a, b) != 1:
			continue
		var road := CityHarbour.carriageway(a, b, Num.f(street["width"]) * 0.5, 1)
		if not CityHarbour.wet(road, strips).is_empty():
			out.append(road)
	return out


## x moved (dir) to the far side of the cut carriageway of `lanes` it lies in across strip s's
## z-span; x when it lies in none.
static func _across(lanes: Array[Rect2], s: Rect2, x: float, dir: float) -> float:
	for lane: Rect2 in lanes:
		var spans := lane.position.y < s.end.y and lane.end.y > s.position.y
		if spans and lane.position.x < x and lane.end.x > x:
			return lane.end.x if dir > 0.0 else lane.position.x
	return x


## The carriageways of the streets no band of `strips` reaches, run on over their junction
## boxes (they stay whole: no quay step may take them).
static func _dry_roads(plan: Dictionary, strips: Array[Rect2]) -> Array[Rect2]:
	var nodes: Array[Vector2] = plan["nodes"]
	var out: Array[Rect2] = []
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var half := Num.f(street["width"]) * 0.5
		var axis := CityHarbour.axis_of(a, b)
		var road := CityHarbour.carriageway(a, b, half, axis)
		if CityHarbour.wet(road, strips).is_empty():  # with its junction boxes at each end
			var ends := Vector2(half, 0.0) if axis == 0 else Vector2(0.0, half if axis == 1 else 0.0)
			out.append(road.grow_individual(ends.x, ends.y, ends.x, ends.y))
	return out

