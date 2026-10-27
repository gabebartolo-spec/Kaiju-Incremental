class_name BodyContact
extends RefCounted
## The kaiju's body as a solid (playtest note 2): a chain of discs along the body's heading,
## sized per life stage to the drawn model (data/tuning.json "contact"), breaks every standing
## chunk it overlaps as it walks or turns, so the model never passes through an intact wall. The
## path between two steps is swept in samples, so a fast move or a quick turn of the long snout
## or tail leaves nothing standing inside the body. A building that dwarfs the kaiju (D-091) is
## chewed at bite_dps x Growth.dwarf_mult instead of broken outright, and holds the body at its
## wall until its chunks give. Part of RampageSim; pure, no randomness.

var sim: RampageSim
var cfg: Dictionary
## Where the drawn body faces (the model reads it): sim.facing, which steer() turns with weight;
## a facing set from outside (the rise from the river, a test) is turned to at turn_rate_still.
var heading := Vector2(0, -1)
## The stride, 0..1 of full speed: it eases toward the stick's push, less the harder the turn.
var stride := 0.0
## The turn still to make (rad, signed as Vector2.angle_to): the head looks ahead by it.
var turn_left := 0.0
## Chunks the body itself has broken this rampage.
var broken := 0
## True on a step a wall that has not given yet held the body back.
var held := false
## The longest unbroken time a wall has held the body this rampage, seconds.
var longest_hold := 0.0
## The snout tip's forward offset from kaiju_pos at body scale 1, design units ("snout").
var snout := 0.0
## The dash button's leap (Dash): the body crouches, flies and lands on what is ahead.
var dash: Dash
## Steps walked so far (0 at the first step; an integer is a footfall, even the left foot, odd the
## right): the sim's step clock, which the legs follow (ClipGait) and which opens the yaw slices.
var phase := 0.0
## How much of a full step's length each step takes now, 0..1: a turn's quick steps are short ones
## (the legs scale the clip's foot travel by it, so a planted foot is passed at the pace the body
## walks).
var step_ratio := 1.0
## Stomps the sim has made (it counts them): they alternate feet, the left first.
var stomps := 0
## True on a step a foot came down (the step clock passed a whole number): `landed_foot`'s.
var footfall_now := false
## The discs at body scale 1, in design units: [forward offset, radius, bottom, top]; empty
## for a species without a body volume (then the body only slows in walls, as before).
var _discs: Array = []
var _volume: BodyVolume
var _last_pos := Vector2(INF, INF)
var _last_heading := Vector2(0, -1)
var _hold_s := 0.0
var _spin := 0.0  # how fast the body turns now (rad/s, signed as turn_left)
## The feet at body scale 1: (how far ahead of kaiju_pos a foot comes down in a full step; half the
## gap between the feet).
var _pivot := Vector2.ZERO
## Where a stomp's foot comes down at body scale 1: (ahead of kaiju_pos along the heading, out to
## the left foot's side); zero for a body with no entry (its stomp is centred on kaiju_pos).
var _stomp_foot := Vector2.ZERO
var _stage: Dictionary = {}  # the stage's own entry in contact.bodies (empty: none)
## Where the last two feet to land stand in the world (they stay there until they lift): the newest
## first. The body turns about them.
var _feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _cadence := 0.0  # steps/s the turn adds to the step clock now (eases up in a turn)
var _standing := true  # the stick was zero last step: the next step sets off on a footfall
## A real turn is under way (one that began at smooth_below or more): it steps to its end; a smaller
## course correction turns smoothly while walking (D-130).
var _real_turn := false
var _walked_s := 0.0  # seconds since the body set off from a stand
var _turn_total := 0.0  # the size of the real turn under way (rad): how far through it the body is
var _step_len := 0.0  # one step's length at body scale 1: the stage's own (contact.bodies)


