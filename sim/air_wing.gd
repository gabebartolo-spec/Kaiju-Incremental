class_name AirWing
extends RefCounted
## Military helicopters (D-037): once the kaiju has done enough damage they arrive and fire on
## it as stand-off gunships (D-183, AirFlight): they hold firing positions well beyond its
## reach, glide between them under their own speed and turn limits and pull back when it
## advances; now and then one makes a strafing pass within claw reach. A kaiju reaches them
## only when it stands tall enough (a grown body or a climbed roof) or with an attack that
## reaches the air (fire, ink, tentacles); a cephalopod can pluck one out of the sky. They keep
## to the far side of the kaiju from the game camera (`camera_bearing`, clear of `clear_arc`
## either side of it), so a helicopter never hangs between the player and the kaiju. How one dies
## (D-140, D-141, D-145): a killing blow of at least `blow_apart` of its hp blows it apart in
## the air; a lighter one (a glancing hit, a burning coat, a toppling tower sweeping through it)
## sends it spinning down for `fall_seconds`,
## drifting `fall_drift`, its crew sometimes bailing out by parachute (`bailout_chance`, up to
## `bailout_max`), until it crashes: the wreck smashes `crash_floors` floors within
## `crash_radius`, crushing the tanks and squads below (D-167; never the kaiju), and sets the
## building it hits burning (City Ablaze). It pays its rubble when it is downed.
## Part of RampageSim. Pure and seeded.


class Heli:
	var id: int
	var pos: Vector2
	var heading := 0.0  # which way its nose points, radians (turn-limited)
	var vel := Vector2.ZERO  # its velocity, units a second (acceleration-limited)
	var ring := 0.0  # its own stand-off distance from the kaiju (world units)
	var slot := 0.0  # the bearing from the kaiju of its firing position, on its ring (radians)
	var goal := Vector2.ZERO  # the point it steers for now: its firing position, or a pass's point
	var hold := 0.0  # seconds until it glides along the ring to another slot
	var passing := false  # on a strafing pass: a fly-by along a line across his front
	var pass_at := Vector2.ZERO  # unit vector from the kaiju to the pass line's nearest point
	var pass_dir := Vector2.ZERO  # the way along the line it flies
	var pass_left := 0.0
	var hp: float
	var cooldown: float
	var coat_t := 0.0
	var coat_dps := 0.0
	var last_blow := 0.0  # the damage of the latest hit: how hard the killing blow was


## A downed helicopter spinning to the ground; it crashes when `left` runs out.
class Falling:
	var id: int
	var pos: Vector2
	var drift: Vector2  # ground units a second
	var left: float


var sim: RampageSim
var cfg: Dictionary
var flight: AirFlight
var helis: Array[Heli] = []
var falling: Array[Falling] = []
var destroyed := 0
var _fall_rng: RandomNumberGenerator  # its own stream: spawns draw exactly as before deaths fell
var _crashing := false  # a wreck's own impact never reaches the sky
var _spawn_timer := 0.0
var _next_id := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	flight = AirFlight.new(sim, cfg, Seeds.derive(rng, 0xF17))
	_fall_rng = Seeds.derive(rng, 0xFA11)


func altitude() -> float:
	return Num.f(cfg["altitude"])


## How many may be up at once: more the more of the city has fallen.
func cap() -> int:
	var after := Num.i(cfg["after_chunks"])
	if sim.escalation() < after:
		return 0
	var extra := (sim.escalation() - after) / maxi(1, Num.i(cfg["max_per_chunks"]))
	return mini(Num.i(cfg["max"]), 1 + extra)


func step(dt: float) -> void:
	_swept_by_falls()
	# The call-in clock only runs while the sky is short of helicopters: a kill is replaced
	# after `interval`, never on the next step.
	if helis.size() < cap():
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer = Num.f(cfg["interval"])
			spawn()
	flight.step(helis, dt)
	var coated := false
	for heli: Heli in helis:
		if heli.coat_t > 0.0:
			heli.coat_t -= dt
			heli.hp -= heli.coat_dps * dt
			heli.last_blow = heli.coat_dps * dt  # a coat kill is a light blow: it spins down
			coated = true
		heli.cooldown -= dt
		if heli.cooldown <= 0.0:
			heli.cooldown = Num.f(cfg["fire_interval"])
			var army := sim.army
			var hurt := Num.f(cfg["damage"]) - sim.stat("armor")
			sim.hp -= maxf(Num.f(army["min_damage"]), hurt)
			sim.events.append({"type": "heli_fired", "heli": heli.id})
	if coated:
		clear_dead()
	_fall(dt)


## A tower toppling this step (Collapse's fall_start) that is tall enough to reach the sky sweeps
## its landing strip: every helicopter over the strip is knocked spinning down (D-140).
func _swept_by_falls() -> void:
	var hit := false
	for event: Dictionary in sim.events:
		if str(event["type"]) != "fall_start" or not event.has("to"):
			continue
		var pivot: Vector3 = event["pivot"]
		var start := Vector2(pivot.x, pivot.z)
		var end: Vector2 = event["to"]
		var span := end - start
		if span.length() + pivot.y < altitude():
			continue  # it never reaches the helicopters' height
		var half := Num.f(event["width"]) * 0.5 + Num.f(cfg["heli_radius"])
		for heli: Heli in helis:
			var t := clampf(
				(heli.pos - start).dot(span) / maxf(0.001, span.length_squared()), 0.0, 1.0
			)
			if heli.pos.distance_to(start + span * t) <= half:
				heli.hp = 0.0
				heli.last_blow = 0.0  # knocked aside, never blown apart
				hit = true
	if hit:
		clear_dead()


