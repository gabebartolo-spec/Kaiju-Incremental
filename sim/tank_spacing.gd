class_name TankSpacing
extends RefCounted
## Tank-to-tank spacing and right of way (D-066): no tank drives, pivots or backs any part of
## itself into another; a younger tank gives way to an older one held up. A tank is what the
## view draws: its hull along its front, its turret and gun turned to the kaiju (the turret
## tracks it), each grown by `clear`. Part of Convoy; numbers are
## army.convoy (hull, turret, gun, clear, follow) in data/tuning.json.

var convoy: Convoy
var sim: RampageSim
var cfg: Dictionary


func _init(p_convoy: Convoy) -> void:
	convoy = p_convoy
	sim = convoy.sim
	cfg = convoy.cfg


## The tank in the way of a move to `next` with its hull along `dir`, or null: never into a new
## clash (out of one only by opening up), never closer than `follow` behind one going its way
## in its lane.
func blocker(tank: RampageSim.Tank, next: Vector2, dir: Vector2) -> RampageSim.Tank:
	var hull := _half("hull")
	var follow := Num.f(cfg["follow"])
	var gun: Array = cfg["gun"]
	var reach := hull.length() + Num.f(gun[0]) + follow
	var mine: ConvoyRoute = convoy.routes[tank.id]
	var own := mine.front if mine.front != Vector2.ZERO else dir
	for other: RampageSim.Tank in sim.tanks:
		var then := next.distance_to(other.pos)
		if other.id == tank.id or then > reach:
			continue
		var now := tank.pos.distance_to(other.pos)
		var o: ConvoyRoute = convoy.routes.get(other.id)
		var facing := o.front if o != null and o.front != Vector2.ZERO else dir
		if next.distance_to(tank.pos) < 0.0001:  # a pivot in place: only its hull swings
			if (
				hull_clash(next, dir, other.pos, facing)
				and not hull_clash(next, own, other.pos, facing)
			):
				return other
		elif clash(next, dir, other.pos, facing):
			if then <= now or not clash(tank.pos, own, other.pos, facing):
				return other
		var ahead := other.pos - tank.pos
		var lane := dir.dot(ahead) > 0.0 and absf(dir.cross(ahead)) < hull.y * 2.0
		if then < now and lane and then < follow and facing.dot(dir) > 0.7:
			return other
	return null


## A standing tank whose gun has swung over an older one's (the kaiju moved) steps along its own
## hull away from it, `step` at a time, while that keeps it on the road and clear of others.
func open_up(tank: RampageSim.Tank, r: ConvoyRoute, step: float) -> void:
	if r.front == Vector2.ZERO:
		return
	for other: RampageSim.Tank in sim.tanks:
		var o: ConvoyRoute = convoy.routes.get(other.id)
		if other.id >= tank.id or o == null or o.front == Vector2.ZERO:
			continue
		if not clash(tank.pos, r.front, other.pos, o.front):
			continue
		var away := r.front if r.front.dot(tank.pos - other.pos) >= 0.0 else -r.front
		var to := tank.pos + away * step
		if convoy.graph.drivable(to, r.front) and blocker(tank, to, r.front) == null:
			tank.pos = to
			r.reversing = away.dot(r.front) < 0.0
		return


## Giving way: back up while the older tank is held up (up to 3 x stuck), then wait.
func yielding(tank: RampageSim.Tank, r: ConvoyRoute, dt: float, back: float) -> void:
	r.yield_t -= dt
	for older: RampageSim.Tank in sim.tanks:
		if older.id != r.give_to:
			continue
		back_off(tank, older, back)
		var o: ConvoyRoute = convoy.routes.get(older.id)
		var held := o != null and o.stuck_t > 0.0
		if held and r.yield_t <= 0.0 and r.yield_all < Num.f(cfg["stuck"]) * 3.0:
			r.yield_t = dt
		r.yield_all += dt


