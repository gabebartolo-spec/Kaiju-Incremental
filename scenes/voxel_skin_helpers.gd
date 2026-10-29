class_name VoxelSkinHelpers
extends RefCounted
## D-374: corrective helper joints a skin may carry after its bones (the Colossus's hip, knee,
## web, ankle and belly helpers per leg). A helper has no node in the rig: each frame its pose is
## worked out from the two bones it sits between, so every clip drives it with no re-bake, and the
## skin's cubes weighted to it keep the thigh, belly and knee full when the leg folds far.
## Read from an optional block after a .vskin's filler (tools/kaiju_skin/bake.py write_helpers);
## a .vskin without one has no helpers. Presentation only.

## Block tag, then u16 count; per helper HELPER_BYTES (bake.py HELPER_FORMAT).
const TAG := "HELP"
## u8 a, u8 b, u8 flags (1 = push grows with the turn), u8 pad, f32 frac, centre xyz, push xyz,
## push-per-turn 3x3 (column-major), all rig units.
const HELPER_BYTES := 68
## Below this turn (radians) between its two bones a helper takes bone a's turn.
const STILL := 1e-6

var count := 0
var _a := PackedInt32Array()
var _b := PackedInt32Array()
var _grow := PackedByteArray()
var _frac := PackedFloat32Array()
var _centre: Array[Vector3] = []
var _push: Array[Vector3] = []
var _per_turn: Array[Basis] = []


## The helpers in raw from byte `at` (the end of the filler), or none when no block follows.
static func read(raw: PackedByteArray, at: int) -> VoxelSkinHelpers:
	var out := VoxelSkinHelpers.new()
	if at + 6 > raw.size() or raw.slice(at, at + 4).get_string_from_ascii() != TAG:
		return out
	var n := raw.decode_u16(at + 4)
	at += 6
	if at + n * HELPER_BYTES > raw.size():
		push_warning("VoxelSkinHelpers: truncated helper block")
		return out
	for i: int in n:
		out._a.append(raw.decode_u8(at))
		out._b.append(raw.decode_u8(at + 1))
		out._grow.append(raw.decode_u8(at + 2))
		out._frac.append(raw.decode_float(at + 4))
		out._centre.append(_vec(raw, at + 8))
		out._push.append(_vec(raw, at + 20))
		out._per_turn.append(Basis(_vec(raw, at + 32), _vec(raw, at + 44), _vec(raw, at + 56)))
		at += HELPER_BYTES
	out.count = n
	return out


## Whether every helper's two bones are among the first `bones` poses.
func fits(bones: int) -> bool:
	for i: int in count:
		if _a[i] >= bones or _b[i] >= bones:
			return false
	return true


## Appends each helper's pose to `pose` (the bones' rest-to-now transforms, rig space).
func add_poses(pose: Array[Projection], bones: int) -> void:
	pose.resize(bones + count)
	for i: int in count:
		pose[bones + i] = Projection(helper(Transform3D(pose[_a[i]]), Transform3D(pose[_b[i]]), i))


## Helper i between bone poses a and b: turned frac of the way from a to b about its centre (the
## two bones' mean image of it), then pushed out by its push, which grows with the turn.
func helper(a: Transform3D, b: Transform3D, i: int) -> Transform3D:
	var ra := a.basis.orthonormalized()
	var q := (ra.transposed() * b.basis.orthonormalized()).get_rotation_quaternion().normalized()
	if q.w < 0.0:
		q = -q
	var v := Vector3(q.x, q.y, q.z)
	var s := v.length()
	var angle := 2.0 * atan2(s, q.w)
	var turn := Vector3.ZERO
	var r := ra
	if s > sin(STILL * 0.5):
		var axis := v / s
		turn = axis * angle
		r = ra * Basis(axis, _frac[i] * angle)
	var c := _centre[i]
	var t := (a * c + b * c) * 0.5
	var g := (1.0 - cos(angle)) * 0.5
	var push := _per_turn[i] * turn + _push[i] * g
	if _grow[i] & 1:
		push = (_per_turn[i] * turn + _push[i]) * g
	return Transform3D(r, t - r * c + r * push)


static func _vec(raw: PackedByteArray, at: int) -> Vector3:
	return Vector3(raw.decode_float(at), raw.decode_float(at + 4), raw.decode_float(at + 8))
