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
## Where a heavy body's drawn body faces (D-200, "Head aims, body follows"): it follows the heading
## at the aim's pace and never lets the neck turn past its cap; the body volume faces it about the
## hips. The heading for any other body.
var body_dir := Vector2(0, -1)
## A heavy body's tail swing (D-208, TailSim); null for any other body.
var tail: TailSim
## A heavy body's contact (D-208): its clip clock and the volume that rides the drawn body; null for
## any other body.
var heavy_contact: HeavyContact
## The discs at body scale 1, in design units: [forward offset, radius, bottom, top]; empty
## for a species without a body volume (then the body only slows in walls, as before).
var _discs: Array = []
var _volume: BodyVolume
var _last_pos := Vector2(INF, INF)
var _last_heading := Vector2(0, -1)
var _hold_s := 0.0
var _spin := 0.0  # how fast the body turns now (rad/s, signed as turn_left)
var _steps: BodySteps  # its feet and stepped turn (a body that walks by steps)
var _standing := true  # the stick was zero last step: the next step sets off on a footfall
var _walked_s := 0.0  # seconds since the body set off from a stand
var _last_dir := Vector2(0, -1)
var _last_tail: Array = []  # a heavy body's discs at the last step (world)
var _classes: Dictionary = {}  # tuning "body_class"


## tuning: the rampage's whole tuning; the body reads its "contact" section.
func _init(p_sim: RampageSim, tuning: Dictionary) -> void:
	sim = p_sim
	cfg = tuning["contact"]
	heading = sim.facing
	_last_heading = heading
	_steps = BodySteps.new(cfg)
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
		_steps.step_len = Num.f(stage.get("step_len", cfg["step_len"]))
		var pivot: Array = stage.get("pivot", [0.0, 0.0])
		_steps.pivot = Vector2(Num.f(pivot[0]), Num.f(pivot[1]))
	body_dir = heading
	_last_dir = heading
	_last_tail = []
	heavy_contact = HeavyContact.make(sim, _classes, species_id)
	tail = heavy_contact.tail if heavy_contact != null else null
	if heavy_contact != null:  # its volume rides its drawn body (D-208): HeavyContact.discs
		_volume.discs = []


## Faces the body (and its drawn body) `dir` at once: a facing set from outside, not a turn.
func face_now(dir: Vector2) -> void:
	heading = dir
	body_dir = dir
	_last_dir = dir
	_last_heading = dir


## True for a body of a heavy weight class (body_class sim, D-201): its animations lead.
func heavy() -> bool:
	return heavy_contact != null


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
		# sets off on a footfall, both feet down; a heavy body still rolling to its stop (D-201's
		# stop_s) walks on from where its clock is: rounding it jumped the walk clip it rides
		if not heavy() and stride <= 0.0:
			phase = roundf(phase)
		step_ratio = 1.0
		_steps.plant_both(self)
		_standing = false
	turn_left = sim.facing.angle_to(want)
	var stepped := _steps.steps_this_turn(self)
	var keep := lerpf(1.0, Num.f(cfg["turn_slow"]), absf(turn_left) / PI)
	# Sets off at full pace at once, but ramped over walk_off_s, not one frame (the motion critic,
	# 2026-10-22: "the walk start jumps to full speed"); after it the stride eases to the push.
	_walked_s += dt
	var off_s := heavy_contact.start_s() if heavy() else Num.f(cfg["walk_off_s"])
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
		_steps.swing(self, was, absf(turn))
	else:
		_turn_about_hips(was)
	return stride


## The stick is at rest: the body stands, and the next push sets off on a footfall.
func _stand(dt: float) -> void:
	# a heavy body comes to a stop over stop_s (D-201); the rest stop at once
	var stop := heavy_contact.stop_s() if heavy() else 0.0
	stride = move_toward(stride, 0.0, dt / stop) if stop > 0.0 else 0.0
	turn_left = 0.0
	_spin = 0.0
	_steps.cadence = 0.0
	_standing = true
	_walked_s = 0.0
	_steps.real_turn = false
	var was := heading
	_face(dt)
	_turn_about_hips(was)


## How fast the body may turn now, Vector2(top rad/s, rad/s^2); a stepped turn also eases in the
## cadence it adds to the step clock (quick short steps).
func _pace(dt: float, stepped: bool) -> Vector2:
	if heavy():  # its turn clip's pace, whatever the beam (D-201)
		_steps.cadence = 0.0
		return heavy_contact.turn_pace()
	var top := lerpf(_rate("turn_rate_still"), _rate("turn_rate"), stride)
	var accel := Num.f(cfg["turn_accel"])
	if sim.powers.beam_left > 0.0:  # the beam follows the stick at its own pace, whatever the size
		top = maxf(top, sim.powers.beam_turn_rate())
	var cadence := 0.0
	if stepped:
		accel = Num.f(cfg["slice_accel"])
		var paced := _steps.stepped_pace(self, top)  # floats: a Vector2 rounds them to 32 bits
		top = paced[0]
		cadence = paced[1]
	_steps.cadence = move_toward(_steps.cadence, cadence, Num.f(cfg["cadence_ease"]) * dt)
	return Vector2(top, accel)


