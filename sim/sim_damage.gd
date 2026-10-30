class_name SimDamage
extends RefCounted
## RampageSim's two damage paths, kept out of rampage_sim.gd for its line cap: an area blow
## (hit_area) and the blows on one building's chunks (damage_cells). Pure sim, no Node.


## Damages every standing chunk on floors y_lo..y_hi-1 (y_hi < 0: up to the kaiju's reach), every
## tank, roof squad, walking mech and helicopter it can reach, by damage x force(position, own
## radius), force 0..1; then lets the hit buildings settle. hit_coat and hit_air widen what it does.
static func area(sim: RampageSim, force: Callable, damage: float, y_lo: int, y_hi: int) -> void:
	var top := ceili(sim.reach_height()) if y_hi < 0 else y_hi
	StrayShell.hit_buildings(sim, force, damage, Vector2i(y_lo, top))
	for tank: RampageSim.Tank in sim.tanks:
		var k: float = force.call(tank.pos, RampageSim.TANK_RADIUS)
		tank.hp -= damage * k
		if k > 0.0 and not sim.hit_coat.is_empty():
			tank.coat_t = Num.f(sim.hit_coat["seconds"])
			tank.coat_dps = Num.f(sim.hit_coat["dps"]) * Num.f(sim.powers_cfg["ink_unit_mult"])
	sim.army_units.splash(force, maxi(0, y_lo), top)  # then clears dead tanks and squads
	sim.army_units.taskforce.mechs.hit(force, damage)  # one blow that reaches a mech kills it
	sim.air.hit(force, damage, sim.hit_air or sim.reach_top() >= sim.air.altitude())
	sim.rail.hit(force, damage)
	sim.vip.hit(force, damage)


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
