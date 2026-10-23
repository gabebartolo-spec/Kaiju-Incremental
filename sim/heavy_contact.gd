class_name HeavyContact
extends RefCounted
## A heavy body's contact volume (D-208: "our carve destruction must still work"; "any contact a
## kaiju has with a building will damage it"): it rides the drawn body by construction. The sim's
## own clip clock (ClipClock) picks the clip and frame the presentation then shows (ClipGait reads
## it), and the body's slots are taken from the track baked from those same clips (HeavyTrack):
## the cross-fade between clips, a roar's walking legs, the claw rake, the maw held open, the
## head's look into the heading (D-200) and the tail's swing (TailSim) are laid on them as ClipGait
## lays them on the bones; a planted hind foot holds where it came down (its IK lock). The body's
## aim (D-200) lives here too. Part of BodyContact; pure, no randomness.

var sim: RampageSim
## The class's sim block (body_class <class> "sim", D-201) and aim (D-200).
var tune: Dictionary
var aim: Dictionary
var tail: TailSim
var track: HeavyTrack
var clock: ClipClock
## The claw rake as it runs (seconds in, < 0 none; its side), and the maw held open 0..1.
var rake_t := -1.0
var rake_side := 1.0
var jaw_hold := 0.0
var _rake_cross := 0.0
var _rake_total := 0.0
var _still := 0.0  # tuning clip_motion: standing under this ground speed (hip heights/s)
var _jaw_s := 1.0  # and the maw's open/shut time (s)
var _now := PackedFloat32Array()  # the pose this step: slots, heads, toes (body space)
var _hips_at := Vector2.INF
var _pose: HeavyPose
var _feet: HeavyFeet


## The heavy contact for a species at the sim's growth stage (classes: tuning "body_class"), or
## null for a body of no heavy class or with no track.
static func make(p_sim: RampageSim, classes: Dictionary, species_id: String) -> HeavyContact:
	var stage_names: Array[String] = ["baby", "adolescent", "adult"]
	var kind := "%s_%s" % [species_id, stage_names[clampi(p_sim.size_tier() - 1, 0, 2)]]
	var found := BodyClass.of(classes, kind)
	if found.is_empty():
		return null
	var p_track := HeavyTrack.of(kind)
	if not found.has("sim") or p_track == null:
		return null
	var out := HeavyContact.new()
	out._setup(p_sim, found, p_track)
	return out


func _setup(p_sim: RampageSim, found: Dictionary, p_track: HeavyTrack) -> void:
	sim = p_sim
	tune = found["sim"]
	aim = found.get("aim", {})
	track = p_track
	clock = ClipClock.new(track.meta)
	_pose = HeavyPose.new(track)
	_feet = HeavyFeet.new(track, _pose)
	var tails := 0
	for b: String in track.bones:
		tails += 1 if b.begins_with("tail") else 0
	var tail_tune: Dictionary = found.get("tail", {})
	tail = TailSim.new(tail_tune, tails) if not tail_tune.is_empty() else null
	var claw := Content.section("claw_fx")
	var lift := maxf(0.05, Num.f(sim.powers_cfg["swipe_windup"]) - Num.f(claw["strike_s"]) * 0.5)
	_rake_cross = lift + Num.f(claw["strike_s"]) * 0.5
	_rake_total = _rake_cross + Num.f(claw["strike_s"]) * 0.5 + Num.f(claw["recover_s"])
	var motion := Content.section("clip_motion")
	_still = Num.f(motion["still_hips_per_s"])
	_jaw_s = Num.f(motion["jaw_hold_s"])


## The walk sets off over start_s and comes to a stop over stop_s (D-201).
func start_s() -> float:
	return Num.f(tune["start_s"])


func stop_s() -> float:
	return Num.f(tune["stop_s"])


## Its turn clip's pace, whatever the beam (D-201): Vector2(top rad/s, rad/s^2).
func turn_pace() -> Vector2:
	return Vector2(
		deg_to_rad(Num.f(tune["turn_deg_s"])), deg_to_rad(Num.f(tune["turn_accel_deg_s2"]))
	)


## Where a body at `at` that turned from `was` to `now` stands: swung about its hips, pivot_ahead
## ahead of it, as its turn clip turns (D-201).
func about_hips(at: Vector2, was: Vector2, now: Vector2) -> Vector2:
	var hips := at + was * Num.f(tune["pivot_ahead"]) * sim.body_scale()
	return hips + (at - hips).rotated(was.angle_to(now))


## The middle of the body volume (the rig's origin) for the kaiju at `at` heading `h` with its
## drawn body facing `dir`: the body turns about its hips, pivot_ahead ahead of the middle.
func centre(at: Vector2, h: Vector2, dir: Vector2) -> Vector2:
	return at + (h - dir) * Num.f(tune["pivot_ahead"]) * sim.body_scale()


