class_name HeavyPose
extends RefCounted
## A heavy body's pose in body space as its clip clock has it, from the baked track (HeavyTrack):
## the slots (HeavyTrack.SLOT values each: a disc at its bottom and one at its top), every
## bone's head [forward, across, height], the hind toes, the root's turn. Laid as ClipGait lays
## the clips on the bones: the two clips cross-faded, a roar on the move on the walk's legs,
## pelvis and tail, the raking arm, the maw held open; then the head's look into the heading and
## the tail's bends, both about the world's up at each joint as the rig turns them. Part of
## HeavyContact; pure, no randomness.

## The root bone (the pelvis): a roar on the move takes it, the legs and the tail from the walk
## (ClipGait._walking_legs) and hangs the roar's upper body on it.
const ROOT := "spine0"
const S := HeavyTrack.SLOT
## A raked slot value's axis in a bone head ([forward, across, height]): forward, across, -, the
## two heights, forward, across.
const RAKE_AXIS: Array[int] = [0, 1, 0, 2, 2, 0, 1]

## The hind feet the laid pose has down (bit 0 the left, bit 1 the right).
var bits := 0
var _track: HeavyTrack
var _slots := 0
var _size := 0  # values in a pose
var _of := {}  # bone name -> Array[int] of its slots
var _bone_of: Array[int] = []
var _walked: Array[bool] = []  # per bone: a roar on the move takes it from the walk
var _arms := {}  # rake side (-1, 1) -> the bone indexes of that arm
var _tails: Array[int] = []  # the tail bones, base first
var _head: Array[int] = []  # head0's bones (it, its skull, its jaw), then head1's
var _skull: Array[int] = []
var _root := 0  # the root bone (the pelvis): a roar on the move hangs its upper body on the walk's
var _claw: Dictionary  # the rake's timing ("claw_fx", lift_s as BipedSwing has it)
var _youth := 0.0  # the rake's reach: as the drawn body has it (the track's)


func _init(p_track: HeavyTrack) -> void:
	_track = p_track
	_youth = _track.youth
	_claw = Content.section("claw_fx").duplicate()
	var windup := Num.f(Content.section("powers")["swipe_windup"])
	_claw["lift_s"] = maxf(0.05, windup - Num.f(_claw["strike_s"]) * 0.5)
	_slots = _track.slot_bone.size()
	_size = _slots * S + _track.bones.size() * 3 + _track.legs.size() * 3 + 4
	_root = _track.bones.find(ROOT)
	for j: int in _slots:
		var name := _track.bones[_track.slot_bone[j]]
		if not _of.has(name):
			_of[name] = [] as Array[int]
		var list: Array[int] = _of[name]
		list.append(j)
	for b: int in _track.bones.size():
		var name := _track.bones[b]
		_walked.append(name == ROOT or name.begins_with("leg") or name.begins_with("tail"))
		if name.begins_with("tail"):
			_tails.append(b)
		if name in ["head0", "head1", "jaw"]:
			_head.append(b)
		if name in ["head1", "jaw"]:
			_skull.append(b)
	var sides: Dictionary = _track.rake_arms
	for side: String in sides:
		var arm: Array[int] = []
		for name: Variant in sides[side]:
			arm.append(_track.bones.find(str(name)))
		_arms[1.0 if side == "p" else -1.0] = arm


## Where hind toe i starts in a pose.
func toe(i: int) -> int:
	return _slots * S + _track.bones.size() * 3 + i * 3


## True when slot j is on the tail.
func in_tail(j: int) -> bool:
	return _track.slot_bone[j] in _tails


func slots_of(name: String) -> Array[int]:
	var list: Array[int] = _of.get(name, [] as Array[int])
	return list


## The pose the clock is at; extra: [rake seconds (< 0 none), rake side, maw held open 0..1].
func lay(clock: ClipClock, extra: Array) -> PackedFloat32Array:
	var pose := _sample(clock.state, clock.time, Num.f(extra[2]))
	var pose_bits := bits
	if clock.blend < 1.0 and not clock.from.is_empty():
		var was := _sample(clock.from, clock.from_time, Num.f(extra[2]))
		var w := smoothstep(0.0, 1.0, clock.blend)
		for k: int in _size:
			pose[k] = lerpf(was[k], pose[k], w)
		pose_bits = pose_bits if w >= 0.5 else bits
	if clock.legs_on:
		pose_bits = _walk_legs(pose, clock.legs_t, Num.f(extra[2]))
	if Num.f(extra[0]) >= 0.0:
		_rake(pose, Num.f(extra[0]), Num.f(extra[1]), Num.f(extra[2]))
	bits = pose_bits
	return pose


