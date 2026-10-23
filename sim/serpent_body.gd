class_name SerpentBody
extends RefCounted
## The serpent's head steered with weight (D-198; data/tuning.json "serpent"), laying the trail
## its body follows (SerpentTrail). The stick sets where it wants to go and how fast: the head
## speeds up at accel and slows at decel, and turns toward the stick at most turn_rate, gathering
## and easing at turn_accel so it lands on the new way without overshooting (a 90 deg turn in
## about 1.5 s, "About 1.5 s"); it never turns tighter than min_radius, so it cannot pivot on the
## spot. It only ever moves along its heading. Prototype: not yet part of RampageSim. Pure.

var cfg: Dictionary
var pos: Vector2
var heading: Vector2
var speed := 0.0
## How fast the heading turns now (rad/s, signed as Vector2.angle_to).
var spin := 0.0
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
	var target := Num.f(cfg["speed"]) * push
	var rate := Num.f(cfg["accel"]) if target > speed else Num.f(cfg["decel"])
	speed = move_toward(speed, target, rate * dt)
	turn_left = heading.angle_to(want) if push > 0.0 else 0.0
	var accel := Num.f(cfg["turn_accel"])
	var top := minf(Num.f(cfg["turn_rate"]), speed / Num.f(cfg["min_radius"]))
	var aim := signf(turn_left) * minf(top, sqrt(2.0 * accel * absf(turn_left)))
	spin = clampf(move_toward(spin, aim, accel * dt), -top, top)
	var turn := spin * dt
	if push > 0.0 and signf(turn) == signf(turn_left) and absf(turn) >= absf(turn_left):
		turn = turn_left  # lands on the new way exactly
		spin = 0.0
	heading = heading.rotated(turn).normalized()
	pos += heading * speed * dt
	trail.advance(pos, heading, speed, spin)


## Where the body's centreline lies `behind` the head (the sim's footprint for crushing, later).
func centre_at(behind: float) -> Vector2:
	return trail.at(behind)


func length() -> float:
	return Num.f(cfg["length"])
