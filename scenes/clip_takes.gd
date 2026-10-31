class_name ClipTakes
extends RefCounted
## The Colossus's keyed walking takes over ClipGait (roadmap row 1, PR3; Cascadeur FIX takes, r13f):
## - walk_start: from standing, its first WALK_START_SECONDS (D-355's ease), then the walk loop;
## - run: the walk blends into the keyed run as momentum builds (Momentum.blend, D-335/D-337), both
##   on the sim's step clock (ClipSteps), so the feet land where the sim steps either way;
## - slam_stop: the momentum slam into a building stops him with it (Momentum, "slam" event);
## - walking turns: a turn while he walks lays its take over the walk's upper body (spine, neck,
##   head, arms, tail), timed by how far the sim has turned him: head_look (its left one mirrored
##   for the right) under BIG_TURN, walk_turn_left / walk_turn_right from there.
## Clips a body lacks are skipped (the baby and Behemoth walk as before). Presentation only.

## The walk start's share of the take played before the walk loop (D-355: about 1.3 s).
const WALK_START_SECONDS := 1.3
## The run take loops over its first RUN_LOOP frames (one full cycle: frame 95 matches frame 0
## within 10.5 deg on every bone; the take runs on to 129).
const RUN_LOOP := 95
## Yaw still to turn (rad) that starts a walking turn's take, and from which it is the 90 deg one.
const TURN_START := 0.35
const BIG_TURN := 1.05
## The head looks into a turn before the body makes it (director comments #16, moved from
## ClipGait): it eases (1/s) toward the yaw still to turn, at most HEAD_LEAD_MAX (rad), the neck
## taking NECK_SHARE of it and the skull the rest; a turn take laid on takes over from it.
const HEAD_LEAD_MAX := 0.6
const HEAD_LEAD_EASE := 10.0
const NECK_SHARE := 0.4
## Seconds the turn layer takes to come in and to leave.
const FADE_SECONDS := 0.4
## The bones the turn layer moves: everything above the hips but the jaw and lids.
const LAYER_PREFIXES: Array[String] = ["spine", "neck", "head", "clavicle", "arm", "tail"]

var clips: KaijuClips
## 0..1: how far the walk has blended into the run (the sim's momentum, set each frame).
var run_blend := 0.0
var slams := 0  # the sim's slams seen (Momentum.slams)
## The walking turn playing ("" when none), whether it is mirrored, and its frame.
var turn := ""
var mirrored := false
var turn_time := 0.0
var look := 0.0  # the head's look-ahead into the turn (rad)
var _run: ClipSteps
var _total := 0.0  # the yaw still to turn when the turn started (rad)
var _progress := 0.0
var _weight := 0.0
var _layer: Array[int] = []
var _mirror: Array[int] = []  # bone i's other side (itself when it has none)
var _rest: Dictionary = {}  # turn clip -> its first pose
var _yaws: Dictionary = {}  # turn clip -> |yaw| per frame, start to its peak


func _init(p_clips: KaijuClips) -> void:
	clips = p_clips
	if clips.has_clip("run"):
		_run = ClipSteps.new(clips, "run", mini(RUN_LOOP, clips.frames_of("run")))
	for i: int in clips.bones.size():
		var bone_name := clips.bones[i]
		if LAYER_PREFIXES.any(func(p: String) -> bool: return bone_name.begins_with(p)):
			_layer.append(i)
		var other := bone_name.replace("_l", "_r")
		other = bone_name.replace("_r", "_l") if other == bone_name else other
		_mirror.append(maxi(0, clips.bones.find(other)) if other != bone_name else i)
	for clip: String in ["head_look", "walk_turn_left", "walk_turn_right"]:
		if clips.has_clip(clip):
			_rest[clip] = clips.pose_at(clip, 0.0)
			_yaws[clip] = _to_peak(clip)


func has_walk_start() -> bool:
	return clips.has_clip("walk_start")


## Whether the walk start has played its share (clip frames).
func walk_started(clip_time: float) -> bool:
	return clip_time >= minf(WALK_START_SECONDS * clips.fps, clips.frames_of("walk_start") - 1.0)