## Turns the head into the heading (D-200, ClipGait._look_ahead): the neck (head0) takes `share`
## of `look` (rad, + to the left) about its joint, the skull (head1) the rest about its own.
func look(pose: PackedFloat32Array, look_yaw: float, share: float) -> void:
	if _head.is_empty() or is_zero_approx(look_yaw):
		return
	_turn(pose, _head, _head[0], look_yaw * share)
	if _skull.size() > 0:
		_turn(pose, _skull, _skull[0], look_yaw * (1.0 - share))


## Bends the tail (TailSim.bends, base first, + to the left): each bone turns about its own joint,
## carrying the bones after it.
func bend_tail(pose: PackedFloat32Array, bends: Array[float]) -> void:
	for i: int in mini(bends.size(), _tails.size()):
		if not is_zero_approx(bends[i]):
			_turn(pose, _tails.slice(i), _tails[i], bends[i])


## Clip values at time t (frames), the jaw's slots opened by `open`; sets bits.
func _sample(clip: String, t: float, open: float) -> PackedFloat32Array:
	var at := _track.frames_at(clip, t)
	var a := int(at.x)
	var b := int(at.y)
	var w := at.z
	var out := PackedFloat32Array()
	out.resize(_size)
	var heads := _slots * S
	var vals := _track.values
	var fa := a * _track.per_frame
	var fb := b * _track.per_frame
	for k: int in heads:
		out[k] = lerpf(vals[fa + k], vals[fb + k], w)
	var skip := _track.head_at(0) - heads  # the jaw's open slots, between the slots and the heads
	for k: int in range(heads, _size):
		out[k] = lerpf(vals[fa + skip + k], vals[fb + skip + k], w)
	bits = _track.planted(b if w >= 0.5 else a)
	if open > 0.0:
		_open_jaw(out, a, b, Vector2(w, smoothstep(0.0, 1.0, open)))
	return out


## The jaw's slots toward the maw held open (ClipGait: the jaw slerped to the roar's peak).
func _open_jaw(out: PackedFloat32Array, a: int, b: int, w: Vector2) -> void:
	var jaw := slots_of("jaw")
	for n: int in jaw.size():
		var from := _track.open_at(n)
		for v: int in S:
			var open := lerpf(_track.value(a, from + v), _track.value(b, from + v), w.x)
			out[jaw[n] * S + v] = lerpf(out[jaw[n] * S + v], open, w.y)


## A roar on the move: the walk's legs, pelvis and tail at walk frame `t`, the roar's upper body
## hung on the walk's pelvis (as ClipGait poses it: the root's turn from the walk, the rest from
## the roar). Returns the walk's planted bits.
func _walk_legs(pose: PackedFloat32Array, t: float, open: float) -> int:
	var walk := _sample("walk", t, open)
	var at := _slots * S + _root * 3
	var from := _rig_point(pose, at)
	var to := _rig_point(walk, at)
	var turn := Basis(_root_turn(walk)) * Basis(_root_turn(pose)).inverse()
	for j: int in _slots:
		var k := j * S
		if _walked[_track.slot_bone[j]]:
			for v: int in S:
				pose[k + v] = walk[k + v]
			continue
		var e := ends(pose, k)
		put_ends(pose, k, to + turn * (e[0] - from), to + turn * (e[1] - from))
	for b: int in _track.bones.size():
		var h := _slots * S + b * 3
		var c := _rig_point(walk, h) if _walked[b] else to + turn * (_rig_point(pose, h) - from)
		pose[h] = -c.z
		pose[h + 1] = c.x
		pose[h + 2] = c.y
	for k: int in range(toe(0), _size):  # the hind toes and the root's turn: the walk's
		pose[k] = walk[k]
	return bits


## Slot k's two ends in the rig's own axes (x across, y up, z back): its bottom disc's centre, then
## its top disc's.
static func ends(pose: PackedFloat32Array, k: int) -> Array[Vector3]:
	var bottom := Vector3(pose[k + 1], pose[k + 3], -pose[k])
	return [bottom, Vector3(pose[k + 6], pose[k + 4], -pose[k + 5])]


## Puts slot k's ends (rig axes) back; turned over, the lower end becomes its bottom.
static func put_ends(pose: PackedFloat32Array, k: int, a: Vector3, b: Vector3) -> void:
	if a.y > b.y:
		var swap := a
		a = b
		b = swap
		var r := pose[k + 2]
		pose[k + 2] = pose[k + 7]
		pose[k + 7] = r
	pose[k] = -a.z
	pose[k + 1] = a.x
	pose[k + 3] = a.y
	pose[k + 4] = b.y
	pose[k + 5] = -b.z
	pose[k + 6] = b.x


## A pose's point at k ([forward, across, height]) in the rig's own axes (x across, y up, z back).
static func _rig_point(pose: PackedFloat32Array, k: int) -> Vector3:
	return Vector3(pose[k + 1], pose[k + 2], -pose[k])


