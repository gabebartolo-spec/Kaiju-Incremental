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
	var seen := _pack(d, buf, n)
	if cached:
		if not _bound.encloses(seen):
			_bound = _bound.merge(seen)
			mm.custom_aabb = _bound
		_shown = n
	mm.buffer = buf
	mm.visible_instance_count = n


## Writes the n pieces as drawn (sunk ones lifted, fading ones shrunk) into `buf`; returns the box
## they lie in, grown by the largest piece.
func _pack(d: CarveDebris, buf: PackedFloat32Array, n: int) -> AABB:
	var t := d._t
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var reach := 0.0
	for k: int in n:
		var xf := d._xf_at(k)
		var low := d._low_of(xf, k)
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
		var scale := d._sizes[k]
		if d._fade[k] >= 0.0:
			scale *= maxf(CarveDebris.SHRINK_MIN, 1.0 - d._fade[k] / t.fade_t)
		var drawn := Transform3D(xf.basis.scaled_local(scale), xf.origin)
		CarveRubble.pack(buf, k * CarveRubble.FLOATS, drawn, d._colors[k])
		lo = lo.min(xf.origin)
		hi = hi.max(xf.origin)
		reach = maxf(reach, d._sizes[k].length())
	return AABB(lo, hi - lo).grow(reach)