## tuning: the rampage's whole tuning; the body reads its "contact" section.
func _init(p_sim: RampageSim, tuning: Dictionary) -> void:
	sim = p_sim
	cfg = tuning["contact"]
	heading = sim.facing
	_last_heading = heading
	_step_len = Num.f(cfg["step_len"])
	dash = Dash.new(self, cfg)
	_volume = BodyVolume.new(sim, cfg)


## Picks the body volume for a species at the sim's size tier (call after setting the species).
func use_species(species_id: String) -> void:
	var bodies: Dictionary = cfg.get("bodies", {})
	var stages: Array = bodies.get(species_id, [])
	dash.use_species(species_id)
	_discs = []
	_volume.discs = _discs
	_stomp_foot = Vector2.ZERO  # a body without an entry stomps at kaiju_pos, never a stale foot
	_stage = {}
	if not stages.is_empty():
		var stage: Dictionary = stages[clampi(sim.size_tier() - 1, 0, stages.size() - 1)]
		_stage = stage
		_discs = stage["discs"]
		_volume.discs = _discs
		snout = Num.f(stage["snout"])
		_step_len = Num.f(stage.get("step_len", cfg["step_len"]))
		var pivot: Array = stage.get("pivot", [0.0, 0.0])
		_pivot = Vector2(Num.f(pivot[0]), Num.f(pivot[1]))
		var foot: Array = stage.get("stomp_foot", [0.0, 0.0])
		_stomp_foot = Vector2(Num.f(foot[0]), Num.f(foot[1]))


func active() -> bool:
	return not _discs.is_empty()


## The discs at body scale 1: [forward offset, radius, bottom, top] each.
func discs() -> Array:
	return _discs


## Snout to tail tip, world units.
func length() -> float:
	var front := 0.0
	var back := 0.0
	for d: Array in _discs:
		front = maxf(front, Num.f(d[0]) + Num.f(d[1]))
		back = minf(back, Num.f(d[0]) - Num.f(d[1]))
	return (front - back) * sim.body_scale()


## Turns sim.facing toward `want` (the stick, length 0..1; zero: standing) with weight
## (director comments #16, "lumbering and unstoppable"): the turn gathers speed at turn_accel up
## to turn_rate (turn_rate_still at a standstill; both slower for a bigger body, _rate) and slows
## before it lands, never overshooting,
## while the stride eases down in a hard turn (to turn_slow at an about-face) and back up after.
## A body with planted feet (stepping) turns in steps instead (director 2026-10-21 #3, "rather
## than swivelling on the spot like a plastic toy"): the body yaws only in the first slice_open of
## each step, from its footfall, at the same pace on average, holds between (the head leads by
## turn_left), and swings about its planted feet, not its middle. A course correction under
## smooth_below turns smoothly while walking, with no slice (D-130, "Small turns smooth"), but over
## the planted foot like any turn: a held curve never drags the feet (D-177).
## Returns the stride; RampageSim moves the kaiju along the heading by it, never sideways.
func steer(dt: float, want: Vector2) -> float:
	footfall_now = false
	if want == Vector2.ZERO:
		_stand(dt)
		return 0.0
	if _standing:
		phase = roundf(phase)  # sets off on a footfall: both feet down
		step_ratio = 1.0
		_plant_both()
		_standing = false
	turn_left = sim.facing.angle_to(want)
	var stepped := _steps_this_turn()
	var keep := lerpf(1.0, Num.f(cfg["turn_slow"]), absf(turn_left) / PI)
	# Sets off at full pace at once, but ramped over walk_off_s, not one frame (the motion critic,
	# 2026-10-22: "the walk start jumps to full speed"); after it the stride eases to the push.
	_walked_s += dt
	var launching := _walked_s < Num.f(cfg["walk_off_s"])
	var ease := 1.0 if launching else minf(1.0, Num.f(cfg["stride_ease"]) * dt)
	stride = minf(lerpf(stride, want.length() * keep, ease), stride + dt / Num.f(cfg["walk_off_s"]))
	var pace := _pace(dt, stepped)  # (top turn speed, its acceleration)
	var aim := signf(turn_left) * minf(pace.x, sqrt(2.0 * pace.y * absf(turn_left)))
	_spin = move_toward(_spin, aim, pace.y * dt)
	var turn := _spin * dt
	if signf(turn) == signf(turn_left) and absf(turn) >= absf(turn_left):
		turn = turn_left  # lands on the new way exactly
		_spin = 0.0
	sim.facing = sim.powers.turn_toward(sim.facing, sim.facing.rotated(turn), dt)
	var was := heading
	_face(dt)
	if turns_in_steps() and not dash.on():  # a turn too is made over the planted foot (D-177)
		_swing(was, absf(turn))
	return stride


