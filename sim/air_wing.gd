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
## trailing it wing_gap along their arc, `stagger` higher, on the same side of it through every
## turn, and holds out at cruise covering its lead's run. Between runs they orbit at cruise
## distance, drawn in where that would leave the game camera's frame (AirSpace); every
## run_every seconds the lead turns in on an attack run down to attack_clear beyond the kaiju's
## body (never over or inside it), holds a strafing pass along its arc for run_hold seconds,
## nose on the kaiju (guns only on the run, within fire_cone of the nose), and breaks back out.
## If the kaiju turns to face either of the pair, they break off and reverse their sweep. A
## reversal is flown, not pivoted: the sweep eases through reverse_s while it swings `swing`
## wider, and the nose follows its flight at yaw_rate. Each flies roof_clear over the tallest
## roof within `facade` of its way (AirSpace).

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
	var side := 1.0  # a wingman: which way along the arc it trails its lead (fixed)
	var pos: Vector2
	var omega := 0.0  # how fast it sweeps along its arc now (rad/s, signed)
	var front := Vector2.ZERO  # where its nose points (the view draws it)
	var alt := 0.0  # how high it flies
	var hp: float
	var cooldown: float
	var coat_t := 0.0
	var coat_dps := 0.0


var sim: RampageSim
var cfg: Dictionary
var helis: Array[Heli] = []
var destroyed := 0
var space: AirSpace
var _form: Dictionary  # air.formation: pairs, runs and break-offs (D-066)
var _rng: RandomNumberGenerator
var _spawn_timer := 0.0
var _next_id := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_form = cfg["formation"]
	_rng = rng
	space = AirSpace.new(sim, cfg)


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
		_fly(heli, orbit_pos(heli), dt)
		if heli.coat_t > 0.0:
			heli.coat_t -= dt
			heli.hp -= heli.coat_dps * dt
			coated = true
		heli.cooldown -= dt
		if heli.cooldown <= 0.0 and heli.state == RUN and _on_target(heli):  # guns on a run only
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
		heli.r = lead.r
		heli.side = -lead.turn  # behind it, or ahead while behind is on the camera's side
		if _off_arc(_slot(lead, heli)) < 0.0:
			heli.side = lead.turn
		heli.angle = _slot(lead, heli)
	heli.pos = orbit_pos(heli)
	heli.front = (sim.kaiju_pos - heli.pos).normalized().orthogonal() * heli.turn
	heli.alt = _alt(heli, heli.pos)
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
	var sweep := Num.f(cfg["orbit_speed"]) / maxf(1.0, heli.radius)
	var low := attack_radius()
	var aim := heli.turn * sweep
	if heli.state == RUN and heli.r > low + 0.01:  # the run is flown in at it, not round it
		aim *= Num.f(_form["run_sweep"])
	elif heli.state == RUN:  # the strafing pass, at run_speed along the arc
		aim = heli.turn * Num.f(_form["run_speed"]) / maxf(1.0, heli.r)
	heli.omega = move_toward(heli.omega, aim, 2.0 * sweep / Num.f(_form["reverse_s"]) * dt)
	heli.angle += heli.omega * dt
	var faced := _faced(heli)
	for wing: Heli in helis:
		if wing.wing_of == heli.id:
			faced = faced or _faced(wing)
	var out := maxf(heli.cruise, low)
	# Turning about, it swings wide as its sweep slows, so it never stands still in the air.
	var wide := out + Num.f(_form["swing"]) * clampf(1.0 - absf(heli.omega) / sweep, 0.0, 1.0)
	match heli.state:
		ORBIT:
			heli.r = move_toward(heli.r, wide, Num.f(_form["break_speed"]) * dt)
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
			heli.r = move_toward(heli.r, wide, Num.f(_form["break_speed"]) * dt)
			if heli.r >= minf(out, _framed(heli, out)) - 0.01:
				heli.state = ORBIT
				heli.run_t = _next_run()
	var pull := Num.f(_form["break_speed"]) * 2.0 * dt  # drawn in, flown not jumped
	heli.r = move_toward(heli.r, minf(heli.r, _framed(heli, heli.r)), pull)


## r, or as far out as heli stays in the game camera's frame on its bearing over the roofs
## there (AirSpace.reach; never in past an attack run). Where it may be nowhere it holds r: it
## never falls back on the kaiju (the pair turns back short of such a block, _blocked).
func _framed(heli: Heli, r: float) -> float:
	var low := minf(r, attack_radius())
	var up := Num.f(_form["stagger"]) if heli.wing_of >= 0 else 0.0
	var at := space.reach(heli.angle, low, r, up)
	return at if at >= 0.0 else r


## The wingman holds its slot on its side of its lead, closing on it at a bounded rate, out at
## cruise (in the frame) while its lead runs in.
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
	heli.run_t = lead.run_t
	var post := _framed(heli, maxf(lead.r, maxf(lead.cruise, attack_radius())))
	heli.r = move_toward(heli.r, post, Num.f(_form["break_speed"]) * 2.0 * dt)
	var rate := Num.f(cfg["orbit_speed"]) * 2.0 / maxf(1.0, heli.r) * dt
	heli.angle += clampf(wrapf(_slot(lead, heli) - heli.angle, -PI, PI), -rate, rate)


