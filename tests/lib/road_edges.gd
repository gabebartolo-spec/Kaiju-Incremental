extends RefCounted
## The edges and surface of every road the stage draws (tests/lib/road_ground.gd), walked both
## sides crossing to crossing (director 2026-10-26: roads meeting "other roads and pavements in a
## natural, realistic way", and "a seam between them rather than a seamless join"). Each rule
## returns named violations with world coordinates (x, z in metres), one per road side and cause.
##   R3 the asphalt edge is straight through a junction: no pavement juts into a carriageway or
##      the box where two roads cross
##   R4 a kerbed pavement lines both sides of every road (bridges and quays excepted): asphalt
##      never meets bare asphalt, a lawn, a plaza or a car park, nor a pavement no higher than it
##   R5 lane paint stops at junction edges; zebra crossings only at the central junction (D-054)
##   R6 (geometry) two road pieces that meet are one surface: no height step along a road

const RoadGround := preload("res://tests/lib/road_ground.gd")
const RoadNet := preload("res://tests/lib/road_net.gd")
const STEP := 0.5  # sample spacing along a road edge (m)
const INSET := 0.25  # a sample's distance in from, or out past, the asphalt edge (m)
const KERB := 0.05  # the least step from asphalt up to its pavement that reads as a kerb (m)
const FLAT := 0.005  # the greatest height step two joined road pieces may have (m)
const ZEBRA_SIZE := Vector2(0.3, 1.2)  # RoadPaint._zebra's stripe (across, along)
const ZEBRA_OFF := 0.9  # RoadPaint.marks: a zebra's centre past the crossing's kerb line
const STOP_REACH := 3.5  # a stop line's farthest centre past the junction box, zebra counted
const SHORT_SPAN := 4.0  # R7: a road with a slanted end this short (dash pitches) may be bare
const PERPENDICULAR := 0.999  # |sin| of a crossing whose junction box an edge runs through


## R3: pavement inside a carriageway, or inside the box of a junction the road runs through.
static func r3_edges(ground: RoadGround) -> Array[String]:
	var out: Array[String] = []
	var all := RoadNet.arms(ground)
	for r: int in ground.roads.size():
		if not _shown(ground, r):
			continue
		var road := ground.roads[r]
		var h0 := _box(ground, all, Num.i(road["from"]), r)
		var h1 := _box(ground, all, Num.i(road["to"]), r)
		for side: float in [-1.0, 1.0]:
			var t := -h0 + INSET
			while t <= Num.f(road["length"]) + h1 - INSET:
				var p := _edge(road, t, side, -INSET)
				var kind := str(ground.at(p)["kind"])
				t += STEP
				if not kind in [RoadGround.ROAD, RoadGround.DECK]:
					out.append(
						(
							"R3 jagged edge at %s: %s juts into the %s's asphalt"
							% [RoadGround.where(p), kind, road["kind"]]
						)
					)
					break
	return out


## R4: what lies just past each asphalt edge, between the junctions.
static func r4_kerbs(ground: RoadGround) -> Array[String]:
	var out: Array[String] = []
	var all := RoadNet.arms(ground)
	for r: int in ground.roads.size():
		if not _shown(ground, r):
			continue
		var road := ground.roads[r]
		var h0 := RoadNet.reach_into(ground, all, Num.i(road["from"]), r) + INSET
		var h1 := RoadNet.reach_into(ground, all, Num.i(road["to"]), r) + INSET
		for side: float in [-1.0, 1.0]:
			var t := h0
			while t <= Num.f(road["length"]) - h1:
				var bad := _kerb_fault(ground, r, t, side)
				t += STEP
				if not bad.is_empty():
					out.append(bad)
					break
	return out


