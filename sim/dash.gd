class_name Dash
extends RefCounted
## The dash button (Shift / pad B). Its move is the croc's leap (D-259, "a leap that lands on a
## building and crushes it with a shockwave (replaces the dash)"): the body crouches, flies a fixed
## time along its facing to the standing building ahead in reach (else the full reach), and lands:
## the landing is one blow through the carve path (RampageSim.hit_area, D-253) that crushes what is
## under it and sends a shockwave ring through units and buildings around it, flinging tanks
## outward (b2-9); damage lands on the contact, never on the press (D-166). Then it settles and
## recovers, standing, before it walks again. Phase times, reach, ring, damage and cooldown are per
## stage in data/tuning.json contact.leap (times from the reader's bars, C:/kt/croc_kit/reference.md
## L1). Only a species listed there with a body volume leaps; the old charge is gone (no species
## keeps it). Part of RampageSim (BodyContact owns it); pure, no randomness.

## The step() button flag for the dash button, beside RampageSim.HELD and ULTIMATE.
const BUTTON := 4
## The leap's phases, in order; "" when no leap is under way.
const PHASES: Array[String] = ["crouch", "flight", "settle", "recover"]

var sim: RampageSim
var body: BodyContact
## data/tuning.json contact.leap (aim, and the stages per species).
var cfg: Dictionary
## Seconds until the button is ready again (from the press).
var ready_in := 0.0
## Presses that started a leap this rampage (the Taskforce's frost reads it: a leap shatters ice).
var dashes := 0
## Leaps that landed this rampage.
var landings := 0
## Where the leap under way sets off and lands (kaiju_pos), and the building it aims at (-1: none).
var from := Vector2.ZERO
var to := Vector2.ZERO
var target := -1
var dir := Vector2.ZERO
var _stages: Array = []
var _stage: Dictionary = {}
var _phase := -1  # index into PHASES; -1: no leap
var _t := 0.0  # seconds into the current phase


## contact: tuning "contact"; the leap reads its "leap" sub-object.
func _init(p_body: BodyContact, contact: Dictionary) -> void:
	body = p_body
	sim = body.sim
	cfg = contact.get("leap", {})


## Picks the species' stages (none: this species has no leap).
func use_species(species_id: String) -> void:
	var by_species: Dictionary = cfg.get("stages", {})
	_stages = by_species.get(species_id, [])


## A leap is under way (any phase): the body takes no stick and holds its facing.
func on() -> bool:
	return _phase >= 0


func available() -> bool:
	return body.active() and not _stages.is_empty()


## The cooldown of the stage the kaiju is at (seconds, press to ready).
func cooldown() -> float:
	return Num.f(_now().get("cooldown", 0.0))


## The phase under way ("crouch", "flight", "settle", "recover"), "" with no leap.
func phase() -> String:
	return PHASES[_phase] if _phase >= 0 else ""


## How far through its phase the leap is, 0..1.
func phase_t() -> float:
	return clampf(_t / maxf(0.001, _phase_s(_phase)), 0.0, 1.0) if _phase >= 0 else 0.0


## The phase's seconds at the kaiju's stage (presentation holds its poses on them).
func phase_seconds(phase_name: String) -> float:
	return _phase_s(PHASES.find(phase_name))


## How high the body is above where it stands (world units): a parabola through the flight,
## apex at mid-flight, zero on the ground.
func height() -> float:
	if phase() != "flight":
		return 0.0
	var s := phase_t()
	return 4.0 * Num.f(_stage["apex"]) * sim.body_scale() * s * (1.0 - s)


## Starts a leap when pressed and ready, then carries it through its phases. Before the sweep.
func step(dt: float, pressed: bool) -> void:
	ready_in = maxf(0.0, ready_in - dt)
	if pressed and ready_in <= 0.0 and _phase < 0 and available() and not sim.airborne:
		_start()
		return
	if _phase < 0:
		return
	sim.facing = dir
	_t += dt
	while _phase >= 0 and _t >= _phase_s(_phase):
		_t -= _phase_s(_phase)
		_next()
	if phase() == "flight":
		sim.kaiju_pos = from.lerp(to, phase_t())


## The building ahead in reach the leap lands on, the landing spot, the crouch begins.
func _start() -> void:
	_stage = _now()
	ready_in = Num.f(_stage["cooldown"])
	dashes += 1
	dir = sim.facing
	from = sim.kaiju_pos
	var aim := aim_at(from, dir)
	target = Num.i(aim["building"])
	to = aim["to"]
	_phase = 0
	_t = 0.0
	var leap := {"type": "leap", "from": from, "to": to, "building": target, "dir": dir}
	for n: int in PHASES.size():
		leap[PHASES[n]] = _phase_s(n)
	leap["apex"] = Num.f(_stage["apex"]) * sim.body_scale()
	sim.events.append(leap)


