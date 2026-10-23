class_name BipedSwing
extends RefCounted
## The reptilian's tail and arms: the tail (a spring chain) is carried low and level as a
## counterweight and sweeps against the hips, the sweep travelling down it so the tip trails; the
## arms are posed muscle, held tucked and forward, braced in on a turn, clawing at a roar.

## Tail: lift per bone (positive lowers), sideways curl straightened (0..1), stiffness and
## gravity share (soft: it lags and droops between steps), the sweep against the hips (per bone,
## times the hip yaw), how fast that sweep travels down the tail (1/s), idle sway.
const TAIL_LIFT := -0.08
## A young tail is carried higher, clear of the legs; the tail flicks against the pelvis drop.
const TAIL_YOUTH_LIFT := -0.02
const TAIL_FLICK := 0.05
const TAIL_STRAIGHTEN := 0.75
const TAIL_STIFFNESS := 7.0
const TAIL_GRAVITY := 0.8
const TAIL_SWEEP := 0.9
const TAIL_DELAY := 4.0
const TAIL_SWAY := 0.03
## At most this much bend per tail bone (rad), so the voxel segments never part.
const TAIL_BEND_MAX := 0.12
## Tail whip (species power): length (s) and bend per bone at its height (rad).
const WHIP_SECONDS := 0.35
const WHIP := 0.22
## Arms (posed, never simulated: director, "limp scarves", "outstretched like a zombie"), as the
## Jurassic Park tyrannosaur and Godzilla 2014 carry theirs. Each bone is aimed along a direction
## in the body's heading frame (x outward, y up, -z forward), so it bends at the joint and never
## rolls: the upper arm hangs down and a little forward, the elbow is bent about 60 degrees so
## the forearm reaches forward with the hands resting in front of the belly, below the chest
## (director: a relaxed tyrannosaur hang), the hand drooping loosely. A roar lifts
## and spreads them into a claw; nothing else raises them.
const ARM_UPPER := Vector3(0.15, -0.92, -0.35)
const ARM_FORE := Vector3(-0.25, -0.2, -0.95)
const ARM_HAND := Vector3(-0.2, -0.55, -0.8)
const ARM_UPPER_ROAR := Vector3(0.45, -0.4, -0.8)
const ARM_FORE_ROAR := Vector3(0.2, 0.55, -0.8)
## A small counter-swing with the stride (rad of forward/back swing at the hips' full yaw), and a
## brace in on a turn (per rad/s of yaw rate, at most ARM_BRACE_MAX); both follow a stiff spring
## (rad/s, damping), so the lag is a few degrees and the arms never fling past the body line.
const ARM_STRIDE := 0.14
const ARM_BRACE := 0.25
const ARM_BRACE_MAX := 0.2
const ARM_OMEGA := 18.0
const ARM_ZETA := 0.9
## Claw rake (Claws, D-095; PR #89 motion review): on the sim's swipe_windup one arm swings up
## and out wide of the body, then on the swipe it rakes hard across the front to the far side
## (the sim's rake lands as it crosses the snout line) and hangs again; the arm reaches further
## (scaled) for the rake, more on a young body. Poses and timings: the "claw_fx" tuning.

var rig: KaijuRig
## The pelvis's drop speed (hip heights/s) and how young the body is (0..1), set each frame.
var hip_drop := 0.0
var youth := 0.0
## The body's turn rate (rad/s), set each frame: the arms brace in against it.
var yaw_rate := 0.0
## A gait that poses the arms itself sets this, and the raking claw lays its streak from the arm.
var trail: ClawTrail
var _straight: Array[float] = []
var _sweep: Array[float] = []  # the hips' yaw as it travels down the tail, one per bone
var _whip := 0.0  # 1 -> 0 over a tail whip
var _whip_side := 1.0
var _arm_swing := Vector2.ZERO
var _arm_brace := Vector2.ZERO
var _rake_t := -1.0  # seconds into a claw rake; negative when none runs
var _rake_side := 1.0
var _claw: Dictionary = _claw_timing()


