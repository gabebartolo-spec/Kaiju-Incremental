class_name ClipRestep
extends RefCounted
## When a clip-driven kaiju's (ClipGait) planted foot has been left too far behind or ahead of its
## clip spot to hold, so it takes a quick catch step (ClipStomp.restep), and the walk frame a
## standing kaiju sets off from. The legs set off one at a time: the young croc once set off with
## both feet catching up at once (director 2026-10-29).

## A planted foot that ends this far from its clip spot (strides), or past a straight leg (fraction
## of the leg's length), takes a catch step. At 0.98 the adolescent's long legs, nearly straight at
## heel strike, re-stepped on every plant (PR #54).
const RESTEP_GAP := 0.3
const RESTEP_REACH := 1.0
## Off the walk, a foot holds this much (fraction of the leg's length) past the clip's own reach:
## the 36-bone baby's idle keys his legs straight (0.999), and both feet tripped as he set off.
const STAND_SLACK := 0.05
## Setting off, a foot holds to this gap (strides) while the other foot is in the air.
const SET_OFF_GAP := 0.5

## A smooth turner's foot still down where it stood when the walk set off takes no catch step on
## reach (the baby's walk keys his leg straight, which read as overreach on the first frame), nor
## while the other foot is in the air.
var set_off: Array[bool] = [false, false]


## A clip starts: `walking` when a smooth turner sets off into the walk from another clip.
func go(walking: bool) -> void:
	set_off = [walking, walking]


## Foot i is down (`planted`) this frame: once lifted, it is past setting off.
func update(i: int, planted: bool) -> void:
	set_off[i] = set_off[i] and planted


## True when foot i, planted at `lock`, has been left too far from its clip spot to hold.
func overreached(gait: ClipGait, i: int, lock: Vector3, clip_toe: Vector3) -> bool:
	var leg := gait.legs[i]
	var gap := (lock - clip_toe).length()
	if set_off[i]:  # held through the other foot's step; only a gap catches it up
		return gap > (RESTEP_GAP if gait.legs[1 - i].planted else SET_OFF_GAP) * gait.stride()
	if gap > RESTEP_GAP * gait.stride():
		return true
	var hip := gait.rig.bone(leg.names[0]).global_position
	var to_ankle := gait.rig.bone(leg.names[2]).global_position - gait.rig.tail_world(leg.tip)
	var length := (leg.l1 + leg.l2) * gait.s
	var reach := RESTEP_REACH * length
	if gait.state != "walk":  # standing on a straight-keyed leg is not overreach (STAND_SLACK)
		reach = maxf(reach, (clip_toe + to_ankle - hip).length() + STAND_SLACK * length)
	return (lock + to_ankle - hip).length() > reach


## The walk frame to start from: the one whose feet stand nearest where the feet are now (rig
## space), so the first stance does not overreach. Every foot counts, lifted or not: counting only
## the planted ones chose a frame with one foot in the air, near its far end.
static func walk_entry(gait: ClipGait) -> float:
	var best := 0.0
	var best_cost := INF
	var to_rig := gait.rig.global_transform.affine_inverse()
	for t: int in gait.clips.frames_of("walk"):
		var pose := gait.clips.pose_at("walk", t)
		var cost := 0.0
		for i: int in mini(gait.legs.size(), 2):
			var now := to_rig * gait.rig.tail_world(gait.legs[i].tip)
			cost += (gait.clips.to_rig(pose.feet[i]) - now).length()
		if cost < best_cost:
			best_cost = cost
			best = t
	return best
