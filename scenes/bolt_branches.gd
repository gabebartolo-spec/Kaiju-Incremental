class_name BoltBranches
extends RefCounted
## The forks off a bolt's main channel (BoltRig): at each stroke, 3-5 (the owner's row) fresh
## branches off the channel, each to its own target and cut short where something solid is in the
## way, and a few short sub-forks off those. Presentation only; every number is tuning "fx" "bolt".

## A sub-fork leaves its branch this far along it (0..1), turned this many radians, at this share
## of the rest of the branch's length.
const SUB_FORK_AT := 0.55
const SUB_FORK_TURN := 0.7
const SUB_FORK_LENGTH := 0.9

var _rig: BoltRig
var _cfg: Dictionary
var _row: Dictionary
var _rng: RandomNumberGenerator
var _mouth := Vector3.ZERO
var _hit := Vector3.ZERO
var _list: Array[Dictionary] = []


func _init(rig: BoltRig, cfg: Dictionary, row: Dictionary) -> void:
	_rig = rig
	_cfg = cfg
	_row = row


## 3-5 (the owner's row) fresh branches off `main`, each to its own target, as the bolt runs from
## `mouth` to `hit`. Each is {"t", "end", "shape", "of"}; the sub-forks come last.
func roll(
	rng: RandomNumberGenerator, main: PackedVector3Array, mouth: Vector3, hit: Vector3
) -> Array[Dictionary]:
	_rng = rng
	_mouth = mouth
	_hit = hit
	_list = []
	var count: Array = _row["branches"]
	var n := _rng.randi_range(Num.i(count[0]), Num.i(count[1]))
	var targets: Array = []
	if _rig.ends.is_valid():
		targets = _rig.ends.call(_rng, n)
	elif not _rig.cone.is_empty():
		var fan := _rig.cone.duplicate()  # a tighter fan, forking toward where the bolt lands
		fan["spread"] = _row["fan_spread"]
		fan["near"] = _row["fan_near"]
		targets = BoltShape.fan_ends(_rng, fan, n)
	for target: Vector3 in targets:
		var t := _anchor(target)
		var from := BoltShape.at_t(main, t)
		var shape := BoltShape.channel(
			_rng, Num.i(_cfg["branch_depth"]), Num.f(_row["branch_sway"])
		)
		_list.append({"t": t, "end": _stopped(from, target), "shape": shape, "of": -1})
	for k: int in mini(Num.i(_row["sub_forks"]), _list.size()):
		_list.append(_sub_fork(k, main))
	return _list


## A short fork off branch `k`, a bit past its middle, turned to one side (same cone, same blocker).
func _sub_fork(k: int, main: PackedVector3Array) -> Dictionary:
	var parent := _list[k]
	var pend: Vector3 = parent["end"]
	var from := BoltShape.at_t(main, Num.f(parent["t"]))
	var mid := from.lerp(pend, SUB_FORK_AT)
	var turn := SUB_FORK_TURN if _rng.randf() < 0.5 else -SUB_FORK_TURN
	var end := mid + (pend - mid).rotated(Vector3.UP, turn) * SUB_FORK_LENGTH
	if not _rig.cone.is_empty():
		end = BoltShape.clamp_to_cone(end, _rig.cone)
	var shape := BoltShape.channel(_rng, Num.i(_cfg["branch_depth"]), Num.f(_row["branch_sway"]))
	return {"t": SUB_FORK_AT, "end": _stopped(mid, end), "shape": shape, "of": k}


## Where along the main channel (0..1) a branch to `target` forks off: the owner's range at random,
## or, where its branches strike things beside the beam, just short of the point nearest the target.
func _anchor(target: Vector3) -> float:
	var span: Array = _row["branch_from"]
	var lo := Num.f(span[0])
	var hi := Num.f(span[1])
	var near: bool = _row["anchor_near"]
	if not near:
		return _rng.randf_range(lo, hi)
	var axis := _hit - _mouth
	var along := (target - _mouth).dot(axis) / maxf(axis.length_squared(), 0.001)
	return clampf(along - Num.f(_row["anchor_back"]), lo, hi)


## `target` cut short where something solid is in the way from `from`.
func _stopped(from: Vector3, target: Vector3) -> Vector3:
	if not _rig.blocker.is_valid():
		return target
	var span := target - from
	var share: float = _rig.blocker.call(from, span)
	return from + span * share
