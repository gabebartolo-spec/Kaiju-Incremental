class_name TankKeepOut
extends RefCounted
## Cars keep out of the tanks' way (D-066): a car stops short of a tank in its lane (then turns
## round, as behind any hold-up), and a parked police cruiser a tank closes on pulls back along
## its street. Presentation only: the sim's tanks never see a car. Part of Traffic.

## How near (m, centre to centre) a car comes to a tank ahead in its lane, or a tank to a parked
## cruiser before it pulls back.
const KEEP := 6.5
const LANE := 0.8  # beyond the hull's side, how far a car's lane still meets it (half a car + room)
const PULL_BACK := 9.0  # how far a cruiser pulls back
const CAR_HALF := Vector2(1.0, 0.5)  # a car as drawn, half length x half width (m)


## The tanks' positions and facings, read once a frame for every car's checks. `reach` bounds
## how far (centre to centre) a tank can be and still matter to a car.
class Poses:
	extends RefCounted
	var pos := PackedVector2Array()
	var front := PackedVector2Array()
	var length := 0.0
	var width := 0.0
	var reach := 0.0

	func _init(sim: RampageSim) -> void:
		var hull: Array = sim.army["convoy"]["hull"]
		length = Num.f(hull[0])
		width = Num.f(hull[1])
		reach = (length + width) * 0.5 + KEEP + LANE + CAR_HALF.x + CAR_HALF.y
		for tank: RampageSim.Tank in sim.tanks:
			pos.append(tank.pos)
			front.append(sim.army_units.convoy.front(tank.id))


## Is a tank in the lane ahead of a car at `pos` driving along `dir` (its drawn hull, any way
## it lies)?
static func in_lane(tanks: Poses, car: Traffic.Car, dir: Vector2) -> bool:
	var side := dir.orthogonal()
	var reach2 := tanks.reach * tanks.reach
	for i: int in tanks.pos.size():
		var rel := tanks.pos[i] - car.pos
		if rel.length_squared() > reach2:
			continue
		var front := tanks.front[i]
		if front == Vector2.ZERO:
			front = dir
		var wide := (
			tanks.length * 0.5 * absf(front.dot(side)) + tanks.width * 0.5 * absf(front.cross(side))
		)
		var long := (
			tanks.length * 0.5 * absf(front.dot(dir)) + tanks.width * 0.5 * absf(front.cross(dir))
		)
		if absf(rel.dot(side)) >= wide + LANE:
			continue
		var ahead := rel.dot(dir)
		if ahead > -long and ahead < KEEP + long:
			return true
	return false


## Does a tank's drawn hull lie over the car (a car it could not keep clear of)? Then the tank
## runs it over and the caller flattens it.
static func run_over(tanks: Poses, car: Traffic.Car) -> bool:
	var reach2 := tanks.reach * tanks.reach
	for i: int in tanks.pos.size():
		var front := tanks.front[i]
		if front == Vector2.ZERO:
			continue
		var rel := car.pos - tanks.pos[i]
		if rel.length_squared() > reach2:
			continue
		var along := absf(rel.dot(front)) - tanks.length * 0.5 - CAR_HALF.x
		var across := absf(rel.dot(front.orthogonal())) - tanks.width * 0.5 - CAR_HALF.y
		if maxf(along, across) <= 0.0:
			return true
	return false


## A parked cruiser a tank closes on pulls back along its street (across its nose), away from
## the tank.
static func make_way(tanks: Poses, car: Traffic.Car) -> void:
	if not car.police:
		return  # a car parked at the kerb stays, and a tank drives over it
	for tank_pos: Vector2 in tanks.pos:
		var rel := car.pos - tank_pos
		if rel.length() >= KEEP:
			continue
		var street := car.arrive_facing.orthogonal().normalized()
		car.parked = false
		car.arrive_from = car.pos
		car.arrive_to = car.pos + (street if street.dot(rel) >= 0.0 else -street) * PULL_BACK
		car.arrive_t = 0.0
		return
