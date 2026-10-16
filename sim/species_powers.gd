class_name SpeciesPowers
extends RefCounted
## The species branches of the upgrade tree as simulation (docs/SPECIES.md): each power is
## off until its node is bought (its stat is 0) and grows with every level. Part of
## RampageSim; split out to keep files small. Pure and seeded.
##   Reptilian: tail sweep on a hard turn, momentum on a straight line, Atomic Beam.
##   Insectoid: glide after a leap while the button is held, climbing (Brood is in Brood).
##   Cephalopod: squeezing through gaps, Corrosive Ink (limbs, grab and throw: Tentacles).
## Shared: buildings block the body (slow it) unless a power says otherwise, and coatings
## (beam fire, ink) that eat chunks and units over time.

## A chunk is one sim unit across: its centre is this far from its faces.
const CHUNK_HALF := 0.5

var sim: RampageSim
var cfg: Dictionary
## 0..1: how much straight-line speed the reptilian has built.
var momentum := 0.0
var beam_left := 0.0
var glide_left := 0.0
## Coated chunks, key building * 2^20 + chunk index: {"b", "c", "t", "dps", "kind"}.
var coats: Dictionary = {}
## The cephalopod's limbs: hydra strikes, grab and throw (Tentacles).
var tentacles: Tentacles
var tail_sweeps := 0
## Chunks broken by tail sweeps themselves (not what falls after).
var tail_cut := 0
var _rng: RandomNumberGenerator
var _turn := 0.0
var _tail_cd := 0.0
var _ram_cd := 0.0
var _glide_armed := false


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = sim.powers_cfg
	_rng = rng
	tentacles = Tentacles.new(sim, rng)


func _bs() -> float:
	return sim.body_scale()


## --- Movement: blocking, momentum, climbing --------------------------------------------


## Speed multiplier this step: buildings in the way slow the body, except when it climbs
## over them, glides above them, squeezes between them or has the momentum to ram on.
func speed_mult() -> float:
	if beam_left > 0.0:
		return Num.f(cfg["beam_move_mult"])
	if sim.airborne:
		return Num.f(cfg["glide_speed_mult"])
	var mult := 1.0 + momentum * Num.f(cfg["momentum_speed"]) if sim.stat("momentum") > 0.0 else 1.0
	if sim.stat("climb") > 0.0:
		return mult
	if blocked(sim.kaiju_pos, block_radius()):
		var slow := Num.f(cfg["block_slow"])
		if sim.stat("momentum") > 0.0:
			slow = lerpf(slow, 1.0, momentum)
		mult *= slow
	return mult


## The body's footprint for being held up by buildings. It does not grow with the kaiju, and
## it stays narrower than a street (block_street_margin inside half its width): a grown kaiju
## strides down any street and only the walls it walks into hold it back. It is wider than
## an alley, so alleys hold it, unless Squeeze shrinks it.
func block_radius() -> float:
	var street := Num.f(sim.city["street_width"]) * 0.5 - Num.f(cfg["block_street_margin"])
	var squeeze := 1.0 - clampf(sim.stat("squeeze"), 0.0, Num.f(cfg["squeeze_max"]))
	return minf(Num.f(cfg["block_radius"]), street) * squeeze


## Any standing street-level chunk whose square the circle (pos, radius) overlaps.
func blocked(pos: Vector2, radius: float) -> bool:
	for b: RampageSim.Building in sim.buildings:
		if b.frame.alive_count == 0:
			continue
		if absf(b.x - pos.x) > b.w * 0.5 + radius or absf(b.z - pos.y) > b.d * 0.5 + radius:
			continue
		for x: int in b.w:
			for z: int in b.d:
				var c := Vector3i(x, 0, z)
				if b.frame.alive(c):
					var p := b.chunk_world(c)
					var gap := Vector2(
						maxf(absf(p.x - pos.x) - CHUNK_HALF, 0.0),
						maxf(absf(p.z - pos.y) - CHUNK_HALF, 0.0)
					)
					if gap.length() < radius:
						return true
	return false


## The beam turns the kaiju slowly (steering the beam); otherwise it faces where it moves.
func turn_toward(from: Vector2, to: Vector2, dt: float) -> Vector2:
	if beam_left <= 0.0:
		return to
	var angle := from.angle_to(to)
	var most := Num.f(cfg["beam_turn_speed"]) * TAU * dt
	return from.rotated(clampf(angle, -most, most))


