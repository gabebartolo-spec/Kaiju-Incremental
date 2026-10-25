class_name ArmArc
extends RefCounted
## How a limb chain turns from one pose to another along arcs (BipedSwing's claw rake): pose
## directions per bone, root first, in any one frame.


## Bone i's direction k (0..1) of the way from pose `from` to pose `to`, along arcs: the upper arm
## turns along its own arc; a forearm or hand turns within the frame of the bone above it, so the
## elbow and wrist bends move straight from one pose's to the next and never flick open mid-way.
static func blend(i: int, from: Array[Vector3], to: Array[Vector3], k: float) -> Vector3:
	if i == 0:
		return from[0].slerp(to[0], k)
	var local_from := frame(from[i - 1]).transposed() * from[i]
	var local_to := frame(to[i - 1]).transposed() * to[i]
	return frame(blend(i - 1, from, to, k)) * local_from.slerp(local_to, k)


## A frame along direction d (z = d), rolled so its x stays level: the same d gives the same frame.
static func frame(d: Vector3) -> Basis:
	var side := Vector3.UP.cross(d)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	return Basis(side, d.cross(side), d)
