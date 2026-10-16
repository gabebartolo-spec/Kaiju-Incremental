class_name Brood
extends RefCounted
## The insectoid's ultimate: eggs laid around the kaiju hatch into elephant-sized young that
## hunt on their own, biting tanks first and buildings otherwise (presentation lets each bite
## eat the people and police where it lands). Tanks shoot the nearest young instead of the
## kaiju. Capped and seeded. Part of RampageSim.


class Young:
	var id: int
	var pos: Vector2
	var hp: float
	var life: float
	var hatch: float
	var bite_cd := 0.0
	var target := Vector2(INF, INF)
	var retarget := 0.0


var sim: RampageSim
var cfg: Dictionary
## Eggs (hatch > 0) and hatched young.
var young: Array[Young] = []
var bites := 0
var hatched := 0
var _rng: RandomNumberGenerator
var _next_id := 0


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = sim.powers_cfg
	_rng = rng


## Lays up to `count` eggs (never more than the cap alive at once).
func lay(count: int) -> void:
	var room := mini(count, Num.i(cfg["brood_max"]) - young.size())
	var at: Array[Vector2] = []
	for n: int in room:
		var y := Young.new()
		y.id = _next_id
		_next_id += 1
		var spread := Num.f(cfg["egg_spread"]) * sim.body_scale()
		y.pos = sim.kaiju_pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.5, 1.0) * spread
		y.hp = Num.f(cfg["brood_hp"])
		y.life = Num.f(cfg["brood_life"])
		y.hatch = Num.f(cfg["hatch_seconds"])
		y.retarget = _rng.randf() * 0.5
		young.append(y)
		at.append(y.pos)
	sim.events.append({"type": "eggs_laid", "at": at})


func step(dt: float) -> void:
	if young.is_empty():
		return
	var alive: Array[Young] = []
	for y: Young in young:
		if y.hatch > 0.0:
			y.hatch -= dt
			if y.hatch <= 0.0:
				hatched += 1
				sim.events.append({"type": "brood_hatched", "id": y.id, "at": y.pos})
			alive.append(y)
			continue
		y.life -= dt
		if y.hp <= 0.0 or y.life <= 0.0:
			sim.events.append({"type": "brood_died", "id": y.id, "at": y.pos})
			continue
		_hunt(y, dt)
		alive.append(y)
	young = alive


func _hunt(y: Young, dt: float) -> void:
	y.retarget -= dt
	if y.retarget <= 0.0:
		y.retarget = 0.5
		y.target = _pick_target(y.pos)
	if y.target.x == INF:
		return
	var radius := Num.f(cfg["brood_bite_radius"])
	var to := y.target - y.pos
	if to.length() > radius * 0.8:
		y.pos += to.limit_length(Num.f(cfg["brood_speed"]) * dt)
	y.bite_cd -= dt
	if y.bite_cd > 0.0 or to.length() > radius * 1.5:
		return
	y.bite_cd = Num.f(cfg["brood_bite_interval"])
	bites += 1
	var at := y.pos
	sim.events.append({"type": "brood_bite", "id": y.id, "at": at})
	sim.hit_area(
		func(p: Vector2, r: float) -> float: return 1.0 if p.distance_to(at) <= radius + r else 0.0,
		Num.f(cfg["brood_damage"]),
		0,
		3
	)


## The nearest tank within the hunting radius, else the nearest standing street-level chunk.
func _pick_target(from: Vector2) -> Vector2:
	var best := Num.f(cfg["brood_hunt_radius"])
	var target := Vector2(INF, INF)
	for tank: RampageSim.Tank in sim.tanks:
		var d := tank.pos.distance_to(from)
		if d < best:
			best = d
			target = tank.pos
	if target.x == INF:
		target = sim.nearest_standing(from)
	return target


## The nearest hatched young within `within` of pos, or null.
func nearest_young(pos: Vector2, within: float) -> Young:
	var best: Young = null
	var best_d := within
	for y: Young in young:
		if y.hatch > 0.0:
			continue
		var d := y.pos.distance_to(pos)
		if d < best_d:
			best_d = d
			best = y
	return best
