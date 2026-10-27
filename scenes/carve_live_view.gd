class_name CarveLiveView
extends RefCounted
## Draws one building's live debris (CarveDebris) as one MultiMesh. With debris_cache on it draws
## only after something changed, sets the MultiMesh's bounds by hand (Godot would otherwise walk
## every instance to rebuild them on each assignment) and grows them if a piece leaves; off, it
## redraws every frame as before. `d` is the owning CarveDebris, whose piece arrays it reads.

var mm: MultiMesh
var cached := true
var dirty := true  # something changed since the last draw
var _bound := AABB()
var _shown := -1  # the instance count last drawn


func _init(p_mm: MultiMesh, p_cached: bool, start: AABB) -> void:
	mm = p_mm
	cached = p_cached
	if cached:
		_bound = start
		mm.custom_aabb = start


func draw(d: CarveDebris) -> void:
	var n := d._rids.size()
	if cached:
		if n == 0:
			if _shown != 0:
				mm.visible_instance_count = 0
				_shown = 0
			return
		if not dirty:
			return  # nothing moved since the last draw: the buffer would be identical
		dirty = false
		d._poses.sync(d._rids)
	CarveRubble.fit(mm, n)
	var buf := PackedFloat32Array()
	buf.resize(mm.instance_count * CarveRubble.FLOATS)
	_pack(d, buf, n)
	if cached:
		_shown = n
	mm.buffer = buf
	mm.visible_instance_count = n


## Writes the n pieces as drawn (sunk ones lifted, fading ones shrunk) into `buf`. With the cache
## on, a piece whose origin leaves the bounds widens them (grown by that piece's size) and the
## bounds are set again once.
func _pack(d: CarveDebris, buf: PackedFloat32Array, n: int) -> void:
	var t := d._t
	var grown := false
	for k: int in n:
		var xf := d._xf_at(k)
		var size := d._sizes[k]
		var b := xf.basis.scaled_local(size)
		var low := xf.origin.y - 0.5 * (absf(b.x.y) + absf(b.y.y) + absf(b.z.y))
		if low < t.ground - t.slop:
			# The physics steps since the last fix can press a piece in again: never draw it so.
			# Cached, the body is left to the next tick's fix (it sees this same state); the old
			# path lifted it here, which came to the same one tick sooner.
			if not cached:
				d._raise(
					k,
					t.ground - low,
					d._poses.vel(d._rids[k], PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
				)
			xf.origin.y += t.ground - low
		if d._fade[k] >= 0.0:
			var shrunk := size * maxf(CarveDebris.SHRINK_MIN, 1.0 - d._fade[k] / t.fade_t)
			b = xf.basis.scaled_local(shrunk)
		CarveRubble.pack(buf, k * CarveRubble.FLOATS, Transform3D(b, xf.origin), d._colors[k])
		if cached and not _bound.has_point(xf.origin):
			_bound = _bound.expand(xf.origin).grow(size.length())
			grown = true
	if grown:
		mm.custom_aabb = _bound