## The drawn body's way after dt (D-200, the class's aim): it eases toward the heading, no faster
## than follow_deg_s plus catch_per_deg for every degree past catch_from_deg, and is dragged along
## so the neck never turns past neck_max_deg; the tail swings on its turning.
func follow(dir: Vector2, heading: Vector2, dt: float) -> Vector2:
	if not aim.is_empty():
		var err := dir.angle_to(heading)
		var past := maxf(0.0, rad_to_deg(absf(err)) - Num.f(aim["catch_from_deg"]))
		var top := deg_to_rad(Num.f(aim["follow_deg_s"]) + Num.f(aim["catch_per_deg"]) * past)
		top = minf(top, absf(err) * Num.f(aim["ease_per_s"]))
		dir = dir.rotated(clampf(err, -top * dt, top * dt))
		var most := deg_to_rad(Num.f(aim["neck_max_deg"]))
		var left := dir.angle_to(heading)
		if absf(left) > most:
			dir = heading.rotated(-signf(left) * most)
	if tail != null:
		tail.step(atan2(-dir.x, -dir.y), dt)
	return dir


## The step's pose (call once a step, after the body moved and turned): the clip clock runs on
## (walking when the hips move over the ground), then the rake and the maw; the pose is laid out.
func step(dt: float) -> void:
	var body := sim.body
	var s := sim.body_scale()
	var hips := centre(sim.kaiju_pos, body.heading, body.body_dir) + body.body_dir * track.hips * s
	var moved := 0.0 if _hips_at.x == INF else hips.distance_to(_hips_at)
	_hips_at = hips
	var moving := moved > _still * track.hip_height * s * dt
	var err := wrapf(_yaw(body.heading) - _yaw(body.body_dir), -PI, PI)
	var phase := body.phase
	clock.step(dt, moving, err, func(_entering: bool) -> float: return track.walk_frame(phase))
	_feet.walk(clock)
	if rake_t >= 0.0:
		rake_t += dt
		rake_t = -1.0 if rake_t > _rake_total else rake_t
	var open := sim.powers.beam_left > 0.0
	jaw_hold = clampf(jaw_hold + (dt if open else -dt) / _jaw_s, 0.0, 1.0)
	_now = _pose.lay(clock, [rake_t, rake_side, jaw_hold])
	_pose.look(_now, err, Num.f(aim.get("neck_share", 0.0)))
	if tail != null:
		_pose.bend_tail(_now, tail.bends)
	var at := centre(sim.kaiju_pos, body.heading, body.body_dir)
	_feet.step(_now, _pose.bits, [at, body.body_dir, s], dt)


## How far the drawn body is sunk so no leg overreaches (world units; the leg solve shows it).
func sink() -> float:
	return _feet.sink


## Where hind foot i (0 the left) is down in the world, INF while it is up (the leg solve puts the
## drawn foot there).
func toe_lock(i: int) -> Vector2:
	return _feet.toe(i)


## Where lifted hind foot i's toe is in the world, INF while it is down (the drawn foot's way).
func toe_air(i: int) -> Vector2:
	return _feet.toe_air(i)


## The sim's events of the step just run: a roar (every ability, and an ultimate the sim roars
## on, RoarGate, as RoarCue sounds it) and the claw rake's cues.
func after_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		var kind := str(event["type"])
		if kind == "ability" or (kind == "ultimate" and event.get("roar", false) == true):
			clock.roar()
		elif kind == "swipe_windup" or kind == "swipe":
			rake_t = 0.0 if kind == "swipe_windup" else _rake_cross
			rake_side = Num.f(event["side"])


## The body's slots at a pose (its middle `at_centre`, its drawn body facing `dir`) in the world,
## [bottom centre, bottom radius, lowest, highest, top centre, top radius] (the sizes at body scale
## 1; BodyVolume takes the hull of the two discs): every slot of the pose (the tail's only when
## `tail`: a tail brushing a tower does not hold the body back); a planted hind foot's slots where
## it came down.
func discs(at_centre: Vector2, dir: Vector2, with_tail: bool = true) -> Array:
	var out: Array = []
	var s := sim.body_scale()
	var right := Vector2(-dir.y, dir.x)
	for j: int in track.slot_bone.size():
		if not with_tail and _pose.in_tail(j):
			continue
		var k := j * HeavyTrack.SLOT
		var held := _feet.spot(j)
		var lo := at_centre + (dir * _now[k] + right * _now[k + 1]) * s
		var hi := at_centre + (dir * _now[k + 5] + right * _now[k + 6]) * s
		if held.x != INF:
			lo = Vector2(held.x, held.y)
			hi = Vector2(held.z, held.w)
		out.append([lo, _now[k + 2], _now[k + 3], _now[k + 4], hi, _now[k + 7]])
	return out


## How far the body reaches from its middle (body scale 1), for the city search.
func reach() -> float:
	var most := 0.0
	for j: int in track.slot_bone.size():
		var k := j * HeavyTrack.SLOT
		most = maxf(most, Vector2(_now[k], _now[k + 1]).length() + _now[k + 2])
		most = maxf(most, Vector2(_now[k + 5], _now[k + 6]).length() + _now[k + 7])
	return most


## The presentation's yaw of a way in the sim's plane (0 facing -Z).
static func _yaw(v: Vector2) -> float:
	return atan2(-v.x, -v.y)
