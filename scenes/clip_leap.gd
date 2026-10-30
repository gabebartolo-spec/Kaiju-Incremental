class_name ClipLeap
extends RefCounted
## ClipGait's leap: the Cascadeur leap clip (r13f) on the sim's Dash phases (KaijuModel.leap). The
## crouch plays the clip to its lift-off, the flight to its landing, and the settle and recover
## share the rest (the settle's share given by the sim's seconds). The sim flies the body
## (Dash.height), so the clip's own rise is taken out, and the feet ride the body through the
## flight and the settle (it sinks through the roof it landed on). Presentation only.

const CLIP := "leap"

## True while the sim's leap drives the pose (set by ClipGait.leap each frame; grounded clears it).
var on := false
var _clips: KaijuClips
var _air := Vector2.ZERO  # the clip's lift-off and landing frames
var _rest_y := 0.0  # the pelvis's height standing (frame 0)
var _rides := false


func _init(clips: KaijuClips) -> void:
	_clips = clips
	if not clips.has_clip(CLIP):
		return
	var n := clips.frames_of(CLIP)
	var off := 0
	while off < n - 1 and _down(off):
		off += 1
	var land := off
	while land < n - 1 and not _down(land):
		land += 1
	_air = Vector2(off, land)
	_rest_y = clips.pose_at(CLIP, 0.0).offset.y


## Whether the gait has a leap clip to play.
func playable() -> bool:
	return _clips.has_clip(CLIP)


## The clip frame for a Dash phase t (0..1) through it.
func frame(phase: String, t: float, settle_share: float) -> float:
	var last := float(_clips.frames_of(CLIP) - 1)
	var mid := lerpf(_air.y, last, settle_share)
	on = true
	_rides = phase == "flight" or phase == "settle"
	match phase:
		"crouch":
			return lerpf(0.0, _air.x, t)
		"flight":
			return lerpf(_air.x, _air.y, t)
		"settle":
			return lerpf(_air.y, mid, t)
	return lerpf(mid, last, t)


## The leap pose with the clip's rise taken out (the sim lifts the body), its feet lifted while
## they ride the body; any other pose as it is. Called once a frame: the leap's hold ends with it.
func grounded(pose: KaijuClips.Pose) -> KaijuClips.Pose:
	if not on:
		return pose
	on = false
	var lift := Vector3.UP * maxf(0.0, pose.offset.y - _rest_y)
	pose.offset -= lift
	pose.feet = [pose.feet[0] - lift, pose.feet[1] - lift]
	if _rides:
		pose.planted = [false, false]
	return pose


func _down(at: int) -> bool:
	var p := _clips.pose_at(CLIP, at)
	return p.planted[0] or p.planted[1]
