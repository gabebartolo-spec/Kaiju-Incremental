class_name TankSpacing
extends RefCounted
## Tank-to-tank spacing (D-066): no tank drives, pivots or backs any part of itself into
## another. A tank is what the view draws: its hull along its front, its turret and gun turned to
## the kaiju (the turret tracks it), each grown by `clear`. Part of Convoy; numbers are
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
		if clash(next, dir, other.pos, facing):
			if then <= now or not clash(tank.pos, own, other.pos, facing):
				return other
		var ahead := other.pos - tank.pos
		var lane := dir.dot(ahead) > 0.0 and absf(dir.cross(ahead)) < hull.y * 2.0
		if then < now and lane and then < follow and facing.dot(dir) > 0.7:
			return other
	return null


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
