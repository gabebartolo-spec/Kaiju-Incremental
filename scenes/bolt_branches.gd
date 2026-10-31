class_name BoltBranches
extends RefCounted
## The forks off a bolt's main channel (BoltRig): at each stroke, 3-5 (the owner's row) fresh
## branches off the channel, each to its own target and cut short where something solid is in the
## way, and a few short sub-forks off those. Rows with "strands" also braid that many arcs from the
## mouth to around the struck point (the column), and rows with "pool" splash that many arcs out
## across the ground from it, each chaining on "chain" hops (director 2026-10-31: the breath is a
## dragon's fire stream, column into a pool, made of lightning). Presentation only; every number
## is tuning "fx" "bolt".

## A sub-fork leaves its branch this far along it (0..1), turned this many radians, at this share
## of the rest of the branch's length.
const SUB_FORK_AT := 0.55
const SUB_FORK_TURN := 0.7
const SUB_FORK_LENGTH := 0.9

var _rig: BoltRig
var _scale: float
var _cfg: Dictionary
var _row: Dictionary
var _rng: RandomNumberGenerator
var _mouth := Vector3.ZERO
var _hit := Vector3.ZERO
var _list: Array[Dictionary] = []


func _init(rig: BoltRig, cfg: Dictionary, row: Dictionary, body_scale: float) -> void:
	_rig = rig
	_scale = body_scale
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
	_strands(main)
	_pool()
	return _list


## The column: arcs from the mouth (t 0) braided along the main channel to points within
## strand_spread of the struck point, so the breath is a thick bundle leaving the jaws.
func _strands(main: PackedVector3Array) -> void:
	var count: Array = _row.get("strands", [0, 0])
	var reach := Num.f(_row.get("strand_spread", 0.0)) * _scale
	for i: int in _rng.randi_range(Num.i(count[0]), Num.i(count[1])):
		var off := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 1), _rng.randf_range(-1, 1)
		)
		var end := _kept(_hit + off.limit_length(1.0) * reach)
		var shape := BoltShape.channel(_rng, Num.i(_cfg["depth"]), Num.f(_row["strand_sway"]))
		_list.append(
			{"t": 0.0, "end": _stopped(BoltShape.at_t(main, 0.0), end), "shape": shape, "of": -1}
		)


## The pool: arcs splashing out over the ground from the struck point, each chaining on from its
## end `chain` more hops of chain_step, all inside the cone.
func _pool() -> void:
	var count := Num.i(_row.get("pool", 0))
	var radius := Num.f(_row.get("pool_radius", 0.0)) * _scale
	var y := Num.f(_rig.cone["y"]) if not _rig.cone.is_empty() else _hit.y
	var sway := Num.f(_row.get("strand_sway", 0.2))
	for i: int in count:
		var ang := TAU * (i + _rng.randf()) / maxf(count, 1)
		var d := _rng.randf_range(0.35, 1.0) * radius
		var end := _kept(Vector3(_hit.x + cos(ang) * d, y, _hit.z + sin(ang) * d))
		var shape := BoltShape.channel(_rng, Num.i(_cfg["branch_depth"]), sway)
		_list.append({"t": 1.0, "end": end, "shape": shape, "of": -1})
		var prev := end
		var climbing := false
		for hop: int in Num.i(_row.get("chain", 0)):
			var turn := ang + _rng.randf_range(-1.0, 1.0)
			var step := _rng.randf_range(0.5, 1.0) * Num.f(_row["chain_step"]) * _scale
			var way := Vector3(cos(turn), 0.0, sin(turn)) * step
			var next := prev + way * 0.4 + Vector3.UP * step if climbing else _kept(prev + way)
			if not climbing:
				var met := _stopped(prev, next)
				climbing = met.distance_to(next) > 0.01  # a wall: the next hops climb and wrap it
				next = met
			shape = BoltShape.channel(_rng, Num.i(_cfg["branch_depth"]), sway)
			_list.append({"t": 1.0, "end": next, "shape": shape, "of": _list.size() - 1})
			prev = next


func _kept(p: Vector3) -> Vector3:
	return p if _rig.cone.is_empty() else BoltShape.clamp_to_cone(p, _rig.cone)


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
