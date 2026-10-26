extends RefCounted
## Render plan item 2 (kaiju shadow bounds): the box the croc titan's skin (VoxelSkin) hands the
## engine always holds every cube and every filler vertex, and is a real saving on the fixed box.
## The cube shader moves every vertex (voxel_skin.gdshader), so this redoes its maths on the CPU
## from the baked .vskin (an independent reader of the file, not the skin's own arrays) for the
## idle, walk and roar clips, 30 poses each, at every stage:
##  - a stride sample of cubes (every corner, turned by the main bone as the shader turns it) and
##    of filler vertices lie inside the box on all 90 poses;
##  - on the middle pose of each clip EVERY cube centre is checked and, for those within a corner
##    of the box's faces, every corner as well;
##  - the idle box is at most half the fixed 24 m box (VoxelSkin.BOUNDS); the cubes' instance and
##    the filler carry the same box; with the flag off the fixed box stays.
## Reads the nodes' custom_aabb (the headless renderer keeps no MultiMesh buffers).
## Seeded by design: fixed 60 Hz steps, no random numbers.

const STAGES: Array[String] = ["baby", "adolescent", "adult"]
const DT := 1.0 / 60.0
## Frames to run, frames between poses, for each clip (30 poses each; the walk warms up 30 first).
const CLIPS := {"idle": [180, 6], "walk": [180, 5], "roar": [420, 14]}
const WALK_WARMUP := 30
const POSES := 30
const CUBE_SAMPLE := 1000
const FILL_SAMPLE := 1000
## A point on the box's face counts as inside, to a tenth of a millimetre.
const EDGE := 1.0e-4
## The idle box may be this much of the fixed one.
const MAX_IDLE_SHARE := 0.5

var _check: Callable
var _root: Node


## check: the runner's check; root: where to put the kaiju.
func _init(p_check: Callable, p_root: Node) -> void:
	_check = p_check
	_root = p_root


func run() -> void:
	var on := Num.i(Content.section("render_opt").get("kaiju_tight_bounds", false)) != 0
	_check.call(on, "render_opt.kaiju_tight_bounds is ON by default")
	for stage: String in STAGES:
		await _stage(stage)
	await _flag_off()


func _model(stage: String) -> KaijuModel:
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	_root.add_child(kaiju)
	return kaiju


## The skin's draw nodes: [cubes, filler].
func _nodes(skin: VoxelSkin) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = [null, null]
	for n: Node in skin.get_children():
		if n is MultiMeshInstance3D:
			out[0] = n
		elif n is MeshInstance3D:
			out[1] = n
	return out


func _stage(stage: String) -> void:
	var kaiju := _model(stage)
	var found := kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)
	_check.call(found.size() == 1, "%s: the croc has a voxel skin" % stage)
	if found.size() != 1:
		kaiju.queue_free()
		return
	var skin: VoxelSkin = found[0]
	var nodes := _nodes(skin)
	var data := Oracle.read("res://assets/kaiju/reptilian_%s.vskin" % stage)
	var cubes := data.pick(data.centres.size(), CUBE_SAMPLE)
	var verts := data.pick(data.fill_pos.size(), FILL_SAMPLE)
	data.pose = skin.pose
	var worst := INF
	var worst_fill := INF
	var worst_all := INF
	var same_box := true
	var idle_box := AABB()
	for clip: String in CLIPS:
		var frames: int = CLIPS[clip][0]
		var every: int = CLIPS[clip][1]
		var posed := 0
		for frame: int in frames:
			_step(kaiju, clip, frame)
			if frame < (WALK_WARMUP if clip == "walk" else 0) or frame % every != 0:
				continue
			posed += 1
			var box := nodes[0].custom_aabb
			same_box = same_box and nodes[1].custom_aabb == box
			worst = minf(worst, data.worst_cubes(box, cubes))
			worst_fill = minf(worst_fill, data.worst_fill(nodes[1].custom_aabb, verts))
			if posed == POSES / 2:
				worst_all = minf(worst_all, data.worst_every_cube(box))
				if clip == "idle":
					idle_box = box
		_check.call(posed >= POSES, "%s %s: %d poses sampled" % [stage, clip, posed])
	_check.call(
		worst >= -EDGE,
		"%s: every sampled cube corner lies inside the box (worst margin %.4f m)" % [stage, worst]
	)
	_check.call(
		worst_fill >= -EDGE,
		(
			"%s: every sampled filler vertex lies inside the box (worst margin %.4f m)"
			% [stage, worst_fill]
		)
	)
	_check.call(
		worst_all >= -EDGE,
		(
			"%s: no cube anywhere in the body reaches outside it (worst margin %.4f m)"
			% [stage, worst_all]
		)
	)
	_check.call(same_box, "%s: the cubes and the filler carry one box" % stage)
	var share := idle_box.get_volume() / VoxelSkin.BOUNDS.get_volume()
	_check.call(
		share <= MAX_IDLE_SHARE,
		(
			"%s: the idle box is %.0f%% of the fixed 24 m box (at most %.0f%%)"
			% [stage, share * 100.0, MAX_IDLE_SHARE * 100.0]
		)
	)
	kaiju.queue_free()
	await _root.get_tree().process_frame


