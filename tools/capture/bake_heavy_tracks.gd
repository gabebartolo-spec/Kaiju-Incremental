extends SceneTree
## Bakes a heavy kaiju's drawn poses into the sim's contact track (D-208, "any contact a kaiju has
## with a building will damage it"): for every frame of every clip it plays (the .kclip the game
## draws), and for the claw rake laid over the arms (BipedSwing, code not a clip), each bone's
## voxels are posed exactly as the rig poses them and cut into slots (SEG long along the bone, and
## across a lying bone SEG wide and BAND high: a slot about as wide as it is long, so the upright
## disc that holds it reaches little past it); each slot is written as that disc in body space (rig
## units = body scale 1: forward, across to the right, radius, lowest, highest), with every bone's
## head, the hind toes, the root's turn and the clip's planted feet. The sim (HeavyTrack,
## HeavyContact) plays the same clips on its own clip clock (ClipClock), so its contact volume
## rides the drawn body by construction.
## Run it again after any clip or model change (a Cascadeur re-animation): it reads the clip files.
##
##   godot --headless --path . --script tools/capture/bake_heavy_tracks.gd -- --kind=reptilian_adult

const Kit := preload("res://tools/capture/capture_kit.gd")
const SEG := 0.6
const BAND := 0.6
const UPRIGHT := 0.7  # a bone this close to vertical is cut along its length only
const CLIPS: Array[String] = ["idle", "walk", "roar", "turn_left", "turn_right"]
const RAKE_FPS := 60.0
const SUPPORT := 3  # directions per axis for a slot's support points (3x3x3 - 1 = 26)
const FEET: Array[String] = ["leg_l", "leg_r"]  # the hind legs, as the clips' planted bits

var _rig: KaijuRig
var _clips: KaijuClips
var _gait: ClipGait
var _to_rig := Transform3D.IDENTITY
var _names: Array[String] = []  # the rig's bones, as the track numbers them
var _slot_bone: Array[int] = []
var _slot_pts: Array[PackedVector3Array] = []  # each slot's support points (bone-local)
var _jaw: int = -1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var a := Kit.args({"kind": "reptilian_adult"})
	var kind := str(a["kind"])
	var cut := kind.rfind("_")
	var species := kind.substr(0, cut)
	var def := Content.species_def(species)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(species, colors, kind.substr(cut + 1))
	root.add_child(kaiju)
	await process_frame
	_rig = kaiju._rig
	_gait = _rig.gait
	_clips = _gait.clips
	_to_rig = _rig.global_transform.affine_inverse()
	# the claw rake reaches as ClipGait._apply has it for a heavy body: an adult, past ADULT_SCALE
	_gait.swing.youth = 0.0
	_cut_slots()
	var header := _header()
	var data := PackedByteArray()
	var first := 0
	var clips_out: Array = []
	for clip: String in CLIPS:
		if not _clips.has_clip(clip):
			continue
		var n := _clips.frames_of(clip)
		for f: int in n:
			_pose(clip, float(f))
			_frame_into(data, clip, float(f))
		clips_out.append(_clip_row(clip, [first, n, _clips.fps, _clips.loops(clip)]))
		first += n
	for side: float in [-1.0, 1.0]:
		var n := _bake_rake(data, side)
		clips_out.append(
			_clip_row("rake_%s" % ("n" if side < 0.0 else "p"), [first, n, RAKE_FPS, false])
		)
		first += n
	header["clips"] = clips_out
	_write("res://assets/kaiju/%s.ktrack" % kind, header, data)
	print("TRACK %s: %d slots, %d frames, %d bytes" % [kind, _slot_bone.size(), first, data.size()])
	quit()


