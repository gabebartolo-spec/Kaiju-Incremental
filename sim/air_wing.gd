class_name AirWing
extends RefCounted
## Military helicopters (D-037): once the kaiju has done enough damage they arrive, circle it
## and strafe it. A kaiju reaches them only when it stands tall enough (a grown body or a
## climbed roof) or with an attack that reaches the air (fire, ink, tentacles); a cephalopod
## can pluck one out of the sky. They keep to the far side of the kaiju from the game camera
## (`camera_bearing`, clear of `clear_arc` either side of it) and cruise `clear_margin` beyond
## its body, so a helicopter never hangs between the player and the kaiju. Part of RampageSim.
## Pure and seeded.
## Like a real gunship section (D-066): a second helicopter flies as the first one's wingman,
## trailing it wing_gap back and wing_out wider. Between runs they orbit at cruise distance; every
## run_every seconds the lead turns in on an attack run down to attack_clear beyond the kaiju's
## body (never over or inside it), holds a strafing pass along its arc for run_hold seconds,
## firing only on the run, and breaks back out. If the kaiju turns to face either of the
## pair, they break off at once and reverse their sweep.

const ORBIT := 0
const RUN := 1
const BREAK := 2


class Heli:
	var id: int
	var angle: float
	var turn := 1.0  # which way it sweeps along its arc
	var radius: float  # its circle: sets its speed and how deep it dives
	var cruise: float  # how far out it flies between dives (clear of the kaiju's body)
	var r: float  # how far out it is now
	var state := ORBIT
	var run_t := 0.0  # seconds to its next attack run
	var wing_of := -1  # the lead it flies wing for (-1: it leads)
	var pos: Vector2
	var hp: float
	var cooldown: float
	var coat_t := 0.0
	var coat_dps := 0.0


var sim: RampageSim
var cfg: Dictionary
var helis: Array[Heli] = []
var destroyed := 0
var _form: Dictionary  # air.formation: pairs, runs and break-offs (D-066)
var _rng: RandomNumberGenerator
var _spawn_timer := 0.0
var _next_id := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_form = cfg["formation"]
	_rng = rng


func altitude() -> float:
	return Num.f(cfg["altitude"])


## How many may be up at once: more the more of the city has fallen.
func cap() -> int:
	var after := Num.i(cfg["after_chunks"])
	if sim.chunks_destroyed < after:
		return 0
	var extra := (sim.chunks_destroyed - after) / maxi(1, Num.i(cfg["max_per_chunks"]))
	return mini(Num.i(cfg["max"]), 1 + extra)


func step(dt: float) -> void:
	# The call-in clock only runs while the sky is short of helicopters: a kill is replaced
	# after `interval`, never on the next step.
	if helis.size() < cap():
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer = Num.f(cfg["interval"])
			spawn()
	var coated := false
	for heli: Heli in helis:
		if heli.wing_of < 0:
			_lead(heli, dt)
	for heli: Heli in helis:
		if heli.wing_of >= 0:
			_wing(heli, dt)
	for heli: Heli in helis:
		_keep_clear(heli)
		heli.pos = orbit_pos(heli)
		if heli.coat_t > 0.0:
			heli.coat_t -= dt
			heli.hp -= heli.coat_dps * dt
			coated = true
		heli.cooldown -= dt
		if heli.cooldown <= 0.0 and heli.state == RUN:  # guns only on an attack run
			heli.cooldown = Num.f(cfg["fire_interval"])
			var army := sim.army
			var hurt := Num.f(cfg["damage"]) - sim.stat("armor")
			sim.hp -= maxf(Num.f(army["min_damage"]), hurt)
			sim.events.append({"type": "heli_fired", "heli": heli.id})
	if coated:
		clear_dead()


## A new helicopter joins the circle at a seeded angle and distance, or as wingman to a lead
## flying alone.
func spawn() -> Heli:
	var heli := Heli.new()
	heli.id = _next_id
	_next_id += 1
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	heli.angle = _bearing() + arc + _rng.randf() * (TAU - 2.0 * arc)
	var jitter := Num.f(cfg["orbit_jitter"])
	var circle := Num.f(cfg["orbit_radius"]) * _rng.randf_range(1.0 - jitter, 1.0 + jitter)
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	heli.radius = circle * sim.body_scale()
	heli.cruise = maxf(heli.radius, body + Num.f(cfg["clear_margin"]))
	heli.r = heli.cruise
	heli.run_t = _next_run()
	var lead := _lone_lead()
	if lead != null:
		heli.wing_of = lead.id
		heli.radius = lead.radius
		heli.cruise = lead.cruise
		heli.turn = lead.turn
		heli.angle = _slot(lead)
		heli.r = lead.r + Num.f(_form["wing_out"])
	heli.pos = orbit_pos(heli)
	heli.hp = Num.f(cfg["hp"])
	heli.cooldown = Num.f(cfg["fire_interval"]) * Num.f(cfg["first_burst_delay"])
	helis.append(heli)
	sim.events.append({"type": "heli_spawned", "heli": heli.id})
	return heli


