class_name ConvoyLeg
extends RefCounted
## The next leg of a tank's drive (Convoy._drive): which way and how far to its waypoint, how
## fast (backing off, or out fast from the kaiju's feet), and how far the hull turns and steps
## this tick. Built once per tank per step; stopper() and advance() finish the leg.

var dir := Vector2.ZERO  ## to the waypoint (the hull's front when it is on it)
var dist := 0.0  ## to the waypoint
var want := Vector2.ZERO  ## where the hull should point: dir, or its reverse when backing
var turn := 0.0  ## the turn from the hull's front to want
var rate := 0.0  ## the most the hull may turn this tick
var front := Vector2.ZERO  ## the hull's front after this tick's turn
var move := 0.0  ## how far it drives this tick (0 while it is still squaring up)
var next := Vector2.ZERO  ## where that puts it
var _convoy: Convoy
var _r: ConvoyRoute


func _init(convoy: Convoy, tank: RampageSim.Tank, r: ConvoyRoute, dt: float) -> void:
	_convoy = convoy
	_r = r
	var to := r.path[0] - tank.pos
	dist = to.length()
	dir = to / dist if dist > 0.0001 else r.front
	var speed := _pace(tank)
	want = -dir if r.reversing else dir
	r.front = want if r.front == Vector2.ZERO else r.front
	turn = r.front.angle_to(want)
	rate = convoy.hull_rate(dt)
	front = r.front.rotated(clampf(turn, -rate, rate))
	move = 0.0 if absf(turn) > rate else minf(dist, speed * dt)  # squared first, then on
	next = tank.pos + dir * move


## At the waypoint already, bar the turn: the last metre is not worth one.
func arrives() -> bool:
	return dist <= 1.0 and absf(turn) > rate


## Short of the standoff line: it brakes there, never across it.
func brakes() -> bool:
	if _r.retreating or move <= 0.0:
		return false
	return _convoy.posts.to_body(next) < _convoy.danger()


## What holds this leg up: the tank in the way, the tank itself when the hull would leave the
## road or the turn has no room, or null.
func stopper(tank: RampageSim.Tank) -> RampageSim.Tank:
	var graph := _convoy.graph
	var blocker := _convoy.spacing.blocker(tank, next, front)
	var fits := (
		graph.drivable(next, front) and (move > 0.0 or _convoy.sweep_fits(tank, tank.pos, want))
	)
	if blocker == null and not fits and graph.drivable(tank.pos, _r.front):
		return tank
	return blocker


## Drives the leg: the hull turned, the tank moved, on to the next waypoint when it is there.
func advance(tank: RampageSim.Tank) -> void:
	_r.stuck_t = 0.0
	_r.heading = dir
	_r.front = front
	tank.pos = next
	if not _r.edges.is_empty() and _r.edges[0] >= 0:
		_r.edge = _r.edges[0]
	if move > 0.0 and move >= dist - 0.0001 or dist <= 0.0001:
		_r.arrive()


## Its speed along the leg: backing up rather than turning tail, slower; out fast and then slow
## when it retreats.
func _pace(tank: RampageSim.Tank) -> float:
	var cfg := _convoy.cfg
	var speed := Num.f(_convoy.sim.army["speed"])
	var behind := _r.front.dot(dir) < (0.0 if _r.retreating else -0.5)  # back off, never turn tail
	var clear_of := _r.retreating and _convoy.posts.to_body(tank.pos) < _convoy.danger()
	if behind and _r.front != Vector2.ZERO:  # and back up rather than turn about in the road
		_r.reversing = true
		speed = Num.f(cfg["retreat_speed"]) if clear_of else speed * Num.f(cfg["reverse"])
	elif clear_of:
		speed = maxf(speed, Num.f(cfg["retreat_speed"]))
	return speed
