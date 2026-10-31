class_name ClipLash
extends RefCounted
## The tail lash keyed in Cascadeur (director 2026-10-31: the fix3 takes, "looks shippable"): on a
## body whose clips carry the layer clips "lash_r" and "lash_l" it replaces BipedSwing's code whip.
## On the sim's tail_windup the clip starts so its hit frame (the tail crossing behind him) comes
## powers.lash_windup later, when the sim's lash lands; the sim's tail_sweep snaps it to that frame.
## It is laid over whatever the body plays: the tail takes the lash's own turns, and the pelvis,
## spine, neck and head add the lash's twist to their own (the hips counter and lead the strike).
## Presentation only: it reads the sim's cues.

## Seconds the layer takes to come in when a lash starts and to leave as its clip ends.
const FADE_SECONDS := 0.3
## The bones that add the lash's twist to the clip's (the tail takes its turns outright).
const TWIST_PREFIXES: Array[String] = ["pelvis", "spine", "lumbar", "chest", "neck", "head"]

var clips: KaijuClips
## True when the clips carry both keyed lashes: the sim's tail cues come here (BipedSwing.clip_lash).
var on := false
## The lash playing ("lash_r" or "lash_l"; "" when none) and its time (clip frames; negative while
## it waits for its start).
var clip := ""
var clip_time := 0.0
var _age := 0.0
var _windup := 0.0
var _tail: Array[int] = []
var _twist: Array[int] = []
var _rest: Dictionary = {}


func _init(p_clips: KaijuClips, swing: BipedSwing) -> void:
	clips = p_clips
	on = true
	for lash: String in ["lash_r", "lash_l"]:
		on = on and clips.has_clip(lash) and clips.is_layer(lash)
	if not on:
		return
	swing.clip_lash = self
	_windup = Num.f(Content.section("powers")["lash_windup"])
	for i: int in clips.bones.size():
		var bone_name := clips.bones[i]
		if bone_name.begins_with("tail"):
			_tail.append(i)
		elif TWIST_PREFIXES.any(func(p: String) -> bool: return bone_name.begins_with(p)):
			_twist.append(i)
	for lash: String in ["lash_r", "lash_l"]:
		_rest[lash] = clips.pose_at(lash, 0.0)


## The sim's cue: "tail_windup" starts the lash to that side, "tail" puts it at its hit frame
## (starting it there if none was wound up).
func cue(limb: String, side: float) -> void:
	var want := "lash_r" if side > 0.0 else "lash_l"
	if limb == "tail_windup":
		clip = want
		clip_time = clips.hit_frame(want) - _windup * clips.fps
		_age = 0.0
	elif clip != want:
		clip = want
		_age = 0.0
		clip_time = clips.hit_frame(want)


## Runs the lash on by dt and lays it over the clip's pose; returns the pose.
func layer(pose: KaijuClips.Pose, dt: float) -> KaijuClips.Pose:
	if clip.is_empty():
		return pose
	clip_time += dt * clips.fps
	_age += dt
	if clip_time >= clips.frames_of(clip) - 1:
		clip = ""
		return pose
	var w := weight()
	if w <= 0.0:
		return pose
	var now := clips.pose_at(clip, clip_time)
	var rest: KaijuClips.Pose = _rest[clip]
	for i: int in _tail:
		pose.turns[i] = pose.turns[i].slerp(now.turns[i], w)
	for i: int in _twist:
		var twist := now.turns[i] * rest.turns[i].inverse()
		pose.turns[i] = (Quaternion.IDENTITY.slerp(twist, w) * pose.turns[i]).normalized()
	return pose


## How much of the lash is laid on now (0..1): in over FADE_SECONDS, out over the clip's last
## FADE_SECONDS; 0 while it waits.
func weight() -> float:
	if clip.is_empty() or clip_time < 0.0:
		return 0.0
	var out := (clips.frames_of(clip) - 1.0 - clip_time) / (FADE_SECONDS * clips.fps)
	return smoothstep(0.0, 1.0, _age / FADE_SECONDS) * smoothstep(0.0, 1.0, out)
