class_name DeathOverload
extends RefCounted
## The kaiju's death (director 2026-10-26, every kaiju): "overloaded with kaiju energy, crackling
## up, turning them to stone then exploding into shards". A death (tuning death.reasons: killed,
## time's up, End rampage) no longer ends the run at once: he staggers (the clip's time), turns to
## stone, then shatters. The shards are cells of his own body (BodyContact's discs) thrown out on
## seeded arcs; each smashes what it lands on through RampageSim.hit_area, the normal destruction
## path (it pays biomass as any blow does). The Death Blast nodes (stat death_blast) add a front
## that runs out from the body and wrecks every floor in a ring round his body: death_blast x
## per_node beyond the body's edge (director 2026-10-26, "Smaller: a ring round his body"; node 3
## about one street block), also through hit_area. Shards first (director 2026-10-27, D-294): his
## falling stone body smashes buildings, then the blast clears the rest, so the front starts
## blast_after_s after the last shard lands. The run ends (RampageSim.end) settle_s after the front
## (or the last shard), so the results wait for the burst. Part of RampageSim; pure: one derived
## stream, no clock.
## Time's up runs the jets' final strike first (FinalStrike, D-263), then his death.
## Events: death_begin {reason}, death_stone, death_shatter {shards, centre, blast}, death_shard
## {id, x, z}, death_blast {radius, x, z} (the front starts), then run_over.

enum Phase { NONE, STRIKE, STAGGER, STONE, SHATTER }


## One piece of him in the air: from (world), to (ground point), landing `t` s after the shatter.
class Shard:
	var id: int
	var from: Vector3
	var to: Vector2
	var t: float
	var landed := false


var sim: RampageSim
var cfg: Dictionary
var phase := Phase.NONE
var reason := ""
## Seconds since the death began, and since the shatter.
var t := 0.0
var since_shatter := 0.0
var shards: Array[Shard] = []
## The blast front's centre, its full radius (0: no node), how far it has run and when it starts
## (seconds after the shatter: the last shard's landing + blast_after_s, D-294 shards first).
var centre := Vector2.ZERO
var blast_radius := 0.0
var blast_front := 0.0
var blast_at := 0.0
var blast_began := false
## Seconds after the shatter when the last shard lands.
var landing_end := 0.0
## What the shards and the front broke (chunks), for tests and the results.
var shard_chunks := 0
var blast_chunks := 0
## The jets' run at time's up.
var strike: FinalStrike

var _rng: RandomNumberGenerator


