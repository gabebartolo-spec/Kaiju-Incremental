class_name MultiMeshBuckets
extends RefCounted
## A set of MultiMeshes filled one frame at a time (render plan item 7, render_opt.people_buffers):
## instances are added in order, then commit() shows them. Buffered, each bucket's transforms (and
## colours) go straight into one PackedFloat32Array and reach the MultiMesh in a single
## `buffer` assignment, instead of one set_instance_transform call per instance. Unbuffered, the
## same instances go through the per-instance setters (the flag-off path). Either way the same
## slot holds the same transform: the buffer is the layout the setters write (3x4 transform
## row by row, origin in the fourth column; colours after it).
## A buffer must be exactly instance_count * stride long, so a bucket's instance_count follows
## its people: it grows with headroom and shrinks once the bucket is under half full.
## Presentation only.

const TRANSFORM_FLOATS := 12
const COLOR_FLOATS := 4

## Instances added to each bucket since begin().
var counts := PackedInt32Array()
## Each bucket's buffer (empty while unbuffered).
var bufs: Array[PackedFloat32Array] = []
## Microseconds spent between begin() and commit(), summed over frames (benchmarking).
var usec := 0
var _mms: Array[MultiMesh] = []
var _slots := PackedInt32Array()  # instances each buffer holds
var _buffered: bool
var _colored: bool
var _stride: int
var _min_slots: int
var _began := 0


## min_slots: the fewest instances a buffered bucket keeps (instance_count is set to it).
func _init(mms: Array[MultiMesh], buffered: bool, min_slots: int, colored: bool = false) -> void:
	_mms = mms
	_buffered = buffered
	_colored = colored
	_min_slots = min_slots
	_stride = TRANSFORM_FLOATS + (COLOR_FLOATS if colored else 0)
	counts.resize(mms.size())
	_slots.resize(mms.size())
	if not buffered:
		return
	for b: int in mms.size():
		mms[b].instance_count = min_slots
		_slots[b] = min_slots
		var buf := PackedFloat32Array()
		buf.resize(min_slots * _stride)
		bufs.append(buf)


func begin() -> void:
	counts.fill(0)
	_began = Time.get_ticks_usec()


## The next instance of bucket b stands at t (and shows colour c, when the buckets are coloured).
func add(b: int, t: Transform3D, c: Color = Color.WHITE) -> void:
	var n := counts[b]
	counts[b] = n + 1
	if not _buffered:
		_mms[b].set_instance_transform(n, t)
		if _colored:
			_mms[b].set_instance_color(n, c)
		return
	var buf := bufs[b]
	var at := n * _stride
	if n >= _slots[b]:  # full: grow by half again
		_slots[b] = n + 1 + (n >> 1)
		buf.resize(_slots[b] * _stride)
	var bx := t.basis.x
	var by := t.basis.y
	var bz := t.basis.z
	var o := t.origin
	buf[at] = bx.x
	buf[at + 1] = by.x
	buf[at + 2] = bz.x
	buf[at + 3] = o.x
	buf[at + 4] = bx.y
	buf[at + 5] = by.y
	buf[at + 6] = bz.y
	buf[at + 7] = o.y
	buf[at + 8] = bx.z
	buf[at + 9] = by.z
	buf[at + 10] = bz.z
	buf[at + 11] = o.z
	if _colored:
		buf[at + 12] = c.r
		buf[at + 13] = c.g
		buf[at + 14] = c.b
		buf[at + 15] = c.a


## Shows what was added: each MultiMesh gets its buffer (resized to fit) and its count.
func commit() -> void:
	for b: int in _mms.size():
		var mm := _mms[b]
		if _buffered:
			var buf := bufs[b]
			var slots := _slots[b]
			if slots > _min_slots and counts[b] * 2 < slots:
				slots = maxi(_min_slots, counts[b] + (counts[b] >> 2) + 1)
				_slots[b] = slots
				buf.resize(slots * _stride)
			if mm.instance_count != slots:
				mm.instance_count = slots
			mm.buffer = buf
		mm.visible_instance_count = counts[b]
	usec += Time.get_ticks_usec() - _began


## Gives every MultiMesh a fixed culling box (the engine otherwise rebuilds one from every
## instance slot each time a buffer is set): the bounds of `points` (x, z), `top` tall, and
## render_opt.people_aabb_margin_m wider every way, for the figures' own size and a squad's step.
static func bound(mms: Array[MultiMesh], points: PackedVector2Array, top: float = 2.0) -> void:
	if points.is_empty():
		return
	var lo := points[0]
	var hi := points[0]
	for p: Vector2 in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var m := Num.f(Content.section("render_opt")["people_aabb_margin_m"])
	var size := Vector3(hi.x - lo.x + 2.0 * m, top + 2.0 * m, hi.y - lo.y + 2.0 * m)
	var box := AABB(Vector3(lo.x - m, -m, lo.y - m), size)
	for mm: MultiMesh in mms:
		mm.custom_aabb = box
