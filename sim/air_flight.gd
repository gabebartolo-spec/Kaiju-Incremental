class_name AirFlight
extends RefCounted
## How the military helicopters fly (D-183 "Stand-off gunships", motion first D-177). Each one
## has its own position, heading and speed and steers for a firing position (`spot`) on a ring
## well beyond the kaiju's claws (`standoff` x body scale, so it grows with him), never pinned to
## him: its speed, acceleration and turn rate are limited (`heli_speed`, `heli_accel`,
## `heli_turn_deg`), so it glides in smooth banking turns and brakes into its spot, where it
## hovers facing the kaiju and fires. After `hold_seconds` it glides to another spot along the
## ring; when the kaiju comes within `pull_back` of its spot it leaves for one farther out; when
## the kaiju walks off (past `lose` rings) it follows to a spot near him. Now and then
## (`strafe_gap`) ONE helicopter makes a strafing pass: in to `strafe_close` ahead of the kaiju,
## inside its claw reach, then out to the ring on a side. Spots and passes keep `clear_arc` off the
## camera's side
## (`camera_bearing`). Part of AirWing; pure, on its own seeded stream.

var sim: RampageSim
var cfg: Dictionary
## Strafing passes started this run.
var passes := 0
var _rng: RandomNumberGenerator
var _gap_left: float


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng
	_gap_left = _span("strafe_gap")


## A new helicopter: on the far side of the kaiju from the camera, `spawn_far` rings out, flying
## in to its ring.
func place(heli: AirWing.Heli) -> void:
	var jitter := Num.f(cfg["standoff_jitter"])
	heli.ring = (
		Num.f(cfg["standoff"]) * sim.body_scale() * _rng.randf_range(1.0 - jitter, 1.0 + jitter)
	)
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	var way := Vector2.from_angle(_bearing() + arc + _rng.randf() * (TAU - 2.0 * arc))
	heli.pos = sim.kaiju_pos + way * heli.ring * Num.f(cfg["spawn_far"])
	heli.spot = sim.kaiju_pos + way * heli.ring
	heli.goal = heli.spot
	heli.heading = (-way).angle()
	heli.hold = _span("hold_seconds")


## One step for every helicopter: the strafing clock, then each one's plan and flight.
func step(helis: Array[AirWing.Heli], dt: float) -> void:
	_strafe_clock(helis, dt)
	for heli: AirWing.Heli in helis:
		_plan(heli, helis, dt)
		_steer(heli, dt)


## Sends `heli` on a strafing pass (the clock does it now and then; a test may too).
func start_pass(heli: AirWing.Heli) -> void:
	heli.passing = true
	heli.pass_out = false
	heli.pass_left = Num.f(cfg["strafe_seconds"])
	passes += 1


## The clock only runs while no pass is on; when it is up one held-and-ready helicopter goes.
func _strafe_clock(helis: Array[AirWing.Heli], dt: float) -> void:
	var ready: Array[AirWing.Heli] = []
	for heli: AirWing.Heli in helis:
		if heli.passing:
			return
		ready.append(heli)
	if ready.is_empty():
		return
	_gap_left -= dt
	if _gap_left <= 0.0:
		_gap_left = _span("strafe_gap")
		start_pass(ready[_rng.randi_range(0, ready.size() - 1)])


## Decides where `heli` steers: its pass, a new spot when the kaiju closes on this one or has
## walked off, a glide to another spot once it has held this one long enough.
func _plan(heli: AirWing.Heli, helis: Array[AirWing.Heli], dt: float) -> void:
	if heli.passing:
		_plan_pass(heli, dt)
		return
	var kaiju := sim.kaiju_pos
	var left := heli.spot.distance_to(kaiju)
	if left < Num.f(cfg["pull_back"]) * sim.body_scale() or left > heli.ring * Num.f(cfg["lose"]):
		_relocate(heli, helis, false)
	elif heli.pos.distance_to(heli.spot) <= Num.f(cfg["arrive"]):
		heli.hold -= dt
		if heli.hold <= 0.0:
			_relocate(heli, helis, true)
	heli.goal = heli.spot


