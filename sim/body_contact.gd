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
var _walked_s := 0.0  # seconds since the body set off from a stand
var _turn_total := 0.0  # the size of the real turn under way (rad): how far through it the body is
var _step_len := 0.0  # one step's length at body scale 1: the stage's own (contact.bodies)
## Where a heavy body's drawn body faces (D-200, "Head aims, body follows"): it follows the heading
## at the aim's pace and never lets the neck turn past its cap; the body volume faces it about the
## hips. The heading for any other body.
var body_dir := Vector2(0, -1)
## A heavy body's tail (D-208): its swing and its discs; null for any other body.
var tail: TailSim
## A heavy body's turn and pace (tuning "body_class" sim, D-201; {} for none): its animations lead.
var _heavy: Dictionary = {}
var _aim: Dictionary = {}  # its class's aim (D-200)
var _last_dir := Vector2(0, -1)
var _last_tail: Array = []  # the tail's discs at the last step
var _classes: Dictionary = {}  # tuning "body_class"


## tuning: the rampage's whole tuning; the body reads its "contact" section.
func _init(p_sim: RampageSim, tuning: Dictionary) -> void:
	sim = p_sim
	cfg = tuning["contact"]
	heading = sim.facing
	_last_heading = heading
	_step_len = Num.f(cfg["step_len"])
	_classes = tuning.get("body_class", {})
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
		_step_len = Num.f(stage.get("step_len", cfg["step_len"]))
		var pivot: Array = stage.get("pivot", [0.0, 0.0])
		_pivot = Vector2(Num.f(pivot[0]), Num.f(pivot[1]))
	var found := _class_of(species_id)
	_heavy = found.get("sim", {})
	_aim = found.get("aim", {})
	body_dir = heading
	_last_dir = heading
	_last_tail = []
	var tail_tune: Dictionary = found.get("tail", {})
	tail = TailSim.new(tail_tune) if tail_tune.has("chain") else null
	if _heavy.has("discs"):  # its own body ahead of the tail (the tail's discs ride the tail)
		_discs = _heavy["discs"]
		_volume.discs = _discs


## This species' weight class at the sim's growth stage (body_class "classes"), or {}.
func _class_of(species_id: String) -> Dictionary:
	if _classes.is_empty():
		return {}
	var by_kaiju: Dictionary = _classes["kaiju"]
	var stage_names: Array[String] = ["baby", "adolescent", "adult"]
	var kind := "%s_%s" % [species_id, stage_names[clampi(sim.size_tier() - 1, 0, 2)]]
	if not by_kaiju.has(kind):
		return {}
	var all: Dictionary = _classes["classes"]
	var found: Dictionary = all[str(by_kaiju[kind])]
	return found


## Faces the body (and its drawn body) `dir` at once: a facing set from outside, not a turn.
func face_now(dir: Vector2) -> void:
	heading = dir
	body_dir = dir
	_last_dir = dir
	_last_heading = dir


## True for a body of a heavy weight class (body_class sim, D-201): its animations lead.
func heavy() -> bool:
	return not _heavy.is_empty()


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
	if want == Vector2.ZERO:
		_stand(dt)
		return stride
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
	var off_s := Num.f(_heavy["start_s"]) if not _heavy.is_empty() else Num.f(cfg["walk_off_s"])
	var launching := _walked_s < off_s
	var ease := 1.0 if launching else minf(1.0, Num.f(cfg["stride_ease"]) * dt)
	stride = minf(lerpf(stride, want.length() * keep, ease), stride + dt / off_s)
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
	else:
		_turn_about_hips(was)
	return stride


## The stick is at rest: the body stands, and the next push sets off on a footfall.
func _stand(dt: float) -> void:
	# a heavy body comes to a stop over stop_s (D-201); the rest stop at once
	var stop := Num.f(_heavy["stop_s"]) if not _heavy.is_empty() else 0.0
	stride = move_toward(stride, 0.0, dt / stop) if stop > 0.0 else 0.0
	turn_left = 0.0
	_spin = 0.0
	_cadence = 0.0
	_standing = true
	_walked_s = 0.0
	_real_turn = false
	var was := heading
	_face(dt)
	_turn_about_hips(was)


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
	if not _heavy.is_empty():  # its turn clip's pace, whatever the beam (D-201)
		_cadence = 0.0
		var heavy_top := deg_to_rad(Num.f(_heavy["turn_deg_s"]))
		return Vector2(heavy_top, deg_to_rad(Num.f(_heavy["turn_accel_deg_s2"])))
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


## A heavy body turns about its hips, as its turn clip does (D-201): the turn from `was` swings
## kaiju_pos about the point pivot_ahead ahead of it.
func _turn_about_hips(was: Vector2) -> void:
	if _heavy.is_empty() or dash.on():
		return
	var hips := sim.kaiju_pos + was * Num.f(_heavy["pivot_ahead"]) * sim.body_scale()
	sim.kaiju_pos = hips + (sim.kaiju_pos - hips).rotated(was.angle_to(heading))


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
	return stepping() and sim.powers.beam_left <= 0.0 and _heavy.is_empty()


