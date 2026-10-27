class_name RoadGraph
extends RoadNet
## The roads tanks use (D-066), from the street plan (CityGen.map): avenues, streets and the
## diagonal, never an alley, clipped to the box round the playable city plus the entry depth.
## Also the grids that keep a hull on the carriageway and off every lot, the start of a route
## and the waypoints along one (right-hand lane on a two-lane road), and the roads a toppled
## tower closes. Part of Convoy; numbers are army.convoy in data/tuning.json.


## Room for the whole hull at p, its front along `front`: the centre no further off a road's
## centre line than the road's half width plus the sidewalk less half the hull's width, every
## corner over a road or its sidewalk, and the hull (corners and all) clear of every building lot
## (where a street runs out into an alley between buildings).
func drivable(p: Vector2, front: Vector2) -> bool:
	var hull: Array = cfg["hull"]
	var half := Vector2(Num.f(hull[0]), Num.f(hull[1])) * 0.5
	var walk := Num.f(sim.city["sidewalk"])
	if not _over_road(p, walk - half.y - 0.1):
		return false
	var side := front.orthogonal()
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			if not _over_road(p + front * half.x * sx + side * half.y * sy, walk):
				return false
	half += Vector2(0.05, 0.05)
	var ext := Vector2(
		absf(front.x) * half.x + absf(side.x) * half.y,
		absf(front.y) * half.x + absf(side.y) * half.y
	)
	var key := cell_of(p)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			for i: int in lots_at(key + Vector2i(dx, dz)):
				var b := sim.buildings[i]
				var d := Vector2(b.x, b.z) - p
				var hb := Vector2(b.w, b.d) * 0.5
				if absf(d.x) >= ext.x + hb.x or absf(d.y) >= ext.y + hb.y:
					continue
				var rf := hb.x * absf(front.x) + hb.y * absf(front.y)
				var rs := hb.x * absf(side.x) + hb.y * absf(side.y)
				if absf(d.dot(front)) < half.x + rf and absf(d.dot(side)) < half.y + rs:
					return false
	return true


## The way in for a column on `bearing`: the road entry at the city's edge on that side, or, in
## a city grown past the spawn radius, the road crossing nearest spawn_radius from the kaiju
## (D-039); never a stub too short for a hull.
func pick_entry(bearing: float, kaiju: Vector2, spawn_radius: float) -> int:
	var dir := Vector2.from_angle(bearing)
	var edge := box <= spawn_radius
	var aim := dir * box * 2.0 if edge else kaiju + dir * spawn_radius
	var pool: Array[int] = []
	pool.assign(entries if edge else PackedInt32Array(range(nodes.size())))
	var best := -1
	var best_d := INF
	for n: int in pool:
		var d := nodes[n].distance_squared_to(aim)
		if d < best_d and not links[n].is_empty() and fits(n):
			best_d = d
			best = n
	return best


## Does a hull fit at node n facing into its first road (no tank enters on a short stub)?
func fits(n: int) -> bool:
	var e := links[n][0]
	var far := edge_b[e] if edge_a[e] == n else edge_a[e]
	return drivable(nodes[n], (nodes[far] - nodes[n]).normalized())


func _over_road(p: Vector2, spare: float) -> bool:
	for e: int in roads_at(cell_of(p)):
		if off_line(p, e) <= edge_half[e] + spare:
			return true
	return false


## The road nearest p (the one it is on when `edge` still holds it).
func road_under(p: Vector2, edge: int) -> int:
	if edge >= 0 and on_edge(p, edge):
		return edge
	var near: Array[int] = []
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			for k: int in roads_at(cell_of(p) + Vector2i(dx, dz)):
				near.append(k)
	if near.is_empty():  # far off the plan: every road
		near.assign(range(edge_a.size()))
	var best := -1
	var best_d := INF
	for k: int in near:
		var d := off_line(p, k)
		if d < best_d:
			best_d = d
			best = k
	return best


## The waypoints from `from` along `chain` (roads, from start node n) to `at` on road `last`:
## [path, legs]. On a road wide enough for two lanes it keeps right of the centre line (each
## waypoint moves right of the way it arrives), so columns going opposite ways pass each other.
func waypoints(from: Vector2, start: Dictionary, chain: Array[int], goal: Dictionary) -> Array:
	var raw := _raw_path(from, start, chain, goal)
	var path: Array[Vector2] = raw[0]
	var legs: Array[int] = raw[1]
	var last := from
	var sharp := cos(deg_to_rad(Num.f(cfg["pivot_deg"])))
	var lead := Num.f(cfg["follow"])
	var out: Array[Vector2] = []
	var out_legs: Array[int] = []
	for i: int in path.size():
		var centre := path[i]
		var e := legs[i]
		var d := (centre - last).normalized()
		var span := centre.distance_to(last)
		if i + 1 < path.size() and d.dot((path[i + 1] - centre).normalized()) < sharp:
			if span > lead * 1.5:  # a sharp turn ahead: ease to the crown, turn standing there
				out.append(centre - d * lead)
				out_legs.append(e)
			out.append(centre)
		elif e >= 0 and edge_lane[e] > 0.0 and span > 0.01:
			out.append(centre + Vector2(-d.y, d.x) * edge_lane[e])
		else:
			out.append(centre)
		out_legs.append(e)
		last = centre
	_square_legs(from, Num.i(start["edge"]), out, out_legs)
	return [out, out_legs]


