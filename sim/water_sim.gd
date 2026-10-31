class_name WaterSim
extends RefCounted
## The city's water as a liquid (director 2026-10-31: "make the water a real physical thing ...
## make it act like water should"; "real splash physics reacting dynamically to things which
## disturb the water"): the bay and the river are each a grid of water columns (tuning
## "water_sim" "cell" metres square) on the sim's own floor (CityHarbour.floor_at, the river's
## channel bed), moved by the shallow-water equations as virtual pipes between neighbouring
## columns: water runs downhill from a higher surface to a lower one, so a push makes a real wave
## that travels at the speed its depth gives it (sqrt(g * depth)), slows and steepens over the
## shelf, bounces off the quays and banks, runs up the sand and drains back. Nothing is added or
## lost: each column holds its depth of water and the pipes only move it.
##
## What disturbs it: the kaiju's body (its submerged column stands in the water, so where it
## walks it lifts the surface ahead of it and the water closes in behind: a bow wave and a wake),
## each stomp in the water and the rise from the sea (a volume thrown out of a disc onto its rim:
## a crater and a ring wave, with a splash event for the spray), and anything else through
## disturb(). Only an active window round the disturbance is stepped (the rest is at rest); it
## grows with the waves and sleeps once they die down (tuning friction). Fire is untouched: the
## water's puts-out stays where it was.

const G := 9.8
const SPLASHES_KEPT := 16
const WALL := 1000.0  # a floor this far over the surface: never wet


## One body of water (the bay, the river): a grid of columns.
class Basin:
	var origin: Vector2  # world (x, z) of cell (0, 0)'s corner
	var cell := 1.0
	var nx := 0
	var nz := 0
	var rest := 0.0  # the still surface (world y)
	var floor_y := PackedFloat32Array()  # each column's bed (world y)
	var depth := PackedFloat32Array()  # its water (m)
	var body := PackedFloat32Array()  # metres of the kaiju's body standing in it
	var flow := PackedFloat32Array()  # 4 per column: outflow right, left, down (+z), up (-z), m^2/s
	var active := Rect2i()  # the stepped columns (empty: all at rest)
	var focus := Vector2i()  # the latest push's column: a window too big is kept round it

	func _init(p_origin: Vector2, p_cell: float, p_n: Vector2i, p_rest: float) -> void:
		origin = p_origin
		cell = p_cell
		nx = p_n.x
		nz = p_n.y
		rest = p_rest
		floor_y.resize(nx * nz)
		depth.resize(nx * nz)
		body.resize(nx * nz)
		flow.resize(nx * nz * 4)

	## The surface's height over the still water at column k (under the bed when dry).
	func lift(k: int) -> float:
		return floor_y[k] + depth[k] + body[k] - rest

	func at(p: Vector2) -> Vector2i:
		return Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / cell))

	func centre(c: Vector2i) -> Vector2:
		return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell

	func size() -> Vector2:
		return Vector2(nx, nz) * cell

	func wake(rect: Rect2i) -> void:
		var r := rect.intersection(Rect2i(0, 0, nx, nz))
		if r.has_area():
			active = r if not active.has_area() else active.merge(r)
			focus = r.get_center()


var basins: Array[Basin] = []
## Splashes this step, for the view's spray: {"pos": Vector3, "size": metres}.
var splashes: Array[Dictionary] = []
var _cfg: Dictionary
var _surfaced := false
var _ripple := 0.0  # seconds to the next ripple while the body holds under
var _r := Rect2i()  # the sub-step being taken: its window, length (s) and flow kept
var _h := 0.0
var _keep := 1.0


func _init(city: Dictionary, tuning: Dictionary) -> void:
	_cfg = tuning["water_sim"]
	var plan := CityGen.map(city)
	var cell := Num.f(_cfg["cell"])
	if plan.has("harbour"):
		basins.append(_bay(plan, city, cell))
	var channels := CityRiver.channels(plan, city)
	if not channels.is_empty():
		basins.append(_river(channels, city, cell))