## The root bone's turn in a pose (rig space), after the toes.
func _root_turn(pose: PackedFloat32Array) -> Quaternion:
	var k := _size - 4
	return Quaternion(pose[k], pose[k + 1], pose[k + 2], pose[k + 3]).normalized()


## The raking arm (BipedSwing's rake, baked over the idle) at `t` seconds, its shoulder where the
## pose holds it now; while the rake still blends from (or back to) where the clip holds the arm,
## the clip's arm (against the idle's) is blended in by the same weight.
func _rake(pose: PackedFloat32Array, t: float, side: float, open: float) -> void:
	var clip := "rake_p" if side > 0.0 else "rake_n"
	if not _arms.has(side) or not _track.has_clip(clip):
		return
	var arm: Array[int] = _arms[side]
	var keep := bits
	var rake := _sample(clip, t * _track.fps_of(clip), open)
	var idle := _sample("idle", 0.0, open)
	bits = keep
	var rest := _rest_weight(t) * _reach(t)
	var h := _slots * S + arm[0] * 3
	for b: int in arm:
		for j: int in slots_of(_track.bones[b]):
			var k := j * S
			pose[k + 2] = rake[k + 2]  # the radii
			pose[k + 7] = rake[k + 7]
			for v: int in [0, 1, 3, 4, 5, 6]:
				_rake_value(pose, [rake, idle], Vector3i(k + v, h + RAKE_AXIS[v], 0), rest)
	for b: int in arm.slice(1):  # the arm's joints after the shoulder
		var k := _slots * S + b * 3
		for v: int in 3:
			_rake_value(pose, [rake, idle], Vector3i(k + v, h + v, 0), rest)


## Pose value at.x raked: the rake's, carried with the shoulder (pose value at.y on the same axis),
## plus `rest` of the clip arm's own offset from the idle's.
static func _rake_value(pose: PackedFloat32Array, by: Array, at: Vector3i, rest: float) -> void:
	var rake: PackedFloat32Array = by[0]
	var idle: PackedFloat32Array = by[1]
	var clip_off := (pose[at.x] - pose[at.y]) - (idle[at.x] - idle[at.y])
	pose[at.x] = rake[at.x] + (pose[at.y] - rake[at.y]) + rest * clip_off


## How much of the clip's own arm the rake still holds at `t` (BipedSwing._rake_dirs: all of it at
## the start, none from the end of the lift to the settle, all again at the end; eased).
func _rest_weight(t: float) -> float:
	var lift := Num.f(_claw["lift_s"])
	var strike := Num.f(_claw["strike_s"])
	var back := Num.f(_claw["recover_s"])
	var settle := back * Num.f(_claw["settle_at"])
	if t < lift:
		return 1.0 - smoothstep(0.0, 1.0, t / maxf(lift, 0.0001))
	var home := lift + strike + settle
	if t < home:
		return 0.0
	return smoothstep(0.0, 1.0, clampf((t - home) / maxf(back - settle, 0.0001), 0.0, 1.0))


## The raking arm's reach then, as BipedSwing._reach_arm scales it (1 at rest).
func _reach(t: float) -> float:
	var grow := lerpf(Num.f(_claw["arm_reach_adult"]), Num.f(_claw["arm_reach_young"]), _youth)
	var lift := Num.f(_claw["lift_s"])
	var strike := Num.f(_claw["strike_s"])
	var out := 1.0
	if t < lift:
		out = smoothstep(0.0, 1.0, t / lift)
	elif t >= lift + strike:
		out = 1.0 - smoothstep(0.0, 1.0, (t - lift - strike) / Num.f(_claw["recover_s"]))
	return lerpf(1.0, grow, out)


## Turns `bones` (their slots and heads, not the pivot's own head) about bone `pivot`'s head by
## `yaw` (rad, + to the left as the rig's yaw about the world's up).
func _turn(pose: PackedFloat32Array, bones: Array[int], pivot: int, yaw: float) -> void:
	var p := _slots * S + pivot * 3
	var at := Vector2(pose[p + 1], -pose[p])  # (across, back): the rig's x and z
	for b: int in bones:
		for j: int in slots_of(_track.bones[b]):
			_turn_at(pose, j * S, at, yaw)
			_turn_at(pose, j * S + 5, at, yaw)
		if b != pivot:
			_turn_at(pose, _slots * S + b * 3, at, yaw)


static func _turn_at(pose: PackedFloat32Array, k: int, at: Vector2, yaw: float) -> void:
	var v := (Vector2(pose[k + 1], -pose[k]) - at).rotated(-yaw) + at
	pose[k] = -v.y
	pose[k + 1] = v.x