func _lone_lead() -> Heli:
	for lead: Heli in helis:
		if lead.wing_of >= 0:
			continue
		if not helis.any(func(h: Heli) -> bool: return h.wing_of == lead.id):
			return lead
	return null


func _next_run() -> float:
	return Num.f(_form["run_every"]) * _rng.randf_range(0.75, 1.25)


## How close an attack run comes: attack_clear beyond the kaiju's body.
func attack_radius() -> float:
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	return body + Num.f(_form["attack_clear"])


## The lead flies the pair's pattern: orbit, run in, break out; faced, it breaks off at once.
func _lead(heli: Heli, dt: float) -> void:
	heli.angle += heli.turn * Num.f(cfg["orbit_speed"]) / maxf(1.0, heli.radius) * dt
	var faced := _faced(heli)
	for wing: Heli in helis:
		if wing.wing_of == heli.id:
			faced = faced or _faced(wing)
	var low := attack_radius()
	var out := maxf(heli.cruise, low)
	match heli.state:
		ORBIT:
			heli.r = move_toward(heli.r, out, Num.f(_form["break_speed"]) * dt)
			heli.run_t -= dt
			if heli.run_t <= 0.0 and not faced:
				heli.state = RUN
				heli.run_t = 0.0
		RUN:
			heli.r = move_toward(heli.r, low, Num.f(_form["run_speed"]) * dt)
			if heli.r <= low + 0.01:
				heli.run_t -= dt  # the strafing pass along the arc, run_hold long
			if faced:
				heli.turn = -heli.turn
				heli.state = BREAK
			elif heli.r <= low + 0.01 and heli.run_t <= -Num.f(_form["run_hold"]):
				heli.state = BREAK
		BREAK:
			heli.r = move_toward(heli.r, out, Num.f(_form["break_speed"]) * dt)
			if heli.r >= out - 0.01:
				heli.state = ORBIT
				heli.run_t = _next_run()


## The wingman holds its slot behind and outside its lead, closing on it at a bounded rate.
func _wing(heli: Heli, dt: float) -> void:
	var lead: Heli = null
	for h: Heli in helis:
		if h.id == heli.wing_of:
			lead = h
	if lead == null:  # its lead is down: it leads now, breaking out first
		heli.wing_of = -1
		heli.state = BREAK
		_lead(heli, dt)
		return
	heli.turn = lead.turn
	heli.state = lead.state
	heli.r = lead.r + Num.f(_form["wing_out"])
	var rate := Num.f(cfg["orbit_speed"]) * 2.0 / maxf(1.0, heli.r) * dt
	heli.angle += clampf(wrapf(_slot(lead) - heli.angle, -PI, PI), -rate, rate)


func _slot(lead: Heli) -> float:
	var r := lead.r + Num.f(_form["wing_out"])
	return lead.angle - lead.turn * Num.f(_form["wing_gap"]) / maxf(1.0, r)


## Is the kaiju facing this helicopter (within face_deg of its heading)?
func _faced(heli: Heli) -> bool:
	var to := orbit_pos(heli) - sim.kaiju_pos
	return absf(sim.facing.angle_to(to)) < deg_to_rad(Num.f(_form["face_deg"]))


## Where it flies: on its bearing from the kaiju, r out.
func orbit_pos(heli: Heli) -> Vector2:
	return sim.kaiju_pos + Vector2.from_angle(heli.angle) * heli.r


## The direction from the kaiju toward the game camera, on the ground plane.
func _bearing() -> float:
	return deg_to_rad(Num.f(cfg["camera_bearing"]))


## Turns a helicopter back at either end of its arc, so it never crosses the camera's side.
func _keep_clear(heli: Heli) -> void:
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	var side := wrapf(heli.angle - _bearing(), 0.0, TAU)
	if side < arc:
		heli.angle = _bearing() + arc
		heli.turn = 1.0
	elif side > TAU - arc:
		heli.angle = _bearing() + TAU - arc
		heli.turn = -1.0


## An attack's force reaches helicopters only when reaches_air (else they fly too high).
func hit(force: Callable, damage: float, reaches_air: bool) -> void:
	if not reaches_air or helis.is_empty():
		return
	for heli: Heli in helis:
		var k: float = force.call(heli.pos, Num.f(cfg["heli_radius"]))
		heli.hp -= damage * k
		if k > 0.0 and not sim.hit_coat.is_empty():
			heli.coat_t = Num.f(sim.hit_coat["seconds"])
			heli.coat_dps = Num.f(sim.hit_coat["dps"]) * Num.f(sim.powers_cfg["ink_unit_mult"])
	clear_dead()


func clear_dead() -> void:
	var alive: Array[Heli] = []
	for heli: Heli in helis:
		if heli.hp > 0.0:
			alive.append(heli)
			continue
		destroyed += 1
		sim.rubble += Num.f(cfg["rubble"]) * sim.stat("rubble_mult")
		sim.events.append(
			{"type": "heli_destroyed", "heli": heli.id, "x": heli.pos.x, "z": heli.pos.y}
		)
	helis = alive
