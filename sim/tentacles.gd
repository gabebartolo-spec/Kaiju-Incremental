class_name Tentacles
extends RefCounted
## The cephalopod's limbs (docs/SPECIES.md): each freed tentacle strikes on its own timer at a
## target it picks (Hydra Limbs), and one seizes a tank, helicopter or car and hurls it where
## the kaiju faces (Grab and Throw). Part of SpeciesPowers. Pure and seeded.


## Something a tentacle grabbed, in flight to where the kaiju faced.
class Thrown:
	var kind: String
	var from: Vector2
	var to: Vector2
	var t := 0.0
	var duration: float


var sim: RampageSim
var cfg: Dictionary
var thrown: Array[Thrown] = []
var limb_strikes := 0
var _rng: RandomNumberGenerator
var _grab_cd := 0.0
var _limb_cd: Array[float] = []


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = sim.powers_cfg
	_rng = rng


func _bs() -> float:
	return sim.body_scale()


func step(dt: float) -> void:
	_limbs(dt)
	if not _grab_vip():
		_grab(dt)
	_thrown(dt)


## Each freed tentacle strikes on its own timer at a target it picks: a nearby tank or
## helicopter if there is one, else a seeded spot all around the body.
func _limbs(dt: float) -> void:
	var count := Num.i(sim.stat("limbs"))
	var interval := Num.f(cfg["limb_interval"])
	while _limb_cd.size() < count:
		_limb_cd.append(interval * (1.0 + float(_limb_cd.size()) / maxf(1.0, count)))
	var reach := Num.f(cfg["limb_reach"]) * _bs()
	for i: int in count:
		_limb_cd[i] -= dt
		if _limb_cd[i] > 0.0:
			continue
		_limb_cd[i] += interval
		var targets := _units_within(reach)
		if targets.is_empty():
			targets = _chunks_within(reach)
		if not targets.is_empty():
			_strike(i, targets[_rng.randi_range(0, targets.size() - 1)])


func _strike(limb: int, at: Vector2) -> void:
	limb_strikes += 1
	var radius := Num.f(cfg["limb_radius"]) * _bs()
	sim.events.append({"type": "limb", "limb": limb, "at": at})
	sim.hit_air = true
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(at) - r, radius),
		sim.stat("stomp_damage") * Num.f(cfg["limb_mult"])
	)
	sim.hit_air = false


## For every building in reach, its standing chunk nearest the kaiju (one target each).
func _chunks_within(reach: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var from := sim.kaiju_pos
	var top := ceili(sim.reach_top())
	for b: RampageSim.Building in sim.buildings:
		if b.frame.alive_count == 0:
			continue
		if Vector2(b.x, b.z).distance_to(from) - Vector2(b.w, b.d).length() * 0.5 > reach:
			continue
		var best := Vector2(INF, INF)
		var best_d := reach
		for y: int in mini(top, b.height):
			for x: int in b.w:
				for z: int in b.d:
					if b.frame.alive(Vector3i(x, y, z)):
						var p := b.chunk_world(Vector3i(x, y, z))
						var d := Vector2(p.x, p.z).distance_to(from)
						if d <= best_d:
							best_d = d
							best = Vector2(p.x, p.z)
		if best.x < INF:
			out.append(best)
	return out


func _units_within(reach: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for tank: RampageSim.Tank in sim.tanks:
		if tank.pos.distance_to(sim.kaiju_pos) <= reach:
			out.append(tank.pos)
	for heli: AirWing.Heli in sim.air.helis:
		if heli.pos.distance_to(sim.kaiju_pos) <= reach:
			out.append(heli.pos)
	return out


## A tentacle seizes the nearest tank or helicopter and hurls it where the kaiju faces; with
## none in reach for a while it settles for a car off the street.
func _grab(dt: float) -> void:
	_grab_cd -= dt
	if sim.stat("throw_damage") <= 0.0 or _grab_cd > 0.0:
		return
	var reach := Num.f(cfg["grab_reach"]) * _bs()
	if _units_within(reach).is_empty() and _grab_cd > -Num.f(cfg["car_wait"]):
		return
	_grab_cd = Num.f(cfg["grab_cooldown"])
	var kind := "car"
	var from := sim.kaiju_pos
	var best := reach
	var best_tank: RampageSim.Tank = null
	var best_heli: AirWing.Heli = null
	for tank: RampageSim.Tank in sim.tanks:
		var d := tank.pos.distance_to(sim.kaiju_pos)
		if d <= best:
			best = d
			best_tank = tank
	for heli: AirWing.Heli in sim.air.helis:
		var d := heli.pos.distance_to(sim.kaiju_pos)
		if d <= best:
			best = d
			best_heli = heli
			best_tank = null
	if best_heli != null:
		kind = "heli"
		from = best_heli.pos
		best_heli.hp = 0.0
		sim.air.clear_dead(true)
	elif best_tank != null:
		kind = "tank"
		from = best_tank.pos
		best_tank.hp = 0.0
		sim.army_units.clear_dead()
	_throw(kind, from)


## The leader's helicopter (D-149), low and in reach, is the prize: the first free limb takes it.
func _grab_vip() -> bool:
	if sim.stat("throw_damage") <= 0.0 or _grab_cd > 0.0:
		return false
	var at := sim.vip.grab_pos(Num.f(cfg["grab_reach"]) * _bs())
	if at.x == INF:
		return false
	_grab_cd = Num.f(cfg["grab_cooldown"])
	sim.vip.down(true, "grab")
	_throw("heli", at)
	return true


## Hurls what a limb holds (`kind` from `from`) where the kaiju faces.
func _throw(kind: String, from: Vector2) -> void:
	var throw := Thrown.new()
	throw.kind = kind
	throw.from = from
	throw.to = sim.clamp_to_arena(sim.kaiju_pos + sim.facing * Num.f(cfg["throw_range"]) * _bs())
	throw.duration = Num.f(cfg["throw_seconds"])
	thrown.append(throw)
	sim.events.append({"type": "grab", "kind": kind, "from": from, "to": throw.to})


func _thrown(dt: float) -> void:
	var landed: Array[Thrown] = []
	for throw: Thrown in thrown:
		throw.t += dt
		if throw.t >= throw.duration:
			landed.append(throw)
	for throw: Thrown in landed:
		thrown.erase(throw)
		var blast: Dictionary = cfg["throw_blast"]
		var mults: Dictionary = cfg["throw_mult"]
		var radius := Num.f(blast[throw.kind]) * _bs()
		var at := throw.to
		sim.events.append({"type": "throw_land", "kind": throw.kind, "at": at, "radius": radius})
		sim.hit_area(
			func(p: Vector2, r: float) -> float:
				return RampageSim.falloff(p.distance_to(at) - r, radius),
			sim.stat("throw_damage") * Num.f(mults[throw.kind])
		)
