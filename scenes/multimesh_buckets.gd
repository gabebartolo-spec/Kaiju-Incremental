class_name MultiMeshBuckets
extends RefCounted
## A set of MultiMeshes filled one frame at a time (render plan item 7, render_opt.people_buffers):
## instances are added in order, then commit() shows them. Buffered, with the native extension
## loaded, KaijuBuckets (native/) writes each bucket's transforms (and colours) into one float
## buffer that reaches its MultiMesh in a single set_buffer, instead of one setter call per
## instance; StreetDraw even places the street's civilians there in one call a frame. Unbuffered,
## or without the extension, every instance goes through the per-instance setters (the GDScript
## path, as before item 7). Either way the same slot holds the same transform: the buffer is the
## layout the setters write. A buffered bucket's instance_count follows its instances: it grows
## with headroom and shrinks once the bucket is under half full. Presentation only.

## Instances added to each bucket since begin().
var counts := PackedInt32Array()
## The native buckets (KaijuBuckets) when buffered and the extension is loaded, else null.
var native: Object = null
## Microseconds spent between begin() and commit(), summed over frames (benchmarking).
var usec := 0
var _mms: Array[MultiMesh] = []
var _colored: bool
var _began := 0


## Buffered: min_slots is the fewest instances a bucket keeps (its instance_count). Unbuffered,
## each MultiMesh keeps the instance_count it was made with.
func _init(mms: Array[MultiMesh], buffered: bool, min_slots: int, colored: bool = false) -> void:
	_mms = mms
	_colored = colored
	counts.resize(mms.size())
	if buffered and ClassDB.class_exists("KaijuBuckets"):
		native = ClassDB.instantiate("KaijuBuckets")
		native.call("setup", mms, min_slots, colored)


func begin() -> void:
	counts.fill(0)
	_began = Time.get_ticks_usec()
	if native != null:
		native.call("begin")


## The next instance of bucket b stands at t (and shows colour c, when the buckets are coloured).
func add(b: int, t: Transform3D, c: Color = Color.WHITE) -> void:
	var n := counts[b]
	counts[b] = n + 1
	if native != null:
		native.call("add", b, t, c)
		return
	_mms[b].set_instance_transform(n, t)
	if _colored:
		_mms[b].set_instance_color(n, c)


## Shows what was added: buffered, each MultiMesh gets its buffer (sized to fit) and its count.
func commit() -> void:
	if native != null:
		native.call("commit")
	else:
		for b: int in _mms.size():
			_mms[b].visible_instance_count = counts[b]
	usec += Time.get_ticks_usec() - _began


## The buffer bucket b last handed its MultiMesh (empty when unbuffered).
func buffer(b: int) -> PackedFloat32Array:
	return native.call("get_buffer", b) if native != null else PackedFloat32Array()


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