## "" when the edge of road r at t (one side) is kerbed, or is a bridge or quay; else the fault.
static func _kerb_fault(ground: RoadGround, r: int, t: float, side: float) -> String:
	var road := ground.roads[r]
	var inner: Dictionary = ground.at(_edge(road, t, side, -INSET))
	if str(inner["kind"]) != RoadGround.ROAD:
		return ""  # a deck (bridges are excepted) or not this road's asphalt (R3 says)
	var p := _edge(road, t, side, INSET)
	var outer: Dictionary = ground.at(p)
	var kind := str(outer["kind"])
	if kind in [RoadGround.DECK, RoadGround.WATER] or not Num.i(outer["road"]) in [-1, r]:
		return ""  # a bridge, a quay, or another road crossing this one
	if kind == RoadGround.PAVE and Num.f(outer["top"]) >= Num.f(inner["top"]) + KERB:
		return ""
	var what := (
		(
			"a pavement with no kerb (%.2f m against the asphalt's %.2f m)"
			% [Num.f(outer["top"]), Num.f(inner["top"])]
		)
		if kind == RoadGround.PAVE
		else kind
	)
	return "R4 the %s's asphalt meets %s at %s" % [road["kind"], what, RoadGround.where(p)]


## R6 (geometry): along each road's centre line, through its junctions and onto its decks, the
## road's top never steps.
static func r6_seams(ground: RoadGround) -> Array[String]:
	var out: Array[String] = []
	var all := RoadNet.arms(ground)
	for r: int in ground.roads.size():
		if not _shown(ground, r):
			continue
		var road := ground.roads[r]
		var t := -RoadNet.reach_into(ground, all, Num.i(road["from"]), r)
		var end := Num.f(road["length"]) + RoadNet.reach_into(ground, all, Num.i(road["to"]), r)
		var last := NAN
		while t <= end:
			var p := _edge(road, t, 0.0, 0.0)
			var here: Dictionary = ground.at(p)
			t += STEP
			if not str(here["kind"]) in [RoadGround.ROAD, RoadGround.DECK]:
				last = NAN
				continue
			var top := Num.f(here["top"])
			if not is_nan(last) and absf(top - last) > FLAT:
				out.append(
					(
						"R6 height step of %.0f cm on the %s at %s"
						% [absf(top - last) * 100.0, road["kind"], RoadGround.where(p)]
					)
				)
				break
			last = top
	return out


## R5: every dash and zebra stripe CityGround paints lies on its own road and outside every
## junction box; zebras stand only at the central junction (the avenues' crossing nearest the
## centre), and there are zebras there.
static func r5_paint(ground: RoadGround, paint: Array[Transform3D]) -> Array[String]:
	var out: Array[String] = []
	var zebra_at := {}
	var central := central_junction(ground)
	var nodes: Array[Vector2] = ground.plan["nodes"]
	# A zebra belongs to the central junction when it lies on one of its arms, within the widest
	# avenue's width plus its stripe's offset and length (RoadPaint._zebra) of the crossing.
	var avenue := CityGen.width_of(CityGen.AVENUE, ground.cfg)
	var zebra_reach := Vector2(avenue * 0.5 + ZEBRA_OFF + ZEBRA_SIZE.y, avenue * 0.5).length()
	for stripe: Transform3D in paint:
		var c := Vector2(stripe.origin.x, stripe.origin.z)
		if not ground.in_view(c):
			continue
		var size := Vector2(stripe.basis.x.length(), stripe.basis.z.length())
		if size.is_equal_approx(ZEBRA_SIZE):
			var at_central := central >= 0 and nodes[central].distance_to(c) <= zebra_reach
			zebra_at[central if at_central else _nearest(nodes, c)] = true
		var bad := _stripe_fault(ground, stripe)
		if not bad.is_empty():
			out.append(bad)
	for n: int in zebra_at:
		if n != central:
			out.append(
				"R5 zebra crossing at %s, not the central junction" % RoadGround.where(nodes[n])
			)
	if central >= 0 and not zebra_at.has(central):
		out.append("R5 the central junction at %s has no zebra" % RoadGround.where(nodes[central]))
	return out