func after_move(dt: float, old_facing: Vector2, moving: bool) -> void:
	var turn := absf(old_facing.angle_to(sim.facing)) if moving else 0.0
	if moving:
		momentum += (
			dt / Num.f(cfg["momentum_build_seconds"]) - turn * Num.f(cfg["momentum_turn_bleed"])
		)
	else:
		momentum -= dt * Num.f(cfg["momentum_idle_decay"])
	momentum = clampf(momentum, 0.0, 1.0)
	_turn = _turn * exp(-Num.f(cfg["tail_turn_decay"]) * dt) + turn
	_tail_cd -= dt
	if sim.stat("tail_damage") > 0.0 and _turn >= Num.f(cfg["tail_turn_rad"]) and _tail_cd <= 0.0:
		_tail_cd = Num.f(cfg["tail_cooldown"])
		_turn = 0.0
		_tail_sweep(signf(old_facing.cross(sim.facing)))
	_climb(dt)
	_ram(dt)


## Stomp (and ram) damage multiplier from momentum.
func hit_mult() -> float:
	return 1.0 + sim.stat("momentum") * momentum


## The tail whips through the arc behind and beside the body, cutting a band of floors above
## the ground floor at full force (no falloff): what stands above the cut drops.
func _tail_sweep(side: float) -> void:
	tail_sweeps += 1
	var reach := (Num.f(cfg["tail_reach"]) + sim.stat("tail_reach")) * _bs()
	var centre := sim.kaiju_pos
	var ahead := sim.facing
	var lo := Num.i(cfg["tail_floor_lo"])
	var per_scale := Num.f(cfg["tail_floors_per_scale"])
	var floors := ceili((Num.f(cfg["tail_floors"]) + sim.stat("tail_floors")) * _bs() * per_scale)
	var arc := Num.f(cfg["tail_arc_dot"])
	sim.events.append({"type": "tail_sweep", "side": side, "reach": reach})
	var before := sim.chunks_destroyed
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			var to := p - centre
			if to.length() > reach + r:
				return 0.0
			return 1.0 if to.length() <= r or ahead.dot(to.normalized()) <= arc else 0.0,
		sim.stat("tail_damage"),
		lo,
		lo + floors
	)
	tail_cut += sim.chunks_destroyed - before


## With momentum the reptilian rams what is in front of it and knocks tanks away.
func _ram(dt: float) -> void:
	_ram_cd -= dt
	if sim.stat("momentum") <= 0.0 or momentum < Num.f(cfg["ram_min"]) or _ram_cd > 0.0:
		return
	_ram_cd = Num.f(cfg["ram_interval"])
	var centre := sim.kaiju_pos
	var ahead := sim.facing
	var radius := Num.f(cfg["body_radius"]) * _bs() + Num.f(cfg["ram_reach_extra"])
	var front := func(p: Vector2, r: float) -> float:
		var to := p - centre
		return 1.0 if to.length() <= radius + r and to.dot(ahead) >= -r else 0.0
	for tank: RampageSim.Tank in sim.tanks:
		if front.call(tank.pos, RampageSim.TANK_RADIUS) > 0.0:
			tank.pos += ahead * Num.f(cfg["knockback"]) * momentum
	sim.hit_area(front, sim.stat("stomp_damage") * sim.stat("momentum") * momentum)


## A climber stands on the highest chunk under it, rising at climb speed; its weight breaks
## the chunks it stands on.
func _climb(dt: float) -> void:
	if sim.stat("climb") <= 0.0 or sim.airborne:
		sim.stand_y = 0.0
		return
	var top := column_top(sim.kaiju_pos)
	if top > sim.stand_y:
		sim.stand_y = minf(top, sim.stand_y + Num.f(cfg["climb_speed"]) * dt)
	else:
		sim.stand_y = top
	if sim.stand_y < 1.0:
		return
	var centre := sim.kaiju_pos
	var load_radius := Num.f(cfg["climb_load_radius"])
	var y := floori(sim.stand_y) - 1
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return 1.0 if p.distance_to(centre) <= load_radius + r else 0.0,
		Num.f(cfg["climb_load"]) * sim.stat("climb") * dt,
		y,
		y + 1
	)


## Height (floors) of the standing top of the building column at pos, 0 on the street.
func column_top(pos: Vector2) -> float:
	for b: RampageSim.Building in sim.buildings:
		var lx := floori(pos.x - (b.x - b.w * 0.5))
		var lz := floori(pos.y - (b.z - b.d * 0.5))
		if lx >= 0 and lz >= 0 and lx < b.w and lz < b.d:
			return float(b.frame.top_below(lx, lz, b.height) + 1)
	return 0.0


## --- Signature follow-ups and ultimates ------------------------------------------------


## Leap Slam just landed: if Wing Buzz is owned, keeping the button held glides on.
func leap_landed() -> void:
	_glide_armed = sim.stat("glide_seconds") > 0.0


func has_ultimate() -> bool:
	return sim.stat("beam_dps") > 0.0 or sim.stat("brood_count") > 0.0 or sim.stat("ink_dps") > 0.0


