extends RefCounted
## The road network of a street plan as a graph (tests/lib/road_ground.gd's roads: every street
## but the alleys, which carry no asphalt), and the rules for where roads end, cross the river and
## meet (director 2026-10-26: "we need a system to ensure that roads are intersecting with other
## roads and pavements in a natural, realistic way"). Each rule returns its violations as named
## strings with world coordinates (x, z in metres); an empty array is a pass. Only what the stage
## draws as the real city counts (RoadGround.in_view).
##   R1 every road end meets a road, a junction, a bridge deck, the sea bay or the plan's edge
##   R2 a bridge deck lands on a road of its width and axis at both ends; no road crosses open
##      water off a deck
##   R3 junctions are T or X junctions; a road keeps its width through a junction

const RoadGround := preload("res://tests/lib/road_ground.gd")
const EPS := 0.01
const COLLINEAR := 0.999  # |cos| of the angle between two arms that run on as one road
const NEAR_STRAIGHT := 0.97  # a pair this close to straight, but not quite, is a kink
const MAX_ARMS := 4  # a T has 3 roads, an X 4
const PAST := 0.25  # how far past a deck end, or a road end, the ground is read (m)
const STEP := 0.5  # sample spacing along and across a road (m)


## Per node index: its roads, each {road (index into ground.roads), dir (unit, away from the
## node)}.
static func arms(ground: RoadGround) -> Dictionary:
	var out := {}
	for r: int in ground.roads.size():
		var road := ground.roads[r]
		var dir: Vector2 = road["dir"]
		for end: Array in [[road["from"], dir], [road["to"], -dir]]:
			if not out.has(end[0]):
				out[end[0]] = []
			var list: Array = out[end[0]]
			list.append({"road": r, "dir": end[1]})
	return out


## How far a junction at `node` reaches along road r from the node: the widest crossing road's
## half width, measured along r (0 when nothing crosses it there).
static func reach_into(ground: RoadGround, all: Dictionary, node: int, r: int) -> float:
	var own: Vector2 = ground.roads[r]["dir"]
	var out := 0.0
	for arm: Dictionary in all.get(node, []):
		var d: Vector2 = arm["dir"]
		var sine := absf(own.cross(d))
		if Num.i(arm["road"]) != r and sine > 1.0 - COLLINEAR:
			out = maxf(out, Num.f(ground.roads[Num.i(arm["road"])]["half"]) / sine)
	return out


## R1: a road with nothing beyond its end, short of the plan's edge.
static func r1_dead_ends(ground: RoadGround) -> Array[String]:
	var out: Array[String] = []
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var outer := Num.f(ground.cfg["outer_half"])
	var all := arms(ground)
	for n: int in all:
		var list: Array = all[n]
		var p := nodes[n]
		if list.size() != 1 or not ground.in_view(p):
			continue
		if maxf(absf(p.x), absf(p.y)) >= outer - EPS:
			continue
		var road := ground.roads[Num.i(list[0]["road"])]
		var dir: Vector2 = list[0]["dir"]
		var beyond: Dictionary = ground.at(p - dir * (Num.f(road["half"]) + PAST))
		if _at_the_bay(ground, p, dir, Num.f(road["half"])):
			continue
		out.append(
			(
				"R1 dead end at %s: a %s %.0f m wide runs into %s"
				% [RoadGround.where(p), road["kind"], Num.f(road["half"]) * 2.0, beyond["kind"]]
			)
		)
	return out


## Whether a road ending at p (dir: along it, away from the end) runs into the sea bay's water:
## water just past its end anywhere across its carriageway (lead 2026-10-28: each street the bay
## cuts ends in a junction or at the beach).
static func _at_the_bay(ground: RoadGround, p: Vector2, dir: Vector2, half: float) -> bool:
	var across := dir.orthogonal()
	var t := -half
	while t <= half:
		var q := p - dir * (half + PAST) + across * t
		if str(ground.at(q)["kind"]) == RoadGround.HARBOUR:
			return true
		t += STEP
	return false


## R2: every deck carries a road of its own width and axis, which goes on onto the land at both
## of its ends; and no road crosses the open water off a deck.
static func r2_bridges(ground: RoadGround) -> Array[String]:
	var out: Array[String] = []
	for deck: Rect2 in ground.decks:
		var c := deck.get_center()
		if not ground.in_view(c):
			continue
		var r := _road_on(ground, deck)
		if r < 0:
			out.append(
				(
					"R2 deck at %s (%.1f m wide) carries no road of its width and axis"
					% [RoadGround.where(c), deck.size.x]
				)
			)
			continue
		for z: float in [deck.position.y - PAST, deck.end.y + PAST]:
			var bad := _lands_off(ground, deck, z, r)
			if not bad.is_empty():
				out.append(_landing(c, bad))
	out.append_array(_open_water(ground))
	return out