## The step clock for the legs to follow (steps walked), INF for a body that does not step.
func step_clock() -> float:
	return phase if stepping() else INF


## The kaiju has walked `distance` world units in dt (a stride or a dash): the step clock follows,
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


## Carries a dash (dash_pressed: the button this step), faces the body where sim.facing points,
## then breaks what the body moved or turned into.
func step(dt: float, dash_pressed: bool = false) -> void:
	dash.step(dt, dash_pressed)
	if _heavy.is_empty():  # a heavy body turned once this step, about its hips (steer, D-201)
		_face(dt)
	_follow(dt)
	if not active() or sim.airborne:
		_last_pos = Vector2(INF, INF)
		return
	var from := sim.kaiju_pos if _last_pos.x == INF else _last_pos
	var from_heading := heading if _last_pos.x == INF else _last_heading
	_sweep(from, from_heading, dt)
	held = not inside(sim.kaiju_pos, heading).is_empty()
	_hold_s = _hold_s + dt if held else 0.0
	longest_hold = maxf(longest_hold, _hold_s)
	if held:
		_hold(from, from_heading)
		dash.left = 0.0  # a dash into a wall that has not given yet stops at it
	_last_pos = sim.kaiju_pos
	_last_heading = heading
	_last_dir = body_dir


## While the kaiju rises out of the river and wades to the bank (Emergence), a heavy body breaks
## what it rises and wades into (D-208: "any contact a kaiju has with a building will damage it");
## nothing holds it there.
func emerging(dt: float) -> void:
	if _heavy.is_empty() or not active():
		return
	_follow(dt)
	var from := sim.kaiju_pos if _last_pos.x == INF else _last_pos
	var from_heading := heading if _last_pos.x == INF else _last_heading
	_sweep(from, from_heading, dt)
	_last_pos = sim.kaiju_pos
	_last_heading = heading
	_last_dir = body_dir


## Breaks every standing chunk the body (and a heavy body's tail) touched since `from`.
func _sweep(from: Vector2, from_heading: Vector2, dt: float) -> void:
	_volume.step_s = dt
	var s := sim.body_scale()
	var tail_to: Array = tail.discs(_centre(sim.kaiju_pos, heading), body_dir, s) if tail else []
	var tail_from: Array = _last_tail if _last_tail.size() == tail_to.size() else tail_to
	var was_dir := from_heading
	if not _heavy.is_empty():
		was_dir = _last_dir if _last_pos.x != INF else body_dir
	broken += _volume.sweep(
		_centre(from, from_heading, was_dir),
		was_dir,
		_centre(sim.kaiju_pos, heading),
		body_dir,
		tail_from,
		tail_to
	)
	_last_tail = tail_to


## A heavy body's drawn body follows the heading (D-200, its class's aim): it eases toward it, no
## faster than follow_deg_s plus catch_per_deg for every degree past catch_from_deg, and is dragged
## along so the neck never turns past neck_max_deg; its tail swings on the body's turning. Any
## other body faces the heading.
func _follow(dt: float) -> void:
	if _aim.is_empty():
		body_dir = heading
		return
	var err := body_dir.angle_to(heading)
	var past := maxf(0.0, rad_to_deg(absf(err)) - Num.f(_aim["catch_from_deg"]))
	var top := deg_to_rad(Num.f(_aim["follow_deg_s"]) + Num.f(_aim["catch_per_deg"]) * past)
	top = minf(top, absf(err) * Num.f(_aim["ease_per_s"]))
	body_dir = body_dir.rotated(clampf(err, -top * dt, top * dt))
	var most := deg_to_rad(Num.f(_aim["neck_max_deg"]))
	var left := body_dir.angle_to(heading)
	if absf(left) > most:
		body_dir = heading.rotated(-signf(left) * most)
	if tail != null:
		tail.step(atan2(-body_dir.x, -body_dir.y), dt)


## The middle of the body volume for the kaiju at `at` heading `h`: a heavy body's drawn body
## turns about its hips (pivot_ahead ahead of the middle) to `dir`; any other's is `at`.
func _centre(at: Vector2, h: Vector2, dir: Vector2 = body_dir) -> Vector2:
	if _heavy.is_empty():
		return at
	return at + (h - dir) * Num.f(_heavy["pivot_ahead"]) * sim.body_scale()


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
	if not _heavy.is_empty():
		most = deg_to_rad(Num.f(_heavy["turn_deg_s"])) * dt
	elif turns_in_steps():
		# a slice turns quicker than the average (steer), most so at the middle of a turn
		most *= 0.5 * PI * maxf(1.0, Num.f(cfg["turn_ease_peak"])) / Num.f(cfg["slice_open"])
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
## A heavy body's drawn body faces body_dir about its hips; its tail, which only sweeps, is not
## counted here (a tail brushing a tower does not hold the body back).
func inside(pos: Vector2, facing: Vector2) -> Dictionary:
	var out: Dictionary = {}
	var centre := _centre(pos, facing)
	var dir := facing if _heavy.is_empty() else body_dir
	_volume.collect(centre, dir, out, _volume.near(centre, centre, _volume.reach()))
	return out
