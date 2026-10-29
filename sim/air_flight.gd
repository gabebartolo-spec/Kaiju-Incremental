class_name AirFlight
extends RefCounted
## How the military helicopters fly (D-183 "Stand-off gunships", motion first D-177). Each one
## has its own position, velocity and nose and steers for its firing position: a slot on a ring
## well beyond the kaiju's claws (`standoff` x body scale, so it grows with him) that goes where
## he goes, `lead_seconds` of his walk ahead of him. It is never pinned to him: its speed,
## acceleration and nose turn are limited (`heli_speed`, `heli_accel`, `heli_turn_deg`), so it
## glides to its slot, matches the kaiju's walk, backs off in front of him when he walks at it
## and hovers facing him when he stops. When he comes within `pull_back` of it, its slot is
## straight behind it. After `hold_seconds` it glides along the ring to another slot (`glide_deg`).
## Now and then (`strafe_gap`) ONE helicopter makes a strafing pass: a fly-by at full speed along a
## straight flank line along the camera's view that passes `strafe_close` from him, inside his claw
## reach, aimed at where he will be (his smoothed walk); it never brakes, is over `strafe_exit` past
## him and turns back out to its slot. Slots keep `clear_arc` (and `clear_lead_deg` more) off the
## camera's side (`camera_bearing`); a pass flies a flank line that never crosses the corridor
## between the camera and him.
## Part of AirWing; pure, on its own seeded stream.

var sim: RampageSim
var cfg: Dictionary
## Strafing passes started this run.
var passes := 0
var _rng: RandomNumberGenerator
var _gap_left: float
var _anchor := Vector2.ZERO  # where the pilots take the kaiju to be (smoothed, `anchor_seconds`)
var _walk := Vector2.ZERO  # the anchor's velocity, units a second: where the pilots expect it to go


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng
	_gap_left = _span("strafe_gap")
	_anchor = sim.kaiju_pos


## A new helicopter: on the far side of the kaiju from the camera, `spawn_far` rings out, flying
## in to its slot.
func place(heli: AirWing.Heli) -> void:
	var jitter := Num.f(cfg["standoff_jitter"])
	heli.ring = (
		Num.f(cfg["standoff"]) * sim.body_scale() * _rng.randf_range(1.0 - jitter, 1.0 + jitter)
	)
	var arc := _arc()
	heli.slot = _bearing() + arc + _rng.randf() * (TAU - 2.0 * arc)
	heli.goal = _slot_point(heli)
	heli.pos = sim.kaiju_pos + Vector2.from_angle(heli.slot) * heli.ring * Num.f(cfg["spawn_far"])
	heli.heading = (sim.kaiju_pos - heli.pos).angle()
	heli.vel = Vector2.ZERO
	heli.hold = _span("hold_seconds")


## One step for every helicopter: the strafing clock, then each one's plan and flight.
func step(helis: Array[AirWing.Heli], dt: float) -> void:
	if dt <= 0.0:
		return
	_watch_kaiju(dt)
	_strafe_clock(helis, dt)
	for heli: AirWing.Heli in helis:
		_plan(heli, helis, dt)
		_steer(heli, dt)


## Where the pilots take the kaiju to be: his position smoothed over `anchor_seconds`, which is also
## about where the camera looks (his stepped turns swing the root point ten units a step).
func anchor() -> Vector2:
	return _anchor


## The pilots' estimate of where the kaiju is and where it is heading: his position smoothed over
## `anchor_seconds` (a stepped turn swings it ten units about the planted foot every few steps,
## which the pilots do not chase) and that anchor's velocity.
func _watch_kaiju(dt: float) -> void:
	var before := _anchor
	_anchor = _anchor.lerp(sim.kaiju_pos, minf(1.0, dt / Num.f(cfg["anchor_seconds"])))
	_walk = (_anchor - before) / dt


## Sends `heli` on a strafing pass (the clock does it now and then; a test may too).
func start_pass(heli: AirWing.Heli) -> void:
	var line := _pass_line(heli)
	heli.passing = true
	heli.run = false
	heli.pass_at = Vector2.from_angle(Num.f(line[0]))
	heli.pass_dir = heli.pass_at.orthogonal() * Num.f(line[1])
	heli.pass_left = Num.f(cfg["strafe_seconds"])
	passes += 1


## The line a pass of `heli` flies: [the bearing of its nearest point to the kaiju, +1 or -1 for
## the way along it, how far round the ring the heli's slot is from the line's entry end (radians)].
## The line passes `strafe_close` from him and runs out to the heli's ring at both ends. It is the
## flank pass on the side of the heli's slot (so it never crosses to the other side) that keeps
## clear of the corridor between the camera and him (`pass_corridor` x scale either side of the
## camera's line to him; D-183: it may cross the camera's side but never fly between the camera and
## him), so it runs along the camera's view beside him where the player sees it. Its entry is the
## end nearer the heli's slot.
func _pass_line(heli: AirWing.Heli) -> Array:
	var close := Num.f(cfg["strafe_close"]) * sim.body_scale()
	var centre := _flank(heli.slot, close, heli.ring)
	var best := [centre, 1.0, INF]
	for way: float in [1.0, -1.0]:
		var entry := _line_end(centre, close, heli.ring, -way)
		var apart := absf(wrapf(heli.slot - entry, -PI, PI))
		if apart < Num.f(best[2]):
			best = [centre, way, apart]
	return best


