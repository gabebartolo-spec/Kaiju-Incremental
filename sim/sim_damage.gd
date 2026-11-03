class_name SimDamage
extends RefCounted
## RampageSim's two damage paths, kept out of rampage_sim.gd for its line cap: an area blow
## (hit_area) and the blows on one building's chunks (damage_cells). Pure sim, no Node.


## Damages every standing chunk on floors y_lo..y_hi-1 (y_hi < 0: up to the kaiju's reach) by
## damage x force(position, own radius), force 0..1; then lets the hit buildings settle. Units have
## no hit points (D-437): a blow that reaches a tank wrecks it, thrown (throw()) when `throws` (a
## sideways hit: tail lash, tail sweep, explosion) or where it stands (a stomp, slam, crash, breath;
## director 2026-11-01: "a stomp shouldnt send it flying but a tail swipe? or a charge attack? yeah
## it should go flying"); roof squads, walking mechs and helicopters it reaches go down. hit_coat
## and hit_air widen what it does.
static func area(
	sim: RampageSim, force: Callable, damage: float, y_lo: int, y_hi: int, throws := false
) -> void:
	var top := ceili(sim.reach_height()) if y_hi < 0 else y_hi
	StrayShell.hit_buildings(sim, force, damage, Vector2i(y_lo, top))
	for tank: RampageSim.Tank in sim.tanks:
		var k: float = force.call(tank.pos, RampageSim.TANK_RADIUS)
		if k <= 0.0 or tank.flying:
			continue
		if throws:
			throw(sim, tank, force, damage * k)
		else:
			tank.last_blow = damage * k
			tank.wrecked = true  # crushed or burnt where it stands
	sim.army_units.splash(force, maxi(0, y_lo), top)  # then clears dead tanks and squads
	sim.army_units.taskforce.mechs.hit(force, damage)  # one blow that reaches a mech kills it
	var air := sim.hit_air or sim.reach_top() >= sim.air.altitude()
	sim.air.hit(force, damage, air)
	sim.army_units.taskforce.gunships.hit(force, damage, air)  # flies at the helicopters' height
	sim.rail.hit(force, damage)
	sim.vip.hit(force, damage)


## A blow of `blow` (damage x force) on a grounded tank throws it: blow_throw m per unit of blow,
## throw_min..throw_max out, away from where the blow is strongest (the force falls off that way;
## a flat force: away from the kaiju). TankFlight wrecks it where it comes down.
static func throw(sim: RampageSim, tank: RampageSim.Tank, force: Callable, blow: float) -> void:
	var cfg: Dictionary = sim.army["flight"]
	tank.last_blow = blow
	var r := RampageSim.TANK_RADIUS
	var e := r * 0.5
	var dx: float = (
		force.call(tank.pos + Vector2(e, 0.0), r) - force.call(tank.pos - Vector2(e, 0.0), r)
	)
	var dz: float = (
		force.call(tank.pos + Vector2(0.0, e), r) - force.call(tank.pos - Vector2(0.0, e), r)
	)
	var way := -Vector2(dx, dz)
	if way.length() < 0.001:
		way = tank.pos - sim.kaiju_pos
	if way == Vector2.ZERO:
		way = sim.facing
	var far := clampf(
		blow * Num.f(cfg["blow_throw"]), Num.f(cfg["throw_min"]), Num.f(cfg["throw_max"])
	)
	sim.flight.launch(tank, way, far)


## Damages chunks of one building, each by its own amount. A building that dwarfs the kaiju
## takes less of each blow (Growth.dwarf_mult, D-091). Broken chunks pay rubble; then whatever
## lost support starts to fall. Returns chunks broken. A carved building goes to Carving.
static func cells(
	sim: RampageSim, index: int, hit: Array[Vector3i], amounts: PackedFloat32Array
) -> int:
	if not hit.is_empty():
		sim.explosives.damaged(index)  # a red barrel lights its fuse at any blow
	if sim.carving.takes(index):
		return sim.carving.apply(index, hit, amounts)
	var b := sim.buildings[index]
	var mult := Growth.dwarf_mult(sim.size_tier(), b.tier, sim.city)
	var broken: Array[Vector3i] = []
	for n: int in hit.size():
		if b.frame.damage(hit[n], amounts[n] * mult):
			broken.append(hit[n])
	if broken.is_empty():
		return 0
	sim.pay(b, broken.size(), 1.0)
	sim.events.append({"type": "chunks_broken", "building": index, "cells": broken})
	sim.collapse.settle(index)
	return broken.size()
