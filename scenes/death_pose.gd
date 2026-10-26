class_name DeathPose
extends RefCounted
## His body while he dies (DeathOverload): the gait lets go and the stagger clip plays once from
## where he stood (a short cross-fade), then holds its last frame, the pose the stone freezes him
## in (director 2026-10-26: "good if he freezes in that end pose"). The clip is keyed in Cascadeur
## (D-199, D-216: no procedural creature motion). A rig without the clip (every kaiju until the
## game_r11 export ships "death_stagger") holds the pose it had when he died. Presentation only.

const BLEND_SECONDS := 0.2

var rig: KaijuRig
var clips: KaijuClips
var clip := ""
## Clip frames played (held at the last frame).
var frame := 0.0
var _from: KaijuClips.Pose
var _blend := 0.0


## The death pose for `rig`, playing `clip_name` when its gait has that clip baked.
func _init(p_rig: KaijuRig, clip_name: String) -> void:
	rig = p_rig
	if rig == null or not rig.gait is ClipGait:
		return
	var gait := rig.gait as ClipGait
	if not gait.clips.has_clip(clip_name):
		return
	clips = gait.clips
	clip = clip_name
	_from = clips.pose_at(gait.state, gait.clip_time)


## True when the clip plays; false: the body holds the pose it died in.
func plays() -> bool:
	return clips != null


## True once the clip has reached its last frame (at once when there is no clip).
func held() -> bool:
	return not plays() or frame >= clips.frames_of(clip) - 1


func update(delta: float) -> void:
	if not plays():
		return
	frame = minf(frame + delta * clips.fps, clips.frames_of(clip) - 1)
	_blend = minf(1.0, _blend + delta / BLEND_SECONDS)
	var pose := KaijuClips.mix(_from, clips.pose_at(clip, frame), smoothstep(0.0, 1.0, _blend))
	for i: int in clips.bones.size():
		var offset := pose.offset * clips.rig_scale if i == 0 else Vector3.ZERO
		rig.pose_basis(clips.bones[i], Basis(pose.turns[i]), offset)