## The stick is at rest: the body stands, and the next push sets off on a footfall.
func _stand(dt: float) -> void:
	stride = 0.0
	turn_left = 0.0
	_spin = 0.0
	_cadence = 0.0
	_standing = true
	_walked_s = 0.0
	_real_turn = false
	_face(dt)


## Both feet down where they stand when the body sets off (or after a dash or leap).
func _plant_both() -> void:
	_feet = [_foot_at(_pivot.x, 1.0), _foot_at(_pivot.x - _step_len, -1.0)]


## True when this turn is made in steps: a real turn (begun at smooth_below or more, kept until it
## is made) by a body that turns in steps; a smaller course correction turns smoothly (D-130).
func _steps_this_turn() -> bool:
	if absf(turn_left) >= Num.f(cfg["smooth_below"]):
		if not _real_turn:
			_turn_total = 0.0
		_real_turn = true
		_turn_total = maxf(_turn_total, absf(turn_left))
	elif absf(turn_left) <= Num.f(cfg["turn_min"]):
		_real_turn = false  # the turn is made: the next small one is a correction
	return turns_in_steps() and _real_turn


## How fast the body may turn now, Vector2(top rad/s, rad/s^2); a stepped turn also eases in the
## cadence it adds to the step clock (quick short steps).
func _pace(dt: float, stepped: bool) -> Vector2:
	var top := lerpf(_rate("turn_rate_still"), _rate("turn_rate"), stride)
	var accel := Num.f(cfg["turn_accel"])
	if sim.powers.beam_left > 0.0:  # the beam follows the stick at its own pace, whatever the size
		top = maxf(top, sim.powers.beam_turn_rate())
	var cadence := 0.0
	if stepped:
		accel = Num.f(cfg["slice_accel"])
		top = top * _turn_ease() * _slice_bell()
		if absf(turn_left) > Num.f(cfg["turn_min"]):
			cadence = Num.f(cfg["turn_cadence"]) / sqrt(sim.body_scale())
	_cadence = move_toward(_cadence, cadence, Num.f(cfg["cadence_ease"]) * dt)
	return Vector2(top, accel)


## A stepped turn's pace through the turn: slow off the mark (turn_ease_min), quickest in the middle
## (turn_ease_peak), settling at the end, so the body does not yaw at one rate from start to stop.
func _turn_ease() -> float:
	var done := 1.0 - absf(turn_left) / maxf(_turn_total, 0.001)
	var lo := Num.f(cfg["turn_ease_min"])
	return lo + (Num.f(cfg["turn_ease_peak"]) - lo) * sin(PI * clampf(done, 0.0, 1.0))


## A turn swings the body about the foot that is down (since `was`): that foot stays put. Only the
## `most` the stick turned this step swings it: a larger catch-up of the heading (the hand-over from
## the river, where the body lies along the water) stays about the middle.
func _swing(was: Vector2, most: float) -> void:
	var both := fposmod(phase, 1.0) < Num.f(cfg["support_both"])  # the old foot is not up yet
	var at := (_feet[0] + _feet[1]) * 0.5 if both else _feet[0]
	if at.distance_to(sim.kaiju_pos) > 3.0 * _pivot.x * sim.body_scale():  # a dash or leap left them
		_plant_both()
		at = _feet[0]
	sim.kaiju_pos = at + (sim.kaiju_pos - at).rotated(clampf(was.angle_to(heading), -most, most))


