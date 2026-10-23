class_name BodySteps
extends RefCounted
## A body that walks by steps (it has planted feet, BodyContact.stepping): its turn is made in steps
## (director 2026-10-21 #3, "rather than swivelling on the spot like a plastic toy"): the body yaws
## only in a bell through each step from its footfall, slow off the mark and settling at the end,
## and swings about the planted foot, which stays put; a course correction under smooth_below turns
## smoothly (D-130) but over the planted foot too (D-177). The feet land where the step clock says.
## Part of BodyContact (each call takes it: no kept reference, no cycle); pure, no randomness.

## The feet at body scale 1: (how far ahead of kaiju_pos a foot comes down in a full step; half the
## gap between the feet).
var pivot := Vector2.ZERO
## One step's length at body scale 1: the stage's own (contact.bodies).
var step_len := 0.0
## Steps/s the turn adds to the step clock now (eases up in a turn).
var cadence := 0.0
## Where the last two feet to land stand in the world (they stay there until they lift): the newest
## first. The body turns about them.
var feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
## A real turn is under way (one that began at smooth_below or more): it steps to its end; a smaller
## course correction turns smoothly while walking (D-130).
var real_turn := false
var _turn_total := 0.0  # the size of the real turn under way (rad): how far through it the body is
var _cfg: Dictionary


func _init(cfg: Dictionary) -> void:
	_cfg = cfg
	step_len = Num.f(cfg["step_len"])


## Both feet down where they stand when the body sets off (or after a dash or leap).
func plant_both(body: BodyContact) -> void:
	feet = [_foot_at(body, pivot.x, 1.0), _foot_at(body, pivot.x - step_len, -1.0)]


## True when this turn is made in steps: a real turn (begun at smooth_below or more, kept until it
## is made) by a body that turns in steps; a smaller course correction turns smoothly (D-130).
func steps_this_turn(body: BodyContact) -> bool:
	var left := absf(body.turn_left)
	if left >= Num.f(_cfg["smooth_below"]):
		if not real_turn:
			_turn_total = 0.0
		real_turn = true
		_turn_total = maxf(_turn_total, left)
	elif left <= Num.f(_cfg["turn_min"]):
		real_turn = false  # the turn is made: the next small one is a correction
	return body.turns_in_steps() and real_turn


## A stepped turn's top speed from the plain `top` (rad/s), and the cadence it eases in (quick
## short steps): [top, cadence wanted], 64-bit floats (a Vector2 would round them to 32 bits and
## move the croc off the path it walked before, the sim review of D-208).
func stepped_pace(body: BodyContact, top: float) -> Array[float]:
	var want := 0.0
	if absf(body.turn_left) > Num.f(_cfg["turn_min"]):
		want = Num.f(_cfg["turn_cadence"]) / sqrt(body.sim.body_scale())
	return [top * _turn_ease(body) * _slice_bell(body), want]


## A turn swings the body about the foot that is down (since `was`): that foot stays put. Only the
## `most` the stick turned this step swings it: a larger catch-up of the heading (the hand-over from
## the river, where the body lies along the water) stays about the middle.
func swing(body: BodyContact, was: Vector2, most: float) -> void:
	var sim := body.sim
	var both := fposmod(body.phase, 1.0) < Num.f(_cfg["support_both"])  # the old foot is not up yet
	var at := (feet[0] + feet[1]) * 0.5 if both else feet[0]
	if at.distance_to(sim.kaiju_pos) > 3.0 * pivot.x * sim.body_scale():  # a dash or leap left them
		plant_both(body)
		at = feet[0]
	var turn := clampf(was.angle_to(body.heading), -most, most)
	sim.kaiju_pos = at + (sim.kaiju_pos - at).rotated(turn)


## A footfall on the step clock: that foot comes down short of a full step by the step ratio.
func footfall(body: BodyContact) -> void:
	var short := 0.5 * step_len * (1.0 - body.step_ratio)
	feet = [_foot_at(body, pivot.x - short, 1.0), feet[0]]


## A stepped turn's pace through the turn: slow off the mark (turn_ease_min), quickest in the middle
## (turn_ease_peak), settling at the end, so the body does not yaw at one rate from start to stop.
func _turn_ease(body: BodyContact) -> float:
	var done := 1.0 - absf(body.turn_left) / maxf(_turn_total, 0.001)
	var lo := Num.f(_cfg["turn_ease_min"])
	return lo + (Num.f(_cfg["turn_ease_peak"]) - lo) * sin(PI * clampf(done, 0.0, 1.0))


## Where the foot that lands now comes down (world): `ahead` of kaiju_pos (body units at scale 1),
## `side` 1 on its own side of the middle, -1 on the other.
func _foot_at(body: BodyContact, ahead: float, side: float) -> Vector2:
	var lateral := (-1.0 if int(floorf(body.phase)) % 2 == 0 else 1.0) * side  # an even step: left
	var across := body.heading.rotated(PI * 0.5) * pivot.y * lateral
	return body.sim.kaiju_pos + (body.heading * ahead + across) * body.sim.body_scale()


## How much of the average pace the yaw may run at now: a bell (smooth rise and fall, no jump in
## the rate) through the stretch of each step from slice_from, after its footfall; zero outside it.
## The bell's mean is 2/pi of its peak, so its peak is pi/2 of the pace the slice is spread over.
func _slice_bell(body: BodyContact) -> float:
	var open := Num.f(_cfg["slice_open"])
	var at := (fposmod(body.phase, 1.0) - Num.f(_cfg["slice_from"])) / open
	return 0.5 * PI * sin(PI * at) / open if at >= 0.0 and at < 1.0 else 0.0
