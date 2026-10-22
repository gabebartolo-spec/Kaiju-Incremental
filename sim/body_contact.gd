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
## The charge along the facing (Dash), which this body's sweep carries through the city.
var dash: Dash
## Steps walked so far (0 at the first step; an integer is a footfall, even the left foot, odd the
## right): the sim's step clock, which the legs follow (ClipGait) and which opens the yaw slices.
var phase := 0.0
## How much of a full step's length each step takes now, 0..1: a turn's quick steps are short ones
## (the legs scale the clip's foot travel by it, so a planted foot is passed at the pace the body
## walks).
var step_ratio := 1.0
## The discs at body scale 1, in design units: [forward offset, radius, bottom, top]; empty
## for a species without a body volume (then the body only slows in walls, as before).
var _discs: Array = []
var _volume: BodyVolume
var _last_pos := Vector2(INF, INF)
var _last_heading := Vector2(0, -1)
var _dt := 0.0
var _hold_s := 0.0
var _spin := 0.0  # how fast the body turns now (rad/s, signed as turn_left)
## The feet at body scale 1: (how far ahead of kaiju_pos a foot comes down in a full step; half the
## gap between the feet).
var _pivot := Vector2.ZERO
## Where the last two feet to land stand in the world (they stay there until they lift): the newest
## first. The body turns about them.
var _feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _cadence := 0.0  # steps/s the turn adds to the step clock now (eases up in a turn)
var _standing := true  # the stick was zero last step: the next step sets off on a footfall
## A real turn is under way (one that began at smooth_below or more): it steps to its end; a smaller
## course correction turns smoothly while walking (D-130).
var _real_turn := false


## tuning: the rampage's whole tuning; the body reads its "contact" section.
func _init(p_sim: RampageSim, tuning: Dictionary) -> void:
	sim = p_sim
	cfg = tuning["contact"]
	heading = sim.facing
	_last_heading = heading
	dash = Dash.new(self, cfg)
	_volume = BodyVolume.new(sim, cfg)


## Picks the body volume for a species at the sim's size tier (call after setting the species).
func use_species(species_id: String) -> void:
	var bodies: Dictionary = cfg.get("bodies", {})
	var stages: Array = bodies.get(species_id, [])
	_discs = []
	_volume.discs = _discs
	if not stages.is_empty():
		var stage: Dictionary = stages[clampi(sim.size_tier() - 1, 0, stages.size() - 1)]
		_discs = stage["discs"]
		_volume.discs = _discs
		snout = Num.f(stage["snout"])
		var pivot: Array = stage.get("pivot", [0.0, 0.0])
		_pivot = Vector2(Num.f(pivot[0]), Num.f(pivot[1]))


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
## smooth_below turns smoothly while walking, with no slice or pivot (D-130, "Small turns smooth").
## Returns the stride; RampageSim moves the kaiju along the heading by it, never sideways.
func steer(dt: float, want: Vector2) -> float:
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
	var ease := minf(1.0, Num.f(cfg["stride_ease"]) * dt) if stride > 0.0 else 1.0  # sets off at once
	stride = lerpf(stride, want.length() * keep, ease)
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
	if stepped:
		_swing(was)
	return stride


## The stick is at rest: the body stands, and the next push sets off on a footfall.
func _stand(dt: float) -> void:
	stride = 0.0
	turn_left = 0.0
	_spin = 0.0
	_cadence = 0.0
	_standing = true
	_real_turn = false
	_face(dt)


## Both feet down where they stand when the body sets off (or after a dash or leap).
func _plant_both() -> void:
	_feet = [_foot_at(_pivot.x, 1.0), _foot_at(_pivot.x - Num.f(cfg["step_len"]), -1.0)]


## True when this turn is made in steps: a real turn (begun at smooth_below or more, kept until it
## is made) by a body that turns in steps; a smaller course correction turns smoothly (D-130).
func _steps_this_turn() -> bool:
	if absf(turn_left) >= Num.f(cfg["smooth_below"]):
		_real_turn = true
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
		top = top / Num.f(cfg["slice_open"]) if _slice() else 0.0
		if absf(turn_left) > Num.f(cfg["turn_min"]):
			cadence = Num.f(cfg["turn_cadence"]) / sqrt(sim.body_scale())
	_cadence = move_toward(_cadence, cadence, Num.f(cfg["cadence_ease"]) * dt)
	return Vector2(top, accel)


## A stepped turn swings the body about the foot that is down (since `was`): that foot stays put.
func _swing(was: Vector2) -> void:
	var both := fposmod(phase, 1.0) < Num.f(cfg["support_both"])  # the old foot is not up yet
	var at := (_feet[0] + _feet[1]) * 0.5 if both else _feet[0]
	if at.distance_to(sim.kaiju_pos) > 3.0 * _pivot.x * sim.body_scale():  # a dash or leap left them
		_plant_both()
		at = _feet[0]
	sim.kaiju_pos = at + (sim.kaiju_pos - at).rotated(was.angle_to(heading))