## The ground point a stomp lands on (world): the left foot's (or the right's) spot ahead of
## kaiju_pos on the body's heading, so the damage is where the drawn ring is, not at the tail base.
func stomp_foot(left: bool) -> Vector2:
	var across := heading.orthogonal() * _stomp_foot.y * (1.0 if left else -1.0)
	return sim.kaiju_pos + (heading * _stomp_foot.x + across) * sim.body_scale()


## Lifts the body volume off the ground (world units) for what it overlaps: a leap's arc.
func set_lift(lift: float) -> void:
	_volume.lift = lift


## How far ahead of kaiju_pos the feet come down (world units): a leap aims them at its target.
func feet_ahead() -> float:
	return _stomp_foot.x * sim.body_scale()


## True when the body walks by its step clock (it has planted feet and the stick is pushed).
func walking() -> bool:
	return stepping() and not _standing


## The foot that came down on the latest footfall (world), and whether it is the left: an even step
## is the left foot's (the step clock and the legs agree). Read on a step `footfall_now` is true.
func landed_foot() -> Vector2:
	return _feet[0]


func landed_left() -> bool:
	return int(floorf(phase)) % 2 == 0


## True when the stomp's next foot is on `target` (within half a stomp's reach): a scripted player
## stops when this holds, so the foot that comes down next lands on the building, as a person aims
## it (D-166). Every measuring player (tests, pacing, captures, autoplay) walks by this rule.
func stomp_reaches(target: Vector2) -> bool:
	return stomp_foot(stomps % 2 == 0).distance_to(target) <= sim.stomp_radius() * 0.5


## Where the foot that lands now comes down (world): `ahead` of kaiju_pos (body units at scale 1),
## `side` 1 on its own side of the middle, -1 on the other.
func _foot_at(ahead: float, side: float) -> Vector2:
	var lateral := (-1.0 if int(floorf(phase)) % 2 == 0 else 1.0) * side  # an even step: left
	var across := heading.rotated(PI * 0.5) * _pivot.y * lateral
	return sim.kaiju_pos + (heading * ahead + across) * sim.body_scale()


## How much of the average pace the yaw may run at now: a bell (smooth rise and fall, no jump in
## the rate) through the stretch of each step from slice_from, after its footfall; zero outside it.
## The bell's mean is 2/pi of its peak, so its peak is pi/2 of the pace the slice is spread over.
func _slice_bell() -> float:
	var at := (fposmod(phase, 1.0) - Num.f(cfg["slice_from"])) / Num.f(cfg["slice_open"])
	return 0.5 * PI * sin(PI * at) / Num.f(cfg["slice_open"]) if at >= 0.0 and at < 1.0 else 0.0


## True when this body walks by steps (it has planted feet): the stepped turn and the step clock.
func stepping() -> bool:
	return _pivot.x > 0.0


## True when the turn is made in steps: a body with planted feet, except while the beam is on,
## which is swept smoothly by the stick (its own turn speed, SpeciesPowers.turn_toward).
func turns_in_steps() -> bool:
	return stepping() and sim.powers.beam_left <= 0.0


## The step clock for the legs to follow (steps walked), INF for a body that does not step.
func step_clock() -> float:
	return phase if stepping() else INF


## The kaiju has walked `distance` world units in dt (a stride): the step clock follows,
## at least as fast as a turn's cadence (a turn takes short quick steps).
func walked(distance: float, dt: float) -> void:
	if stepping():
		var before := floorf(phase)
		var steps := distance / (_step_len * sim.body_scale())
		var moved := maxf(steps, _cadence * dt)
		phase += moved
		if moved > 0.0:
			step_ratio = maxf(steps / moved, Num.f(cfg["step_ratio_min"]))
		if floorf(phase) != before:  # a footfall: that foot comes down short of a full step
			var short := 0.5 * _step_len * (1.0 - step_ratio)
			_feet = [_foot_at(_pivot.x - short, 1.0), _feet[0]]
			footfall_now = true


