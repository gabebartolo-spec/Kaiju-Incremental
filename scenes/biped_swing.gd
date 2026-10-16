class_name BipedSwing
extends RefCounted
## The reptilian's tail and arms (spring chains BipedGait steers): the tail is carried level as
## a counterweight and swings against the hips; the small arms hang tucked and claw at a roar.

## Tail: lift (negative lowers), curl straightened (0..1), counter-swing, sway, stiffness.
const TAIL_LIFT := -0.1
const TAIL_STRAIGHTEN := 0.75
const TAIL_COUNTER := 1.6
const TAIL_SWAY := 0.035
const TAIL_STIFFNESS := 16.0
## Arms: tuck at rest, extra curl at a roar, elbow bend, swing against the hips.
const ARM_TUCK := 0.25
const ARM_ROAR := 0.4
const ARM_ELBOW := 0.35
const ARM_SWING := 0.8

var rig: KaijuRig
var _straight: Array[float] = []


func _init(p_rig: KaijuRig) -> void:
	rig = p_rig
	var tail := rig.chain_named("tail0")
	if tail == null:
		return
	tail.stiffness = TAIL_STIFFNESS
	var before := 0.0
	for n: String in tail.names:
		var d := rig.dir_of(n)
		var a := atan2(d.x, d.z) if absf(d.z) > 0.0001 else 0.0
		_straight.append(-(a - before) * TAIL_STRAIGHTEN)
		before = a


## hip_yaw: the pelvis's swing this frame; roar_open 0..1.
func update(time: float, hip_yaw: float, roar_open: float) -> void:
	var tail := rig.chain_named("tail0")
	if tail != null:
		var n := tail.drive.size()
		for i: int in n:
			var k := float(i + 1) / n
			var sway := sin(time * 0.9 - i * 0.45) * TAIL_SWAY
			var yaw := -TAIL_COUNTER * hip_yaw * k / n * 3.0 + sway + _straight[i]
			var lift := TAIL_LIFT * (1.0 - k)
			tail.drive[i] = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift)
	for side: String in ["l", "r"]:
		var chain := rig.chain_named("arm_%s0" % side)
		if chain == null:
			continue
		var sgn := -1.0 if side == "l" else 1.0
		var curl := Basis(Vector3.RIGHT, -ARM_TUCK - ARM_ROAR * maxf(0.0, roar_open))
		chain.drive[0] = Basis(Vector3.UP, -sgn * hip_yaw * ARM_SWING) * curl
		if chain.drive.size() > 1:
			chain.drive[1] = Basis(Vector3.RIGHT, -ARM_ELBOW)
