class_name BipedLeg
extends RefCounted
## One of the reptilian's legs (BipedGait): its bones, its foot in the world and its step state,
## and the two-bone IK that bends it to the planted or swinging foot.

var names: Array[String] = []
var tip := ""  ## the bone whose tail is the toe tip: leg_x3 when the rig has one, else the foot
var foot_dir := Vector3.ZERO  ## rest vector from the ankle to the toe tip, rig space (the foot)
var side := 1.0  ## -1 left (-x), +1 right
var offset := 0.0  ## phase offset in the stride
var home := Vector3.ZERO  ## rig space, on the ground
var l1 := 0.0
var l2 := 0.0
var foot := Vector3.ZERO  ## world
var planted := true
var lift_from := Vector3.ZERO
var t := 0.0
var swing_time := 0.4
var lift := 0.2
var stomping := false
var last_cycle := -1
var tilt := 0.0
var walking := false  ## this swing is a walk step (its pace follows the stride)
var down_for := 0.0  ## seconds since it planted
## Foot-slide meter: where the foot was planted, worst drift during this stance (world units).
var plant_at := Vector3.ZERO
var drift := 0.0


## The `side` leg ("l" or "r") of the rig, its home under the hip and `narrowing` x the toe's x;
## null when the rig has no such leg.
static func build(rig: KaijuRig, side: String, narrowing: float) -> BipedLeg:
	var leg := BipedLeg.new()
	for i: int in 3:
		leg.names.append("leg_%s%d" % [side, i])
	if not rig.has_bone(leg.names[2]):
		return null
	leg.side = -1.0 if side == "l" else 1.0
	leg.offset = 0.0 if side == "l" else 0.5
	leg.l1 = rig.dir_of(leg.names[0]).length()
	leg.l2 = rig.dir_of(leg.names[1]).length()
	leg.tip = "leg_%s3" % side if rig.has_bone("leg_%s3" % side) else leg.names[2]
	var toe := rig.head_of(leg.tip) + rig.dir_of(leg.tip)
	leg.foot_dir = toe - rig.head_of(leg.names[2])
	var hip := rig.head_of(leg.names[0])
	leg.home = Vector3(toe.x * narrowing, 0.0, hip.z - 0.06 * hip.y)
	return leg


## Bends the leg to its foot: the heel rises as the body passes over the toes, a swinging foot
## folds; the knee from the two-bone solve, its pole forward and out to its side.
func solve(g: BipedGait, root: Transform3D) -> void:
	var fwd := -root.basis.z.normalized()
	var right := root.basis.x.normalized()
	var hip := g.rig.bone(names[0]).global_position
	var behind := (hip - foot).dot(fwd) / (g.hip_height * g.s)
	if planted:
		tilt = lerpf(tilt, -clampf(behind * 0.4, -0.1, 0.25), 0.35)
	else:
		var fold := sin(PI * clampf(t, 0.0, 1.0))
		tilt = lerpf(tilt, -0.3 * fold + 0.06 * t, 0.5)
	var ankle := g._ankle(self, root)
	var pole := fwd + right * side * 0.2
	var knee := KaijuGait.solve_knee(hip, ankle, l1 * g.s, l2 * g.s, pole)
	g.rig.aim(names[0], hip, knee)
	g.rig.aim(names[1], knee, ankle)
	g.rig.aim(names[2], ankle, foot, foot_dir)