## The bearing of a pass's nearest point: the one of the two flanks (a quarter turn each side of the
## camera's bearing) on the side of `slot`, turned on until its line clears the corridor.
func _flank(slot: float, close: float, ring: float) -> float:
	var side := 1.0 if wrapf(slot - _bearing(), -PI, PI) >= 0.0 else -1.0
	for step: int in 37:
		var centre := _bearing() + side * (PI * 0.5 + deg_to_rad(5.0) * step)
		if _line_clear(centre, close, ring):
			return centre
	return _bearing() + side * PI


## Does the pass line with nearest point `close` out at bearing `centre` keep out of the corridor
## between the camera and the kaiju (on the camera's side, within `pass_corridor` of its line)?
func _line_clear(centre: float, close: float, ring: float) -> bool:
	var toward := Vector2.from_angle(_bearing())
	var near := Vector2.from_angle(centre)
	var half_len := sqrt(maxf(0.0, ring * ring - close * close))
	var wide := Num.f(cfg["pass_corridor"]) * sim.body_scale()
	var t := -half_len
	while t <= half_len:
		var at := near * close + near.orthogonal() * t
		if at.dot(toward) > 0.0 and absf(at.dot(toward.orthogonal())) < wide:
			return false
		t += 1.0
	return true


## The bearing from the kaiju of the end of the line (nearest point at bearing `centre`, `close`
## out) that lies `end` x its half-length along the way `way` points: the line's entry for -1.
func _line_end(centre: float, close: float, ring: float, end: float) -> float:
	var near := Vector2.from_angle(centre)
	var half_len := sqrt(maxf(0.0, ring * ring - close * close))
	return (near * close + near.orthogonal() * end * half_len).angle()


## The clock only runs while no pass is on; when it is up the helicopter whose slot is nearest the
## entry of a pass goes, if it is near enough (else the clock tries again soon).
func _strafe_clock(helis: Array[AirWing.Heli], dt: float) -> void:
	if helis.is_empty():
		return
	for heli: AirWing.Heli in helis:
		if heli.passing:
			return
	_gap_left -= dt
	if _gap_left > 0.0:
		return
	var pick: AirWing.Heli = null
	var least := deg_to_rad(Num.f(cfg["strafe_reach_deg"]))
	for heli: AirWing.Heli in helis:
		var apart := Num.f(_pass_line(heli)[2])
		if apart <= least:
			pick = heli
			least = apart
	if pick == null:
		_gap_left = Num.f(cfg["strafe_retry"])
		return
	_gap_left = _span("strafe_gap")
	start_pass(pick)


## Decides where `heli` steers: its pass, else its slot, which is straight behind it when the
## kaiju is within `pull_back` and a new one along the ring once it has held this one `hold` long.
func _plan(heli: AirWing.Heli, helis: Array[AirWing.Heli], dt: float) -> void:
	if heli.passing:
		_plan_pass(heli, dt)
		if heli.passing:
			return
	heli.hold -= dt
	var away := heli.pos - sim.kaiju_pos
	if away.length() < Num.f(cfg["pull_back"]) * sim.body_scale():
		heli.slot = _clear(away.angle())
	elif heli.hold <= 0.0:
		_glide(heli, helis)
	heli.goal = _slot_point(heli)


## A pass in two parts. It lines up: the helicopter flies to the entry end of the line (on its own
## side, beyond him, as it flies to a slot, braking to a hover) and once there (`arrive`, and
## drifting across the line no faster than it hovers: run sooner and it skids on over the line)
## it runs:
## it follows a point `strafe_carrot` ahead along the line (which moves with the kaiju's walk) at
## full speed; once abeam of him the line bends outward (`strafe_veer`, so it never swings back
## across the corridor) and it is over `strafe_exit` past him, where it turns back out to its slot.
func _plan_pass(heli: AirWing.Heli, dt: float) -> void:
	heli.pass_left -= dt
	var close := Num.f(cfg["strafe_close"]) * sim.body_scale()
	var origin := _anchor + _walk * Num.f(cfg["strafe_lead"]) + heli.pass_at * close
	var reach := sqrt(maxf(0.0, heli.ring * heli.ring - close * close))
	var along := (heli.pos - origin).dot(heli.pass_dir)
	if not heli.run:
		heli.goal = origin - heli.pass_dir * reach
		var hover := Num.f(cfg["nose_share"]) * Num.f(cfg["heli_speed"])
		heli.run = (
			heli.pos.distance_to(heli.goal) <= Num.f(cfg["arrive"]) * 2.0
			and absf(heli.vel.dot(heli.pass_at)) <= hover
		)
	if heli.run and along >= Num.f(cfg["strafe_exit"]) * sim.body_scale() or heli.pass_left <= 0.0:
		heli.passing = false
		heli.run = false
		heli.slot = _clear((heli.pos - sim.kaiju_pos).angle())
		heli.hold = _span("hold_seconds")
		return
	if heli.run:
		var carrot := clampf(along, -reach, reach) + Num.f(cfg["strafe_carrot"]) * sim.body_scale()
		var veer := maxf(0.0, carrot) * Num.f(cfg["strafe_veer"])  # past him the line bends outward
		heli.goal = origin + heli.pass_dir * carrot + heli.pass_at * veer