## Right of way: blocked by an older tank that is itself held up trying to move, the younger
## one gives way for `stuck` seconds.
func give_way(tank: RampageSim.Tank, blocker: RampageSim.Tank, back: float) -> void:
	var o: ConvoyRoute = convoy.routes.get(blocker.id)
	if blocker.id >= tank.id or o == null or o.path.is_empty() or o.stuck_t <= 0.0:
		return
	var r: ConvoyRoute = convoy.routes[tank.id]
	r.give_to = blocker.id
	r.yield_t = Num.f(cfg["stuck"])
	back_off(tank, blocker, back)


## Straight back along its hull, away from the older tank, only while the hull stays on the road.
func back_off(tank: RampageSim.Tank, older: RampageSim.Tank, step: float) -> void:
	var o: ConvoyRoute = convoy.routes.get(older.id)
	var r: ConvoyRoute = convoy.routes[tank.id]
	if o == null or o.stuck_t <= 0.0:
		return
	var own := r.front if r.front != Vector2.ZERO else (tank.pos - older.pos).normalized()
	if not convoy.graph.square(r.front, r.edge):
		return  # half turned: it squares up first (_settle), then backs
	var back := own if own.dot(tank.pos - older.pos) > 0.0 else -own
	var to := tank.pos + back * step
	if convoy.graph.drivable(to, own) and blocker(tank, to, own) == null:
		tank.pos = to
		r.reversing = back.dot(own) < 0.0


## Do two tanks as drawn (hull along u / w, turret and gun on the kaiju), each grown by
## `clear`, touch?
func clash(p: Vector2, u: Vector2, q: Vector2, w: Vector2) -> bool:
	var mine := _boxes(p, u)
	var theirs := _boxes(q, w)
	for i: int in range(0, 9, 3):
		for j: int in range(0, 9, 3):
			var at := theirs[j]
			if boxes_overlap(mine[i], mine[i + 1], mine[i + 2], at, theirs[j + 1], theirs[j + 2]):
				return true
	return false


## Does the hull at p (along u) touch any part of the tank at q (hull along w), or its hull
## touch this tank's turret or gun? (A pivot moves only the hull: turrets track the kaiju.)
func hull_clash(p: Vector2, u: Vector2, q: Vector2, w: Vector2) -> bool:
	var mine := _boxes(p, u)
	var theirs := _boxes(q, w)
	for j: int in range(0, 9, 3):
		var at := theirs[j]
		if boxes_overlap(mine[0], mine[1], mine[2], at, theirs[j + 1], theirs[j + 2]):
			return true
	for i: int in range(3, 9, 3):
		if boxes_overlap(mine[i], mine[i + 1], mine[i + 2], theirs[0], theirs[1], theirs[2]):
			return true
	return false


## Centre, long axis and half extents, in turn, for the hull, the turret and the gun at p.
func _boxes(p: Vector2, front: Vector2) -> PackedVector2Array:
	var aim := (sim.kaiju_pos - p).normalized()
	if aim == Vector2.ZERO:
		aim = front
	var gun := _half("gun")
	return PackedVector2Array(
		[p, front, _half("hull"), p, aim, _half("turret"), p + aim * gun.x, aim, gun]
	)


func _half(part: String) -> Vector2:
	var size: Array = cfg[part]
	var clear := Num.f(cfg["clear"])
	return Vector2(Num.f(size[0]), Num.f(size[1])) * 0.5 + Vector2(clear, clear)


## Do two oriented boxes overlap (separating axes)? Centre, long axis, half extents each.
static func boxes_overlap(
	p: Vector2, u: Vector2, ha: Vector2, q: Vector2, w: Vector2, hb: Vector2
) -> bool:
	var d := q - p
	for axis: Vector2 in [u, u.orthogonal(), w, w.orthogonal()] as Array[Vector2]:
		var ra := ha.x * absf(u.dot(axis)) + ha.y * absf(u.orthogonal().dot(axis))
		var rb := hb.x * absf(w.dot(axis)) + hb.y * absf(w.orthogonal().dot(axis))
		if absf(d.dot(axis)) > ra + rb:
			return false
	return true