func _init(p_sim: RampageSim, tuning: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = tuning["death"]
	_rng = rng
	var strike_cfg: Dictionary = cfg["airstrike"]
	strike = FinalStrike.new(sim, strike_cfg)


## True for an ending that is his death (the rest end at once: the city fell).
func is_death(why: String) -> bool:
	var reasons: Array = cfg["reasons"]
	return reasons.has(why)


func active() -> bool:
	return phase != Phase.NONE


## He dies of `why`: the stagger starts now. False (nothing happens) for a reason that is no death.
func begin(why: String) -> bool:
	if not is_death(why):
		return false
	if active():
		return true
	reason = why
	if why == "time":
		phase = Phase.STRIKE
		strike.start(_rng)
		return true
	_stagger()
	return true


func _stagger() -> void:
	phase = Phase.STAGGER
	t = 0.0
	sim.events.append({"type": "death_begin", "reason": reason})


## True when the kaiju takes no step of his own: the run is over, or he is dying and this runs the
## sequence in place of his step: the world going on without him (falls, blasts, the army, the
## sky, the trains); no input, no clock (RampageSim.step's early return).
func holds(dt: float) -> bool:
	if sim.over:
		return true
	if not active():
		return false
	step(dt)
	sim.collapse.step(dt)
	sim.explosives.step(dt)
	sim.army_units.step(dt)
	sim.air.step(dt)
	sim.rail.step(dt)
	sim.news.step(sim.events)
	return true


## One step of the sequence.
func step(dt: float) -> void:
	if phase == Phase.STRIKE:
		if strike.step(dt):
			_stagger()
		return
	t += dt
	var stone_at := Num.f(cfg["stagger_s"])
	if phase == Phase.STAGGER and t >= stone_at:
		phase = Phase.STONE
		sim.events.append({"type": "death_stone", "seconds": Num.f(cfg["stone_s"])})
	if phase == Phase.STONE and t >= stone_at + Num.f(cfg["stone_s"]):
		_shatter()
		return
	if phase == Phase.SHATTER:
		_step_shatter(dt)


## After the shatter: shards land as they come down, the blast front runs, then the run ends.
func _step_shatter(dt: float) -> void:
	since_shatter += dt
	for s: Shard in shards:
		if not s.landed and since_shatter >= s.t:
			_land(s)
	_run_front()
	var done := blast_at + Num.f(cfg["blast_s"]) if blast_radius > 0.0 else landing_end
	if since_shatter >= done + Num.f(cfg["settle_s"]):
		sim.end(reason, true)


## A shard's size (world units): one body cell at his scale.
func cell_size() -> float:
	return Num.f(cfg["cell"]) * sim.body_scale()


## The blast's full radius for `nodes` Death Blast levels (world units from his centre; 0
## without one): his body's edge plus nodes x per_node.
func radius_for(nodes: float) -> float:
	if nodes <= 0.0:
		return 0.0
	return body_edge() + nodes * Num.f(cfg["per_node"])


## How far his body reaches from where he stands (world units; BodyVolume.reach's rule).
func body_edge() -> float:
	var discs: Array = sim.body.discs() if sim.body.active() else [cfg["fallback_disc"]]
	var reach := 0.0
	for d: Array in discs:
		reach = maxf(reach, absf(Num.f(d[0])) + Num.f(d[1]))
	return reach * sim.body_scale()


func _shatter() -> void:
	phase = Phase.SHATTER
	since_shatter = 0.0
	centre = sim.kaiju_pos
	blast_radius = radius_for(sim.stat("death_blast"))
	shards = _throw(_body_cells(), _rng)
	landing_end = 0.0
	for s: Shard in shards:
		landing_end = maxf(landing_end, s.t)
	blast_at = landing_end + Num.f(cfg["blast_after_s"])
	var out: Array[Dictionary] = []
	for s: Shard in shards:
		out.append({"id": s.id, "from": s.from, "to": s.to, "t": s.t})
	(
		sim
		. events
		. append(
			{
				"type": "death_shatter",
				"shards": out,
				"centre": centre,
				"blast": blast_radius,
				"cell": cell_size(),
			}
		)
	)


## Every cell of his body (world centres, one cell apart at his scale), in a fixed scan order.
func _body_cells() -> Array[Vector3]:
	var s := sim.body_scale()
	var step := Num.f(cfg["cell"]) * s
	var discs: Array = sim.body.discs() if sim.body.active() else [cfg["fallback_disc"]]
	var seen := {}
	var out: Array[Vector3] = []
	for d: Array in discs:
		var c := sim.kaiju_pos + sim.facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		var n := ceili(r / step)
		var y_lo := floori((sim.stand_y + Num.f(d[2]) * s) / step)
		var y_hi := maxi(y_lo + 1, ceili((sim.stand_y + Num.f(d[3]) * s) / step))
		for gy: int in range(y_lo, y_hi):
			for gx: int in range(-n, n + 1):
				for gz: int in range(-n, n + 1):
					var off := Vector2(gx, gz) * step
					var key := Vector3i(
						roundi((c.x + off.x) / step), gy, roundi((c.y + off.y) / step)
					)
					if off.length() <= r and not seen.has(key):
						seen[key] = true
						out.append(Vector3(key.x * step, (gy + 0.5) * step, key.z * step))
	return out


## Picks the shards from his cells and throws each out from the body on a seeded arc.
func _throw(cells: Array[Vector3], rng: RandomNumberGenerator) -> Array[Shard]:
	var count := mini(Num.i(cfg["shards"]), cells.size())
	for i: int in count:  # a partial Fisher-Yates: the first `count` cells, seeded
		var j := i + rng.randi_range(0, cells.size() - 1 - i)
		var keep := cells[i]
		cells[i] = cells[j]
		cells[j] = keep
	var s := sim.body_scale()
	var flight: Array = cfg["flight_s"]
	var jitter := deg_to_rad(Num.f(cfg["throw_jitter_deg"]))
	var out: Array[Shard] = []
	for i: int in count:
		var shard := Shard.new()
		shard.id = i
		shard.from = cells[i]
		var flat := Vector2(shard.from.x, shard.from.z) - sim.kaiju_pos
		var dir := (
			flat.normalized() if flat.length() > 0.01 else Vector2.from_angle(rng.randf() * TAU)
		)
		dir = dir.rotated(rng.randf_range(-jitter, jitter))
		var reach := rng.randf_range(Num.f(cfg["throw_min"]), Num.f(cfg["throw_max"])) * s
		shard.to = sim.clamp_to_arena(Vector2(shard.from.x, shard.from.z) + dir * reach)
		shard.t = rng.randf_range(Num.f(flight[0]), Num.f(flight[1]))
		out.append(shard)
	return out


## A shard comes down: a blow on the top floors of whatever stands under it.
func _land(s: Shard) -> void:
	s.landed = true
	sim.events.append({"type": "death_shard", "id": s.id, "x": s.to.x, "z": s.to.y})
	var at := s.to
	var radius := Num.f(cfg["shard_radius"])
	var top := _top_at(at)
	var before := sim.chunks_destroyed
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(at) - r, radius),
		Num.f(cfg["shard_damage"]),
		maxi(0, top - Num.i(cfg["shard_floors"])),
		maxi(top, Num.i(cfg["shard_floors"]))
	)
	shard_chunks += sim.chunks_destroyed - before


## The tallest standing building's height (floors) whose footprint holds `p`; 0 on open ground.
func _top_at(p: Vector2) -> int:
	var top := 0
	for b: RampageSim.Building in sim.buildings:
		if b.frame.alive_count == 0:
			continue
		if absf(p.x - b.x) <= b.w * 0.5 and absf(p.y - b.z) <= b.d * 0.5:
			top = maxi(top, b.height + b.base)
	return top


## The blast front moves on once the last shard is down (blast_at): everything between where it
## was and where it is now takes the blow once, every floor (his own power, the one effect that
## goes big).
func _run_front() -> void:
	if blast_radius <= 0.0 or blast_front >= blast_radius or since_shatter < blast_at:
		return
	if not blast_began:
		blast_began = true
		sim.events.append(
			{"type": "death_blast", "radius": blast_radius, "x": centre.x, "z": centre.y}
		)
	var was := blast_front
	var k := clampf((since_shatter - blast_at) / maxf(0.001, Num.f(cfg["blast_s"])), 0.0, 1.0)
	blast_front = blast_radius * k
	var now := blast_front
	var at := centre
	var before := sim.chunks_destroyed
	sim.hit_air = true
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			var dist := p.distance_to(at)
			return 1.0 if dist - r < now and dist + r >= was else 0.0,
		Num.f(cfg["blast_damage"]),
		0,
		Num.i(cfg["blast_floors"])
	)
	sim.hit_air = false
	blast_chunks += sim.chunks_destroyed - before
