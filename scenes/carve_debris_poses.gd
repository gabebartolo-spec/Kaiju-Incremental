class_name CarveDebrisPoses
extends RefCounted
## The physics-server reads of one building's live debris, and with debris_cache on a cache of
## every live piece's transform taken once per physics step: the tick and the
## draw that follows it share one read per piece instead of repeating it. `n` leading entries are
## current; a physics step makes none of them so (stale), a new piece is read alone.

var reads := 0  # state reads made so far (a test bounds them per live piece per tick)
var cached := true  # off: every pose is read from the server on demand, as before
var n := 0
var _xf: Array[Transform3D] = []


func add() -> void:
	_xf.append(Transform3D())


func drop(k: int) -> void:
	_xf.remove_at(k)
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
	return _xf[k]


func store(k: int, xf: Transform3D) -> void:
	_xf[k] = xf


## Reads the pieces whose entry is stale (every one after a step; a new one alone).
func sync(rids: Array[RID]) -> void:
	for k: int in range(n, rids.size()):
		store(k, tf(rids[k]))
	n = rids.size()