## Each bone's voxels cut into slots, each kept as its support points in the bone's own frame.
func _cut_slots() -> void:
	var spec: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/kaiju/%s.rig.json" % _rig.kind)
	)
	for d: Dictionary in spec["bones"]:
		_names.append(str(d["name"]))
	var vox: VoxelBuilder = Kvox.read("res://assets/kaiju/%s.kvox" % _rig.kind).frames[0]
	var size := _rig.voxel_size()
	var by_slot := {}  # Vector4i(bone, segment, band, across) -> PackedVector3Array
	for cell: Vector3i in vox.cells:
		var bone: int = vox.flags.get(cell, 0)
		var name := _names[bone]
		var p := Vector3(cell) * size + Vector3.ONE * size * 0.5 - _rig.head_of(name)
		var axis := _rig.dir_of(name).normalized()
		var seg := floori(p.dot(axis) / SEG)
		var lying := absf(axis.y) <= UPRIGHT
		var band := floori(p.y / BAND) if lying else 0
		var side := axis.cross(Vector3.UP).normalized() if lying else Vector3.ZERO
		var cross := floori(p.dot(side) / SEG) if lying else 0
		var key := Vector4i(bone, seg, band, cross)
		if not by_slot.has(key):
			by_slot[key] = PackedVector3Array()
		var list: PackedVector3Array = by_slot[key]
		list.append(p)
		by_slot[key] = list
	var keys := by_slot.keys()
	keys.sort()
	for key: Vector4i in keys:
		var pts: PackedVector3Array = by_slot[key]
		_slot_bone.append(key.x)
		_slot_pts.append(_support(pts, size))
	_jaw = _names.find("jaw")