## The bay: the harbour from its mouth to run_up metres up the beach (the floor decides the rest:
## the street and the quays stand over the water, so they are its walls).
static func _bay(plan: Dictionary, city: Dictionary, cell: float) -> Basin:
	var b: Dictionary = plan["harbour"]
	var rect: Rect2 = b["rect"]
	var far := Num.f(b["quay_z"])
	for p: Vector2 in CityHarbour.arc(plan, city):
		far = maxf(far, p.y)
	var z0 := Num.f(b["mouth"])
	var basin := Basin.new(
		Vector2(rect.position.x, z0),
		cell,
		Vector2i(ceili(rect.size.x / cell), ceili((far - z0) / cell) + 1),
		CityHarbour.sea(city)
	)
	for k: int in basin.nx * basin.nz:
		var p := basin.centre(Vector2i(k % basin.nx, k / basin.nx))
		var bed := CityHarbour.floor_at(plan, city, p) if CityHarbour.holds(plan, p) else WALL
		basin.floor_y[k] = bed
		basin.depth[k] = maxf(0.0, basin.rest - bed)
	return basin


## The river: every channel's bed (city river_depth + wade_depth under the street), the banks
## between them walls.
static func _river(channels: Array[Rect2], city: Dictionary, cell: float) -> Basin:
	var whole := channels[0]
	for c: Rect2 in channels:
		whole = whole.merge(c)
	var rest := -Num.f(city["river_depth"])
	var bed := rest - Num.f(city["wade_depth"])
	var basin := Basin.new(
		whole.position, cell, Vector2i(ceili(whole.size.x / cell), ceili(whole.size.y / cell)), rest
	)
	for k: int in basin.nx * basin.nz:
		var p := basin.centre(Vector2i(k % basin.nx, k / basin.nx))
		var wet := channels.any(func(c: Rect2) -> bool: return c.has_point(p))
		basin.floor_y[k] = bed if wet else WALL
		basin.depth[k] = rest - bed if wet else 0.0
	return basin


## The basin holding p, or null.
func basin_at(p: Vector2) -> Basin:
	for basin: Basin in basins:
		var c := basin.at(p)
		if c.x >= 0 and c.y >= 0 and c.x < basin.nx and c.y < basin.nz:
			if basin.floor_y[c.y * basin.nx + c.x] < basin.rest:
				return basin
	return null


## The surface's height at p (world y), or NAN where there is no water.
func surface_at(p: Vector2) -> float:
	var basin := basin_at(p)
	if basin == null:
		return NAN
	var c := basin.at(p)
	return basin.rest + basin.lift(c.y * basin.nx + c.x)


## Throws `volume` cubic metres of water out of the disc of `radius` at p onto its rim (a stomp,
## a body falling in, the rise): a crater that the water rushes back into, and a ring wave.
## Returns false where there is no water.
func disturb(p: Vector2, volume: float, radius: float) -> bool:
	var basin := basin_at(p)
	if basin == null:
		return false
	var reach := radius * Num.f(_cfg["rim"])
	var c := basin.at(p)
	var n := ceili(reach / basin.cell) + 1
	var rings := _rings(basin, p, Vector2(radius, reach))
	var inner: Array[int] = rings[0]
	var rim: Array[int] = rings[1]
	if inner.is_empty():
		return false
	var area := basin.cell * basin.cell
	var taken := 0.0
	var each := volume / (area * inner.size())
	for k: int in inner:
		var out := minf(each, basin.depth[k])
		basin.depth[k] -= out
		taken += out * area
	if rim.is_empty():
		rim = inner
	for k: int in rim:
		basin.depth[k] += taken / (area * rim.size())
	basin.wake(Rect2i(c - Vector2i(n, n), Vector2i(n, n) * 2 + Vector2i.ONE))
	return true


## The wet columns round p: [those within reach.x, those beyond it out to reach.y].
static func _rings(basin: Basin, p: Vector2, reach: Vector2) -> Array:
	var inner: Array[int] = []
	var rim: Array[int] = []
	var c := basin.at(p)
	var n := ceili(reach.y / basin.cell) + 1
	for j: int in range(maxi(0, c.y - n), mini(basin.nz, c.y + n + 1)):
		for i: int in range(maxi(0, c.x - n), mini(basin.nx, c.x + n + 1)):
			var k := j * basin.nx + i
			if basin.depth[k] <= 0.0:
				continue
			var d := basin.centre(Vector2i(i, j)).distance_to(p)
			if d <= reach.x:
				inner.append(k)
			elif d <= reach.y:
				rim.append(k)
	return [inner, rim]