## wing_gap along the arc from its lead, on its own side (a chord at the nearer one's radius).
func _slot(lead: Heli, wing: Heli) -> float:
	var r := maxf(1.0, minf(lead.r, wing.r))
	return lead.angle + wing.side * 2.0 * asin(minf(1.0, Num.f(_form["wing_gap"]) / (2.0 * r)))


## Is the kaiju facing this helicopter (within face_deg of its heading)?
func _faced(heli: Heli) -> bool:
	var to := orbit_pos(heli) - sim.kaiju_pos
	return absf(sim.facing.angle_to(to)) < deg_to_rad(Num.f(_form["face_deg"]))


## Where it flies: on its bearing from the kaiju, r out.
func orbit_pos(heli: Heli) -> Vector2:
	return sim.kaiju_pos + Vector2.from_angle(heli.angle) * heli.r


## Is there nowhere in the frame on the bearing the pair's front (sides lo / hi from the camera)
## will reach as its reversal ends (stop) plus look_ahead?
func _blocked(heli: Heli, lo: float, hi: float, stop: float) -> bool:
	var front := (hi if heli.turn > 0.0 else lo) + _bearing()
	var ahead := front + heli.turn * (stop + Num.f(_form["look_ahead"]) / maxf(1.0, heli.r))
	return space.reach(ahead, attack_radius(), maxf(heli.cruise, attack_radius())) < 0.0


## How far `angle` lies outside the camera's side (clear_arc either side of camera_bearing):
## negative inside it.
func _off_arc(angle: float) -> float:
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	return absf(wrapf(angle - _bearing(), -PI, PI)) - arc


## The direction from the kaiju toward the game camera, on the ground plane.
func _bearing() -> float:
	return deg_to_rad(Num.f(cfg["camera_bearing"]))


## Turns a helicopter back before either end of its arc (in time for its eased reversal to
## stop short of it, its wingman too), so it never crosses the camera's side; held at the end
## should it not.
func _keep_clear(heli: Heli) -> void:
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	var side := wrapf(heli.angle - _bearing(), 0.0, TAU)
	var sweep := Num.f(cfg["orbit_speed"]) / maxf(1.0, heli.radius)
	var stop := heli.omega * heli.omega * Num.f(_form["reverse_s"]) / (4.0 * sweep) + 0.05
	var lo := side
	var hi := side
	for wing: Heli in helis:
		if wing.wing_of == heli.id:
			var at := side + wrapf(_slot(heli, wing) - heli.angle, -PI, PI)
			lo = minf(lo, at)
			hi = maxf(hi, at)
	if heli.wing_of < 0 and heli.turn * heli.omega > 0.0 and _blocked(heli, lo, hi, stop):
		heli.turn = -heli.turn  # a tall block ahead: it turns back short of it, not over it
	elif lo < arc + stop and heli.turn < 0.0 and heli.wing_of < 0:
		heli.turn = 1.0
	elif hi > TAU - arc - stop and heli.turn > 0.0 and heli.wing_of < 0:
		heli.turn = -1.0
	if side < arc or side > TAU - arc:
		heli.angle = _bearing() + (arc if side < PI else TAU - arc)
		heli.omega = 0.0


## Moves a helicopter to `to`: its nose follows its flight at yaw_rate (lining up on the kaiju
## just before a run, holding it on the run), and it keeps roof_clear over the roofs under it.
func _fly(heli: Heli, to: Vector2, dt: float) -> void:
	var moved := to - heli.pos
	heli.pos = to
	var want := heli.front
	var line_up := PI * 0.5 / deg_to_rad(Num.f(_form["yaw_rate"]))  # turns in ahead of its run
	if heli.state == RUN or heli.state == ORBIT and heli.run_t < line_up:
		want = (sim.kaiju_pos - to).normalized()
	elif moved.length() > 2.0 * dt:  # (below 2 m/s it holds its nose)
		want = moved.normalized()
	if heli.front == Vector2.ZERO:
		heli.front = want
	var slow := moved.length() < 3.0 * dt  # (near a hover it turns its nose only slowly)
	var rate := deg_to_rad(Num.f(_form["hover_yaw" if slow else "yaw_rate"])) * dt
	heli.front = heli.front.rotated(clampf(heli.front.angle_to(want), -rate, rate))
	var over := _alt(heli, to)
	heli.alt = move_toward(heli.alt, over, Num.f(_form["climb"]) * dt)


func _on_target(heli: Heli) -> bool:
	var to := sim.kaiju_pos - heli.pos
	return absf(heli.front.angle_to(to)) <= deg_to_rad(Num.f(_form["fire_cone"]))


## How high it flies at p (AirSpace.alt_at: the height its frame was planned for), a wingman
## `stagger` over that.
func _alt(heli: Heli, p: Vector2) -> float:
	var up := Num.f(_form["stagger"]) if heli.wing_of >= 0 else 0.0
	return space.alt_at(p) + up


## An attack's force reaches helicopters only when reaches_air (else they fly too high: the
## air layer is `altitude`, D-037; clearing a roof is how high one is drawn, not a reprieve).
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