## The crowns along `chain` (roads, from start node n) to the goal on its road, and the road each
## runs on, less any already within reach of `from`: [path, legs].
func _raw_path(from: Vector2, start: Dictionary, chain: Array[int], goal: Dictionary) -> Array:
	var path: Array[Vector2] = []
	var legs: Array[int] = []
	var n := Num.i(start["node"])
	if n >= 0:
		path.append(nodes[n])
		legs.append(Num.i(start["edge"]))
		for e: int in chain:
			n = edge_b[e] if edge_a[e] == n else edge_a[e]
			path.append(nodes[n])
			legs.append(e)
	path.append(goal["at"])
	legs.append(Num.i(goal["edge"]))
	while not path.is_empty() and path[0].distance_to(from) < 0.05:  # already there
		path.remove_at(0)
		legs.remove_at(0)
	return [path, legs]


## Draws each waypoint in so the leg to it runs within skew_deg of its road's axis: a tank set off
## from a post near the kerb drifts back across the road as it drives, never crabbing down a
## diagonal. A leg that cannot (it would cut a corner) turns the corner square instead: along the
## road the tank is on to the crossing, a pivot there, then along the next road.
func _square_legs(from: Vector2, on: int, out: Array[Vector2], out_legs: Array[int]) -> void:
	var slope := tan(deg_to_rad(Num.f(cfg["skew_deg"])))
	var cur := from
	var was := on
	var i := 0
	while i < out.size():
		var e := out_legs[i]
		if e >= 0:
			var a := axis(e)
			var v := out[i] - cur
			var cap := absf(v.dot(a)) * slope
			var to := cur + a * v.dot(a) + a.orthogonal() * clampf(v.dot(a.orthogonal()), -cap, cap)
			if off_line(to, e) <= _room(e):
				out[i] = to
			elif was >= 0 and absf(axis(was).cross(a)) > 0.5:
				var corner := (
					cur + axis(was) * (nodes[edge_a[e]] - cur).cross(a) / axis(was).cross(a)
				)
				if off_line(corner, was) <= _room(was) and off_line(corner, e) <= _room(e):
					out.insert(i, corner)
					out_legs.insert(i, was)
					e = was
			was = e
		cur = out[i]
		i += 1


## The point `to` drawn in so the leg from `from` runs within skew_deg of road e's axis (as
## _square_legs), or `to` itself when that would leave the road.
func square_leg(from: Vector2, to: Vector2, e: int) -> Vector2:
	if e < 0:
		return to
	var a := axis(e)
	var v := to - from
	var cap := absf(v.dot(a)) * tan(deg_to_rad(Num.f(cfg["skew_deg"])))
	var side := v.dot(a.orthogonal())
	if absf(side) <= cap:
		return to
	var drawn := from + a * v.dot(a) + a.orthogonal() * clampf(side, -cap, cap)
	return drawn if off_line(drawn, e) <= _room(e) else to


## Does a hull pointing along `front` lie along road e (within skew_deg)? Any way off a road.
func square(front: Vector2, e: int) -> bool:
	var tilt := absf(front.cross(axis(e))) if e >= 0 else 0.0
	return tilt <= sin(deg_to_rad(Num.f(cfg["skew_deg"])))


## How far off road e's centre line a hull's centre may stand.
func _room(e: int) -> float:
	var hull: Array = cfg["hull"]
	return edge_half[e] + Num.f(sim.city["sidewalk"]) - Num.f(hull[1]) * 0.5 - 0.1


## Closes the roads under every tower that toppled this step (fall_land topple events). True
## when one closed.
func read_rubble(events: Array[Dictionary]) -> bool:
	var closed := false
	for event: Dictionary in events:
		if str(event["type"]) != "fall_land" or str(event.get("kind", "")) != "topple":
			continue
		if event.get("scrap", false) == true:  # a carved scrap blocks no road
			continue
		var from: Vector2 = event["from"]
		var to: Vector2 = event["to"]
		closed = close_strip(from, to, Num.f(event["width"])) or closed
	return closed


## Closes every open road within reach of a fallen strip (from -> to, `width` across) plus half
## a hull. True when one closed.
func close_strip(from: Vector2, to: Vector2, width: float) -> bool:
	var hull: Array = cfg["hull"]
	var within := width * 0.5 + Num.f(hull[1]) * 0.5
	var closed := false
	for e: int in edge_a.size():
		if blocked[e] == 0 and _near(nodes[edge_a[e]], nodes[edge_b[e]], from, to) < within:
			blocked[e] = 1
			closed = true
	return closed


static func _near(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	var best := minf(
		Geometry2D.get_closest_point_to_segment(a, c, d).distance_to(a),
		Geometry2D.get_closest_point_to_segment(b, c, d).distance_to(b)
	)
	best = minf(best, Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c))
	return minf(best, Geometry2D.get_closest_point_to_segment(d, a, b).distance_to(d))
