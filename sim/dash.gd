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
## The flight's height (LeapArc): high over the street, down on the target's roof.
var arc: LeapArc
var _stages: Array = []
var _stage: Dictionary = {}
var _phase := -1  # index into PHASES; -1: no leap
var _t := 0.0  # seconds into the current phase


## contact: tuning "contact"; the leap reads its "leap" sub-object.
func _init(p_body: BodyContact, contact: Dictionary) -> void:
	body = p_body
	sim = body.sim
	cfg = contact.get("leap", {})
	arc = LeapArc.new(sim)


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


## How high the body is above the street (world units): the arc through the flight; through the
## settle it sinks from the roof it landed on to the street as the building breaks under it (the
## body's sweep breaks what it sinks into); zero otherwise.
func height() -> float:
	match phase():
		"flight":
			return arc.at(phase_t())
		"settle":
			return arc.land_y * (1.0 - phase_t() * phase_t())
	return 0.0


## Starts a leap when pressed and ready, then carries it through its phases. Before the sweep.
func step(dt: float, pressed: bool) -> void:
	ready_in = maxf(0.0, ready_in - dt)
	if pressed and can_leap():
		_start(aim_at(sim.kaiju_pos, sim.facing))
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


## True when a press now would leap: ready, idle, on the ground, and with somewhere to land other
## than where it stands (at the arena's edge, or against a tower it may not land on, it has none).
func can_leap() -> bool:
	if ready_in > 0.0 or _phase >= 0 or not available() or sim.airborne:
		return false
	var aim := aim_at(sim.kaiju_pos, sim.facing)
	var to_pos: Vector2 = aim["to"]  # within a landing step of where it stands: nowhere to go
	return to_pos.distance_to(sim.kaiju_pos) >= Num.f(cfg["landing_step"])


## The building a press now would land on (-1 for none, or when it would not leap): the pacing
## bot presses only for one.
func target_ahead() -> int:
	return Num.i(aim_at(sim.kaiju_pos, sim.facing)["building"]) if can_leap() else -1


## The leap to `aim` (aim_at's) begins: the crouch, the cooldown.
func _start(aim: Dictionary) -> void:
	_stage = _now()
	ready_in = Num.f(_stage["cooldown"])
	dashes += 1
	dir = sim.facing
	from = sim.kaiju_pos
	target = Num.i(aim["building"])
	to = aim["to"]
	var numbers := Vector4(
		Num.f(aim["roof"]),
		Num.f(_stage["clear"]) * sim.body_scale(),
		Num.f(cfg["landing_step"]),
		Num.f(cfg["arc_tries"])
	)
	arc.plan(body.discs(), PackedVector2Array([from, to]), dir, numbers)
	_phase = 0
	_t = 0.0
	var leap := {"type": "leap", "from": from, "to": to, "building": target, "dir": dir}
	for n: int in PHASES.size():
		leap[PHASES[n]] = _phase_s(n)
	leap["apex"] = arc.top
	leap["roof"] = arc.land_y
	sim.events.append(leap)


## Where a leap from `at` along `ahead` lands: {"building": index or -1, "to": kaiju_pos there,
## "roof": the height it lands at}. The feet come down on the roof of the nearest standing building
## in the arena whose centre lies within the aim cone and between min_reach and reach of them; with
## none, on the street at the full reach along `ahead`. A building that dwarfs the body (D-091), or
## a landing whose body would sit in one, is not landed on: the body comes down on the street
## before it, clear of it, and the blow chews its wall.
func aim_at(at: Vector2, ahead: Vector2) -> Dictionary:
	var feet := at + ahead * body.feet_ahead()
	var best := _nearest_ahead(feet, ahead)
	var land := feet + ahead * Num.f(_now()["reach"]) * sim.body_scale()
	var roof := 0.0
	if best >= 0:
		var b := sim.buildings[best]
		land = Vector2(b.x, b.z)
		roof = float(b.height)
	var to := sim.clamp_to_arena(land - ahead * body.feet_ahead())
	if best >= 0 and (_dwarfs(best) or _in_tower(to, ahead, roof)):
		roof = 0.0
		var step := Num.f(cfg["landing_step"])
		while to != at and _in_tower(to, ahead, 0.0):
			to = to.move_toward(at, step)
	return {"building": best, "to": to, "roof": roof}


## The nearest standing building in the arena whose centre is in the aim cone along `ahead` and
## between min_reach and reach of `feet`; -1 for none.
func _nearest_ahead(feet: Vector2, ahead: Vector2) -> int:
	var s := sim.body_scale()
	var reach := Num.f(_now()["reach"]) * s
	var near := Num.f(_now()["min_reach"]) * s
	var cone := cos(deg_to_rad(Num.f(cfg["aim_half_angle_deg"])))
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var off := Vector2(b.x, b.z) - feet
		var d := off.length()
		if b.frame.alive_count == 0 or not b.in_arena or d < near or d > reach or d >= best_d:
			continue
		if off.normalized().dot(ahead) >= cone:
			best = i
			best_d = d
	return best


func _dwarfs(index: int) -> bool:
	return Growth.dwarf_mult(sim.size_tier(), sim.buildings[index].tier, sim.city) < 1.0


## Whether the body at `pose`, lifted `lift`, overlaps a standing building that dwarfs it.
func _in_tower(pose: Vector2, ahead: Vector2, lift: float) -> bool:
	body.set_lift(lift)
	var inside := body.inside(pose, ahead)
	body.set_lift(height())
	for index: int in inside:
		if _dwarfs(index):
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
	var top := maxi(ceili(sim.reach_top()), ceili(arc.land_y) + 1)  # landed on a roof: all of it
	sim.hit_area(force, Num.f(_stage["damage"]) * sim.powers.hit_mult(), 0, top)


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