## R7 (director 2026-10-28: "all roads must have road lines when appropriate"): every road in view
## wide enough for two lanes (road_paint.two_lane_min), long enough for a dash, carries its centre
## line, and every end of it that meets a road square to it carries a stop line across its
## approaching lane, unless a slanted crossing's asphalt lies where the stop line would.
static func r7_markings(ground: RoadGround, paint: Array[Transform3D]) -> Array[String]:
	var out: Array[String] = []
	var rp: Dictionary = ground.cfg["road_paint"]
	var centre := {}  # road -> true when a centre line stripe lies on it
	var stops := {}  # Vector2i(road, end) -> true
	var all := RoadNet.arms(ground)
	for stripe: Transform3D in paint:
		var c := Vector2(stripe.origin.x, stripe.origin.z)
		var long := Vector2(stripe.basis.z.x, stripe.basis.z.z).normalized()
		for r: int in ground.roads_at(c, -1.0):
			var road := ground.roads[r]
			var dir: Vector2 = road["dir"]
			var a: Vector2 = road["a"]
			var across := absf((c - a).cross(dir))
			if absf(dir.cross(long)) < 0.01:
				var inside := Num.f(rp["double_gap"]) * 0.5 + Num.f(rp["line_width"])
				if across <= inside:
					centre[r] = true
			elif absf(dir.cross(long)) >= PERPENDICULAR:
				var along := (c - a).dot(dir)
				for end: int in 2:
					var from := along if end == 0 else Num.f(road["length"]) - along
					var box := _box(ground, all, Num.i(road["from"] if end == 0 else road["to"]), r)
					if box > 0.0 and from >= box and from <= box + STOP_REACH:
						stops[Vector2i(r, end)] = true
	for r: int in ground.roads.size():
		if not _shown(ground, r):
			continue
		var road := ground.roads[r]
		var half := Num.f(road["half"])
		if half * 2.0 < Num.f(rp["two_lane_min"]):
			continue
		var start: Vector2 = road["a"]
		var gap := half + Num.f(rp["dash_clear"])
		var span := Num.f(road["length"]) - 2.0 * gap
		# A short road between a slanted crossing's long mouth and the next is left bare.
		var short := (
			span < SHORT_SPAN * Num.f(rp["dash_pitch"]) and _slanted_end(ground, all, road, r)
		)
		if span > Num.f(rp["dash_pitch"]) and not short and not centre.has(r):
			out.append("R7 %s at %s has no centre line" % [road["kind"], RoadGround.where(start)])
		if str(road["kind"]) == CityGen.DIAGONAL:
			continue
		for end: int in 2:
			var node := Num.i(road["from"] if end == 0 else road["to"])
			var box := _box(ground, all, node, r)
			var covered := stops.has(Vector2i(r, end)) or _slanted_there(ground, road, end, box, rp)
			if box > 0.0 and not covered:
				out.append(
					(
						"R7 %s at %s has no stop line at its %s end"
						% [road["kind"], RoadGround.where(start), "first" if end == 0 else "last"]
					)
				)
	return out


## True when a road not square or parallel to road r meets it at either end.
static func _slanted_end(ground: RoadGround, all: Dictionary, road: Dictionary, r: int) -> bool:
	var own: Vector2 = ground.roads[r]["dir"]
	for node: int in [Num.i(road["from"]), Num.i(road["to"])]:
		for arm: Dictionary in all.get(node, []):
			var other: Vector2 = arm["dir"]
			var turn := absf(own.cross(other))
			if turn > 0.01 and turn < PERPENDICULAR:
				return true
	return false


## True when a slanted road's asphalt lies where the stop line of road's `end` would be.
static func _slanted_there(
	ground: RoadGround, road: Dictionary, end: int, box: float, rp: Dictionary
) -> bool:
	var dir: Vector2 = road["dir"]
	var toward := dir if end == 0 else -dir
	var node: Vector2 = road["a"] if end == 0 else road["b"]
	var side := Vector2(toward.y, -toward.x)
	var thick := Num.f(rp["stop_width"])
	var at := node + toward * (box + Num.f(rp["stop_gap"]) + thick * 0.5)
	for off: float in [Num.f(rp["stop_inset"]), Num.f(road["half"])]:
		for ahead: float in [-1.0, 1.0]:
			var corner := at + side * off + toward * thick * 0.5 * ahead
			for other: int in ground.roads_at(corner, -1.0):
				var d: Vector2 = ground.roads[other]["dir"]
				if absf(d.cross(dir)) < PERPENDICULAR and absf(d.cross(dir)) > 0.01:
					return true
	return false


