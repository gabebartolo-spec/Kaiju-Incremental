class_name KaijuClips
extends RefCounted
## A kaiju's baked animation clips, <base>.kclip (tools/blender/motion_test.py task clips, D-047):
## per frame, each game bone's turn from its rest pose, the pelvis offset, both toe tips and which
## feet are planted, in game axes (positions in cm). Data only; ClipGait plays it.
## Layout: "KCLP", u32 version, u32 header length, the header (JSON: bones in rig.json order, the
## skin bones each gathers, rest heads in metres, fps, stride per walk cycle, the clip table), then
## FRAME_BYTES per frame: int16[4] quaternion per bone, int16[3] pelvis offset, int16[6] left and
## right toe tips, int16 root yaw (centidegrees), int16[2] root travel (dm; unused), u8 planted
## bits, u8 pad.

const MAGIC := "KCLP"
const VERSION := 1
const QUAT_SCALE := 32767.0
const CM := 0.01
## Rest heads further than this from the rig's (fraction of body height) mean the clips were
## baked for another skeleton: the rig keeps its procedural gait.
const REST_TOLERANCE := 0.02


class Pose:
	var turns: Array[Quaternion] = []
	var offset := Vector3.ZERO  ## pelvis offset, metres, game axes
	var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  ## left, right toe tips, metres
	var planted: Array[bool] = [true, true]
	var yaw := 0.0  ## root yaw, degrees (+ = left)


var bones: Array[String] = []
var fps := 24.0
var stride_m := 1.0
var body_height_m := 100.0
## Rig units per metre and the rig-space point of the skin origin, set by fit().
var rig_scale := 1.0
var rig_origin := Vector3.ZERO
var _clips: Dictionary = {}  # name -> Vector3i(first frame, frames, loops 0/1)
var _cycles: Dictionary = {}  # name -> walk cycles the clip holds (1 unless the file says)
var _rest_heads: Array[Vector3] = []
var _raw := PackedByteArray()
var _data_at := 0
var _frame_bytes := 0


## Reads <path>; null (with a warning) when it is missing, damaged or of another version.
static func read(path: String) -> KaijuClips:
	if not FileAccess.file_exists(path):
		return null
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.size() < 12 or raw.slice(0, 4).get_string_from_ascii() != MAGIC:
		push_warning("KaijuClips: %s is not a clip file" % path)
		return null
	if raw.decode_u32(4) != VERSION:
		push_warning("KaijuClips: %s is version %d, not %d" % [path, raw.decode_u32(4), VERSION])
		return null
	var length := raw.decode_u32(8)
	var parsed: Variant = JSON.parse_string(raw.slice(12, 12 + length).get_string_from_utf8())
	if not parsed is Dictionary:
		push_warning("KaijuClips: %s has a broken header" % path)
		return null
	var header: Dictionary = parsed
	var clips := KaijuClips.new()
	if not clips._load(header, raw, 12 + length):
		push_warning("KaijuClips: %s does not match its header" % path)
		return null
	return clips


func _load(header: Dictionary, raw: PackedByteArray, data_at: int) -> bool:
	for b: Variant in header.get("bones", []):
		bones.append(str(b))
	var heads: Dictionary = header.get("rest_heads_m", {})
	for b: String in bones:
		var h: Array = heads.get(b, [0.0, 0.0, 0.0])
		_rest_heads.append(Vector3(Num.f(h[0]), Num.f(h[1]), Num.f(h[2])))
	fps = Num.f(header.get("fps", 24.0))
	stride_m = Num.f(header.get("stride_m", 1.0))
	body_height_m = Num.f(header.get("body_height_m", 100.0))
	_frame_bytes = Num.i(header.get("frame_bytes", 0))
	var total := 0
	for c: Dictionary in header.get("clips", []):
		var first := Num.i(c["first"])
		var frames := Num.i(c["frames"])
		_clips[str(c["name"])] = Vector3i(first, frames, 1 if c.get("loop", false) else 0)
		var cycles: float = c.get("cycles", 1.0)
		_cycles[str(c["name"])] = maxi(1, roundi(cycles))
		total = maxi(total, first + frames)
	_raw = raw
	_data_at = data_at
	return (
		not bones.is_empty()
		and _frame_bytes == bones.size() * 8 + 26
		and total > 0
		and raw.size() == data_at + total * _frame_bytes
	)


func has_clip(clip: String) -> bool:
	return _clips.has(clip)


