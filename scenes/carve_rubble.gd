class_name CarveRubble
extends RefCounted
## One building's rubble: pieces that came to rest, drawn by ONE static MultiMesh. Each has a
## static Jolt body (an invalid RID: rubble with no collider left, past the city's static cap).
## Rubble past rubble_cap, or woken and removed, shrinks away over fade_seconds, never vanishing
## in one frame. Cosmetic: nothing here reaches the sim.

const FLOATS := 16  # per MultiMesh instance: a 3x4 transform, then a colour
const SHRINK_MIN := 0.01  # a fading piece's last scale

var dropped := 0  # pieces dropped past rubble_cap so far
var vanished := 0  # pieces that left the screen at over half size in one frame (captures; 0)
var rids: Array[RID] = []
var buf := PackedFloat32Array()  # FLOATS per piece
var fade := PackedFloat32Array()  # < 0: not fading; else seconds since it began
var statics := 0  # pieces that still have a (static) body
var mm: MultiMesh
var _cfg: Dictionary
var _fading := 0
var _dirty := false


func _init(p_mm: MultiMesh, cfg: Dictionary) -> void:
	mm = p_mm
	_cfg = cfg


func count() -> int:
	return rids.size()


## A piece at rest: `xf` already carries its size in its basis.
func add(rid: RID, xf: Transform3D, color: Color) -> void:
	var o := buf.size()
	buf.resize(o + FLOATS)
	pack(buf, o, xf, color)
	rids.append(rid)
	fade.append(-1.0)
	statics += 1
	_dirty = true


func remove(k: int) -> void:
	rids.remove_at(k)
	fade.remove_at(k)
	var o := k * FLOATS
	var tail := buf.slice(o + FLOATS)
	buf.resize(o)
	buf.append_array(tail)
	_dirty = true


func free_bodies() -> void:
	for rid: RID in rids:
		if rid.is_valid():
			PhysicsServer3D.free_rid(rid)
	rids.clear()


func lowest() -> float:
	var low := INF
	for o: int in range(0, buf.size(), FLOATS):
		var reach := absf(buf[o + 4]) + absf(buf[o + 5]) + absf(buf[o + 6])
		low = minf(low, buf[o + 7] - 0.5 * reach)
	return low


func inside(box: AABB) -> int:
	var n := 0
	for o: int in range(0, buf.size(), FLOATS):
		n += 1 if box.has_point(Vector3(buf[o + 3], buf[o + 7], buf[o + 11])) else 0
	return n


## Drops colliders from the oldest rubble until at most `keep` static bodies remain.
func trim_static(keep: int) -> void:
	for k: int in rids.size():
		if statics <= keep:
			return
		_drop_collider(k)


## Per frame: past rubble_cap the oldest rubble (the bottom of the pile, under newer pieces) loses
## its collider and starts to shrink away; fading pieces shrink about their centre and go; the
## MultiMesh is rewritten when anything changed.
func update(delta: float) -> void:
	var over := rids.size() - _fading - Num.i(_cfg["rubble_cap"])
	var k := 0
	while over > 0 and k < rids.size():
		if fade[k] < 0.0:
			fade[k] = 0.0
			_fading += 1
			over -= 1
			dropped += 1
			_drop_collider(k)
		k += 1
	_fade(delta)
	if _dirty:
		_dirty = false
		var n := rids.size()
		fit(mm, n)
		var out := buf.duplicate()
		out.resize(mm.instance_count * FLOATS)
		mm.buffer = out
		mm.visible_instance_count = n


## Counts a piece leaving the screen at `scale` of its size (over half: it popped).
func gone(scale: float) -> void:
	if scale > 0.5:
		vanished += 1


func _drop_collider(k: int) -> void:
	if rids[k].is_valid():
		PhysicsServer3D.free_rid(rids[k])
		rids[k] = RID()
		statics -= 1


func _fade(delta: float) -> void:
	if _fading == 0:
		return
	var fade_t := Num.f(_cfg["fade_seconds"])
	var k := rids.size() - 1
	while k >= 0:
		var f := fade[k]
		if f >= 0.0:
			var before := maxf(SHRINK_MIN, 1.0 - f / fade_t)
			f += delta
			fade[k] = f
			if f >= fade_t:
				gone(before)
				remove(k)
				_fading -= 1
			else:
				var ratio := maxf(SHRINK_MIN, 1.0 - f / fade_t) / before
				var o := k * FLOATS
				for c: int in [0, 1, 2, 4, 5, 6, 8, 9, 10]:
					buf[o + c] *= ratio
				_dirty = true
		k -= 1


## A MultiMesh of unit cubes, scaled per instance to the piece's size, added under `parent`.
static func multimesh(parent: Node) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cube := BoxMesh.new()
	cube.material = CarveMesh.material()
	mm.mesh = cube
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.top_level = true
	parent.add_child(mmi)
	return mm


## Grows the MultiMesh's capacity (doubling) so `n` pieces fit; it never shrinks.
static func fit(target: MultiMesh, n: int) -> void:
	if target.instance_count >= n:
		return
	target.instance_count = maxi(64, nearest_po2(n))


static func pack(out: PackedFloat32Array, o: int, xf: Transform3D, c: Color) -> void:
	var b := xf.basis
	out[o] = b.x.x
	out[o + 1] = b.y.x
	out[o + 2] = b.z.x
	out[o + 3] = xf.origin.x
	out[o + 4] = b.x.y
	out[o + 5] = b.y.y
	out[o + 6] = b.z.y
	out[o + 7] = xf.origin.y
	out[o + 8] = b.x.z
	out[o + 9] = b.y.z
	out[o + 10] = b.z.z
	out[o + 11] = xf.origin.z
	out[o + 12] = c.r
	out[o + 13] = c.g
	out[o + 14] = c.b
	out[o + 15] = 1.0


static func unpack(src: PackedFloat32Array, o: int) -> Transform3D:
	var bx := Vector3(src[o], src[o + 4], src[o + 8])
	var by := Vector3(src[o + 1], src[o + 5], src[o + 9])
	var bz := Vector3(src[o + 2], src[o + 6], src[o + 10])
	return Transform3D(Basis(bx, by, bz), Vector3(src[o + 3], src[o + 7], src[o + 11]))
