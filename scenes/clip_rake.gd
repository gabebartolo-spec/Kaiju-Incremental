class_name ClipRake
extends RefCounted
## The claw rake keyed in Cascadeur (D-185, D-199): on a body whose clips carry the layer clips
## "rake_r" and "rake_l" (the adult croc) it replaces BipedSwing's code rake. On the sim's
## swipe_windup the rake clip starts so its hit frame (the claws crossing the snout line, D-190)
## comes powers.swipe_windup later, when the sim's rake lands (D-166); the sim's swipe snaps it to
## that frame. It is laid over whatever the body plays (idle, walk, a turn): both arms take the
## rake's turns (the off arm draws back out of the raking hand's way), and the lower spine, chest,
## neck, head and tail add the rake's twist to their own (the shoulders and body twist into it);
## the pelvis, legs and jaw stay the clip's. While the claws sweep (the clip's trail frames) the
## raking hand lays the streak (ClawTrail, D-243). Presentation only: it reads the sim's cues.

## Seconds the layer takes to come in when a rake starts and to leave as its clip ends.
const FADE_SECONDS := 0.3
## The bones that take the rake's own turns, and those that add its twist to the clip's.
const ARMS: Array[String] = ["arm_l0", "arm_l1", "arm_l2", "arm_r0", "arm_r1", "arm_r2"]
const TWIST_PREFIXES: Array[String] = ["spine1", "spine2", "head0", "head1", "tail"]

var clips: KaijuClips
var rig: KaijuRig
var trail: ClawTrail
## True when the clips carry both keyed rakes: the sim's claw cues come here (BipedSwing.clip_rake).
var on := false
## The rake playing ("rake_r" or "rake_l"; "" when none) and its time (clip frames; negative while
## it waits for its start).
var clip := ""
var clip_time := 0.0
var _age := 0.0  # seconds since the rake started (its fade in)
var _windup := 0.0  # powers.swipe_windup: the sim's cue comes this long before its rake lands
var _arms: Array[int] = []
var _twist: Array[int] = []
var _rest: Dictionary = {}  # clip -> its frame 0 (the twist is taken against it)


## Gives the gait's swing its claw streak, and takes the claw cues from it when the clips carry
## the keyed rakes.
func _init(p_rig: KaijuRig, p_clips: KaijuClips, swing: BipedSwing) -> void:
	rig = p_rig
	clips = p_clips
	trail = ClawTrail.new(rig)
	swing.trail = trail
	on = true
	for rake: String in ["rake_r", "rake_l"]:
		on = on and clips.has_clip(rake) and clips.is_layer(rake)
	if not on:
		return
	swing.clip_rake = self
	_windup = Num.f(Content.section("powers")["swipe_windup"])
	for i: int in clips.bones.size():
		var bone_name := clips.bones[i]
		if ARMS.has(bone_name):
			_arms.append(i)
		elif TWIST_PREFIXES.any(func(p: String) -> bool: return bone_name.begins_with(p)):
			_twist.append(i)
	for rake: String in ["rake_r", "rake_l"]:
		_rest[rake] = clips.pose_at(rake, 0.0)


## The sim's cue (BipedSwing.strike): "claw_windup" starts the rake on that side, "claw" puts it at
## its hit frame (starting it there if no rake on that side was wound up).
func cue(limb: String, side: float) -> void:
	var want := _clip_for(side)
	if want.is_empty():
		return
	if limb == "claw_windup":
		clip = want
		clip_time = clips.hit_frame(want) - _windup * clips.fps
		_age = 0.0
	elif limb == "claw":
		if clip != want:
			clip = want
			_age = 0.0
		clip_time = clips.hit_frame(want)


## Runs the rake on by dt and lays it over the clip's pose (its turns, in place); returns the pose.
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
	for i: int in _arms:
		pose.turns[i] = pose.turns[i].slerp(now.turns[i], w)
	for i: int in _twist:
		var twist := now.turns[i] * rest.turns[i].inverse()
		pose.turns[i] = (Quaternion.IDENTITY.slerp(twist, w) * pose.turns[i]).normalized()
	return pose


## How much of the rake is laid on now (0..1): in over FADE_SECONDS from its start, out over the
## clip's last FADE_SECONDS; 0 while it waits.
func weight() -> float:
	if clip.is_empty() or clip_time < 0.0:
		return 0.0
	var fade := FADE_SECONDS * clips.fps
	var out := (clips.frames_of(clip) - 1.0 - clip_time) / fade
	return smoothstep(0.0, 1.0, _age / FADE_SECONDS) * smoothstep(0.0, 1.0, out)


## After the bones are posed (BipedSwing.pose_rake): the raking hand lays the streak over the
## clip's trail frames, and older marks fade.
func draw(dt: float) -> void:
	if clip.is_empty() or weight() <= 0.0:
		trail.update(Vector3.ZERO, false, dt)
		return
	var span := clips.trail_span(clip)
	var sweeping := clip_time >= span.x and clip_time <= span.y
	trail.update(rig.tail_world("arm_%s2" % clip.substr(5)), sweeping, dt)


## The rake clip whose arm hangs on that side of the body (-1: -x, +1: +x), as BipedSwing picks its
## raking arm; "" when the rig has no such arm.
func _clip_for(side: float) -> String:
	for s: String in ["l", "r"]:
		if rig.has_bone("arm_%s0" % s) and signf(rig.dir_of("arm_%s0" % s).x) == side:
			return "rake_" + s
	return ""