func _init(p_rig: KaijuRig) -> void:
	rig = p_rig
	var tail := rig.springs.named("tail0")
	if tail == null:
		return
	tail.stiffness = TAIL_STIFFNESS
	tail.gravity_scale = TAIL_GRAVITY
	var before := 0.0
	for n: String in tail.names:
		var d := rig.dir_of(n)
		var a := atan2(d.x, d.z) if absf(d.z) > 0.0001 else 0.0
		_straight.append(-(a - before) * TAIL_STRAIGHTEN)
		_sweep.append(0.0)
		before = a


## hip_yaw: the pelvis's swing this frame; roar_open 0..1.
## A fast tail whip to one side (-1 left, +1 right): the species power's tail sweep.
func whip(side: float) -> void:
	_whip = 1.0
	_whip_side = side


## A species power's strike to one side (-1 left, +1 right): limb "claw_windup" lifts that arm,
## "claw" rakes it (the rake crosses now, synced to the sim), anything else whips the tail.
func strike(limb: String, side: float) -> void:
	if limb == "claw_windup":
		_rake_t = 0.0
		_rake_side = side
	elif limb == "claw":
		_rake_t = _rake_cross()
		_rake_side = side
	else:
		whip(side)


## The "claw_fx" tuning plus lift_s: the lift lasts until half a strike before the sim's rake
## lands (powers.swipe_windup after its windup cue), so the arm crosses as the hits land.
static func _claw_timing() -> Dictionary:
	var cfg: Dictionary = Content.section("claw_fx").duplicate()
	var windup := Num.f(Content.section("powers")["swipe_windup"])
	cfg["lift_s"] = maxf(0.05, windup - Num.f(cfg["strike_s"]) * 0.5)
	return cfg


## When (s into the rake) the arm crosses the snout line: the lift, then half the strike.
func _rake_cross() -> float:
	return Num.f(_claw["lift_s"]) + Num.f(_claw["strike_s"]) * 0.5


## The raking arm's sweep for the slash streaks: {"centre": shoulder (world), "radius": its reach
## now}, or {} when no arm on that side.
func claw_arc(side: float) -> Dictionary:
	for s: String in ["l", "r"]:
		if not rig.has_bone("arm_%s0" % s) or _arm_out(["arm_%s0" % s]) != side:
			continue
		var shoulder := rig.bone("arm_%s0" % s).global_position
		var reach := 0.0
		for i: int in 3:
			var n := "arm_%s%d" % [s, i]
			if rig.has_bone(n):
				reach += (rig.tail_world(n) - rig.bone(n).global_position).length()
		return {"centre": shoulder, "radius": reach, "trailed": trail != null}
	return {}


## Runs the whip down by dt (a gait that poses the tail itself calls this, then whip_yaw()).
func tick_whip(dt: float) -> void:
	_whip = maxf(0.0, _whip - dt / WHIP_SECONDS)


## The whip wave's yaw on tail bone i now (radians; 0 when no whip is running), base first.
func whip_yaw(i: int) -> float:
	if _whip <= 0.0:
		return 0.0
	var wave := clampf((1.0 - _whip) * PI * 1.6 - i * 0.22, 0.0, PI)
	return _whip_side * WHIP * sin(wave)


## Runs a claw rake on by dt; it ends after the recovery (a gait that poses the arms itself calls
## this, then pose_rake()).
func tick_rake(dt: float) -> void:
	if _rake_t < 0.0:
		return
	_rake_t += dt
	var total := _rake_cross() + Num.f(_claw["strike_s"]) * 0.5 + Num.f(_claw["recover_s"])
	if _rake_t > total:
		_rake_t = -1.0


## A rake as the sim runs it (HeavyContact, D-208): seconds into it (< 0: none) and its side.
func feed_rake(t: float, side: float) -> void:
	_rake_t = t
	_rake_side = side


