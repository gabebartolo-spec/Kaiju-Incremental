class_name BipedSwing
extends RefCounted
## The reptilian's tail and arms (spring chains BipedGait steers): the tail is carried low and
## level as a counterweight and sweeps against the hips, the sweep travelling down it so the tip
## trails; the arms are tucked against the chest, jiggle with each step and claw at a roar.

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
## Arms: tucked against the chest (down-curl, inward turn, elbow bend), extra curl at a roar,
## a little swing against the hips; soft chains so they jiggle with each step.
const ARM_TUCK := 0.75
const ARM_IN := 0.5
const ARM_ELBOW := 0.9
const ARM_ROAR := 0.4
const ARM_SWING := 0.5
const ARM_STIFFNESS := 14.0
const ARM_YOUTH_EASE := 0.75

var rig: KaijuRig
## The pelvis's drop speed (hip heights/s) and how young the body is (0..1), set each frame.
var hip_drop := 0.0
var youth := 0.0
var _straight: Array[float] = []
var _sweep: Array[float] = []  # the hips' yaw as it travels down the tail, one per bone
var _whip := 0.0  # 1 -> 0 over a tail whip
var _whip_side := 1.0


func _init(p_rig: KaijuRig) -> void:
	rig = p_rig
	for side: String in ["l", "r"]:
		var arm := rig.chain_named("arm_%s0" % side)
		if arm != null:
			arm.stiffness = ARM_STIFFNESS
	var tail := rig.chain_named("tail0")
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


func update(time: float, hip_yaw: float, roar_open: float, dt: float) -> void:
	_whip = maxf(0.0, _whip - dt / WHIP_SECONDS)
	var tail := rig.chain_named("tail0")
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
			if _whip > 0.0:  # a whip wave running down the tail, base first
				var wave := clampf((1.0 - _whip) * PI * 1.6 - i * 0.22, 0.0, PI)
				bend += _whip_side * WHIP * sin(wave)
			var yaw := bend + _straight[i]
			var lift := (TAIL_LIFT + TAIL_YOUTH_LIFT * youth) * (1.0 - k * 0.5)
			lift += TAIL_FLICK * hip_drop * k
			tail.drive[i] = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift)
	for side: String in ["l", "r"]:
		var chain := rig.chain_named("arm_%s0" % side)
		if chain == null:
			continue
		var sgn := -1.0 if side == "l" else 1.0
		# A young body's arms stay nearer their sculpted pose (tucking them bares unmodelled chest).
		var tuck := 1.0 - ARM_YOUTH_EASE * youth
		var curl := Basis(Vector3.RIGHT, -ARM_TUCK * tuck - ARM_ROAR * maxf(0.0, roar_open))
		var tuck_in := Basis(Vector3.UP, sgn * ARM_IN * tuck - sgn * hip_yaw * ARM_SWING)
		chain.drive[0] = tuck_in * curl
		if chain.drive.size() > 1:
			chain.drive[1] = Basis(Vector3.RIGHT, -ARM_ELBOW)