func ultimate() -> void:
	if sim.stat("beam_dps") > 0.0:
		beam_left = Num.f(cfg["beam_seconds"])
		sim.events.append({"type": "beam_start", "seconds": beam_left})
	elif sim.stat("brood_count") > 0.0:
		sim.brood.lay(Num.i(sim.stat("brood_count")))
	elif sim.stat("ink_dps") > 0.0:
		_ink()


func step(dt: float, held: bool) -> void:
	_glide(dt, held)
	_beam(dt)
	tentacles.step(dt)
	_coats(dt)


func _glide(dt: float, held: bool) -> void:
	if _glide_armed and not sim.airborne:
		_glide_armed = false
		if held:
			sim.airborne = true
			glide_left = sim.stat("glide_seconds")
			sim.events.append({"type": "glide_start"})
		return
	if not sim.airborne:
		return
	glide_left -= dt
	if held and glide_left > 0.0:
		return
	sim.airborne = false
	var land := sim.kaiju_pos
	var reach := sim.ability_reach()
	sim.events.append({"type": "glide_land", "reach": reach})
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(land) - r, reach),
		sim.stat("ability_damage") * Num.f(cfg["glide_land_mult"])
	)


func _beam(dt: float) -> void:
	if beam_left <= 0.0:
		return
	beam_left -= dt
	var origin := sim.kaiju_pos
	var dir := sim.facing
	var length := Num.f(cfg["beam_range"]) * _bs()
	var half := Num.f(cfg["beam_half_width"]) * _bs()
	sim.hit_coat = {"kind": "burn", "dps": Num.f(cfg["burn_dps"]), "seconds": cfg["burn_seconds"]}
	sim.hit_air = true
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			var rel := p - origin
			var t := rel.dot(dir)
			var side := absf(rel.dot(Vector2(-dir.y, dir.x)))
			return 1.0 if t >= -r and t <= length + r and side <= half + r else 0.0,
		sim.stat("beam_dps") * dt,
		0,
		ceili(sim.reach_top() * Num.f(cfg["coat_reach_mult"]))
	)
	sim.hit_coat = {}
	sim.hit_air = false
	if beam_left <= 0.0:
		sim.events.append({"type": "beam_end"})


func _ink() -> void:
	var centre := sim.kaiju_pos
	var reach := Num.f(cfg["ink_reach"]) * _bs()
	var dps := sim.stat("ink_dps")
	sim.events.append({"type": "ink", "reach": reach})
	sim.hit_coat = {"kind": "ink", "dps": dps, "seconds": cfg["ink_seconds"]}
	sim.hit_air = true
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(centre) - r, reach),
		dps * Num.f(cfg["ink_splash"]),
		0,
		ceili(sim.reach_top() * Num.f(cfg["coat_reach_mult"]))
	)
	sim.hit_coat = {}
	sim.hit_air = false


## --- Coatings: beam fire and ink eat what they cover -----------------------------------


## Coats chunks of building `index` with sim.hit_coat (refreshing an existing coat).
func coat(index: int, cells: Array[Vector3i]) -> void:
	if cells.is_empty():
		return
	var b := sim.buildings[index]
	var fresh: Array[Vector3i] = []
	for c: Vector3i in cells:
		var key := index * 1048576 + b.frame.index(c)
		if not coats.has(key):
			fresh.append(c)
		coats[key] = {
			"b": index,
			"c": c,
			"t": Num.f(sim.hit_coat["seconds"]),
			"dps": Num.f(sim.hit_coat["dps"]),
		}
	if not fresh.is_empty():
		sim.events.append(
			{"type": "coated", "building": index, "cells": fresh, "kind": sim.hit_coat["kind"]}
		)


func _coats(dt: float) -> void:
	if coats.is_empty():
		return
	var by_building: Dictionary = {}
	var done: Array[int] = []
	for key: int in coats:
		var entry: Dictionary = coats[key]
		var b := sim.buildings[Num.i(entry["b"])]
		var c: Vector3i = entry["c"]
		entry["t"] = Num.f(entry["t"]) - dt
		if Num.f(entry["t"]) <= 0.0 or not b.frame.alive(c):
			done.append(key)
			continue
		var list: Array = by_building.get(entry["b"], [])
		list.append(entry)
		by_building[entry["b"]] = list
	for key: int in done:
		coats.erase(key)
	for index: int in by_building:
		var cells: Array[Vector3i] = []
		var amounts := PackedFloat32Array()
		for entry: Dictionary in by_building[index]:
			cells.append(entry["c"])
			amounts.append(Num.f(entry["dps"]) * dt)
		sim.damage_cells(index, cells, amounts)
