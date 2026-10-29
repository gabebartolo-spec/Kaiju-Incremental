class_name TankFlight
extends RefCounted
## Tanks the reptilian sends flying (research 22 recs 2-4; director 2026-10-30: real flung tanks
## first, then Ricochet and Domino on them). The ram and the leap launch a tank on a ballistic arc
## that lands where today's shove put it (launch(): the distance sets the speed at loft_deg). Each
## tick it moves by exact constant-gravity kinematics; a building column standing above its hull
## is a wall: the hit carves the floors round the impact (damage per unit of speed) and the tank
## drops at the foot of it. The ground (the street, or a roof it comes down on) ends the flight.
## Ricochet (throw_ricochet, per level) gives a bounce off a wall or the ground instead of
## stopping, at wall_restitution / ground_restitution. Domino (throw_domino, per level) is chain
## depth: a flying tank that reaches a grounded one hurts it by domino_damage and launches it on
## along its own way, domino_reach out, one generation deeper. An airborne tank neither drives
## nor fires (Convoy, Army skip it); a tank left on a roof falls when the roof goes. Numbers are
## army.flight in data/tuning.json.

var sim: RampageSim
var cfg: Dictionary
## Tanks launched, walls hit and tanks knocked on by Domino this rampage (the fixtures read them).
var launched := 0
var walls_hit := 0
var knocked := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## Sends `tank` flying along `dir` to land `distance` out on open ground; chain generation `gen`.
func launch(tank: RampageSim.Tank, dir: Vector2, distance: float, gen := 0) -> void:
	if distance <= Num.f(cfg["min_distance"]) or dir == Vector2.ZERO:
		return
	var loft := deg_to_rad(Num.f(cfg["loft_deg"]))
	var g := Num.f(cfg["gravity"])
	var speed := sqrt(distance * g / sin(2.0 * loft))
	var flat := dir.normalized() * speed * cos(loft)
	tank.vel = Vector3(flat.x, speed * sin(loft), flat.y)
	tank.flying = true
	tank.bounces = 0
	tank.gen = gen
	launched += 1
	(
		sim
		. events
		. append(
			{
				"type": "tank_launched",
				"tank": tank.id,
				"from": tank.pos,
				"height": tank.height,
				"vel": tank.vel,
				"gen": gen,
			}
		)
	)


func step(dt: float) -> void:
	for tank: RampageSim.Tank in sim.tanks:
		if tank.flying:
			_fly(tank, dt)
		elif tank.height > 0.0 and sim.powers.column_top(tank.pos) < tank.height:
			tank.vel = Vector3.ZERO  # its roof is gone: it falls
			tank.flying = true


func _fly(tank: RampageSim.Tank, dt: float) -> void:
	var g := Num.f(cfg["gravity"])
	var flat := Vector2(tank.vel.x, tank.vel.z)
	var next := sim.clamp_to_arena(tank.pos + flat * dt)
	var y := tank.height + tank.vel.y * dt - 0.5 * g * dt * dt
	tank.vel.y -= g * dt
	if sim.powers.column_top(next) > y + Num.f(cfg["clearance"]):
		_wall(tank, next, y)
		next = tank.pos
	tank.pos = next
	tank.height = y
	_strike(tank)
	var ground := sim.powers.column_top(tank.pos)
	if tank.height <= ground:
		tank.height = ground
		_touch_down(tank)


## A building in the way at `next`: carve round the impact, then bounce back off it (Ricochet)
## or lose the forward speed and drop.
func _wall(tank: RampageSim.Tank, next: Vector2, y: float) -> void:
	walls_hit += 1
	var flat := Vector2(tank.vel.x, tank.vel.z)
	var radius := Num.f(cfg["wall_radius"])
	var floor_at := maxi(0, floori(y))
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(next) - r, radius),
		flat.length() * Num.f(cfg["wall_damage"]),
		floor_at,
		floor_at + Num.i(cfg["wall_floors"])
	)
	sim.events.append({"type": "tank_hit_wall", "tank": tank.id, "at": next, "height": y})
	if _bounce_left(tank):
		tank.bounces += 1
		var normal := _wall_normal(tank.pos, next, y)
		flat = (flat - 2.0 * flat.dot(normal) * normal) * Num.f(cfg["wall_restitution"])
	else:
		flat = Vector2.ZERO
	tank.vel = Vector3(flat.x, tank.vel.y, flat.y)


## Which way the wall faces: the axis whose step alone runs into it (both: straight back).
func _wall_normal(from: Vector2, next: Vector2, y: float) -> Vector2:
	var clear := Num.f(cfg["clearance"])
	var x_hits := sim.powers.column_top(Vector2(next.x, from.y)) > y + clear
	var z_hits := sim.powers.column_top(Vector2(from.x, next.y)) > y + clear
	var step := next - from
	if x_hits and not z_hits:
		return Vector2(signf(step.x), 0.0)
	if z_hits and not x_hits:
		return Vector2(0.0, signf(step.y))
	return step.normalized()


func _touch_down(tank: RampageSim.Tank) -> void:
	var fall := -tank.vel.y
	if fall > Num.f(cfg["min_bounce_speed"]) and _bounce_left(tank):
		tank.bounces += 1
		var keep := 1.0 - Num.f(cfg["ground_friction"])
		tank.vel = Vector3(
			tank.vel.x * keep, fall * Num.f(cfg["ground_restitution"]), tank.vel.z * keep
		)
		sim.events.append({"type": "tank_bounced", "tank": tank.id, "at": tank.pos})
		return
	tank.vel = Vector3.ZERO
	tank.flying = false
	sim.events.append(
		{"type": "tank_landed", "tank": tank.id, "at": tank.pos, "height": tank.height}
	)


func _bounce_left(tank: RampageSim.Tank) -> bool:
	return tank.bounces < Num.i(cfg["bounces"]) + roundi(sim.stat("throw_ricochet"))


## Domino: a grounded tank within strike_radius of a flying one of a shallower generation than the
## node's depth is hurt and knocked on along the flyer's way.
func _strike(tank: RampageSim.Tank) -> void:
	if tank.gen >= roundi(sim.stat("throw_domino")):
		return
	var reach := Num.f(cfg["strike_radius"])
	var flat := Vector2(tank.vel.x, tank.vel.z)
	for other: RampageSim.Tank in sim.tanks:
		if other == tank or other.flying or other.hp <= 0.0:
			continue
		if other.pos.distance_to(tank.pos) > reach or tank.height - other.height > reach:
			continue
		var way := flat if flat != Vector2.ZERO else other.pos - tank.pos
		other.hp -= Num.f(cfg["domino_damage"])
		knocked += 1
		sim.events.append({"type": "tank_knocked", "tank": other.id, "by": tank.id})
		if other.hp > 0.0:  # a wreck is cleared where it stands (Army.clear_dead)
			launch(other, way, Num.f(cfg["domino_reach"]), tank.gen + 1)