func frames_of(clip: String) -> int:
	var c: Vector3i = _clips[clip]
	return c.y


## Walk cycles (strides) the clip holds: its frames per stride is frames_of / cycles_of.
func cycles_of(clip: String) -> int:
	return _cycles.get(clip, 1)


func loops(clip: String) -> bool:
	var c: Vector3i = _clips[clip]
	return c.z == 1


## Checks the clips were baked for this rig (same bones, same order, same rest shape) and fits
## the metres -> rig-units map; returns why not, or "" when they fit.
func fit(rig: KaijuRig) -> String:
	var names := rig.bone_names()
	if names != bones:
		return "bones %s, rig has %s" % [bones, names]
	var cm := Vector3.ZERO
	var cr := Vector3.ZERO
	for i: int in bones.size():
		cm += _rest_heads[i]
		cr += rig.head_of(bones[i])
	cm /= bones.size()
	cr /= bones.size()
	var num := 0.0
	var den := 0.0
	for i: int in bones.size():
		num += (rig.head_of(bones[i]) - cr).dot(_rest_heads[i] - cm)
		den += (_rest_heads[i] - cm).length_squared()
	if den <= 0.0 or num <= 0.0:
		return "rest heads are degenerate"
	rig_scale = num / den
	rig_origin = cr - cm * rig_scale
	var worst := 0.0
	for i: int in bones.size():
		worst = maxf(worst, (to_rig(_rest_heads[i]) - rig.head_of(bones[i])).length())
	if worst > REST_TOLERANCE * body_height_m * rig_scale:
		return (
			"rest heads differ by %.1f%% of the body height"
			% (100.0 * worst / (body_height_m * rig_scale))
		)
	return ""


## A point in clip metres as a rig-space point.
func to_rig(p: Vector3) -> Vector3:
	return rig_origin + p * rig_scale


## The pose of a clip at time t (in clip frames, fractional): looped clips wrap, others hold
## their ends. Turns are slerped, positions blended, planted feet taken from the nearer frame.
func pose_at(clip: String, t: float) -> Pose:
	var c: Vector3i = _clips[clip]
	var n := c.y
	var at := fposmod(t, n) if c.z == 1 else clampf(t, 0.0, n - 1)
	var i0 := floori(at)
	var i1 := (i0 + 1) % n if c.z == 1 else mini(i0 + 1, n - 1)
	var a := at - i0
	return mix(_frame(c.x + i0), _frame(c.x + i1), a)


## The first and last frames where a turn clip's yaw moves (0.5 deg from either end).
func yaw_span(turn: String) -> Vector2:
	var n := frames_of(turn)
	var full := pose_at(turn, n - 1).yaw
	var first := 0
	while first < n - 1 and absf(pose_at(turn, first).yaw) < 0.5:
		first += 1
	var last := first
	while last < n - 1 and absf(pose_at(turn, last).yaw - full) > 0.5:
		last += 1
	return Vector2(first, last)


## Cross-fade of two poses (w = 0: a, 1: b).
static func mix(a: Pose, b: Pose, w: float) -> Pose:
	var p := Pose.new()
	for i: int in a.turns.size():
		p.turns.append(a.turns[i].slerp(b.turns[i], w))
	p.offset = a.offset.lerp(b.offset, w)
	p.feet = [a.feet[0].lerp(b.feet[0], w), a.feet[1].lerp(b.feet[1], w)]
	p.planted = b.planted if w >= 0.5 else a.planted
	p.yaw = lerpf(a.yaw, b.yaw, w)
	return p


func _frame(index: int) -> Pose:
	var at := _data_at + index * _frame_bytes
	var p := Pose.new()
	for i: int in bones.size():
		var q := Quaternion(_q(at), _q(at + 2), _q(at + 4), _q(at + 6))
		p.turns.append(q.normalized())
		at += 8
	p.offset = _cm3(at)
	p.feet = [_cm3(at + 6), _cm3(at + 12)]
	p.yaw = _raw.decode_s16(at + 18) * 0.01
	var bits := _raw.decode_u8(at + 24)
	p.planted = [bits & 1 != 0, bits & 2 != 0]
	return p


func _q(at: int) -> float:
	return _raw.decode_s16(at) / QUAT_SCALE


func _cm3(at: int) -> Vector3:
	return Vector3(_raw.decode_s16(at), _raw.decode_s16(at + 2), _raw.decode_s16(at + 4)) * CM