## The walk pose blended toward the run at the sim's step clock (step_phase INF: the walk alone).
func walk_pose(walk: KaijuClips.Pose, step_phase: float) -> KaijuClips.Pose:
	if _run == null or step_phase == INF or run_blend <= 0.0:
		return walk
	var run := clips.pose_at("run", _run.frame_at(step_phase))
	return KaijuClips.mix(walk, run, smoothstep(0.0, 1.0, run_blend))


## Lays the walking turn over a walking pose: turn_ahead is the yaw still to turn (rad, + left;
## INF: not told), walking whether he walks.
func layer(pose: KaijuClips.Pose, turn_ahead: float, walking: bool, dt: float) -> KaijuClips.Pose:
	var ahead := 0.0 if turn_ahead == INF else turn_ahead
	if turn.is_empty() and walking and absf(ahead) > TURN_START:
		_start(ahead)
	if turn.is_empty():
		return pose
	var on := walking and absf(ahead) > 0.05 and signf(ahead) == signf(_total)
	_progress = maxf(_progress, 1.0 - absf(ahead) / absf(_total)) if on else 1.0
	turn_time = _frame_for(_progress)
	_weight = clampf(_weight + (dt if on else -dt) / FADE_SECONDS, 0.0, 1.0)
	if _weight <= 0.0 and not on:
		turn = ""
		return pose
	return _lay(pose)


## The turn take's upper-body twist from its first pose, laid on `pose` at the layer's weight.
func _lay(pose: KaijuClips.Pose) -> KaijuClips.Pose:
	var now := clips.pose_at(turn, turn_time)
	var rest: KaijuClips.Pose = _rest[turn]
	var w := smoothstep(0.0, 1.0, _weight)
	for i: int in _layer:
		var j := _mirror[i] if mirrored else i
		var twist := _flip(now.turns[j] * rest.turns[j].inverse())
		pose.turns[i] = (Quaternion.IDENTITY.slerp(twist, w) * pose.turns[i]).normalized()
	return pose


## How much of the turn take is laid on (0..1): the head's code look-ahead gives way to it.
func turn_weight() -> float:
	return smoothstep(0.0, 1.0, _weight) if not turn.is_empty() else 0.0


## Turns the neck and skull about the world's up into the turn still to make (after the clip),
## giving way to a walking turn's take.
func look_ahead(g: ClipGait, dt: float) -> void:
	var ahead := 0.0 if g.turn_ahead == INF else g.turn_ahead
	ahead = clampf(ahead, -HEAD_LEAD_MAX, HEAD_LEAD_MAX) * (1.0 - turn_weight())
	look = lerpf(look, ahead, minf(1.0, dt * HEAD_LEAD_EASE))
	for bone_name: String in ["head0", "head1"]:
		if g.rig.has_bone(bone_name):
			var share := NECK_SHARE if bone_name == "head0" else 1.0 - NECK_SHARE
			var b := g.rig.bone(bone_name).global_transform.basis.orthonormalized()
			g.rig.set_world_basis(bone_name, Basis(Vector3.UP, look * share) * b)


func _start(ahead: float) -> void:
	var big := absf(ahead) >= BIG_TURN or not clips.has_clip("head_look")
	turn = ("walk_turn_left" if ahead > 0.0 else "walk_turn_right") if big else "head_look"
	if not clips.has_clip(turn):
		turn = ""
		return
	mirrored = turn == "head_look" and ahead < 0.0
	_total = ahead
	_progress = 0.0
	_weight = 0.0


## The take's frame whose yaw has made `progress` of its full turn (start to its peak).
func _frame_for(progress: float) -> float:
	var yaws: PackedFloat32Array = _yaws[turn]
	for f: int in yaws.size():
		if yaws[f] >= progress * yaws[-1]:
			return float(f)
	return float(yaws.size() - 1)


## A turn take's |yaw| per frame from its start to its peak.
func _to_peak(clip: String) -> PackedFloat32Array:
	var yaws := PackedFloat32Array()
	var peak_at := 0
	for f: int in clips.frames_of(clip):
		yaws.append(absf(clips.pose_at(clip, f).yaw))
		peak_at = f if yaws[f] > yaws[peak_at] else peak_at
	return yaws.slice(0, peak_at + 1)


## A local turn mirrored left for right (the YZ plane) when the take plays mirrored.
func _flip(q: Quaternion) -> Quaternion:
	return Quaternion(q.x, -q.y, -q.z, q.w) if mirrored else q