## The heli's slot moves along its ring by `glide_deg` to one side: the best of `slot_tries`
## seeded tries for room from the other helicopters' slots.
func _glide(heli: AirWing.Heli, helis: Array[AirWing.Heli]) -> void:
	var span: Array = cfg["glide_deg"]
	var best := heli.slot
	var room := -1.0
	for _try: int in Num.i(cfg["slot_tries"]):
		var turn := deg_to_rad(_rng.randf_range(Num.f(span[0]), Num.f(span[1])))
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var slot := _clear(heli.slot + side * turn)
		var apart := _room(slot, heli, helis)
		if apart > room:
			best = slot
			room = apart
	heli.slot = best
	heli.hold = _span("hold_seconds")


## How far round the ring `slot` is from the nearest other helicopter's slot (INF with none).
func _room(slot: float, heli: AirWing.Heli, helis: Array[AirWing.Heli]) -> float:
	var least := INF
	for other: AirWing.Heli in helis:
		if other != heli:
			least = minf(least, absf(wrapf(slot - other.slot, -PI, PI)))
	return least


## The flight: the velocity moves toward the one that brings it to its goal (matching the goal's
## own walk, braking to a stop at it) by at most `heli_accel` a second and never past
## `heli_speed`, so it glides, backs off and banks round without a jerk, however the kaiju
## lurches. Its nose turns at most `heli_turn_deg` a second, along its flight when it is moving
## (`nose_share` of top speed or more) and at the kaiju when it hovers.
func _steer(heli: AirWing.Heli, dt: float) -> void:
	var to := heli.goal - heli.pos
	var top := Num.f(cfg["heli_speed"])
	var accel := Num.f(cfg["heli_accel"])
	var want := _walk
	if heli.passing and heli.run:  # a fly-by: at full speed along the line, no braking
		want = to.normalized() * top
	elif to.length() > Num.f(cfg["arrive"]):
		want += to.normalized() * minf(top, sqrt(2.0 * accel * to.length()))
	heli.vel = heli.vel.move_toward(want.limit_length(top), accel * dt)
	heli.pos += heli.vel * dt
	var moving := heli.vel.length() >= Num.f(cfg["nose_share"]) * top
	var look := heli.vel if moving else sim.kaiju_pos - heli.pos
	var turn := deg_to_rad(Num.f(cfg["heli_turn_deg"])) * dt
	var err := wrapf(look.angle() - heli.heading, -PI, PI)
	heli.heading = wrapf(heli.heading + clampf(err, -turn, turn), -PI, PI)


## Where the heli's slot is now: on its ring round the kaiju, at its bearing, and when he is
## walking toward it `lead_seconds` of that walk further out, so it backs off before he is on
## it rather than after (his walk away from it moves the slot no nearer).
func _slot_point(heli: AirWing.Heli) -> Vector2:
	var out := Vector2.from_angle(heli.slot)
	var toward := maxf(0.0, _walk.dot(out))
	return _anchor + out * (heli.ring + toward * Num.f(cfg["lead_seconds"]))


## `angle` moved out of the camera's side (to the nearer edge of the clear arc) if it is in it.
func _clear(angle: float) -> float:
	return _clear_by(angle, _arc())


## `angle` moved to at least `arc` radians round from the camera's bearing (the nearer way).
func _clear_by(angle: float, arc: float) -> float:
	var side := wrapf(angle - _bearing(), -PI, PI)
	if absf(side) >= arc:
		return angle
	return _bearing() + (arc if side >= 0.0 else -arc)


## The half-width of the camera's side no slot may be in: `clear_arc` and `clear_lead_deg` more.
func _arc() -> float:
	return deg_to_rad(Num.f(cfg["clear_arc"]) + Num.f(cfg["clear_lead_deg"]))


## The direction from the kaiju toward the game camera, on the ground plane.
func _bearing() -> float:
	return deg_to_rad(Num.f(cfg["camera_bearing"]))


## A seeded value in the data's [min, max] range `key`.
func _span(key: String) -> float:
	var bounds: Array = cfg[key]
	return _rng.randf_range(Num.f(bounds[0]), Num.f(bounds[1]))