## Where a leap from `at` along `ahead` lands: {"building": index or -1, "to": kaiju_pos there}.
## The feet come down on the nearest standing building in the arena whose centre lies within the
## aim cone and between min_reach and reach of them; with none, the full reach along `ahead`.
func aim_at(at: Vector2, ahead: Vector2) -> Dictionary:
	var stage := _now()
	var s := sim.body_scale()
	var feet := at + ahead * body.feet_ahead()
	var reach := Num.f(stage["reach"]) * s
	var near := Num.f(stage["min_reach"]) * s
	var cone := cos(deg_to_rad(Num.f(cfg["aim_half_angle_deg"])))
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.frame.alive_count == 0 or not b.in_arena:
			continue
		var off := Vector2(b.x, b.z) - feet
		var d := off.length()
		if d < near or d > reach or d >= best_d or off.normalized().dot(ahead) < cone:
			continue
		best = i
		best_d = d
	var land := feet + ahead * reach
	if best >= 0:
		land = Vector2(sim.buildings[best].x, sim.buildings[best].z)
	var to := sim.clamp_to_arena(land - ahead * body.feet_ahead())
	return {"building": best, "to": _clear_of_towers(at, to, ahead)}


## How far the leap from `start` to `land` gets before its body, on its arc, would enter a building
## that dwarfs it (D-091: such a building is chewed, never passed through): it comes down at the
## last clear pose, against that wall. Whatever else the body flies or lands in breaks
## (BodyContact's sweep, lifted by the arc).
func _clear_of_towers(start: Vector2, land: Vector2, ahead: Vector2) -> Vector2:
	var step := Num.f(cfg["landing_step"])
	var span := start.distance_to(land)
	var apex := Num.f(_now()["apex"]) * sim.body_scale()
	var clear := start
	for n: int in ceili(span / step) + 1:
		var f := minf(1.0, n * step / maxf(span, 0.001))
		var pose := start.lerp(land, f)
		if _in_tower(pose, ahead, 4.0 * apex * f * (1.0 - f)):
			break
		clear = pose
	if clear != land:  # it comes down short: that pose on the ground must be clear too
		while clear != start and _in_tower(clear, ahead, 0.0):
			clear = clear.move_toward(start, step)
	return clear


## Whether the body at `pose`, lifted `lift`, overlaps a standing building that dwarfs it.
func _in_tower(pose: Vector2, ahead: Vector2, lift: float) -> bool:
	body.set_lift(lift)
	var inside := body.inside(pose, ahead)
	body.set_lift(height())
	for index: int in inside:
		if Growth.dwarf_mult(sim.size_tier(), sim.buildings[index].tier, sim.city) < 1.0:
			return true
	return false


func _next() -> void:
	match phase():
		"crouch":
			sim.airborne = true  # stomps, claws and the body's sweep wait for the landing
			sim.events.append({"type": "leap_off", "at": from})
		"flight":
			sim.kaiju_pos = to
			sim.airborne = false
			_land()
	_phase += 1
	if _phase >= PHASES.size():
		_phase = -1
		_t = 0.0


## The contact: tanks in the ring are flung outward, then one blow crushes what is under the feet
## at full force within the ring, fading to nothing at twice its radius (RampageSim.falloff).
func _land() -> void:
	landings += 1
	var s := sim.body_scale()
	var ring := Num.f(_stage["ring"]) * s
	var centre := to + dir * body.feet_ahead()
	(
		sim
		. events
		. append(
			{
				"type": "leap_land",
				"at": centre,
				"radius": ring,
				"building": target,
				"damage": Num.f(_stage["damage"]),
			}
		)
	)
	var force := func(p: Vector2, r: float) -> float:
		return RampageSim.falloff(p.distance_to(centre) - r, ring)
	_fling(centre, force, Num.f(_stage["fling"]) * s)
	sim.hit_area(force, Num.f(_stage["damage"]) * sim.powers.hit_mult())


## Every tank the ring reaches slides outward from the centre by `fling` x its force (a tank under
## the feet goes straight along the leap).
func _fling(centre: Vector2, force: Callable, fling: float) -> void:
	for tank: RampageSim.Tank in sim.tanks:
		var k := Num.f(force.call(tank.pos, RampageSim.TANK_RADIUS))
		if k <= 0.0:
			continue
		var out := tank.pos - centre
		out = dir if out.length() < 0.01 else out.normalized()
		var was := tank.pos
		tank.pos = sim.clamp_to_arena(tank.pos + out * fling * k)
		sim.events.append({"type": "tank_flung", "tank": tank.id, "from": was, "to": tank.pos})


## The stage's leap numbers (the kaiju's size tier; empty with no leap).
func _now() -> Dictionary:
	if _stages.is_empty():
		return {}
	return _stages[clampi(sim.size_tier() - 1, 0, _stages.size() - 1)]


## A phase's seconds: the leap under way's, else the stage's now.
func _phase_s(index: int) -> float:
	var stage := _stage if _phase >= 0 else _now()
	if index < 0 or stage.is_empty():
		return 0.0
	return Num.f(stage[PHASES[index] + "_s"])
