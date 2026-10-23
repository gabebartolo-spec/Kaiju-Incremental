extends SceneTree
## Fits a heavy kaiju's sim contact (tuning "body_class" <class> "sim", D-208) to its drawn mesh:
## "discs", the body, head and arms as stacked discs, each [forward, across, radius, bottom, top,
## group] (body scale 1; group 0 the body, 1 the neck, 2 the skull: the head's turn swings groups 1
## and 2; the arms' discs, across != 0, are left out of the data: the drawn arms rake), cut from the
## voxels' cross-sections in SLICE-long slices and BAND-high bands over the walk and idle poses;
## "neck"/"skull": the forward offsets the head turns about; "feet": per foot [landing frame,
## lifting frame, forward, across, footprint half-width, foot top, shin radius, hip height,
## footprint half-length] from the walk clip (the first two, the hind feet, walk; the data takes
## the knee height, 2.6, for the hip height);
## "walk": [frames, first landing frame]. Prints the JSON to paste. Headless is fine.
##
##   godot --headless --path . --script tools/capture/fit_body_contact.gd

const SLICE := 1.0
const BAND := 1.0
const MERGE := 0.3  # bands whose radii differ by less than this (body scale 1) share a disc
const POSES := [["idle", 0], ["idle", 36], ["walk", 0], ["walk", 12], ["walk", 25], ["walk", 38]]
## (3 and 4: the left and right arm, held up off the street: discs set to their side, in group 0.)
const GROUPS := {
	"spine0": 0,
	"spine1": 0,
	"spine2": 0,
	"head0": 1,
	"head1": 2,
	"jaw": 2,
	"arm_l0": 3,
	"arm_l1": 3,
	"arm_l2": 3,
	"arm_r0": 4,
	"arm_r1": 4,
	"arm_r2": 4,
}
const FEET: Array[Array] = [
	["leg_l2", "leg_l1"], ["leg_r2", "leg_r1"], ["arm_l2", "arm_l1"], ["arm_r2", "arm_r1"]
]
const LOW := 0.12  # a toe this close to its lowest is down (body scale 1)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var def := Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, "adult")
	root.add_child(kaiju)
	await process_frame
	var rig: KaijuRig = kaiju._rig
	var g: ClipGait = rig.gait
	var clips := g.clips
	var spec: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/kaiju/%s.rig.json" % rig.kind)
	)
	var defs: Array = spec["bones"]
	var names: Array[String] = []
	for d: Dictionary in defs:
		names.append(str(d["name"]))
	var vox: VoxelBuilder = Kvox.read("res://assets/kaiju/%s.kvox" % rig.kind).frames[0]
	var local := {}  # bone -> voxel centres in its own frame
	for cell: Vector3i in vox.cells:
		var flag: int = vox.flags.get(cell, 0)
		var name := names[flag]
		if not local.has(name):
			local[name] = PackedVector3Array()
		var list: PackedVector3Array = local[name]
		list.append(Vector3(cell) * rig._voxel + Vector3.ONE * rig._voxel * 0.5 - rig.head_of(name))
		local[name] = list
	var to_rig := rig.global_transform.affine_inverse()
	var across := {}  # the same key -> Vector2(least x, most x)
	var cells := {}  # Vector3i(group, slice, band) -> Vector3(max |x|, lowest, highest)
	for pose_at: Array in POSES:
		_pose(rig, clips, str(pose_at[0]), Num.f(pose_at[1]))
		for name: String in GROUPS:
			var xf := to_rig * rig.bone(name).global_transform
			var list: PackedVector3Array = local.get(name, PackedVector3Array())
			for p: Vector3 in list:
				var w := xf * p
				var group: int = GROUPS[name]
				var key := Vector3i(group, floori(-w.z / SLICE), floori(w.y / BAND))
				var was: Vector3 = cells.get(key, Vector3(0.0, INF, -INF))
				cells[key] = Vector3(maxf(was.x, absf(w.x)), minf(was.y, w.y), maxf(was.z, w.y))
				var span: Vector2 = across.get(key, Vector2(INF, -INF))
				across[key] = Vector2(minf(span.x, w.x), maxf(span.y, w.x))
	var discs: Array = []
	var keys := cells.keys()
	keys.sort()
	var open: Array = []
	var open_key := Vector2i(-1, -1)  # (group, slice) of the disc being stacked
	for key: Vector3i in keys:
		var c: Vector3 = cells[key]
		var r := maxf(c.x, SLICE * 0.5)
		var side := 0.0
		if key.x >= 3:  # an arm: a disc set to its side
			var span: Vector2 = across[key]
			side = (span.x + span.y) * 0.5
			r = maxf((span.y - span.x) * 0.5, SLICE * 0.5)
		var fwd := (key.y + 0.5) * SLICE
		var same := open_key == Vector2i(key.x, key.y)
		if same and absf(Num.f(open[2]) - r) < MERGE and Num.f(open[4]) >= c.y - BAND:
			open[1] = (Num.f(open[1]) + side) * 0.5 if key.x >= 3 else 0.0
			open[2] = maxf(Num.f(open[2]), r)
			open[4] = c.z
			continue
		if not open.is_empty():
			discs.append(open)
		open = [fwd, side, r, c.y, c.z, mini(key.x, 2) if key.x < 3 else 0]
		open_key = Vector2i(key.x, key.y)
	discs.append(open)
	for d: Array in discs:
		for k: int in 5:
			d[k] = snappedf(Num.f(d[k]), 0.01)
	print("BODY_DISCS %d %s" % [discs.size(), JSON.stringify(discs)])
	print("PIVOTS neck %.2f skull %.2f" % [-rig.head_of("head0").z, -rig.head_of("head1").z])
	var n := clips.frames_of("walk")
	var feet: Array = []
	for foot: Array in FEET:
		var toes: Array[Vector3] = []
		var knees: Array[Vector3] = []
		for f: int in n:
			_pose(rig, clips, "walk", f)
			toes.append(to_rig * rig.tail_world(str(foot[0])))
			knees.append(to_rig * rig.bone(str(foot[1])).global_position)
		var low := INF
		for t: Vector3 in toes:
			low = minf(low, t.y)
		var land := -1
		var lift := -1
		for f: int in n:
			var down := toes[f].y < low + LOW
			var before := toes[(f + n - 1) % n].y < low + LOW
			if down and not before:
				land = f
			if before and not down:
				lift = f
		_pose(rig, clips, "walk", land)
		var xf := to_rig * rig.bone(str(foot[0])).global_transform
		var pts: PackedVector3Array = local.get(str(foot[0]), PackedVector3Array())
		var mid := Vector3.ZERO
		for p: Vector3 in pts:
			mid += xf * p
		mid /= maxf(1.0, pts.size())
		var size := 0.0  # half its width across
		var front := 0.0  # half its length
		var top := -INF
		for p: Vector3 in pts:
			var w := xf * p
			size = maxf(size, absf(w.x - mid.x))
			front = maxf(front, absf(w.z - mid.z))
			top = maxf(top, w.y)
		var shin := 0.0  # the shin's reach across its own line
		var axis := rig.dir_of(str(foot[1])).normalized()
		for p: Vector3 in local.get(str(foot[1]), PackedVector3Array()):
			shin = maxf(shin, (p - axis * p.dot(axis)).length())
		feet.append(
			[
				land,
				lift,
				snappedf(-mid.z, 0.01),
				snappedf(mid.x, 0.01),
				snappedf(size, 0.01),
				snappedf(top, 0.01),
				snappedf(shin, 0.01),
				snappedf(rig.head_of(str(foot[1]).replace("1", "0")).y, 0.01),
				snappedf(front, 0.01)
			]
		)
	print("FEET %s" % JSON.stringify(feet))
	print("WALK %d land %.1f" % [n, g._steps.land])
	quit()


func _pose(rig: KaijuRig, clips: KaijuClips, clip: String, t: float) -> void:
	var pose := clips.pose_at(clip, t)
	for i: int in clips.bones.size():
		var off := pose.offset * clips.rig_scale if i == 0 else Vector3.ZERO
		rig.pose_basis(clips.bones[i], Basis(pose.turns[i]), off)