## Where the foot that lands now comes down (world): `ahead` of kaiju_pos (body units at scale 1),
## `side` 1 on its own side of the middle, -1 on the other.
func _foot_at(ahead: float, side: float) -> Vector2:
	var lateral := (-1.0 if int(floorf(phase)) % 2 == 0 else 1.0) * side  # an even step: left
	var across := heading.rotated(PI * 0.5) * _pivot.y * lateral
	return sim.kaiju_pos + (heading * ahead + across) * sim.body_scale()


## True while the body may yaw: a stretch of each step from slice_from, after its footfall.
func _slice() -> bool:
	var at := fposmod(phase, 1.0) - Num.f(cfg["slice_from"])
	return at >= 0.0 and at < Num.f(cfg["slice_open"])


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


## The kaiju has walked `distance` world units in dt (a stride or a dash): the step clock follows,
## at least as fast as a turn's cadence (a turn takes short quick steps).
func walked(distance: float, dt: float) -> void:
	if stepping():
		var before := floorf(phase)
		var steps := distance / (Num.f(cfg["step_len"]) * sim.body_scale())
		var moved := maxf(steps, _cadence * dt)
		phase += moved
		if moved > 0.0:
			step_ratio = maxf(steps / moved, Num.f(cfg["step_ratio_min"]))
		if floorf(phase) != before:  # a footfall: that foot comes down short of a full step
			var short := 0.5 * Num.f(cfg["step_len"]) * (1.0 - step_ratio)
			_feet = [_foot_at(_pivot.x - short, 1.0), _feet[0]]


## Carries a dash (dash_pressed: the button this step), faces the body where sim.facing points,
## then breaks what the body moved or turned into.
func step(dt: float, dash_pressed: bool = false) -> void:
	dash.step(dt, dash_pressed)
	_face(dt)
	if not active() or sim.airborne:
		_last_pos = Vector2(INF, INF)
		return
	var from := sim.kaiju_pos if _last_pos.x == INF else _last_pos
	var from_heading := heading if _last_pos.x == INF else _last_heading
	_dt = dt
	_sweep(from, from_heading, sim.kaiju_pos, heading)
	held = not inside(sim.kaiju_pos, heading).is_empty()
	_hold_s = _hold_s + dt if held else 0.0
	longest_hold = maxf(longest_hold, _hold_s)
	if held:
		_hold(from, from_heading)
		dash.left = 0.0  # a dash into a wall that has not given yet stops at it
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
		most /= Num.f(cfg["slice_open"])  # a slice turns faster than the average (steer)
	heading = heading.rotated(clampf(heading.angle_to(sim.facing), -most, most))


## A turn rate (rad/s) for this body: bigger is slower, by body scale to the turn_size_exp
## ("bigger = slower but not TOO slow, lumbering within reason", director 2026-10-21). A body that
## steps its turns reads its own rates (step_turn_*); one that does not, the baby, turns smoothly
## at the plain ones (D-131, "Baby turns smoothly").
func _rate(key: String) -> float:
	var pre := "step_" if stepping() else ""
	var size_exp := Num.f(cfg[pre + "turn_size_exp"])
	return Num.f(cfg[pre + key]) / pow(maxf(sim.body_scale(), 0.01), size_exp)


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


func _sweep(from: Vector2, from_heading: Vector2, to: Vector2, to_heading: Vector2) -> void:
	var reach := _volume.reach()
	var near := _volume.near(from, to, reach)
	if near.is_empty():
		return
	var turn := from_heading.angle_to(to_heading)
	var travel := from.distance_to(to) + absf(turn) * reach
	var samples := maxi(1, ceili(travel / maxf(0.05, Num.f(cfg["sample"]))))
	var hits: Dictionary = {}
	for n: int in range(1, samples + 1):
		var pose := sweep_pose(from, from_heading, to, to_heading, float(n) / samples)
		var at: Vector2 = pose[0]
		var facing: Vector2 = pose[1]
		_volume.collect(at, facing, hits, near)
	for index: int in hits:
		var cells: Array[Vector3i] = []
		for c: Vector3i in hits[index]:
			cells.append(c)
		var before := sim.rubble
		var first := sim.events.size()
		var b := sim.buildings[index]
		var dwarfs := Growth.dwarf_mult(sim.size_tier(), b.tier, sim.city) < 1.0
		var n := sim.damage_chunks(index, cells, Num.f(cfg["bite_dps"]) * _dt if dwarfs else INF)
		var pay := 1.0 if dwarfs else Num.f(cfg["pay_mult"])
		if n > 0:  # what the body breaks outright pays a share (pacing); chewed and falls in full
			sim.rubble = before + (sim.rubble - before) * pay
			sim.events[first]["pay"] = pay
		broken += n


## The body's pose a fraction `t` along a sweep: [position, heading]. The last sample (t = 1) is
## exactly the end pose, the one the hold test reads, so a rounding error in the turn can never
## leave a chunk the sweep missed but the hold sees.
static func sweep_pose(
	from: Vector2, from_heading: Vector2, to: Vector2, to_heading: Vector2, t: float
) -> Array:
	if t >= 1.0:
		return [to, to_heading]
	return [from.lerp(to, t), from_heading.rotated(from_heading.angle_to(to_heading) * t)]
