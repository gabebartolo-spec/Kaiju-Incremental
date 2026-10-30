class_name BodyTurnPace
extends RefCounted
## How fast the kaiju's body may turn (BodyContact.steer): a stepped turn's pace, its top yaw
## rate and its time.


## True when this turn is made in steps: a real turn (begun at smooth_below or more, kept until it
## is made) by a body that turns in steps; a smaller course correction turns smoothly (D-130).
static func steps_this_turn(b: BodyContact) -> bool:
	if absf(b.turn_left) >= Num.f(b.cfg["smooth_below"]):
		b._real_turn = true
		b._landing = false
	elif b._real_turn and absf(b.turn_left) <= Num.f(b.cfg["turn_min"]):
		b._real_turn = false  # the turn is made: the next small one is a correction
		b._landing = b._spin != 0.0
	if b._landing and (b._spin == 0.0 or absf(b.turn_left) > 2.0 * Num.f(b.cfg["turn_min"])):
		b._landing = false
	return b.turns_in_steps() and (b._real_turn or b._landing)


## How fast the body may turn now, Vector2(top rad/s, rad/s^2); eases in a stepped turn's cadence.
static func pace(b: BodyContact, dt: float, stepped: bool) -> Vector2:
	var top := lerpf(b._rate("turn_rate_still"), b._rate("turn_rate"), b.stride)
	var accel := Num.f(b.cfg["turn_accel"])
	if b.sim.powers.beam_left > 0.0:  # the beam follows the stick at its own pace, whatever the size
		top = maxf(top, b.sim.powers.beam_turn_rate())
	var cadence := 0.0
	if stepped and b._uturn_s > 0.0:
		top = turn_peak(b)
		accel = top / (Num.f(b.cfg["turn_ramp"]) * turn_time(b))  # up to speed in the ramp's share
		if absf(b.turn_left) > Num.f(b.cfg["turn_min"]):
			cadence = b._turn_steps / b._uturn_s
	b._cadence = move_toward(b._cadence, cadence, Num.f(b.cfg["cadence_ease"]) * dt)
	return Vector2(top, accel)


## A stepped turn's top yaw rate (rad/s): the U-turn's half circle in turn_time() as a trapezoid
## (speeding up and slowing over turn_ramp of it each), so 1 / (1 - turn_ramp) of the mean rate.
static func turn_peak(b: BodyContact) -> float:
	return PI / (turn_time(b) * (1.0 - Num.f(b.cfg["turn_ramp"])))


## Seconds a U-turn takes until the body is exactly on the new way: uturn_s is the time to come
## within turn_land_deg of it (what a player sees as turned); the slowing ramp takes a bit more.
static func turn_time(b: BodyContact) -> float:
	var ramp := Num.f(b.cfg["turn_ramp"])
	var land := deg_to_rad(Num.f(b.cfg["turn_land_deg"]))
	return b._uturn_s / (1.0 - sqrt(2.0 * land * ramp * (1.0 - ramp) / PI))