## Flag off: the fixed box is kept on every node, whatever the pose.
func _flag_off() -> void:
	var opt := Content.section("render_opt")
	var was: Variant = opt.get("kaiju_tight_bounds", null)
	opt["kaiju_tight_bounds"] = false
	var kaiju := _model("baby")
	for frame: int in 20:
		_step(kaiju, "walk", frame)
	var skin: VoxelSkin = kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)[0]
	var nodes := _nodes(skin)
	_check.call(
		nodes[0].custom_aabb == VoxelSkin.BOUNDS and nodes[1].custom_aabb == VoxelSkin.BOUNDS,
		"flag off: both draw nodes keep the fixed box"
	)
	if was == null:
		opt.erase("kaiju_tight_bounds")
	else:
		opt["kaiju_tight_bounds"] = was
	kaiju.queue_free()
	await _root.get_tree().process_frame


## One 60 Hz step of a clip: idle stands, walk strides forward, roar starts at frame 0.
func _step(kaiju: KaijuModel, clip: String, frame: int) -> void:
	if clip == "roar" and frame == 0:
		kaiju.roar()
	if clip == "walk":
		kaiju.position += Vector3(0, 0, -4.0 * DT)
	kaiju.animate(DT, 1.0 if clip == "walk" else 0.0)


## The baked cubes and filler vertices read straight from a .vskin, and the shader's maths.
class Oracle:
	extends RefCounted
	const SIGNS: Array[float] = [-1.0, 1.0]
	var voxel := 0.0
	## Per cube: its rest centre, three bones, three weights (the shader's w0, w1 and the rest).
	var centres := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	## The same per filler vertex.
	var fill_pos := PackedVector3Array()
	var fill_bones := PackedInt32Array()
	var fill_weights := PackedFloat32Array()
	## The bone matrices the shaders got (VoxelSkin.pose, shared, so always the current pose).
	var pose: Array[Projection] = []

	## How far inside the box a point is (negative: outside).
	static func margin(box: AABB, p: Vector3) -> float:
		var lo := p - box.position
		var hi := box.end - p
		return minf(minf(minf(lo.x, lo.y), minf(lo.z, hi.x)), minf(hi.y, hi.z))

	static func read(path: String) -> Oracle:
		var raw := FileAccess.get_file_as_bytes(path).decompress_dynamic(
			-1, FileAccess.COMPRESSION_GZIP
		)
		var o := Oracle.new()
		o.voxel = raw.decode_float(18)
		var cells := raw.decode_u32(22)
		var at := VoxelSkin.HEADER_BYTES
		o.centres.resize(cells)
		o.bones.resize(cells * 3)
		o.weights.resize(cells * 3)
		for i: int in cells:
			var cell := Vector3(raw.decode_s16(at), raw.decode_s16(at + 2), raw.decode_s16(at + 4))
			o.centres[i] = (cell + VoxelSkin.HALF_UP) * o.voxel
			var w0 := raw[at + 13] / 255.0
			var w1 := raw[at + 14] / 255.0
			o.weights[i * 3] = w0
			o.weights[i * 3 + 1] = w1
			o.weights[i * 3 + 2] = maxf(0.0, 1.0 - w0 - w1)
			for k: int in 3:
				o.bones[i * 3 + k] = raw[at + 10 + k]
			at += 15
		var verts := raw.decode_u32(at)
		at += 4
		o.fill_pos.resize(verts)
		o.fill_bones.resize(verts * 3)
		o.fill_weights.resize(verts * 3)
		for i: int in verts:
			o.fill_pos[i] = Vector3(
				raw.decode_float(at), raw.decode_float(at + 4), raw.decode_float(at + 8)
			)
			var w0 := raw[at + 18] / 255.0
			var w1 := raw[at + 19] / 255.0
			o.fill_weights[i * 3] = w0
			o.fill_weights[i * 3 + 1] = w1
			o.fill_weights[i * 3 + 2] = maxf(0.0, 1.0 - w0 - w1)
			for k: int in 3:
				o.fill_bones[i * 3 + k] = raw[at + 15 + k]
			at += 20
		return o

	## count indices spread evenly over total.
	func pick(total: int, count: int) -> PackedInt32Array:
		var out := PackedInt32Array()
		var stride := maxi(1, floori(float(total) / count))
		for i: int in range(0, total, stride):
			out.append(i)
		return out

	## The shader's blended position of rest point p, with item i's bones and weights.
	func moved(p: Vector3, i: int, on_fill: bool) -> Vector3:
		var bs := fill_bones if on_fill else bones
		var ws := fill_weights if on_fill else weights
		var q := Vector4(p.x, p.y, p.z, 1.0)
		var out := Vector3.ZERO
		for k: int in 3:
			var w := ws[i * 3 + k]
			if w > 0.0:
				var r := pose[bs[i * 3 + k]] * q
				out += Vector3(r.x, r.y, r.z) * w
		return out

	## The cube's corner offsets in the skin's space: the main bone's turn only (the shader's mat3
	## from ax, ay, az), the cube's size unchanged (max_grow 0).
	func corners(i: int) -> PackedVector3Array:
		var m := pose[bones[i * 3]]
		var ax := Vector3(m.x.x, m.x.y, m.x.z).normalized()
		var c1 := Vector3(m.y.x, m.y.y, m.y.z)
		var ay := (c1 - ax * ax.dot(c1)).normalized()
		var az := ax.cross(ay)
		var half := voxel * Look.value("voxel_inset") * 0.5
		var out := PackedVector3Array()
		for sx: float in SIGNS:
			for sy: float in SIGNS:
				for sz: float in SIGNS:
					out.append((ax * sx + ay * sy + az * sz) * half)
		return out

	## Worst margin over the picked cubes' eight corners.
	func worst_cubes(box: AABB, picked: PackedInt32Array) -> float:
		var worst := INF
		for i: int in picked:
			var at := moved(centres[i], i, false)
			for c: Vector3 in corners(i):
				worst = minf(worst, margin(box, at + c))
		return worst

	func worst_fill(box: AABB, picked: PackedInt32Array) -> float:
		var worst := INF
		for i: int in picked:
			worst = minf(worst, margin(box, moved(fill_pos[i], i, true)))
		return worst

	## Every cube's centre; the corners too for each centre within a corner's reach of a face.
	func worst_every_cube(box: AABB) -> float:
		var reach := voxel * Look.value("voxel_inset") * 0.8660254
		var worst := INF
		for i: int in centres.size():
			var at := moved(centres[i], i, false)
			var m := margin(box, at)
			if m >= reach:
				worst = minf(worst, m - reach)
			else:
				for c: Vector3 in corners(i):
					worst = minf(worst, margin(box, at + c))
		return worst