## One step: the kaiju's body stands in the water; its stomps and the rise throw it; the water
## flows. events: the sim's events this step (read for "stomp").
func step(sim: RampageSim, dt: float, events: Array[Dictionary]) -> void:
	# the view takes them each frame; a headless run keeps the last
	if splashes.size() > SPLASHES_KEPT:
		splashes = splashes.slice(-SPLASHES_KEPT)
	_stand(sim)
	var bs := sim.body_scale()
	for event: Dictionary in events:
		if str(event["type"]) != "stomp":
			continue
		var p: Vector2 = event["at"]
		var r := Num.f(event["radius"]) * Num.f(_cfg["stomp_share"])
		if disturb(p, Num.f(_cfg["stomp_volume"]) * bs * bs * bs, r):
			splashes.append({"pos": Vector3(p.x, surface_at(p), p.y), "size": r})
	if sim.emerge.active and not sim.emerge.surfaced:  # it holds under: rings spread from over it
		_ripple -= dt
		if _ripple <= 0.0:
			_ripple += Num.f(_cfg["ripple_seconds"])
			var r := Num.f(_cfg["rise_radius"]) * bs * 0.5
			disturb(sim.kaiju_pos, Num.f(_cfg["ripple_volume"]) * bs * bs * bs, r)
	if sim.emerge.surfaced and not _surfaced:  # the body breaks the surface: the fountain
		var p := sim.kaiju_pos
		var r := Num.f(_cfg["rise_radius"]) * bs
		if disturb(p, Num.f(_cfg["rise_volume"]) * bs * bs * bs, r):
			splashes.append({"pos": Vector3(p.x, surface_at(p), p.y), "size": r})
	_surfaced = sim.emerge.surfaced
	for basin: Basin in basins:
		_flow(basin, dt)


## Puts the kaiju's submerged body into the columns it stands in (an upright column of
## water_sim body_radius times its height, from where it stands up to the still surface).
func _stand(sim: RampageSim) -> void:
	var radius := Num.f(_cfg["body_radius"]) * sim.reach_height()
	var p := sim.kaiju_pos
	for basin: Basin in basins:
		var c := basin.at(p)
		var n := ceili(radius / basin.cell) + 1
		var near := Rect2i(c - Vector2i(n, n), Vector2i(n, n) * 2 + Vector2i.ONE)
		var span := near.merge(basin.active) if basin.active.has_area() else near
		span = span.intersection(Rect2i(0, 0, basin.nx, basin.nz))
		var moved := false
		for j: int in range(span.position.y, span.end.y):
			for i: int in range(span.position.x, span.end.x):
				var k := j * basin.nx + i
				var share := (
					1.0
					- smoothstep(radius * 0.6, radius, basin.centre(Vector2i(i, j)).distance_to(p))
				)
				var foot := maxf(basin.floor_y[k], sim.stand_y)
				var want := share * maxf(0.0, basin.rest - foot) if basin.depth[k] > 0.0 else 0.0
				if absf(want - basin.body[k]) > 0.0001:
					basin.body[k] = want
					moved = true
		if moved:
			basin.wake(near)


## The virtual pipes: each column pushes water into each lower neighbour (g * its depth * the
## surface drop over a cell, kept by friction), never more than it holds; then every column
## takes in what flowed to it. Sub-stepped so a wave never crosses more than a share of a cell.
func _flow(basin: Basin, dt: float) -> void:
	if not basin.active.has_area():
		return
	# The window spreads a column a step each way (waves outrun it only where they are already
	# small), up to water_sim window metres a side.
	var most := ceili(Num.f(_cfg["window"]) / basin.cell)
	var r := basin.active.grow(1)
	if r.size.x > most:
		r.position.x = clampi(basin.focus.x - most / 2, r.position.x, r.end.x - most)
		r.size.x = most
	if r.size.y > most:
		r.position.y = clampi(basin.focus.y - most / 2, r.position.y, r.end.y - most)
		r.size.y = most
	r = r.intersection(Rect2i(0, 0, basin.nx, basin.nz))
	basin.active = r
	var deepest := 0.0
	for j: int in range(r.position.y, r.end.y):
		for i: int in range(r.position.x, r.end.x):
			deepest = maxf(deepest, basin.depth[j * basin.nx + i])
	var speed := sqrt(G * maxf(deepest, 0.01))
	var subs := maxi(1, ceili(speed * dt / (basin.cell * Num.f(_cfg["courant"]))))
	var h := dt / subs
	var keep := maxf(0.0, 1.0 - Num.f(_cfg["friction"]) * h)
	var stir := 0.0
	for s: int in subs:
		stir = _pipes(basin, r, h, keep)
	if stir < Num.f(_cfg["calm"]):
		_settle(basin, r)