## The raking arm alone, laid over the pose a clip gait has already put on the bones: from where the
## clip holds the arm, up and out, across the front, and back to where the clip holds it. Nothing
## is touched while no rake runs. The claw reach follows `youth`.
func pose_rake(dt: float) -> void:
	if _rake_t < 0.0:
		if trail != null:
			trail.update(Vector3.ZERO, false, dt)  # the last marks fade
		return
	var body := rig.global_transform.basis.orthonormalized()
	for side: String in ["l", "r"]:
		var names := _arm_names(side)
		if names.is_empty() or _arm_out(names) != _rake_side:
			continue
		var held: Array[Vector3] = []
		for n: String in names:
			var d := body.inverse() * (rig.tail_world(n) - rig.bone(n).global_position)
			held.append(d.normalized() * Vector3(_rake_side, 1, 1))
		_aim_arm(names, _rake_dirs(_rake_t, held), _rake_side, body)
		_reach_arm(names)
		if trail != null:  # the downswing and strike (and a beat after) leave the streak
			var lift := Num.f(_claw["lift_s"])
			var swinging := _rake_t >= lift and _rake_t < lift + Num.f(_claw["strike_s"]) * 1.3
			trail.update(rig.tail_world(names[-1]), swinging, dt)


func update(time: float, hip_yaw: float, roar_open: float, dt: float) -> void:
	tick_whip(dt)
	tick_rake(dt)
	var tail := rig.springs.named("tail0")
	if tail != null:
		var n := tail.drive.size()
		var before := hip_yaw
		for i: int in n:
			# The hips' swing reaches each bone a moment after the one before: the tail whips.
			_sweep[i] = lerpf(_sweep[i], before, minf(1.0, dt * TAIL_DELAY))
			before = _sweep[i]
			var k := float(i + 1) / n
			var sway := sin(time * 0.9 - i * 0.45) * TAIL_SWAY
			var bend := clampf(-TAIL_SWEEP * _sweep[i] + sway, -TAIL_BEND_MAX, TAIL_BEND_MAX)
			bend += whip_yaw(i)  # a whip wave running down the tail, base first
			var yaw := bend + _straight[i]
			var lift := (TAIL_LIFT + TAIL_YOUTH_LIFT * youth) * (1.0 - k * 0.5)
			lift += TAIL_FLICK * hip_drop * k
			tail.drive[i] = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift)
	_pose_arms(roar_open, hip_yaw, dt)


## The standing arm pose as the rig's rest pose: bone name -> rest basis that turns arm_<side>0/1/2
## (in rig space, which at rest is the heading frame) to point along ARM_UPPER/FORE/HAND. Bends at
## the joints, no roll.
static func rest_arm_bases(rig: KaijuRig) -> Dictionary:
	var out: Dictionary = {}
	var dirs: Array[Vector3] = [ARM_UPPER, ARM_FORE, ARM_HAND]
	for side: String in ["l", "r"]:
		if not rig.has_bone("arm_%s0" % side):
			continue
		var outward := signf(rig.dir_of("arm_%s0" % side).x)
		var above := Basis.IDENTITY  # the parent's rest orientation (the spine has none)
		for i: int in dirs.size():
			var n := "arm_%s%d" % [side, i]
			if not rig.has_bone(n):
				break
			var want := (dirs[i] * Vector3(outward, 1, 1)).normalized()
			var world := Basis(Quaternion(rig.dir_of(n).normalized(), want))
			out[n] = above.inverse() * world
			above = world
	return out


func _pose_arms(roar_open: float, hip_yaw: float, dt: float) -> void:
	var brace := minf(ARM_BRACE_MAX, absf(yaw_rate) * ARM_BRACE)
	var stride := clampf(hip_yaw / BipedBody.HIP_YAW, -1.0, 1.0) * ARM_STRIDE
	_arm_swing = KaijuGait.spring(_arm_swing.x, _arm_swing.y, stride, ARM_OMEGA, ARM_ZETA, dt)
	_arm_brace = KaijuGait.spring(_arm_brace.x, _arm_brace.y, brace, ARM_OMEGA, ARM_ZETA, dt)
	var body := rig.global_transform.basis.orthonormalized()
	var roar := clampf(roar_open, 0.0, 1.0)
	for side: String in ["l", "r"]:
		var names := _arm_names(side)
		if names.is_empty():
			continue
		var out := _arm_out(names)
		# The arm on the side of the trailing leg swings forward (left arm with the right leg).
		var swing := Basis(Vector3.RIGHT, -out * _arm_swing.x * (1.0 - roar))
		var dirs: Array[Vector3] = [
			swing * ARM_UPPER.lerp(ARM_UPPER_ROAR, roar) - Vector3(_arm_brace.x, 0, 0),
			swing * ARM_FORE.lerp(ARM_FORE_ROAR, roar),
			swing * ARM_HAND,
		]
		var raking := _rake_t >= 0.0 and out == _rake_side
		if raking:
			dirs = _rake_dirs(_rake_t, [ARM_UPPER, ARM_FORE, ARM_HAND])
		_aim_arm(names, dirs, out, body)
		if raking:
			_reach_arm(names)