## A deck's bad landing, named: a bridge into a block (the director's bridge into a park, stage
## 1, seed 7301, deck x=-3, 2026-10-26) says which.
static func _landing(deck: Vector2, bad: Array) -> String:
	if str(bad[2]) != "":
		return (
			"R2 bridge into a %s: the deck at %s lands on its %s at %s"
			% [bad[2], RoadGround.where(deck), bad[0], bad[1]]
		)
	return (
		"R2 deck at %s lands on %s at %s, not on its road"
		% [RoadGround.where(deck), bad[0], bad[1]]
	)


## The road a deck carries: along z, its centre line on the deck's, as wide as the deck.
static func _road_on(ground: RoadGround, deck: Rect2) -> int:
	for r: int in ground.roads_at(deck.get_center(), 0.0):
		var road := ground.roads[r]
		var dir: Vector2 = road["dir"]
		var a: Vector2 = road["a"]
		var on_axis := absf(dir.x) < EPS and absf(a.x - deck.get_center().x) < EPS
		if on_axis and absf(Num.f(road["half"]) * 2.0 - deck.size.x) < EPS:
			return r
	return -1


## [kind, where, block use ("" off a block)] of the first point just past a deck end (across its
## width) that is not road r's own asphalt; [] when the deck lands on its road all the way across.
static func _lands_off(ground: RoadGround, deck: Rect2, z: float, r: int) -> Array:
	var x := deck.position.x + PAST
	while x <= deck.end.x - PAST + EPS:
		var p := Vector2(x, z)
		var got: Dictionary = ground.at(p)
		var kind := str(got["kind"])
		var on_road := kind in [RoadGround.ROAD, RoadGround.DECK]
		if not on_road or not _carried(ground, p, r):
			return [kind if not on_road else "another road", RoadGround.where(p), ground.use_at(p)]
		x += STEP
	return []


## True when a road of road r's width, on its centre line, holds p.
static func _carried(ground: RoadGround, p: Vector2, r: int) -> bool:
	var own := ground.roads[r]
	var a: Vector2 = own["a"]
	var dir: Vector2 = own["dir"]
	for q: int in ground.roads_at(p, 0.0):
		var road := ground.roads[q]
		var b: Vector2 = road["a"]
		var d: Vector2 = road["dir"]
		var same_line := absf((b - a).cross(dir)) < EPS and absf(d.cross(dir)) < EPS
		if same_line and absf(Num.f(road["half"]) - Num.f(own["half"])) < EPS:
			return true
	return false


## Roads whose centre line crosses open water (a river channel) where no deck carries it.
static func _open_water(ground: RoadGround) -> Array[String]:
	var out: Array[String] = []
	for road: Dictionary in ground.roads:
		var a: Vector2 = road["a"]
		var dir: Vector2 = road["dir"]
		var t := 0.0
		while t <= Num.f(road["length"]):
			var p := a + dir * t
			t += STEP
			if not ground.in_view(p) or not _wet(ground, p):
				continue
			out.append(
				(
					"R2 the %s crosses open water at %s on no bridge deck"
					% [road["kind"], RoadGround.where(p)]
				)
			)
			break
	return out


static func _wet(ground: RoadGround, p: Vector2) -> bool:
	if ground.on_deck(p):
		return false
	for w: Rect2 in ground.water:
		if w.has_point(p):
			return true
	return false


## R3 (graph): no more roads at a junction than an X has; a road that runs on through a junction
## keeps its width; no two roads nearly, but not quite, run on as one.
static func r3_junctions(ground: RoadGround) -> Array[String]:
	var out: Array[String] = []
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var all := arms(ground)
	for n: int in all:
		var list: Array = all[n]
		var p := nodes[n]
		if not ground.in_view(p):
			continue
		if list.size() > MAX_ARMS:
			out.append(
				(
					"R3 %d roads meet at %s (an X has %d)"
					% [list.size(), RoadGround.where(p), MAX_ARMS]
				)
			)
		for i: int in list.size():
			for j: int in range(i + 1, list.size()):
				var a: Dictionary = list[i]
				var b: Dictionary = list[j]
				out.append_array(_pair(ground, p, a, b))
	return out


static func _pair(ground: RoadGround, p: Vector2, a: Dictionary, b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var wa := Num.f(ground.roads[Num.i(a["road"])]["half"]) * 2.0
	var wb := Num.f(ground.roads[Num.i(b["road"])]["half"]) * 2.0
	var da: Vector2 = a["dir"]
	var db: Vector2 = b["dir"]
	var c := da.dot(db)
	if c <= -COLLINEAR and absf(wa - wb) > EPS:
		out.append(
			(
				"R3 width step at %s: a %.0f m road runs on as a %.0f m one"
				% [RoadGround.where(p), wa, wb]
			)
		)
	elif c < -NEAR_STRAIGHT and c > -COLLINEAR:
		out.append(
			"R3 kink at %s: two roads nearly, not quite, run on as one" % RoadGround.where(p)
		)
	return out