## One sub-step over r (its edge a wall: nothing leaks out of the window); returns the biggest
## surface lift left in it (m).
func _pipes(basin: Basin, r: Rect2i, h: float, keep: float) -> float:
	_r = r
	_h = h
	_keep = keep
	var top := basin.floor_y.duplicate()
	for j: int in range(r.position.y, r.end.y):
		for k: int in range(j * basin.nx + r.position.x, j * basin.nx + r.end.x):
			top[k] += basin.depth[k] + basin.body[k]
	for j: int in range(r.position.y, r.end.y):
		for i: int in range(r.position.x, r.end.x):
			_outflow(basin, top, i, j)
	return _drain(basin)


## Column (i, j)'s four outflows this sub-step, pushed by the surface drop to each neighbour.
func _outflow(basin: Basin, top: PackedFloat32Array, i: int, j: int) -> void:
	var nx := basin.nx
	var f := basin.flow
	var k := j * nx + i
	var dk := basin.depth[k]
	var e := k * 4
	if dk <= 0.0:
		for o: int in 4:
			f[e + o] = 0.0
		return
	var t := top[k]
	var a := _h * G / basin.cell * dk
	var x1 := _r.end.x - 1
	var y1 := _r.end.y - 1
	var qr := maxf(0.0, f[e] * _keep + a * (t - top[k + 1])) if i < x1 else 0.0
	var ql := maxf(0.0, f[e + 1] * _keep + a * (t - top[k - 1])) if i > _r.position.x else 0.0
	var qd := maxf(0.0, f[e + 2] * _keep + a * (t - top[k + nx])) if j < y1 else 0.0
	var qu := maxf(0.0, f[e + 3] * _keep + a * (t - top[k - nx])) if j > _r.position.y else 0.0
	var out := (qr + ql + qd + qu) * _h
	var scale := 1.0
	if out > dk * basin.cell:  # never more than it holds
		scale = dk * basin.cell / out
	f[e] = qr * scale
	f[e + 1] = ql * scale
	f[e + 2] = qd * scale
	f[e + 3] = qu * scale


## Moves the sub-step's flows into the columns; returns the biggest surface lift left (m).
func _drain(basin: Basin) -> float:
	var nx := basin.nx
	var f := basin.flow
	var d := basin.depth
	var x0 := _r.position.x
	var x1 := _r.end.x - 1
	var y0 := _r.position.y
	var y1 := _r.end.y - 1
	var gain := _h / basin.cell
	var stir := 0.0
	for j: int in range(y0, y1 + 1):
		for i: int in range(x0, x1 + 1):
			var k := j * nx + i
			var e := k * 4
			var net := -(f[e] + f[e + 1] + f[e + 2] + f[e + 3])
			if i > x0:
				net += f[e - 4]  # the left neighbour's right pipe
			if i < x1:
				net += f[e + 5]  # the right neighbour's left pipe
			if j > y0:
				net += f[e - nx * 4 + 2]
			if j < y1:
				net += f[e + nx * 4 + 3]
			if net == 0.0 and d[k] <= 0.0:
				continue
			d[k] = maxf(0.0, d[k] + gain * net)
			if d[k] > 0.0:
				stir = maxf(stir, absf(basin.floor_y[k] + d[k] - basin.rest))
	return stir


## The window has gone still: back to rest, asleep until the next push.
func _settle(basin: Basin, r: Rect2i) -> void:
	for j: int in range(r.position.y, r.end.y):
		for i: int in range(r.position.x, r.end.x):
			var k := j * basin.nx + i
			if basin.body[k] > 0.0:
				return  # he still stands in it
	for j: int in range(r.position.y, r.end.y):
		for i: int in range(r.position.x, r.end.x):
			var k := j * basin.nx + i
			for e: int in 4:
				basin.flow[k * 4 + e] = 0.0
	basin.active = Rect2i()
