class_name CarveDebrisPoses
extends RefCounted
## The physics-server reads of one building's live debris, and with debris_cache on a cache of
## every live piece's transform (12 floats each) taken once per physics step: the tick and the
## draw that follows it share one read per piece instead of repeating it. `n` leading entries are
## current; a physics step makes none of them so (stale), a new piece is read alone.

var reads := 0  # state reads made so far (a test bounds them per live piece per tick)
var cached := true  # off: every pose is read from the server on demand, as before
var n := 0
var _xf := PackedFloat32Array()


func add() -> void:
	_xf.resize(_xf.size() + 12)


func drop(k: int) -> void:
	for _i: int in 12:
		_xf.remove_at(k * 12)
	if k < n:
		n -= 1


## A physics step is about to move every body.
func stale() -> void:
	n = 0


func tf(rid: RID) -> Transform3D:
	reads += 1
	var xf: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	return xf


func vel(rid: RID, which: PhysicsServer3D.BodyState) -> Vector3:
	reads += 1
	var v: Vector3 = PhysicsServer3D.body_get_state(rid, which)
	return v


## Live piece k's transform.
func at(rids: Array[RID], k: int) -> Transform3D:
	if not cached:
		return tf(rids[k])
	if k >= n:
		sync(rids)
	var o := k * 12
	var b := Basis(
		Vector3(_xf[o], _xf[o + 1], _xf[o + 2]),
		Vector3(_xf[o + 3], _xf[o + 4], _xf[o + 5]),
		Vector3(_xf[o + 6], _xf[o + 7], _xf[o + 8])
	)
	return Transform3D(b, Vector3(_xf[o + 9], _xf[o + 10], _xf[o + 11]))


func store(k: int, xf: Transform3D) -> void:
	var o := k * 12
	var b := xf.basis
	_xf[o] = b.x.x
	_xf[o + 1] = b.x.y
	_xf[o + 2] = b.x.z
	_xf[o + 3] = b.y.x
	_xf[o + 4] = b.y.y
	_xf[o + 5] = b.y.z
	_xf[o + 6] = b.z.x
	_xf[o + 7] = b.z.y
	_xf[o + 8] = b.z.z
	_xf[o + 9] = xf.origin.x
	_xf[o + 10] = xf.origin.y
	_xf[o + 11] = xf.origin.z


## Reads the pieces whose entry is stale (every one after a step; a new one alone).
func sync(rids: Array[RID]) -> void:
	for k: int in range(n, rids.size()):
		store(k, tf(rids[k]))
	n = rids.size()