## The bones of one side's arm (arm_<side>0..2 the rig has).
func _arm_names(side: String) -> Array[String]:
	var names: Array[String] = []
	for i: int in 3:
		if rig.has_bone("arm_%s%d" % [side, i]):
			names.append("arm_%s%d" % [side, i])
	return names


## Which side of the body an arm hangs on: -1 (-x) or +1, by its rest direction (a clip may pose the
## young body's arms across its chest).
func _arm_out(names: Array[String]) -> float:
	return signf(rig.dir_of(names[0]).x)


## Aims each bone of an arm along its direction (heading frame, x outward on side `out`).
func _aim_arm(names: Array[String], dirs: Array[Vector3], out: float, body: Basis) -> void:
	for i: int in names.size():
		var n := names[i]
		var from := rig.bone(n).global_position
		var length := (rig.tail_world(n) - from).length()
		var d := (dirs[i] * Vector3(out, 1, 1)).normalized()
		rig.aim(n, from, from + body * d * length)


## The whole raking arm reaches further (uniform: the hand follows), a young body's more.
func _reach_arm(names: Array[String]) -> void:
	var reach := lerpf(Num.f(_claw["arm_reach_adult"]), Num.f(_claw["arm_reach_young"]), youth)
	rig.bone(names[0]).scale = Vector3.ONE * lerpf(1.0, reach, _rake_reach(_rake_t))


## The raking arm's upper, fore and hand directions t seconds into the rake, along five legs:
## `rest` (where the arm hangs) -> up and out (lift_s) -> an arc outside the body's silhouette (the
## first arc_at of strike_s, so the camera sees the swing) -> across the front (the rest of
## strike_s, fast and even) -> out wide again (the first settle_at of recover_s) -> back to `rest`
## (the rest of recover_s, slowly, in view). Lift and the last leg ease; the strike does not.
func _rake_dirs(t: float, rest: Array[Vector3]) -> Array[Vector3]:
	var lift := Num.f(_claw["lift_s"])
	var strike := Num.f(_claw["strike_s"])
	var back := Num.f(_claw["recover_s"])
	var arc := strike * Num.f(_claw["arc_at"])
	var settle := back * Num.f(_claw["settle_at"])
	var up := _pose("arm_up")
	var legs: Array = [
		[rest, up, 0.0, lift, true],
		[up, _pose("arm_arc"), lift, arc, false],
		[_pose("arm_arc"), _pose("arm_across"), lift + arc, strike - arc, false],
		[_pose("arm_across"), _pose("arm_settle"), lift + strike, settle, false],
		[_pose("arm_settle"), rest, lift + strike + settle, back - settle, true],
	]
	var leg: Array = legs[-1]
	for candidate: Array in legs:
		if t < Num.f(candidate[2]) + Num.f(candidate[3]):
			leg = candidate
			break
	var k := clampf((t - Num.f(leg[2])) / maxf(Num.f(leg[3]), 0.0001), 0.0, 1.0)
	k = smoothstep(0.0, 1.0, k) if leg[4] else k
	var from: Array[Vector3] = leg[0]
	var to: Array[Vector3] = leg[1]
	var out: Array[Vector3] = []
	for i: int in rest.size():
		out.append(from[i].lerp(to[i], k))
	return out


## How far into its extra reach the raking arm is (0..1): out over the lift, held through the
## strike, back over the recovery.
func _rake_reach(t: float) -> float:
	var lift := Num.f(_claw["lift_s"])
	var strike := Num.f(_claw["strike_s"])
	if t < lift:
		return smoothstep(0.0, 1.0, t / lift)
	if t < lift + strike:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (t - lift - strike) / Num.f(_claw["recover_s"]))


## A "claw_fx" arm pose: [upper, fore, hand] directions in the heading frame (x outward).
func _pose(key: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Array in _claw[key]:
		out.append(Vector3(Num.f(v[0]), Num.f(v[1]), Num.f(v[2])))
	return out