## The node where an avenue along x crosses one along z, nearest the centre (-1 if none).
static func central_junction(ground: RoadGround) -> int:
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var along_x := {}  # nodes on an avenue along x
	var along_z := {}
	for road: Dictionary in ground.roads:
		if str(road["kind"]) == CityGen.AVENUE:
			var dir: Vector2 = road["dir"]
			var into := along_x if absf(dir.y) < 0.5 else along_z
			into[road["from"]] = true
			into[road["to"]] = true
	var best := -1
	for n: int in along_x:
		if along_z.has(n) and (best < 0 or nodes[n].length() < nodes[best].length()):
			best = n
	return best


## "" when the stripe's four corners lie on one road's asphalt, out of every crossing road's.
static func _stripe_fault(ground: RoadGround, stripe: Transform3D) -> String:
	var c := Vector2(stripe.origin.x, stripe.origin.z)
	var long := Vector2(stripe.basis.z.x, stripe.basis.z.z) * 0.5
	var wide := Vector2(stripe.basis.x.x, stripe.basis.x.z) * 0.5
	var stop := false  # a stop line: square across the road under its middle
	for r: int in ground.roads_at(c, -1.0):
		var under: Vector2 = ground.roads[r]["dir"]
		stop = stop or absf(under.cross(long.normalized())) >= PERPENDICULAR
	for corner: Vector2 in [c + long + wide, c + long - wide, c - long + wide, c - long - wide]:
		var under: Dictionary = ground.at(corner)
		if not str(under["kind"]) in [RoadGround.ROAD, RoadGround.DECK]:
			return "R5 paint off the road at %s (on %s)" % [RoadGround.where(corner), under["kind"]]
		for r: int in ground.roads_at(corner, -1.0):
			var dir: Vector2 = ground.roads[r]["dir"]
			var turn := absf(dir.cross(long.normalized()))
			# A stop line lies square across its own road, so only a road not square to it is a fault.
			var bad := turn < PERPENDICULAR if stop else turn > 1.0 - PERPENDICULAR
			if bad:
				return (
					"R5 paint inside the junction at %s (a stripe %s, on the %s's asphalt)"
					% [RoadGround.where(corner), RoadGround.where(c), ground.roads[r]["kind"]]
				)
	return ""


## How far a junction box reaches along road r from `node`: the half width of a road crossing it
## square there (0 for a slanted crossing, whose asphalt is laid over everything).
static func _box(ground: RoadGround, all: Dictionary, node: int, r: int) -> float:
	var own: Vector2 = ground.roads[r]["dir"]
	var out := 0.0
	for arm: Dictionary in all.get(node, []):
		var d: Vector2 = arm["dir"]
		if absf(own.cross(d)) >= PERPENDICULAR:
			out = maxf(out, Num.f(ground.roads[Num.i(arm["road"])]["half"]))
	return out


## The point at t along road r, off its centre line to `side` (+1 or -1; 0 on it) at the asphalt
## edge moved `off` outward (negative: inward).
static func _edge(road: Dictionary, t: float, side: float, off: float) -> Vector2:
	var a: Vector2 = road["a"]
	var dir: Vector2 = road["dir"]
	var normal := Vector2(-dir.y, dir.x) * side
	var out := a + dir * t
	if side != 0.0:
		out += normal * (Num.f(road["half"]) + off)
	return out


## True when the middle of road r lies in the real city drawn at this stage.
static func _shown(ground: RoadGround, r: int) -> bool:
	var road := ground.roads[r]
	var a: Vector2 = road["a"]
	var b: Vector2 = road["b"]
	return ground.in_view((a + b) * 0.5)


static func _nearest(nodes: Array[Vector2], p: Vector2) -> int:
	var best := 0
	for n: int in nodes.size():
		if nodes[n].distance_to(p) < nodes[best].distance_to(p):
			best = n
	return best