## A new helicopter flies in from beyond its ring (AirFlight.place) on the far side from the camera.
func spawn() -> Heli:
	var heli := Heli.new()
	heli.id = _next_id
	_next_id += 1
	flight.place(heli)
	heli.hp = Num.f(cfg["hp"])
	heli.cooldown = Num.f(cfg["fire_interval"]) * Num.f(cfg["first_burst_delay"])
	helis.append(heli)
	sim.events.append({"type": "heli_spawned", "heli": heli.id})
	return heli


## An attack's force reaches helicopters only when reaches_air (else they fly too high).
func hit(force: Callable, damage: float, reaches_air: bool) -> void:
	if not reaches_air or helis.is_empty() or _crashing:
		return
	for heli: Heli in helis:
		var k: float = force.call(heli.pos, Num.f(cfg["heli_radius"]))
		heli.hp -= damage * k
		if k > 0.0:
			heli.last_blow = damage * k
		if k > 0.0 and not sim.hit_coat.is_empty():
			heli.coat_t = Num.f(sim.hit_coat["seconds"])
			heli.coat_dps = Num.f(sim.hit_coat["dps"]) * Num.f(sim.powers_cfg["ink_unit_mult"])
	clear_dead()


## Takes the dead out of the sky. grabbed: a tentacle has them (no break-up, no fall).
func clear_dead(grabbed := false) -> void:
	var alive: Array[Heli] = []
	for heli: Heli in helis:
		if heli.hp > 0.0:
			alive.append(heli)
			continue
		destroyed += 1
		sim.rubble += Num.f(cfg["rubble"]) * sim.stat("rubble_mult")
		var event := {"type": "heli_destroyed", "heli": heli.id, "x": heli.pos.x, "z": heli.pos.y}
		if grabbed:
			event["fate"] = "grabbed"
		elif heli.last_blow >= Num.f(cfg["hp"]) * Num.f(cfg["blow_apart"]):
			event["fate"] = "burst"
		else:
			event.merge(_spin_down(heli))
		sim.events.append(event)
	helis = alive


## A downed helicopter starts its fall: the fate, the fall's time and drift and the crew who jump.
func _spin_down(heli: Heli) -> Dictionary:
	var down := Falling.new()
	down.id = heli.id
	down.pos = heli.pos
	down.left = Num.f(cfg["fall_seconds"])
	var away := Vector2.from_angle(_fall_rng.randf() * TAU)
	down.drift = away * Num.f(cfg["fall_drift"]) / down.left
	falling.append(down)
	var crew := 0
	if _fall_rng.randf() < Num.f(cfg["bailout_chance"]):
		crew = _fall_rng.randi_range(1, Num.i(cfg["bailout_max"]))
	return {
		"fate": "spin", "seconds": down.left, "dx": down.drift.x, "dz": down.drift.y, "crew": crew
	}


## Falling wrecks drift down; each one that lands crashes.
func _fall(dt: float) -> void:
	var still: Array[Falling] = []
	for down: Falling in falling:
		down.left -= dt
		down.pos = sim.clamp_to_arena(down.pos + down.drift * dt)
		if down.left > 0.0:
			still.append(down)
			continue
		sim.events.append(
			{"type": "heli_crashed", "heli": down.id, "x": down.pos.x, "z": down.pos.y}
		)
		_crash(down.pos)
	falling = still


## The wreck hits the street at `at`: it sets the building it hits burning, which spreads with
## City Ablaze (D-141), and smashes the low floors around it. It hurts the city and the army
## below (D-167), never the kaiju or the sky.
func _crash(at: Vector2) -> void:
	var radius := Num.f(cfg["crash_radius"])
	var nearest := -1
	var best := radius
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.frame.alive_count == 0:
			continue
		var gap := Vector2(
			maxf(0.0, absf(at.x - b.x) - b.w * 0.5), maxf(0.0, absf(at.y - b.z) - b.d * 0.5)
		)
		if gap.length() <= best:
			best = gap.length()
			nearest = i
	if nearest >= 0:
		sim.powers.fire.ignite(nearest)
	_crashing = true
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(at) - r, radius),
		Num.f(cfg["crash_damage"]),
		0,
		Num.i(cfg["crash_floors"])
	)
	_crashing = false
	_crush_roofs(at, radius)


## The wreck lands on the roofs under it (D-167, D-173): every rooftop squad and every perched
## Taskforce agent on a building the impact reaches dies, at any floor (the building's footprint
## decides, as for hit_buildings, not the floor range). Squads have no hp, so a reach above 0 is
## enough, as for any splash (Army.splash). Only the crash does this; stomps and bites keep their
## floor ranges. Agents jetpacking in the air, the kaiju and the sky are not touched.
func _crush_roofs(at: Vector2, radius: float) -> void:
	var struck := func(index: int) -> bool: return _struck(sim.buildings[index], at, radius)
	for squad: Army.Squad in sim.army_units.squads:
		if struck.call(squad.building):
			squad.dead = true
	sim.army_units.clear_dead()
	sim.army_units.taskforce.crush_perched(struck)


## Does the crash at `at` reach building `b`'s footprint (hit_buildings' own test)?
func _struck(b: RampageSim.Building, at: Vector2, radius: float) -> bool:
	var reach := Vector2(b.w, b.d).length() * 0.5
	return RampageSim.falloff(Vector2(b.x, b.z).distance_to(at) - reach, radius) > 0.0
