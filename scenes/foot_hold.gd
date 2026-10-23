class_name FootHold
extends RefCounted
## A planted foot keeps its world yaw while the body turns over it (ClipGait): how far the rig
## faces, and how much of that hold the leg can reach. Presentation only.

## How far a leg may stretch (fraction of its length) to hold a planted foot's yaw.
const HELD_REACH := LegReach.REACH_MAX + 0.01  # the body sinks to REACH_MAX first (LegReach)

var _rig: KaijuRig


func _init(p_rig: KaijuRig) -> void:
	_rig = p_rig


## The rig's yaw in the world (rad, 0 = facing -Z).
func rig_yaw() -> float:
	var fwd := -_rig.global_transform.basis.z
	return atan2(-fwd.x, -fwd.z)


## The most of a foot's yaw hold (`fix`, rad) the leg can reach, at body scale `s`: the ankle stays
## within the leg's length of the hip with the toe on `toe` (bisected; the foot turns only as far
## as the leg allows).
func held(leg: BipedGait.Leg, s: float, toe: Vector3, fix: float) -> float:
	var hip := _rig.bone(leg.names[0]).global_position
	var ankle_now := _rig.bone(leg.names[2]).global_position
	var off := _rig.tail_world(leg.names[2]) - ankle_now
	var most := (leg.l1 + leg.l2) * s * HELD_REACH
	var k := 1.0
	var lo := 0.0
	var hi := 1.0
	for _n: int in 6:
		if (toe - Basis(Vector3.UP, fix * k) * off - hip).length() <= most:
			lo = k
		else:
			hi = k
		k = (lo + hi) * 0.5
	return fix * lo
