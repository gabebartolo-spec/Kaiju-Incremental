class_name ClipSteps
extends RefCounted
## The walk clip measured against the sim's step clock (KaijuGait.step_phase, BodyContact.phase):
## where its first footfall falls, how many frames one step takes and where its feet sit fore-aft,
## so ClipGait plants its feet where the sim turns the body. Presentation only.

## The most a foot spot is bent round (rad): a hard turn is caught up by catch steps instead.
const BEND_MAX := 0.1

var clips: KaijuClips
var land := 0.0  # the walk clip's first footfall (frame), the sim's step phase 0
var step_frames := 1.0  # walk clip frames in one step (half a cycle)
var foot_mid := 0.0  # the walk clip's feet, mean fore-aft position (rig space)
var swing_frames := 1.0  # walk clip frames a foot is in the air each cycle


func _init(p_clips: KaijuClips) -> void:
	clips = p_clips
	land = _first_landing()
	foot_mid = _mean_foot_z()
	step_frames = float(clips.frames_of("walk")) / clips.cycles_of("walk") * 0.5
	var up := 0
	for f: int in clips.frames_of("walk"):
		up += 0 if clips.pose_at("walk", float(f)).planted[0] else 1
	swing_frames = maxf(1.0, float(up) / clips.cycles_of("walk"))


## The walk frame the sim's step clock is at: its footfalls (integer phases) land on the clip's.
func frame_at(step_phase: float) -> float:
	return fposmod(land + step_phase * step_frames, float(clips.frames_of("walk")))


## A foot spot of the clip (rig space) with its fore-aft travel shortened to step_ratio of a full
## step (a quick step in a turn is a short one: the foot is passed at the pace the body walks).
func shortened(toe: Vector3, step_ratio: float) -> Vector3:
	toe.z = foot_mid + (toe.z - foot_mid) * step_ratio
	return toe


## A foot spot of the clip (rig space) bent onto the arc of a body turning `bend` rad per rig unit
## it walks, about its root: a planted foot stays where it stands in the world as the body turns.
func curved(toe: Vector3, bend: float) -> Vector3:
	return toe.rotated(Vector3.UP, clampf(bend * (toe.z - foot_mid), -BEND_MAX, BEND_MAX))


## The walk clip's feet, mean fore-aft position over the loop (rig space).
func _mean_foot_z() -> float:
	var sum := 0.0
	var n := clips.frames_of("walk")
	for f: int in n:
		var pose := clips.pose_at("walk", float(f))
		sum += clips.to_rig(pose.feet[0]).z + clips.to_rig(pose.feet[1]).z
	return sum / (2.0 * n)


## The walk clip's first footfall: the first frame a foot comes down (a foot planted that was not
## the frame before), wrapping round the loop.
func _first_landing() -> float:
	var n := clips.frames_of("walk")
	for f: int in n:
		var before := clips.pose_at("walk", float((f + n - 1) % n))
		var now := clips.pose_at("walk", float(f))
		for i: int in 2:
			if now.planted[i] and not before.planted[i]:
				return float(f)
	return 0.0
