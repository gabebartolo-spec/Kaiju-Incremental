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


## Is a tank in the lane ahead of a car at `pos` driving along `dir` (its drawn hull, any way
## it lies)?
static func in_lane(sim: RampageSim, car: Traffic.Car, dir: Vector2) -> bool:
	var convoy: Dictionary = sim.army["convoy"]
	var hull: Array = convoy["hull"]
	for tank: RampageSim.Tank in sim.tanks:
		var front := sim.army_units.convoy.front(tank.id)
		if front == Vector2.ZERO:
			front = dir
		var side := dir.orthogonal()
		var wide := (
			Num.f(hull[0]) * 0.5 * absf(front.dot(side))
			+ Num.f(hull[1]) * 0.5 * absf(front.cross(side))
		)
		var long := (
			Num.f(hull[0]) * 0.5 * absf(front.dot(dir))
			+ Num.f(hull[1]) * 0.5 * absf(front.cross(dir))
		)
		var rel := tank.pos - car.pos
		if absf(rel.dot(side)) >= wide + LANE:
			continue
		var ahead := rel.dot(dir)
		if ahead > -long and ahead < KEEP + long:
			return true
	return false


## Does a tank's drawn hull lie over the car (a car it could not keep clear of)? Then the tank
## runs it over and the caller flattens it.
static func run_over(sim: RampageSim, car: Traffic.Car) -> bool:
	var hull: Array = sim.army["convoy"]["hull"]
	for tank: RampageSim.Tank in sim.tanks:
		var front := sim.army_units.convoy.front(tank.id)
		if front == Vector2.ZERO:
			continue
		var rel := car.pos - tank.pos
		var along := absf(rel.dot(front)) - Num.f(hull[0]) * 0.5 - CAR_HALF.x
		var across := absf(rel.dot(front.orthogonal())) - Num.f(hull[1]) * 0.5 - CAR_HALF.y
		if maxf(along, across) <= 0.0:
			return true
	return false


## A parked cruiser a tank closes on pulls back along its street (across its nose), away from
## the tank.
static func make_way(sim: RampageSim, car: Traffic.Car) -> void:
	if not car.police:
		return  # a car parked at the kerb stays, and a tank drives over it
	for tank: RampageSim.Tank in sim.tanks:
		var rel := car.pos - tank.pos
		if rel.length() >= KEEP:
			continue
		var street := car.arrive_facing.orthogonal().normalized()
		car.parked = false
		car.arrive_from = car.pos
		car.arrive_to = car.pos + (street if street.dot(rel) >= 0.0 else -street) * PULL_BACK
		car.arrive_t = 0.0
		return