## A heavy body turns about its hips, as its turn clip does (D-201; HeavyContact.about_hips).
func _turn_about_hips(was: Vector2) -> void:
	if heavy() and not dash.on():
		sim.kaiju_pos = heavy_contact.about_hips(sim.kaiju_pos, was, heading)


## True when this body walks by steps (it has planted feet): the stepped turn and the step clock.
func stepping() -> bool:
	return _steps.pivot.x > 0.0


## True when the turn is made in steps: a body with planted feet, except while the beam is on,
## which is swept smoothly by the stick (its own turn speed, SpeciesPowers.turn_toward).
func turns_in_steps() -> bool:
	return stepping() and sim.powers.beam_left <= 0.0 and not heavy()


## The step clock for the legs to follow (steps walked), INF for a body that does not step.
func step_clock() -> float:
	return phase if stepping() else INF


## The kaiju has walked `distance` world units in dt (a stride or a dash): the step clock follows,
## at least as fast as a turn's cadence (a turn takes short quick steps).
func walked(distance: float, dt: float) -> void:
	if stepping():
		var before := floorf(phase)
		var steps := distance / (_steps.step_len * sim.body_scale())
		var moved := maxf(steps, _steps.cadence * dt)
		phase += moved
		if moved > 0.0:
			step_ratio = maxf(steps / moved, Num.f(cfg["step_ratio_min"]))
		if floorf(phase) != before:  # a footfall: that foot comes down short of a full step
			_steps.footfall(self)


## Carries a dash (dash_pressed: the button this step), faces the body where sim.facing points,
## then breaks what the body moved or turned into.
func step(dt: float, dash_pressed: bool = false) -> void:
	dash.step(dt, dash_pressed)
	if not heavy():  # a heavy body turned once this step, about its hips (steer, D-201)
		_face(dt)
	_follow(dt)
	if heavy_contact != null:
		heavy_contact.step(dt)
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
	_remember()


## The pose this step ends on, for the next step's sweep.
func _remember() -> void:
	_last_pos = sim.kaiju_pos
	_last_heading = heading
	_last_dir = body_dir


## While the kaiju rises out of the river and wades to the bank (Emergence), a heavy body breaks
## what it rises and wades into (D-208: "any contact a kaiju has with a building will damage it");
## nothing holds it there.
func emerging(dt: float) -> void:
	if heavy_contact == null or not active():
		return
	_follow(dt)
	heavy_contact.step(dt)
	if _last_pos.x == INF:
		_remember()
	_sweep(_last_pos, _last_heading, dt)
	_remember()


## Breaks every standing chunk the body (a heavy body's own discs too) touched since `from`.
func _sweep(from: Vector2, from_heading: Vector2, dt: float) -> void:
	_volume.step_s = dt
	var centre := _centre(sim.kaiju_pos, heading)
	var moving_to: Array = []
	var was_dir := from_heading
	if heavy_contact != null:
		moving_to = heavy_contact.discs(centre, body_dir)
		was_dir = _last_dir if _last_pos.x != INF else body_dir
	var moving_from: Array = _last_tail if _last_tail.size() == moving_to.size() else moving_to
	var move := BodyVolume.Move.new(_centre(from, from_heading, was_dir), was_dir, centre, body_dir)
	broken += _volume.sweep(move, moving_from, moving_to)
	_last_tail = moving_to


## The sim's events of the step just run (a heavy body's clip clock takes its roars and rakes).
func after_events(events: Array[Dictionary]) -> void:
	if heavy_contact != null:
		heavy_contact.after_events(events)


## A heavy body's drawn body follows the heading (D-200, its class's aim): it eases toward it, no
## faster than follow_deg_s plus catch_per_deg for every degree past catch_from_deg, and is dragged
## along so the neck never turns past neck_max_deg; its tail swings on the body's turning. Any
## other body faces the heading.
func _follow(dt: float) -> void:
	body_dir = heading if heavy_contact == null else heavy_contact.follow(body_dir, heading, dt)


## The middle of the body volume for the kaiju at `at` heading `h`: a heavy body's drawn body
## turns about its hips (pivot_ahead ahead of the middle) to `dir`; any other's is `at`.
func _centre(at: Vector2, h: Vector2, dir: Vector2 = body_dir) -> Vector2:
	return at if heavy_contact == null else heavy_contact.centre(at, h, dir)


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
	if heavy():
		most = heavy_contact.turn_pace().x * dt
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
	return _volume.over(sim.buildings[index], _discs, [sim.kaiju_pos, heading])


## Every standing chunk inside the body at a pose: {building index: {Vector3i: true}}.
## A heavy body's drawn body faces body_dir about its hips; its tail, which only sweeps, is not
## counted here (a tail brushing a tower does not hold the body back).
func inside(pos: Vector2, facing: Vector2) -> Dictionary:
	var out: Dictionary = {}
	var centre := _centre(pos, facing)
	var dir := facing if heavy_contact == null else body_dir
	var own := [] if heavy_contact == null else heavy_contact.discs(centre, dir, false)
	var reach := _volume.reach()
	if heavy_contact != null:
		reach = maxf(reach, heavy_contact.reach() * sim.body_scale())
	_volume.collect([centre, dir], out, _volume.near(centre, centre, reach), own)
	return out