## Carries a leap (dash_pressed: the button this step), faces the body where sim.facing points,
## then breaks what the body moved or turned into.
func step(dt: float, dash_pressed: bool = false) -> void:
	dash.step(dt, dash_pressed)
	_face(dt)
	_volume.lift = dash.height()  # a leap's flight breaks what its body passes through
	if not active() or (sim.airborne and not dash.on()):
		_last_pos = Vector2(INF, INF)
		return
	var from := sim.kaiju_pos if _last_pos.x == INF else _last_pos
	var from_heading := heading if _last_pos.x == INF else _last_heading
	_volume.step_s = dt
	broken += _volume.sweep(from, from_heading, sim.kaiju_pos, heading)
	held = not inside(sim.kaiju_pos, heading).is_empty()
	_hold_s = _hold_s + dt if held else 0.0
	longest_hold = maxf(longest_hold, _hold_s)
	if held:
		_hold(from, from_heading)
	_last_pos = sim.kaiju_pos
	_last_heading = heading


## A wall that has not given yet: the body slides along it if it can, else stays where it was.
func _hold(from: Vector2, from_heading: Vector2) -> void:
	var to := sim.kaiju_pos
	var poses: Array[Array] = [
		[Vector2(to.x, from.y), heading], [Vector2(from.x, to.y), heading], [from, heading]
	]
	for pose: Array in poses:
		var at: Vector2 = pose[0]
		if inside(at, heading).is_empty():
			sim.kaiju_pos = at
			return
	sim.kaiju_pos = from
	heading = from_heading
	sim.facing = from_heading  # the body could not turn here: neither does what it aims
	_spin = 0.0


## The heading turns to sim.facing, at most turn_rate_still: steer() turns the facing no faster,
## so the two stay one; only a facing set from outside is caught up with.
func _face(dt: float) -> void:
	var most := _rate("turn_rate_still") * dt
	if turns_in_steps():
		# a slice turns quicker than the average (steer), most so at the middle of a turn
		most *= 0.5 * PI * maxf(1.0, Num.f(cfg["turn_ease_peak"])) / Num.f(cfg["slice_open"])
	heading = heading.rotated(clampf(heading.angle_to(sim.facing), -most, most))


## A turn rate (rad/s) for this body: bigger is slower, by body scale to the turn_size_exp
## ("bigger = slower but not TOO slow, lumbering within reason", director 2026-10-21). A body that
## steps its turns reads its own rates (step_turn_*); one that does not, the baby, turns smoothly
## at the plain ones (D-131, "Baby turns smoothly"). A stage may set its own rates in contact.bodies
## (the Colossus: D-302, "a step ~1.35 s", so its 90 deg turn spans at least one full step).
func _rate(key: String) -> float:
	var pre := "step_" if stepping() else ""
	var size_exp := Num.f(cfg[pre + "turn_size_exp"])
	var base := Num.f(_stage.get(pre + key, cfg[pre + key]))
	return base / pow(maxf(sim.body_scale(), 0.01), size_exp)


## Whether the body overlaps building `index`'s footprint now (never without a body volume).
func over(index: int) -> bool:
	var b := sim.buildings[index]
	var s := sim.body_scale()
	for d: Array in _discs:
		var c := sim.kaiju_pos + heading * Num.f(d[0]) * s
		var gap := Vector2(
			maxf(absf(c.x - b.x) - b.w * 0.5, 0.0), maxf(absf(c.y - b.z) - b.d * 0.5, 0.0)
		)
		if gap.length() < Num.f(d[1]) * s:
			return true
	return false


## Every standing chunk inside the body at a pose: {building index: {Vector3i: true}}.
func inside(pos: Vector2, facing: Vector2) -> Dictionary:
	var out: Dictionary = {}
	_volume.collect(pos, facing, out, _volume.near(pos, pos, _volume.reach()))
	return out