## The points of a voxel set that lie furthest along each of 26 directions, grown by half a voxel
## along it: a rotated set's bounds are its support points' bounds.
func _support(pts: PackedVector3Array, size: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for x: int in SUPPORT:
		for y: int in SUPPORT:
			for z: int in SUPPORT:
				var dir := Vector3(x - 1, y - 1, z - 1)
				if dir == Vector3.ZERO:
					continue
				var best := pts[0]
				for p: Vector3 in pts:
					if p.dot(dir) > best.dot(dir):
						best = p
				out.append(best + dir.sign() * size * 0.5)
	return out


func _header() -> Dictionary:
	var steps := ClipSteps.new(_clips)
	var spans := {}
	for turn: String in ["turn_left", "turn_right"]:
		if _clips.has_clip(turn):
			var span := _clips.yaw_span(turn)
			spans[turn] = [span.x, span.y]
	var arms := {}  # the rake's side (BipedSwing._arm_out) -> that arm's bones
	for s: String in ["l", "r"]:
		if _rig.has_bone("arm_%s0" % s):
			var out := signf(_rig.dir_of("arm_%s0" % s).x)
			arms["p" if out > 0.0 else "n"] = ["arm_%s0" % s, "arm_%s1" % s, "arm_%s2" % s]
	var legs: Array = []  # each hind leg: thigh and shin length, its rest knee side (LegReach)
	for leg: String in FEET:
		var hip := _rig.head_of(leg + "0")
		var knee := _rig.head_of(leg + "1")
		var line := (_rig.head_of(leg + "2") - hip).normalized()
		var side := ((knee - hip) - line * (knee - hip).dot(line)).normalized()
		var l1 := _rig.dir_of(leg + "0").length()
		legs.append([l1, _rig.dir_of(leg + "1").length(), side.x, side.y, side.z])
	return {
		"legs": legs,
		"youth": _gait.swing.youth,
		"rake_arms": arms,
		"bones": _names,
		"slot_bones": _slot_bone,
		"jaw_slots": _slot_bone.count(_jaw),
		"walk": [steps.land, steps.step_frames],
		"spans": spans,
		"hip_height": _gait.hip_height,
		"hips": -_rig.head_of(_clips.bones[0]).z,
	}


## at: [first frame, frames, fps, loops].
func _clip_row(clip: String, at: Array) -> Dictionary:
	var first: int = at[0]
	var frames: int = at[1]
	var fps: float = at[2]
	var loop: bool = at[3]
	return {"name": clip, "first": first, "frames": frames, "fps": fps, "loop": loop}


## One frame: every slot's disc, then the jaw's slots again with the maw held open (the beam, as
## ClipGait shows it), every bone's head, the hind toes, the root's turn, and the planted bits.
func _frame_into(data: PackedByteArray, clip: String, t: float) -> void:
	for k: int in _slot_bone.size():
		_disc_into(data, k)
	var at := _clips.bones.find("jaw")
	if at >= 0:
		var jaw_was := _rig.bone("jaw").transform
		_rig.pose_basis("jaw", Basis(_gait._jaw_peak))
		for k: int in _slot_bone.size():
			if _slot_bone[k] == _jaw:
				_disc_into(data, k)
		_rig.bone("jaw").transform = jaw_was
	for name: String in _names:
		var h := _to_rig * _rig.bone(name).global_position
		_put(data, [-h.z, h.x, h.y])
	for leg: String in FEET:  # the hind toes, where the leg solve puts a foot down
		var toe := _to_rig * _rig.tail_world(leg + "2")
		_put(data, [-toe.z, toe.x, toe.y])
	var root := (
		(_to_rig.basis * _rig.bone(_clips.bones[0]).global_transform.basis).orthonormalized()
	)
	var q := root.get_rotation_quaternion()  # the root's turn, x100 (centi-units hold 1e-4)
	_put(data, [q.x * 100.0, q.y * 100.0, q.z * 100.0, q.w * 100.0])
	var bits := 0
	if not clip.begins_with("rake"):
		var pose := _clips.pose_at(clip, t)
		bits = (1 if pose.planted[0] else 0) | (2 if pose.planted[1] else 0)
	_put(data, [bits * 0.01])


## Slot k's upright disc in body space: [forward, across, radius, lowest, highest].
func _disc_into(data: PackedByteArray, k: int) -> void:
	var xf := _to_rig * _rig.bone(_names[_slot_bone[k]]).global_transform
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var posed := PackedVector3Array()
	for p: Vector3 in _slot_pts[k]:
		var w := xf * p
		posed.append(w)
		lo = lo.min(w)
		hi = hi.max(w)
	var mid := Vector2(lo.x + hi.x, lo.z + hi.z) * 0.5
	var r := 0.0
	for w: Vector3 in posed:
		r = maxf(r, Vector2(w.x, w.z).distance_to(mid))
	_put(data, [-mid.y, mid.x, r, lo.y, hi.y])


## The claw rake on side `side` over the idle pose, frame n at n / RAKE_FPS seconds in (as the sim
## feeds it: BipedSwing.feed_rake), until it ends; returns its frames.
func _bake_rake(data: PackedByteArray, side: float) -> int:
	var swing := _gait.swing
	var dt := 1.0 / RAKE_FPS
	var n := 0
	while true:
		_pose("idle", 0.0)
		swing.feed_rake(n * dt, side)
		swing.tick_rake(0.0)  # past its end it stops
		if swing._rake_t < 0.0:
			break
		swing.pose_rake(dt)
		_frame_into(data, "rake", 0.0)
		n += 1
	return n


func _pose(clip: String, t: float) -> void:
	var pose := _clips.pose_at(clip, t)
	for i: int in _clips.bones.size():
		var off := pose.offset * _clips.rig_scale if i == 0 else Vector3.ZERO
		_rig.pose_basis(_clips.bones[i], Basis(pose.turns[i]), off)


## Values as signed 16-bit centi-units.
func _put(data: PackedByteArray, values: Array) -> void:
	for v: Variant in values:
		var at := data.size()
		data.resize(at + 2)
		data.encode_s16(at, clampi(roundi(Num.f(v) * 100.0), -32768, 32767))


func _write(path: String, header: Dictionary, data: PackedByteArray) -> void:
	var text := JSON.stringify(header).to_utf8_buffer()
	var out := PackedByteArray()
	out.append_array("KTRK".to_ascii_buffer())
	out.resize(12)
	out.encode_u32(4, 1)
	out.encode_u32(8, text.size())
	out.append_array(text)
	out.append_array(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(out)
	file.close()
