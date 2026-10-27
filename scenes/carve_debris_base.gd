class_name CarveDebrisBase
extends Node3D
## The pieces and the read-outs of CarveDebris (split out to keep files small): the live pieces
## as parallel arrays, the counters the captures read, and the questions about where the pieces
## lie. Nothing here moves a piece; CarveDebris owns the stepping.

var raised := 0  # live pieces lifted out of the road so far (captures)
var max_raise := 0.0  # the deepest of them

var skid_max := 0.0  # how far a settled piece slid along the road from first touch, in its widths
var culled := 0  # pieces faded out because they lay indoors (captures)
var skid_sum := 0.0
var skid_over := 0  # settled pieces that slid more than 5 of their widths
var skid_n := 0

var _rubble: CarveRubble
# Live pieces, parallel arrays.
var _rids: Array[RID] = []
var _sizes := PackedVector3Array()
var _colors := PackedColorArray()
var _still := PackedFloat32Array()
var _age := PackedFloat32Array()
var _fade := PackedFloat32Array()  # < 0: not fading; else seconds since it began to fade
var _touch := PackedVector3Array()  # where it first met the road (y = NAN until it does)
var _fading := 0  # live pieces fading out

var _poses := CarveDebrisPoses.new()


## Live pieces still counted against the cap (fading ones excluded: they are on their way out).
func live() -> int:
	return _rids.size() - _fading


func bodies() -> int:
	return _rids.size()


func rubble() -> int:
	return _rubble.count()


## Rubble pieces dropped past rubble_cap so far.
func dropped() -> int:
	return _rubble.dropped


## Pieces that left the screen at over half size in one frame (captures; 0).
func vanished() -> int:
	return _rubble.vanished


func static_bodies() -> int:
	return _rubble.statics


## The lowest point of any piece, live or rubble (the capture's through-the-ground check).
func lowest_point() -> float:
	var low := INF
	for k: int in _rids.size():
		low = minf(low, _low(k))
	return minf(low, _rubble.lowest())


## How many live pieces reach below `y` (a capture's sunk-into-the-road count).
func sunk(y: float) -> int:
	var n := 0
	for k: int in _rids.size():
		if _low(k) < y:
			n += 1
	return n


## Live and rubble pieces whose centre lies inside `box` (captures: debris inside a building).
func inside(box: AABB) -> int:
	var n := 0
	for k: int in _rids.size():
		n += 1 if box.has_point(_xf_at(k).origin) else 0
	return n + _rubble.inside(box)


## The fastest live piece's speed (captures).
func fastest() -> float:
	var top := 0.0
	for k: int in _rids.size():
		top = maxf(top, _poses.vel(_rids[k], PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY).length())
	return top


## Live piece k's lowest point.
func _low(k: int) -> float:
	return _low_of(_xf_at(k), k)


func _low_of(xf: Transform3D, k: int) -> float:
	var b := xf.basis.scaled_local(_sizes[k])
	return xf.origin.y - 0.5 * (absf(b.x.y) + absf(b.y.y) + absf(b.z.y))


func _xf_at(k: int) -> Transform3D:
	return _poses.at(_rids, k)
