class_name SerpentBody
extends RefCounted
## The serpent's head steered with weight (D-198; data/tuning.json "serpent"), laying the trail
## its body follows (SerpentTrail). The stick sets where it wants to go and how fast: the head
## speeds up at accel and slows at decel, and turns toward the stick at most turn_rate, gathering
## and easing (slow-in, slow-out) so it lands on the new way without overshooting (a 90 deg turn in
## about 1.5 s, "About 1.5 s"); it never turns tighter than min_radius, so it cannot pivot on the
## spot. It only ever moves along its heading. Prototype: not yet part of RampageSim. Pure.

## A turn this close (rad), turning this slowly (rad/s), is made: it lands on the new way.
const LAND_ANGLE := 0.004
const LAND_SPIN := 0.08

var cfg: Dictionary
var pos: Vector2
var heading: Vector2
var speed := 0.0
## How fast the heading turns now (rad/s, signed as Vector2.angle_to).
var spin := 0.0
## How fast the turn rate itself changes now (rad/s^2): the turn's slow-in and slow-out.
var alpha := 0.0
## The turn still to make toward the stick (rad, signed); 0 with the stick at rest.
var turn_left := 0.0
var trail: SerpentTrail


func _init(p_cfg: Dictionary, at: Vector2, p_heading: Vector2) -> void:
	cfg = p_cfg
	pos = at
	heading = p_heading.normalized()
	var reach := Num.f(cfg["length"]) * 1.25  # slack: the drawn S is longer than its centreline
	trail = SerpentTrail.new(Num.f(cfg["sample"]), reach, pos, heading)


## One step: `want` is the stick (length 0..1; zero: let it come to rest).
func step(dt: float, want: Vector2) -> void:
	var push := minf(want.length(), 1.0)
	_pace(dt, Num.f(cfg["speed"]) * push)
	turn_left = heading.angle_to(want) if push > 0.0 else 0.0
	_turn(dt, push > 0.0)
	pos += heading * speed * dt
	trail.advance(pos, heading, speed, spin)


## Speeds up at accel, slows at decel; the last stop_ease_speed m/s of a stop ease off (down to
## stop_ease_floor of decel), so the head eases to a halt rather than braking to it.
func _pace(dt: float, target: float) -> void:
	var rate := Num.f(cfg["accel"])
	if target < speed:
		var ease := smoothstep(0.0, Num.f(cfg["stop_ease_speed"]), speed)
		rate = Num.f(cfg["decel"]) * maxf(Num.f(cfg["stop_ease_floor"]), ease)
	speed = move_toward(speed, target, rate * dt)


## Turns toward the stick with slow-in and slow-out: the turn rate gathers and eases through its
## own acceleration (alpha), which itself changes at most turn_jerk, toward a rate that brakes in
## time to land on the new way (turn_brake of turn_accel); a nearly made turn lands exactly.
func _turn(dt: float, pushed: bool) -> void:
	var accel := Num.f(cfg["turn_accel"])
	var top := minf(Num.f(cfg["turn_rate"]), speed / Num.f(cfg["min_radius"]))
	var brake := 2.0 * accel * Num.f(cfg["turn_brake"]) * absf(turn_left)
	var aim := signf(turn_left) * minf(top, sqrt(brake))
	var want_alpha := clampf((aim - spin) * Num.f(cfg["turn_gain"]), -accel, accel)
	alpha = move_toward(alpha, want_alpha, Num.f(cfg["turn_jerk"]) * dt)
	spin = clampf(spin + alpha * dt, -top, top)
	var turn := spin * dt
	var passes := signf(turn) == signf(turn_left) and absf(turn) >= absf(turn_left)
	if pushed and (passes or (absf(turn_left) < LAND_ANGLE and absf(spin) < LAND_SPIN)):
		turn = turn_left  # lands on the new way exactly
		spin = 0.0
		alpha = 0.0
	heading = heading.rotated(turn).normalized()


## Where the body's centreline lies `behind` the head (the sim's footprint for crushing, later).
func centre_at(behind: float) -> Vector2:
	return trail.at(behind)


func length() -> float:
	return Num.f(cfg["length"])