## A pass: in to a point `strafe_close` ahead of the kaiju (in its claw band), then out to a spot
## on the ring to one side, and over when it is back on the ring.
func _plan_pass(heli: AirWing.Heli, dt: float) -> void:
	heli.pass_left -= dt
	var kaiju := sim.kaiju_pos
	if not heli.pass_out:
		var close := Num.f(cfg["strafe_close"]) * sim.body_scale()
		heli.goal = kaiju + Vector2.from_angle(_clear(sim.facing.angle())) * close
		var done := heli.pos.distance_to(heli.goal) <= close * Num.f(cfg["strafe_done"])
		if done or heli.pass_left <= 0.0:
			heli.pass_out = true
			heli.pass_left = Num.f(cfg["strafe_seconds"])
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			var out := (heli.pos - kaiju).angle() + side * deg_to_rad(Num.f(cfg["strafe_exit_deg"]))
			heli.spot = kaiju + Vector2.from_angle(_clear(out)) * heli.ring
	if heli.pass_out:
		heli.goal = heli.spot
		var back := heli.pos.distance_to(kaiju) >= heli.ring * Num.f(cfg["strafe_back"])
		if back or heli.pass_left <= 0.0:
			heli.passing = false
			heli.hold = _span("hold_seconds")


## A new spot on the heli's ring round the kaiju, off the camera's side: along the ring by
## `glide_deg` (a glide) or straight out from where the heli is (the kaiju closed or left), the
## best of `slot_tries` seeded tries for room from the other helicopters' spots.
func _relocate(heli: AirWing.Heli, helis: Array[AirWing.Heli], glide: bool) -> void:
	var kaiju := sim.kaiju_pos
	var out := heli.pos - kaiju
	var base := out.angle() if out.length() > 0.01 else _bearing() + PI
	var span: Array = cfg["glide_deg"]
	var best := heli.spot
	var room := -1.0
	for _try: int in Num.i(cfg["slot_tries"]):
		var turn := deg_to_rad(_rng.randf_range(Num.f(span[0]), Num.f(span[1])))
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var shift := side * turn if glide else side * turn * Num.f(cfg["pull_back_swing"])
		var spot := kaiju + Vector2.from_angle(_clear(base + shift)) * heli.ring
		var apart := _room(spot, heli, helis)
		if apart > room:
			best = spot
			room = apart
	heli.spot = best
	heli.hold = _span("hold_seconds")


## How far `spot` is from the nearest other helicopter's spot (INF with none).
func _room(spot: Vector2, heli: AirWing.Heli, helis: Array[AirWing.Heli]) -> float:
	var least := INF
	for other: AirWing.Heli in helis:
		if other != heli:
			least = minf(least, spot.distance_to(other.spot))
	return least


## The flight: turns toward its goal at most `heli_turn_deg` a second, speeds up or slows down at
## most `heli_accel`, never past `heli_speed`, brakes to a stop at the goal and flies slowly
## while it is pointing away from it (it swings its nose round first, never skidding), then
## hovers there with its nose on the kaiju.
func _steer(heli: AirWing.Heli, dt: float) -> void:
	var to := heli.goal - heli.pos
	var dist := to.length()
	var arrived := dist <= Num.f(cfg["arrive"])
	var look := sim.kaiju_pos - heli.pos if arrived else to
	var turn := deg_to_rad(Num.f(cfg["heli_turn_deg"])) * dt
	var err := wrapf(look.angle() - heli.heading, -PI, PI)
	heli.heading = wrapf(heli.heading + clampf(err, -turn, turn), -PI, PI)
	var accel := Num.f(cfg["heli_accel"])
	var want := 0.0
	if not arrived:
		want = minf(Num.f(cfg["heli_speed"]), sqrt(2.0 * accel * dist)) * maxf(0.0, cos(err))
	heli.speed = move_toward(heli.speed, want, accel * dt)
	heli.pos += Vector2.from_angle(heli.heading) * heli.speed * dt


## `angle` moved out of the camera's side (to the nearer edge of `clear_arc`) if it is in it.
func _clear(angle: float) -> float:
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	var side := wrapf(angle - _bearing(), -PI, PI)
	if absf(side) >= arc:
		return angle
	return _bearing() + (arc if side >= 0.0 else -arc)


## The direction from the kaiju toward the game camera, on the ground plane.
func _bearing() -> float:
	return deg_to_rad(Num.f(cfg["camera_bearing"]))


## A seeded value in the data's [min, max] range `key`.
func _span(key: String) -> float:
	var bounds: Array = cfg[key]
	return _rng.randf_range(Num.f(bounds[0]), Num.f(bounds[1]))
